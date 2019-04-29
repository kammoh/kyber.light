# from pyber import KYBER_SYMBYTES, KYBER_INDCPA_MSGBYTES, atpk_bytes, compressed_pk_bytes
import pyber2 as pyber
from pyber2 import (atpk_bytes, KYBER_INDCPA_PUBLICKEYBYTES, KYBER_Q, KYBER_CIPHERTEXTBYTES, KYBER_INDCPA_SECRETKEYBYTES, KYBER_POLYVECCOMPRESSEDBYTES,
                    KYBER_POLYCOMPRESSEDBYTES, KYBER_INDCPA_MSGBYTES, KYBER_SYMBYTES)


from pathlib import Path
import subprocess
from cocorun.conf import Manifest
from cocorun.sim.ghdl import Ghdl
from itertools import zip_longest
from random import randint

import random as rnd

pk, sk = pyber.indcpa_keypair()

rsk = pyber.repack_sk_nontt(sk)

msg = [rnd.randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
coins = [rnd.randint(0, 0xff) for i in range(KYBER_SYMBYTES)]

ct = list(pyber.indcpa_enc(msg, pk, coins))

msg1 = list(pyber.indcpa_dec(ct, sk))

assert msg == msg1

# coins = [randint(0, 0xff) for _ in range(KYBER_SYMBYTES)]  # [i & 0xff for i in range(KYBER_SYMBYTES)]
# pk = [randint(0, 0xff) for i in range(compressed_pk_bytes())]
# atpk = list(atpk_bytes(pk))
# msg = [randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
# exp = list(pyber.indcpa_enc_nontt(msg, atpk, coins))
exp = msg
exp_str = [hex(e)[2:].zfill(2) for e in exp]

print(f'exp={exp_str}')

with Path("sdi.in.txt").open('w') as fi:
    for x in rsk:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

with Path("pdi.in.txt").open('w') as fi:
    for x in ct:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

# with Path("coins.in.txt").open('w') as fi:
#     for x in coins:
#         fi.write(f"{hex(x)[2:].zfill(2)}\n")

manifest = Manifest.load_from_file()
sim = Ghdl(manifest, log_level='INFO')
sim.run_test('cpa_tb', elab_only=True)

# subprocess.run(['./cpa_tb', '--wave=enc_tb.ghw', '--ieee-asserts=disable'])
subprocess.run(['./cpa_tb', '--ieee-asserts=disable'])

with Path('sdo.out.txt').open('r') as outfile:
    out = [ line.strip().lower() for line in outfile.readlines()]
    if len(out) != len(exp):
        print(f"[ERROR] expected {len(exp)} words but received {len(out)} words")
    for i, (e, o) in enumerate(zip_longest(exp_str, out)):
        if e != o:
            print(f"[ERROR] @output #{i:>4}  expected: {e}  received: {o}")
            exit(1)

print("output matched expected output")
