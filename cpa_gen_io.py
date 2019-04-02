import pyber
from pyber import KYBER_SYMBYTES, KYBER_INDCPA_MSGBYTES, atpk_bytes, compressed_pk_bytes
from pathlib import Path
import subprocess
from cocorun.conf import Manifest
from cocorun.sim.ghdl import Ghdl


coins = [i & 0xff for i in range(KYBER_SYMBYTES)]
pk = [i & 0xff for i in range(compressed_pk_bytes())]
atpk = list(atpk_bytes(pk))
msg = [i & 0xff for i in range(KYBER_INDCPA_MSGBYTES)]
exp = list(pyber.indcpa_enc_nontt(msg, atpk, coins))
# exit(1)

print(f'exp={[hex(e)[2:].zfill(2) for e in exp]}')


with Path("in.txt").open('w') as fi:
    for x in atpk + msg:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

with Path("coins.txt").open('w') as fi:
    for x in coins:
        fi.write(f"{hex(x)[2:].zfill(2)}\n")

manifest = Manifest.load_from_file()
sim = Ghdl(manifest, log_level='INFO')
sim.run_test('cpa_tb', elab_only=True)
subprocess.run(['./cpa_tb', '--wave=enc_tb.ghw', '--ieee-asserts=disable'])
# subprocess.run(['./cpa_tb', '--ieee-asserts=disable'])
