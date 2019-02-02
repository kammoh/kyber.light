############################################################################################################
##
# @description:  CocoTB testbench for polyvec_mac
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.5+, CocoTB 1.1+
# @copyright:    (c) 2019
##
############################################################################################################
import random
import logging
import cocotb
from cocotb.utils import hexdump
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue, TestError
from cocotb.drivers import BusDriver, ValidatedBusDriver
from cocotb.monitors import BusMonitor
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, NextTimeStep, Event
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.decorators import coroutine
from cocotb.generators.bit import (wave, intermittent_single_cycles, random_50_percent)
from cocotb.generators.byte import random_data, random_word, get_bytes, get_words

from pyber.lib import polyvec_nega_mac

class ValidReadyProtocolError(Exception):
    pass

class ValidReadyDriver(ValidatedBusDriver):
    """Valid-Ready stream Driver"""

    _signals = ["valid", "data", "ready"]

    _default_config = {
        "dataBitsPerSymbol": 8,
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

    @coroutine
    def _wait_ready(self):
        """Wait for a ready cycle on the bus before continuing.

            Can no longer drive values this cycle...

            FIXME assumes readyLatency of 0
        """
        yield ReadOnly()
        while not self.bus.ready.value:
            yield RisingEdge(self.clock)
            yield ReadOnly()

    @coroutine
    def _send_bytes(self, byte_string, sync=True):
        """Args:
            byte_string (bytes): A string of hex to send over the bus.
        """
        self.log.info(f"send_butes {len(byte_string)}")
        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        
        bus_width = len(self.bus.data) // 8

        word = BinaryValue(n_bits=len(self.bus.data), bigEndian=self.config['firstSymbolInHighOrderBits'])
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



    @coroutine
    def _send_iterable(self, words_iterable, sync=True):
        """Args:
            words_iterable (iterable): Will yield words of input data.
        """
        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        firstword = True

        bus_width = len(self.bus.data)

        dump_line_width = 140

        dumped_chars = 0

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
            nibles = (bus_width + 3) // 4
            dumped_chars += nibles + 1
            if dumped_chars > dump_line_width:
                print("")
                dumped_chars = nibles + 1
            print(f"{word:0{nibles}X}", end=' ')
            yield self._wait_ready()

        print("")
        yield clkedge
        self.bus.valid <= 0



    @coroutine
    def _driver_send(self, pkt, sync=True):
        dut = self.entity
        if isinstance(pkt, bytes):
            dut.log.info("Sending packet of length %d bytes" % len(pkt))
            dut.log.info(hexdump(pkt))
            yield self._send_bytes(pkt, sync=sync)
            dut.log.info("Successfully sent packet of length %d bytes" % len(pkt))
        elif isinstance(pkt, str):
            dut.log.error('not implemented <<< hex string')
        else:
            yield self._send_iterable(pkt, sync=sync)


class ValidReadyMonitor(BusMonitor):
    _signals = ["valid", "data", "ready"]

    _default_config = {
        "dataBitsPerSymbol"             : 8,
        "firstSymbolInHighOrderBits"    : True,
    }


    def __init__(self, *args, **kwargs):
        config = kwargs.pop('config', {})
        BusMonitor.__init__(self, *args, **kwargs)

        self.config = self._default_config.copy()

        for configoption, value in config.items():
            self.config[configoption] = value
            self.log.debug("Setting config option %s to %s" %
                           (configoption, str(value)))

    def fire(self):
        return self.bus.valid.value and self.bus.ready.value

    @coroutine
    def _monitor_recv(self):
        """Watch the pins and reconstruct transactions."""

        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        rdonly = ReadOnly()
        pkt = ""


        while True:
            yield clkedge
            yield rdonly

            if self.in_reset:
                continue

            if self.fire():
                vec = self.bus.data.value
                vec.big_endian = self.config['firstSymbolInHighOrderBits']
                pkt += vec.buff


class CmdDoneTester(object):
    def __init__(self, dut, input_name, output_name , debug=False):
        self.dut = dut
        self.stream_in  = ValidReadyDriver(dut, input_name, dut.clk)
        self.stream_out = ValidReadyMonitor(dut, output_name, dut.clk)

        self.pkts_sent = 0
        self.expected_output = []
        self.scoreboard = Scoreboard(dut)
        self.scoreboard.add_interface(self.stream_out, self.expected_output)

        # Reconstruct the input transactions from the pins and send them to our 'model'
        self.stream_in_recovered = ValidReadyMonitor(dut, input_name, dut.clk, callback=self.model)

        level = logging.DEBUG if debug else logging.WARNING
        self.stream_in.log.setLevel(level)
        self.stream_in_recovered.log.setLevel(level)


    def model(self, transaction):
        """Model the DUT based on the input transaction"""
        self.expected_output.append(transaction)
        self.pkts_sent += 1

    @cocotb.coroutine
    def wait_for_done(self):
        done = self.dut.o_done
        if done != 1:
            yield RisingEdge(done)

    @cocotb.coroutine
    def transaction(self, input_gen, *signals):
        for s in signals:
            self.dut._log.info(f"transaction: {s._name}")
            s <= 1

        yield RisingEdge(self.dut.clk)

        for input in input_gen or []:
            yield self.stream_in.send(input)

        self.dut._log.info("waiting for done...")
        yield self.wait_for_done()
        self.dut._log.info(">> received done")
        # deassert all 
        for s in signals:
            s <= 0
        yield RisingEdge(self.dut.clk)


    @cocotb.coroutine
    def reset(self):
        self.dut._log.debug("Resetting DUT")
        self.dut.rst <= 1
        yield RisingEdge(self.dut.clk)
        yield RisingEdge(self.dut.clk)
        yield FallingEdge(self.dut.clk)
        self.dut.rst <= 0
        self.dut._log.debug("Out of reset")


@cocotb.coroutine
def run_test(dut, data_in=None, idle_inserter=None):
    clkedge = RisingEdge(dut.clk)
    cocotb.fork(Clock(dut.clk, 5000).start())
    tb = CmdDoneTester(dut, input_name="din", output_name="dout")
    yield tb.reset()
    if idle_inserter:
        tb.stream_in.set_valid_generator(idle_inserter())

    dut.i_recv_a <= 0
    dut.i_recv_b <= 0
    dut.i_recv_r <= 0
    dut.i_do_mac <= 0
    dut.i_send_r <= 0

    yield clkedge

    yield tb.transaction(data_in(3), dut.i_recv_a)
    yield tb.transaction(data_in(3), dut.i_recv_b)
    yield tb.transaction(data_in(1), dut.i_recv_r)
    yield tb.transaction(None, dut.i_do_mac)
    # yield tb.transaction(None, dut.i_send_r)

    for _ in range(2):
        yield clkedge

    raise tb.scoreboard.result

def random_packet_sizes(npackets=4):
    """random string data of a random length"""
    for _ in range(npackets):
        yield get_bytes(256, random_data())

def random_polynomial_vector(dims):
    """polynomial over Z/Q """
    for _ in range(dims):
        yield get_words(256, random_word(0,7681 - 1))

factory = TestFactory(run_test)
factory.add_option("data_in",
                   [random_polynomial_vector])
factory.add_option("idle_inserter",
                   [intermittent_single_cycles])
# factory.add_option("idle_inserter",
#                    [None, wave, intermittent_single_cycles, random_50_percent])
factory.generate_tests()
