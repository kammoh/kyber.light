import pyber
from pyber import KYBER_SYMBYTES, KYBER_INDCPA_MSGBYTES, atpk_bytes, compressed_pk_bytes
from pathlib import Path
import subprocess
from cocorun.conf import Manifest
from cocorun.sim.ghdl import Ghdl
from itertools import zip_longest
from random import randint

coins = [randint(0, 0xff) for _ in range(KYBER_SYMBYTES)]  # [i & 0xff for i in range(KYBER_SYMBYTES)]
pk = [randint(0, 0xff) for i in range(compressed_pk_bytes())]
atpk = list(atpk_bytes(pk))
msg = [randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
exp = list(pyber.indcpa_enc_nontt(msg, atpk, coins))
exp_str = [hex(e)[2:].zfill(2) for e in exp]

print(f'exp={exp_str}')

with Path("pk.in.txt").open('w') as fi:
    for x in atpk:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

with Path("pt.in.txt").open('w') as fi:
    for x in msg:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

with Path("coins.in.txt").open('w') as fi:
    for x in coins:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

manifest = Manifest.load_from_file()
sim = Ghdl(manifest, log_level='INFO')
sim.run_test('cpa_tb', elab_only=True)

# subprocess.run(['./cpa_tb', '--wave=enc_tb.ghw', '--ieee-asserts=disable'])
subprocess.run(['./cpa_tb', '--ieee-asserts=disable'])

with Path('ct.out.txt').open('r') as outfile:
    out = [ line.strip().lower() for line in outfile.readlines()]
    if len(out) != len(exp):
        print(f"[ERROR] expected {len(exp)} words but received {len(out)} words")
    for i, (e, o) in enumerate(zip_longest(exp_str, out)):
        if e != o:
            print(f"[ERROR] @output #{i:>4}  expected: {e}  received: {o}")
            exit(1)

print("output matched expected output")
