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
from cocotb.regression import TestFactory, TestSuccess, TestError
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cmd_tester import CmdDoneTester, to_hex_str


CMD_RECV_PK = 1
CMD_START_ENC = 2
CMD_RECV_SK = 3
CMD_START_DEC = 4

@cocotb.test()
def cpa_enc_tb(dut, debug=True, enc_dec=(True, False), valid_generator=None, ready_generator=None):
    """
        testbench for CPA encrypt top module
    """
    enc, dec = enc_dec
    tb = CmdDoneTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)

    yield tb.reset()  # important!


    ###
    if tb.dut.DUMMY_NIST_ROUND == 1:
        import pyber
        from pyber import (atpk_bytes, KYBER_INDCPA_PUBLICKEYBYTES, KYBER_Q, KYBER_CIPHERTEXTBYTES, KYBER_INDCPA_SECRETKEYBYTES, KYBER_POLYVECCOMPRESSEDBYTES,
                        KYBER_POLYCOMPRESSEDBYTES, KYBER_INDCPA_MSGBYTES, KYBER_SYMBYTES)

    else:
        import pyber2 as pyber
        from pyber2 import (atpk_bytes, KYBER_INDCPA_PUBLICKEYBYTES, KYBER_Q, KYBER_CIPHERTEXTBYTES, KYBER_INDCPA_SECRETKEYBYTES, KYBER_POLYVECCOMPRESSEDBYTES,
                            KYBER_POLYCOMPRESSEDBYTES, KYBER_INDCPA_MSGBYTES, KYBER_SYMBYTES)
    ###
    clkedge = RisingEdge(dut.clk)

    dut.i_command <= 0

    yield clkedge

    pk, sk = pyber.indcpa_keypair()

    rsk = pyber.repack_sk_nontt(sk)

    msg = [tb.rnd.randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
    coins = [tb.rnd.randint(0, 0xff) for i in range(KYBER_SYMBYTES)]

    ct = list(pyber.indcpa_enc(msg, pk, coins))

    msg1 = list(pyber.indcpa_dec(ct, sk))

    assert msg == msg1

    atpk = list(atpk_bytes(pk))

    if enc:
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
        try:
            raise tb.scoreboard.result
        except TestSuccess:
            tb.log.info("Enc PASSED!")
            pass

    
    if dec:
        # This should come first!
        tb.expect_output('sdo', msg)
        if debug:
            print(f"expecting: msg = {to_hex_str(msg)}")

        tb.log.info("sending SK")
        if debug:
            print(f"repacked sk: {to_hex_str(rsk)}")
        dut.i_command <= CMD_RECV_SK
        yield tb.drive_input('sdi', rsk)

        print("waiting for done...")
        yield tb.wait_for_done()
        yield clkedge  # optional
        dut.i_command <= 0
        yield clkedge  # optional

        tb.log.info("sending [CMD_START_DEC]")
        dut.i_command <= CMD_START_DEC

        tb.log.info("sending ciphertext")
        if debug:
            print(f"ciphertext: {to_hex_str(ct)}")
        yield tb.drive_input('pdi', ct)

        tb.log.info("waiting for done")
        yield tb.wait_for_done()

        dut.i_command <= 0

        yield clkedge  # optional
        
        try:
            raise tb.scoreboard.result
        except TestSuccess:
            tb.log.info("Dec PASSED!")
            pass
        
        yield clkedge  # optional
        yield clkedge  # optional



# Tests
# factory = TestFactory(cpa_enc_tb)

# # # Test configs
# factory.add_option("valid_generator", [intermittent_single_cycles, random_50_percent])
# factory.add_option("ready_generator", [intermittent_single_cycles, random_50_percent])
# factory.add_option("enc_dec", [(True, False), (False, True), (True, True) ])

# factory.generate_tests()
