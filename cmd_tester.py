import random
import logging
import cocotb
from cocotb.utils import hexdump
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue, TestError
from cocotb.drivers import BusDriver, ValidatedBusDriver
from cocotb.monitors import BusMonitor
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ReadOnly, NextTimeStep, Event
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.generators.bit import (
    wave, intermittent_single_cycles, random_50_percent)
from cocotb.generators.byte import random_data, get_bytes
import math
import pyber
from handle import ModifiableObject
from pyber import *
from collections.abc import Iterable


def get_words(nwords, generator):
    result = []
    for _ in range(nwords):
        result.append(next(generator))
    return result


class ValidReadyProtocolError(Exception):
    pass


class ValidReadyDriver(ValidatedBusDriver):
    """Valid-Ready stream Driver"""

    _signals = ["valid", "data", "ready"]

    _default_config = {
        "firstSymbolInHighOrderBits": True,
    }

    def __init__(self, *args, **kwargs):
        config = kwargs.pop('config', {})
        ValidatedBusDriver.__init__(self, *args, **kwargs)
        self.config = ValidReadyDriver._default_config.copy()

        for configoption, value in config.items():
            self.config[configoption] = value
            self.log.debug("Setting config option %s to %s" %
                           (configoption, str(value)))

        word = BinaryValue(n_bits=len(self.bus.data),
                           bigEndian=self.config['firstSymbolInHighOrderBits'])

        single = BinaryValue(n_bits=1, bigEndian=False)

        word.binstr = ("x"*len(self.bus.data))
        single.binstr = ("x")

        self.bus.valid <= 0
        self.bus.data <= word


    @cocotb.coroutine
    def _wait_ready(self):
        """Wait for a ready cycle on the bus before continuing.

            Can no longer drive values this cycle...
        """
        rdonly = ReadOnly()
        clkedge = RisingEdge(self.clock)
        yield rdonly
        while not self.bus.ready.value:
            yield clkedge
            yield rdonly

    @cocotb.coroutine
    def _send_bytes(self, byte_string, sync=True):
        """Args:
            byte_string (bytes): A string of hex to send over the bus.
        """
        self.log.info(f"send_butes {len(byte_string)}")
        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)

        bus_width = len(self.bus.data) // 8

        word = BinaryValue(n_bits=len(self.bus.data),
                           bigEndian=self.config['firstSymbolInHighOrderBits'])
        self.bus.valid <= 0

        while len(byte_string) > 0:
            yield clkedge
            # Insert a gap where valid is low
            if not self.on:
                self.bus.valid <= 0
                for _ in range(self.off):
                    yield clkedge
                # Grab the next set of on/off values
                self._next_valids()

            # Consume a valid cycle
            if self.on is not True and self.on:
                self.on -= 1

            self.bus.valid <= 1
            n_bytes_to_send = min(len(byte_string), bus_width)
            data = byte_string[:n_bytes_to_send]
            word.buff = data

            if n_bytes_to_send >= bus_width:
                byte_string = byte_string[bus_width:]
                self.bus.data <= word
            else:
                byte_string = b""

            yield self._wait_ready()

        yield clkedge
        self.bus.valid <= 0
        word.binstr = ("x"*len(self.bus.data))
        self.bus.data <= word

    @cocotb.coroutine
    def _send_iterable(self, words_iterable, sync=True):
        """Args:
            words_iterable (iterable): Will yield words of input data.
        """
        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        firstword = True

        for word in words_iterable:
            if not firstword or (firstword and sync):
                yield clkedge
                firstword = False

            # Insert a gap where valid is low
            if not self.on:
                self.bus.valid <= 0
                for _ in range(self.off):
                    yield clkedge

                # Grab the next set of on/off values
                self._next_valids()

            # Consume a valid cycle
            if self.on is not True and self.on:
                self.on -= 1

            self.bus.valid <= 1
            self.bus.data <= word
            yield self._wait_ready()

        yield clkedge
        self.bus.valid <= 0

    @cocotb.coroutine
    def _driver_send(self, pkt, sync=True):
        dut = self.entity
        if isinstance(pkt, bytes):
            assert len(self.bus.data) % 8 == 0
            dut._log.info("Sending packet of length %d bytes" % len(pkt))
            dut._log.info(hexdump(pkt))
            yield self._send_bytes(pkt, sync=sync)
            dut._log.info(
                "Successfully sent packet of length %d bytes" % len(pkt))
        elif isinstance(pkt, str):
            dut._log.error('TODO not implemented <<< hex string')
        elif isinstance(pkt, Iterable):
            yield self._send_iterable(pkt, sync=sync)
        else:
            self.log.error("Unknown data to send")
            raise TestError


