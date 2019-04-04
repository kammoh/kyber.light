############################################################################################################
##
# @description:  CocoTB testbench for cpa_enc top (KYBER Encrypt)
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.7+, CocoTB 1.1.xnor
# @copyright:    (c) 2019
##
############################################################################################################

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cmd_tester import CmdDoneTester, to_hex_str
import pyber
from pyber import KYBER_SYMBYTES, KYBER_INDCPA_MSGBYTES, atpk_bytes, compressed_pk_bytes


@cocotb.test()
def cpa_enc_tb(dut, debug=True, valid_generator=intermittent_single_cycles, ready_generator=intermittent_single_cycles):
    """
        testbench for CPA encrypt top module
    """
    tb = CmdDoneTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)
    clkedge = RisingEdge(dut.clk)

    dut.i_start_dec <= 0
    dut.i_start_enc <= 0
    dut.i_recv_pk <= 0

    if debug:
        coins = [i & 0xff for i in range(KYBER_SYMBYTES)]
        pk = [i & 0xff for i in range(compressed_pk_bytes())]
        msg = [i & 0xff for i in range(KYBER_INDCPA_MSGBYTES)]
    else:
        coins = [tb.rnd.randint(0, 0xff) for _ in range(KYBER_SYMBYTES)]  # [i & 0xff for i in range(KYBER_SYMBYTES)]
        pk = [tb.rnd.randint(0, 0xff) for i in range(compressed_pk_bytes())]
        msg = [tb.rnd.randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]


    atpk = list(atpk_bytes(pk))
    exp = list(pyber.indcpa_enc_nontt(msg, atpk, coins))

    # This should come first!
    tb.expect_output('ct', exp)
    if debug:
        print(f"expecting: {to_hex_str(exp)}")

    tb.log.info("sending AT+PK")
    if debug:
        print(f"at+pk: {to_hex_str(atpk)}")
    dut.i_recv_pk <= 1
    yield tb.drive_input('pk', atpk)

    print("waiting for done...")
    yield tb.wait_for_done()
    yield clkedge  # optional
    dut.i_recv_pk <= 0
    yield clkedge  # optional

    tb.log.info("sending coins")
    if debug:
        print(f"coins: {to_hex_str(coins)}")
    dut.i_start_enc <= 1
    yield tb.drive_input('rnd', coins)

    tb.log.info("sending message")
    if debug:
        print(f"message: {to_hex_str(msg)}")
    yield tb.drive_input('msg', msg)

    tb.log.info("waiting for done")
    yield tb.wait_for_done()

    dut.i_start_enc <= 0

    yield clkedge  # optional
    yield clkedge  # optional
    yield clkedge  # optional

    raise tb.scoreboard.result


# Tests
# factory = TestFactory(cpa_enc_tb)

# # Test configs
# # factory.add_option("valid_generator", [intermittent_single_cycles, random_50_percent])
# # factory.add_option("ready_generator", [intermittent_single_cycles, random_50_percent])

# factory.generate_tests()
