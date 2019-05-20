# from pyber import KYBER_SYMBYTES, KYBER_INDCPA_MSGBYTES, atpk_bytes, compressed_pk_bytes
import pyber2 as pyber
from pyber2 import (atpk_bytes, KYBER_INDCPA_PUBLICKEYBYTES, KYBER_Q, KYBER_CIPHERTEXTBYTES, KYBER_INDCPA_SECRETKEYBYTES, KYBER_POLYVECCOMPRESSEDBYTES,
                    KYBER_POLYCOMPRESSEDBYTES, KYBER_INDCPA_MSGBYTES, KYBER_SYMBYTES)


from pathlib import Path
import subprocess
from itertools import zip_longest
from random import randint

import random as rnd

pk, sk = pyber.indcpa_keypair()

rsk = pyber.repack_sk_nontt(sk)


with Path("sdi.fobos.txt").open('w') as fi:
    for x in rsk:
        fi.write(f"{hex(x)[2:].zfill(2)}")
    fi.write("\n")



with Path("pdi.fobos.txt").open('w') as fi:
    for i in range(10000):

        msg = [rnd.randint(0, 0xff) for _ in range(KYBER_INDCPA_MSGBYTES)]

        # msg[0] = i

        print(f"msg={msg}")

        coins = [rnd.randint(0, 0xff) for _ in range(KYBER_SYMBYTES)]

        ct = list(pyber.indcpa_enc(msg=msg, pk=pk, coins=coins))
        print(f"ct[0]={ct[0]}")
        msg1 = list(pyber.indcpa_dec(ct, sk))
        assert msg == msg1

        print(f"ct[0]={ct[0]} msg1={msg1[0]} msg={msg[0]}")

        for x in ct:
            fi.write(f"{hex(x)[2:].zfill(2)}")

        fi.write("\n")

