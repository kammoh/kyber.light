import random
import logging
import math
from collections.abc import Iterable
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
from cocotb.log import SimLog
from cocotb.generators.byte import random_data, get_bytes
from cocotb.handle import ModifiableObject


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

    def __init__(self, entity, name, clock, **kwargs):
        # config = kwargs.pop('config', {})
        ValidatedBusDriver.__init__(entity=entity, name=name, clock=clock, **kwargs)
        self.config = self._default_config.copy()

        self.clock = clock


        word = BinaryValue(n_bits=len(self.bus.data))

        word.binstr = ("x"*len(self.bus.data))

        self.bus.valid <= 0
        self.bus.data <= word


    @cocotb.coroutine
    def _wait_ready(self):
        """Wait for a ready cycle on the bus before continuing.

            Can no longer drive values this cycle...
        """
        rdonly = ReadOnly()
        # clkedge = RisingEdge(self.clock)
        yield rdonly
        ready = self.bus.ready
        while ready.value != 1:
            yield Edge(ready)
            yield rdonly

    @cocotb.coroutine
    def _send_bytes(self, byte_string, sync=True):
        """Args:
            byte_string (bytes): A string of hex to send over the bus.
        """
        self.log.info(f"send_bytes: sending {len(byte_string)}")
        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)

        bus_width = len(self.bus.data) // 8

        word = BinaryValue(n_bits=len(self.bus.data),
                           bigEndian=self.config['firstSymbolInHighOrderBits'])
        self.bus.valid <= 0

        while len(byte_string) > 0:
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
    def _send_bin_string(self, bin_string, sync=True):
        """Args:
            bin_string (str): A binary string to serialize and send.
            serializes from right most (highest index in string) as the LSB
        """
        self.log.debug(f"sending bin_string: {len(bin_string)} bits")

        clkedge = RisingEdge(self.clock)
        bus_width = len(self.bus.data)
        word = BinaryValue(n_bits=len(self.bus.data))
        firstword = True

        while len(bin_string) > 0:
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
            
            bits_to_send = min(len(bin_string), bus_width)

            word.binstr = "0"*(bus_width - bits_to_send) + \
                bin_string[-bits_to_send:]

            bin_string = bin_string[0:len(bin_string) -bits_to_send]

            self.log.debug(f"sending {word}")

            self.bus.valid <= 1
            self.bus.data <= word
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
        self.log.debug(f"_send_iterable : words_iterable={words_iterable}")
        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        firstword = True

        for word in words_iterable:
            if not firstword or (firstword and sync):
                self.log.debug("_send_iterable: yielding 1 clock")
                yield clkedge
                firstword = False
            # Insert a gap where valid is low
            if not self.on:
                self.bus.valid <= 0
                self.log.debug(f"_send_iterable: yielding {self.off} off cycles")
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
        # if isinstance(pkt, bytes):
        #     if len(self.bus.data) % 8 != 0:
        #         self.log.info("_driver_send: self.bus.data) is not multiple of 8")
        #         raise TestError
        #     self.log.info("Sending packet of length %d bytes" % len(pkt))
        #     self.log.info(hexdump(pkt))
        #     yield self._send_bytes(pkt, sync=sync)
        #     # self.log.info(
        #     #     "Successfully sent packet of length %d bytes" % len(pkt))
        # elif isinstance(pkt, str):
        #     yield self._send_bin_string(pkt, sync=sync)
        # el
        if isinstance(pkt, Iterable):
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

        BusMonitor.__init__(self, *args, **kwargs)

        self.on = True
        self.off = False

        self.config = self._default_config.copy()

        for configoption, value in config.items():
            self.config[configoption] = value
            self.log.debug("Setting config option %s to %s" %
                           (configoption, str(value)))

        self.on, self.off = True, False
        
        self.num_expected_words = kwargs.pop('num_expected_words', None)
        self.ready_generator = kwargs.pop('ready_generator', None)

    def set_ready_generator(self, ready_generator):
        """Set a new ready generator for this bus."""
        self.ready_generator = ready_generator
        self._next_readys()

    def _next_readys(self):
        self.on = False

        if self.ready_generator is not None:
            while not self.on:
                try:
                    self.on, self.off = next(self.ready_generator)
                except StopIteration:
                    self.on = True
                    self.log.info("Ready generator exhausted, not inserting "
                                  "non-ready cycles anymore")
                    return

            self.log.debug("Will be on for %d cycles, off for %s" %
                           (self.on, self.off))
        else:
            # Valid every clock cycle
            self.on, self.off = True, False
            self.log.debug("Not using ready generator")


    @cocotb.coroutine
    def _monitor_recv(self):
        """Watch the pins and reconstruct transactions."""

        # Avoid spurious object creation by recycling
        clkedge = RisingEdge(self.clock)
        rdonly = ReadOnly()

        words = []

        # for s in ['data', 'valid', 'ready']:
        #     if not hasattr(self.bus, s):
        #         self.log.info(f"{self.bus._name} does not have a {s} signal")
        #         # raise TestError
        #     else:
        #         self.log.info(f"{s} is in {self.bus._name} ({ getattr(self.bus, s)._name})")

        self.bus.ready <= 0

        yield clkedge

        self.bus.ready <= 1

        while True:

            # if self.in_reset:
            #     continue
            if not self.on:
                self.log.debug(f"skipping {self.off} off cycles")
                self.bus.ready <= 0
                for _ in range(self.off):
                    yield clkedge
                self.bus.ready <= 1
                # Grab the next set of on/off values
                self._next_readys()
            # Consume a valid cycle
            if self.on is not True and self.on:
                self.on -= 1

            yield rdonly

            while self.bus.valid.value != 1:
                yield Edge(self.bus.valid)
            
            # self.log.info(f"received {self.bus.data.value} {len(words)}/{self.num_expected_words} on {self.name}")
            words.append(int(self.bus.data.value))
                # self.log.debug(f"received word {len(words)}{self.num_out_words} ")
            if self.num_expected_words and len(words) >= self.num_expected_words:
                self.log.debug(f"transaction complete: {self.num_expected_words} words")
                self._recv(words)
                words = []

            yield clkedge


