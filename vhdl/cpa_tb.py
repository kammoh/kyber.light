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
from pyber import atpk_bytes, compressed_pk_bytes
from pyber import (KYBER_CIPHERTEXTBYTES, KYBER_INDCPA_SECRETKEYBYTES, KYBER_POLYVECCOMPRESSEDBYTES,
                   KYBER_POLYCOMPRESSEDBYTES, KYBER_INDCPA_MSGBYTES, KYBER_SYMBYTES)

CMD_RECV_PK = 1
CMD_START_ENC = 2
CMD_RECV_SK = 3
CMD_START_DEC = 4

@cocotb.test()
def cpa_enc_tb(dut, debug=True, valid_generator=intermittent_single_cycles, ready_generator=intermittent_single_cycles):
    """
        testbench for CPA encrypt top module
    """
    tb = CmdDoneTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)

    yield tb.reset()  # important!

    clkedge = RisingEdge(dut.clk)

    dut.i_command <= 0

    yield clkedge

    pk, sk = pyber.indcpa_keypair()

    msg = [tb.rnd.randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
    coins = [tb.rnd.randint(0, 0xff) for i in range(KYBER_SYMBYTES)]

    ct = list(pyber.indcpa_enc(msg, pk, coins))

    atpk = list(atpk_bytes(pk))

    # This should come first!
    tb.expect_output('pdo', ct)
    if debug:
        print(f"expecting: ct = {to_hex_str(ct)}")

    tb.log.info("sending AT+PK")
    if debug:
        print(f"at+pk: {to_hex_str(atpk)}")
    dut.i_command <= CMD_RECV_PK
    yield tb.drive_input('pdi', atpk)

    print("waiting for done...")
    yield tb.wait_for_done()
    yield clkedge  # optional
    dut.i_command <= 0
    yield clkedge  # optional

    tb.log.info("sending [CMD_START_ENC]")
    tb.log.info("sending coins")
    if debug:
        print(f"coins: {to_hex_str(coins)}")
    dut.i_command <= CMD_START_ENC
    yield tb.drive_input('rdi', coins)

    tb.log.info("sending message")
    if debug:
        print(f"message: {to_hex_str(msg)}")
    yield tb.drive_input('sdi', msg)

    tb.log.info("waiting for done")
    yield tb.wait_for_done()

    dut.i_command <= 0

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
