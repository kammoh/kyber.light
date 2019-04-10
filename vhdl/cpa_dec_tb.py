############################################################################################################
##
# @description:  CocoTB testbench for cpa_dec (KYBER CPA Decrypt top module)
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
from pyber import (KYBER_CIPHERTEXTBYTES, KYBER_INDCPA_SECRETKEYBYTES, KYBER_POLYVECCOMPRESSEDBYTES,
                   KYBER_POLYCOMPRESSEDBYTES, KYBER_INDCPA_MSGBYTES, KYBER_SYMBYTES)


@cocotb.test()
def cpa_enc_tb(dut, debug=True, valid_generator=None, ready_generator=None):
    """
        testbench for CPA encrypt top module
    """
    tb = CmdDoneTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)

    yield tb.reset()  # important!

    clkedge = RisingEdge(dut.clk)

    dut.i_start_dec <= 0
    dut.i_recv_sk <= 0

    pk, sk = pyber.indcpa_keypair()

    msg = [(i & 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
    coins = [tb.rnd.randint(0, 0xff) for i in range(KYBER_SYMBYTES)]

    ct = list(pyber.indcpa_enc(msg, pk, coins))
    msg1 = list(pyber.indcpa_dec(ct, sk))

    assert msg == msg1

    rsk = pyber.repack_sk_nontt(sk)
    ct_bp = ct[:KYBER_POLYVECCOMPRESSEDBYTES]
    assert len(ct_bp) == KYBER_POLYVECCOMPRESSEDBYTES
    ct_v = ct[KYBER_POLYVECCOMPRESSEDBYTES:] 
    assert len(ct_v) == KYBER_POLYCOMPRESSEDBYTES

    exp = list(pyber.indcpa_dec_nontt(ct_bp + ct_v, rsk))
    assert exp == msg, f"exp = {exp} msg={msg}"

    # This should come first!
    tb.expect_output('pt', exp)
    if debug:
        print(f"expecting: {to_hex_str(exp)}")

    tb.log.info("sending SecretKey")
    if debug:
        tb.log.info(f"rsk: {to_hex_str(rsk)}")
    dut.i_recv_sk <= 1
    yield tb.drive_input('sk', rsk)

    tb.log.info("waiting for done...")
    yield tb.wait_for_done()
    yield clkedge  # optional
    dut.i_recv_sk <= 0
    yield clkedge  # optional

    tb.log.info("sending command start_dec")
    dut.i_start_dec <= 1
    tb.log.info("sending ciphertext")

    tb.log.info(f"sending ct_bp: {to_hex_str(ct_bp)}")
    yield tb.drive_input('ct', ct_bp)

    tb.log.info(f"sending ct_v: {to_hex_str(ct_v)}")
    yield tb.drive_input('ct', ct_v)

    tb.log.info("waiting for done")
    yield tb.wait_for_done()

    dut.i_start_dec <= 0

    yield clkedge  # optional
    yield clkedge  # optional

    raise tb.scoreboard.result


## Tests
factory = TestFactory(cpa_enc_tb)

## Test configs
factory.add_option("valid_generator", [intermittent_single_cycles, random_50_percent])
factory.add_option("ready_generator", [intermittent_single_cycles, random_50_percent])

factory.generate_tests()