class ValidReadyTester(object):
    def __init__(self, dut, clock, **kwargs):
        """
            parameters:
            @dut:
            clock:
            input_name: name of the input bus. Signals of the bus will be <input_name>_{data, valid, ready}
            output_name:
        """
        self.dut = dut
        self.log = SimLog("cocotb.%s" % dut._name)
        self.clock = clock
        self.keep_waiting = True

        self.inports = {}
        self.outports = {}
        self.inoutports = {}
        for thing_ in dut:
            if isinstance(thing_, ModifiableObject) and thing_._is_port:
                if thing_._port_direction == 1:
                    self.inports[thing_._name] = thing_
                elif thing_._port_direction == 2:
                    self.outports[thing_._name] = thing_
                else:
                    self.inoutports[thing_._name] = thing_
        
        self.drivers = {}
        self.monitors = {}

        self.scoreboard = Scoreboard(self.dut, reorder_depth=0, fail_immediately=True)
        self.log.info("created scoreboard")
        
        self.rnd = random.Random()
        self.rnd.seed(kwargs.get('seed', None))

        self.valid_generator = kwargs.get('valid_generator', None)
        self.ready_generator = kwargs.get('ready_generator', None)

        self.clk_period = kwargs.get('clk_period', 10)
        self.clk_thread = cocotb.fork(Clock(self.clock, self.clk_period, 'ns').start())

        cocotb.fork(self.reset())

        self.log.info("ValidReadyTester initialized")

    @property
    def result(self):
        return self.scoreboard.result

    @cocotb.coroutine
    def drive_input(self, in_bus_name, in_words, valid_generator=None):
        if not valid_generator:
            valid_generator = self.valid_generator
        if in_bus_name not in self.drivers:
            self.drivers[in_bus_name] = ValidReadyDriver(self.dut, in_bus_name, self.clock)
        if valid_generator:
            self.drivers[in_bus_name].set_valid_generator(valid_generator())

        yield self.drivers[in_bus_name].send(in_words)

    def expect_output(self, out_bus_name, expected_output, ready_generator=None):
        if not ready_generator:
            ready_generator = self.ready_generator
        if out_bus_name in self.monitors:
            monitor, queue = self.monitors[out_bus_name]
        else:
            self.log.debug(f"adding monitor on {out_bus_name}")
            monitor = ValidReadyMonitor(self.dut, out_bus_name, self.clock)  # , callback=self.model
            queue = []
            self.monitors[out_bus_name] = (monitor, queue)
            self.log.debug(f"monitor added {out_bus_name}")
            
            self.scoreboard.add_interface(monitor, queue, strict_type=True)

        queue.append(expected_output)
        monitor.set_ready_generator(ready_generator)
        monitor.num_expected_words = len(expected_output)
        self.log.info(f"expecting {len(expected_output)} bytes on bus: {out_bus_name}")

    # TODO only checks right now, FIXME later
    def check_bus(self, bus_name, is_input):
        found = False
        data = None
        valid = None
        ready = None
        for in_fix, out_fix in [('i', 'o'), ('in', 'out')]:
            for fmt in ['{bus_name}_{p}', '{fix}_{bus_name}_{p}', '{bus_name}_{p}_{fix}']:
                if is_input:
                    dv_fix = in_fix
                    r_fix = out_fix
                    dv_list = self.inports
                    r_list = self.outports
                else:
                    dv_fix = out_fix
                    r_fix = in_fix
                    dv_list = self.outports
                    r_list = self.inports
                try:
                    data = dv_list[fmt.format(bus_name=bus_name, p='data', fix=dv_fix)]
                    valid = dv_list[fmt.format(bus_name=bus_name, p='valid', fix=dv_fix)]
                    ready = r_list[fmt.format(bus_name=bus_name, p='ready', fix=r_fix)]
                    found = True
                    break
                except:
                    continue
            if found:
                break

        if not found:
            self.log.error(f"{bus_name} bus signals not found")
            raise TestError
        return (data, valid, ready)

    @cocotb.coroutine
    def wait_transaction(self):
            
        clkedge = RisingEdge(self.clock)
        while self.keep_waiting:
            yield clkedge
        # re-arm
        self.keep_waiting = True

    def model(self, transaction):
        """ Verify the transaction usnig golden model """
        # if not transaction or len(transaction) < self.nwords:
        # raise TestError("empty transaction passed to model")
        self.log.info("model:")
        self.log.info(f"len(transaction)={len(transaction)}")
        self.keep_waiting = False

    @cocotb.coroutine
    def reset(self):
        self.log.debug("Resetting DUT")
        self.dut.rst <= 1
        yield RisingEdge(self.clock)
        yield RisingEdge(self.clock)
        self.dut.rst <= 0
        yield FallingEdge(self.clock)
        self.log.debug("Out of reset")