class ValidReadyMonitor(BusMonitor):
    _signals = ["valid", "data", "ready"]

    _default_config = {
        "firstSymbolInHighOrderBits": True,
    }

    def __init__(self, *args, **kwargs):
        config = kwargs.pop('config', {})
        self.num_out_words = kwargs.pop('num_out_words', 1)
        BusMonitor.__init__(self, *args, **kwargs)

        self.config = self._default_config.copy()

        for configoption, value in config.items():
            self.config[configoption] = value
            self.log.debug("Setting config option %s to %s" %
                           (configoption, str(value)))

    @cocotb.coroutine
    def _monitor_recv(self):
        """Watch the pins and reconstruct transactions."""

        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        rdonly = ReadOnly()

        def fire():
            return self.bus.valid.value and self.bus.ready.value

        words = []

        while True:
            yield clkedge
            yield rdonly

            if self.in_reset:
                continue

            if fire():
                words.append(self.bus.data.value)
                self.log.debug(f"received words {len(words)}/{self.num_out_words} ")
                if len(words) >= self.num_out_words:
                    self._recv(words)
                    words = []


class CmdDoneTester(object):
    def __init__(self, dut, input_name, output_name, num_out_words, valid_gen=None, debug=False, seed=None, clk_period=10):
        self.dut = dut
        self.log = dut._log

        for thing_ in dut:
            if isinstance(thing_, ModifiableObject) and thing_._is_port:
                self.log.info(f"port {thing_._name} dir: {thing_._port_direction_string}")
        

        self.nwords = num_out_words
        self.stream_in = ValidReadyDriver(dut, input_name, dut.clk)
        self.stream_out = ValidReadyMonitor(
            dut, output_name, dut.clk, num_out_words=num_out_words, callback=self.model)

        self.expected_output = []
        self.scoreboard = Scoreboard(dut)
        self.scoreboard.add_interface(
            self.stream_out, self.expected_output, strict_type=True)
        self.rnd = random.Random()

        self.rnd.seed(seed)

        if valid_gen:
            self.stream_in.set_valid_generator(valid_gen())

        self.output_ready_thread = cocotb.fork(self.gen_output_ready())

        level = logging.DEBUG if debug else logging.INFO
        self.stream_in.log.setLevel(level)
        self.clk_period = clk_period
        self.clk_thread = None
        self.reset_thread = None

    @cocotb.coroutine
    def start(self):
        self.clk_thread = cocotb.fork(Clock(self.dut.clk, self.clk_period, 'ns').start())
        yield self.reset()

    def model(self, transaction):
        """Model the DUT based on the input transaction"""

        # if not transaction or len(transaction) < self.nwords:
        # raise TestError("empty transaction passed to model")

        self.log.info("model:")
        self.log.info(f"len(transaction)={len(transaction)}")

    @cocotb.coroutine
    def gen_output_ready(self):
        edge = RisingEdge(self.dut.clk)
        while True:
            self.stream_out.bus.ready <= self.rnd.randrange(2)
            yield edge

    @cocotb.coroutine
    def wait_for_done(self, value=1):
        done = self.dut.o_done
        while done != value:
            yield Edge(done)

    @cocotb.coroutine
    def command(self, signals, input=None):
        if not isinstance(signals, list):
            signals = [signals]

        yield self.wait_for_done(value=0)

        for s in signals:
            self.log.info(f"command: {s._name}")
            s <= 1

        if input:
            self.log.debug(f"len(input)={len(input)}")
            yield self.stream_in.send(input)

        self.log.info("waiting for done...")
        yield self.wait_for_done()
        self.log.info(">> received done")
        # deassert all
        for s in signals:
            s <= 0
        yield RisingEdge(self.dut.clk)

    @cocotb.coroutine
    def reset(self):
        self.log.debug("Resetting DUT")
        self.dut.rst <= 1
        yield RisingEdge(self.dut.clk)
        yield RisingEdge(self.dut.clk)
        yield FallingEdge(self.dut.clk)
        self.dut.rst <= 0
        self.log.debug("Out of reset")

