from subprocess import *
import math
from sys import argv

KYBER_Q=3329
MOD_BITS=int(math.ceil(math.log(KYBER_Q, 2)))

in_width_list = [2*MOD_BITS]

if len(argv) > 1:
    in_width_list=[]
    for arg in argv[1:]:
        in_width_list.append(int(arg))

for G_IN_WIDTH in in_width_list:
    XXX = G_IN_WIDTH  # (2*MOD_BITS)-5
    s =  (2**XXX // KYBER_Q) # % KYBER_Q
    const_mults=[(s, G_IN_WIDTH - MOD_BITS + 1), ( KYBER_Q, MOD_BITS+2)]  #min(G_IN_WIDTH - MOD_BITS, MOD_BITS + 1))]
    for n, inWidth in const_mults:
        print("generating constant multiplier for n={} and inW={}".format(n, inWidth))
        name = "ConstMult_{}_{}".format(n, inWidth)
        cmd="flopoco outputFile={}.vhdl name={} frequency=0 generateFigures=1 plainVhdl=0 useHardMult=0 IntConstMult wIn={} n={}".format(name, name, inWidth, n).split()
        proc = Popen(cmd)
        if proc.wait() != 0:
            print("Running command failed: cmd=", cmd)