class CmdDoneTester(ValidReadyTester):
    def __init__(self, dut, clock, **kwargs):
        """ init """
        done_sig_name = kwargs.pop('done_signal', 'o_done')
        ValidReadyTester.__init__(dut, clock, **kwargs)
        if not done_sig_name in self.outports:
            self.log.error(f"{done_sig_name} is not an output port of DUT")
            raise TestError
        self.done_signal = getattr(dut, done_sig_name)

    # def register_commands(self, commands_dict):
    #     for cmd, signals in commands_dict.items():
    #         if not isinstance(signals, list):
    #             signals = [signals]
    #         for sig in signals:
    #             sig <= 0
    #         self.log.info(f'registered command: {cmd} signal(s): {[str(s._name) for s in signals]}')

    @cocotb.coroutine
    def wait_for_done(self, value=1):
        done = self.done_signal
        while done.value != value:
            yield Edge(done)

    # @cocotb.coroutine
    # def command(self, cmd, input=None):
    #     if not isinstance(cmd, list):
    #         cmd = [cmd]

    #     cmd = [ self.commands_dict[c] if isinstance(c, str) else c for c in cmd ]

    #     yield self.wait_for_done(value=0)

    #     for s in cmd:
    #         self.log.info(f"command: {s._name}")
    #         s <= 1

    #     if input:
    #         self.log.debug(f"len(input)={len(input)}")
    #         yield self.stream_in.send(input)

    #     self.log.info("waiting for done...")
    #     yield self.wait_for_done()
    #     self.log.info(">> received done")
    #     # deassert all
    #     for s in cmd:
    #         s <= 0
    #     yield RisingEdge(self.clock)
