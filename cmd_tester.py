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
        super().__init__(entity=entity, name=name, clock=clock, **kwargs)
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
            if len(self.bus.data) % 8 != 0:
                dut._log.info("_driver_send: self.bus.data) is not multiple of 8")
                raise TestError
            dut._log.info("Sending packet of length %d bytes" % len(pkt))
            dut._log.info(hexdump(pkt))
            yield self._send_bytes(pkt, sync=sync)
            # dut._log.info(
            #     "Successfully sent packet of length %d bytes" % len(pkt))
        elif isinstance(pkt, str):
            yield self._send_bin_string(pkt, sync=sync)
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

    def __init__(self, entity, name, clock, **kwargs):
        config = kwargs.pop('config', {})
        self.num_out_words = kwargs.pop('num_out_words', 1)
        super().__init__(entity, name, clock, **kwargs)

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
                self.log.debug(f"port {thing_._name} dir: {thing_._port_direction} {thing_._port_direction_string}")
                if thing_._port_direction == 1:
                    self.inports[thing_._name] = thing_
                elif thing_._port_direction == 2:
                    self.outports[thing_._name] = thing_
                else:
                    self.inoutports[thing_._name] = thing_
        
        self.log.debug(f"in ports: {self.inports.keys()}")
        self.log.debug(f"out ports: {self.outports.keys()}")

        input_name = kwargs.pop('input_name', "din")
        output_name = kwargs.pop('output_name', "dout")

        self.log.info("checking signals...")

        for bus_name, is_input in [(input_name, True),  (output_name, False)]:
            found = False
            for in_fix, out_fix in [('i','o'), ('in', 'out')]:
                for fmt in ['{bus_name}_{p}', '{fix}_{bus_name}_{p}', '{bus_name}_{p}_{fix}']:
                    not_found = False
                    for sigs, isin in [('data', is_input), ('valid', is_input), ('ready', not is_input)]:

                        if (isin and fmt.format(bus_name=bus_name, p=sigs, fix=in_fix) not in self.inports) or   \
                        (not isin and fmt.format(bus_name=bus_name, p=sigs, fix=out_fix) not in self.outports):
                            not_found = True
                            break
                    if not not_found:
                        found = True
                        break
                if found:
                    break
            if not found:
                self.log.error(f"{bus_name} bus signals not found")
                raise TestError

        num_out_words = kwargs.get('num_out_words', 1)
        self.stream_in = ValidReadyDriver(dut, input_name, self.clock, **kwargs)
        self.stream_out = ValidReadyMonitor(
            dut, output_name, self.clock, num_out_words=num_out_words, callback=self.model)

        self.expected_output = []
        self.scoreboard = Scoreboard(
            dut, reorder_depth=0, fail_immediately=True)
        self.scoreboard.add_interface(
            self.stream_out, self.expected_output, strict_type=True)
        
        self.rnd = random.Random()
        self.rnd.seed(kwargs.get('seed', None))

        valid_gen = kwargs.get('valid_gen', None)
        if valid_gen:
            self.stream_in.set_valid_generator(valid_gen())

        self.output_ready_thread = cocotb.fork(self.gen_output_ready())

        debug = kwargs.get('debug', None)
        level = logging.DEBUG if debug else logging.INFO
        self.stream_in.log.setLevel(level)
        self.clk_period = kwargs.get('clk_period', 10)
        self.clk_thread = cocotb.fork(
            Clock(self.clock, self.clk_period, 'ns').start())

        cocotb.fork(self.reset())

        self.log.info("ValidReadyTester initialized")

    @property
    def result(self):
        return self.scoreboard.result

    # @cocotb.coroutine
    def set_expected(self, expected_output):
        self.expected_output.clear()
        self.expected_output.append(expected_output)
        if isinstance(expected_output, list):
            self.stream_out.num_out_words = len(expected_output)

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
    def gen_output_ready(self):
        clkedge = RisingEdge(self.clock)
        while True:
            self.stream_out.bus.ready <= self.rnd.randrange(2)
            yield clkedge

    @cocotb.coroutine
    def reset(self):
        self.log.debug("Resetting DUT")
        self.dut.rst <= 1
        yield RisingEdge(self.clock)
        yield RisingEdge(self.clock)
        self.dut.rst <= 0
        yield FallingEdge(self.clock)
        self.log.debug("Out of reset")

    @cocotb.coroutine
    def send_input(self, input):
        yield self.stream_in.send(input)


class CmdDoneTester(ValidReadyTester):
    def __init__(self, dut, clock, **kwargs):
        """ init """
        done_sig_name = kwargs.pop('done_signal', 'o_done')
        super().__init__(dut, clock, **kwargs)
        if not done_sig_name in self.outports:
            self.log.error(f"{done_sig_name} is not an output port of DUT")
            raise TestError
        self.done_signal = getattr(dut, done_sig_name)
        commands_dict = kwargs.pop('commands_dict', None)
        if commands_dict:
            self.register_commands(commands_dict)

    def register_commands(self, commands_dict):
        self.commands_dict = commands_dict
        for cmd, signals in commands_dict.items():
            if not isinstance(signals, list):
                signals = [signals]
            for sig in signals:
                sig <= 0
            self.log.info(f'registered command: {cmd} signal(s): {[str(s._name) for s in signals]}')

    @cocotb.coroutine
    def wait_for_done(self, value=1):
        done = self.done_signal
        while done != value:
            yield Edge(done)

    @cocotb.coroutine
    def command(self, cmd, input=None):
        if not isinstance(cmd, list):
            cmd = [cmd]

        cmd = [ self.commands_dict[c] if isinstance(c, str) else c for c in cmd ]

        yield self.wait_for_done(value=0)

        for s in cmd:
            self.log.info(f"command: {s._name}")
            s <= 1

        if input:
            self.log.debug(f"len(input)={len(input)}")
            yield self.stream_in.send(input)

        self.log.info("waiting for done...")
        yield self.wait_for_done()
        self.log.info(">> received done")
        # deassert all
        for s in cmd:
            s <= 0
        yield RisingEdge(self.clock)
