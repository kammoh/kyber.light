import subprocess
from math import log2, ceil



def reciprocal(d, w):
    beta = 2**w
    return (beta**2 - 1) // d - beta
    

def gen_recipt_mult(q):
    q_bits = ceil(log2(q))
    v = reciprocal(q, q_bits)
    print(f"reciprocal({q}) = {v}")
    name = f'ConstMult_{v}_{q_bits}_{q_bits}'
    subprocess.run(
        f'flopoco IntConstMult wIn={q_bits} wOut={q_bits} n={v} name={name} frequency=0 outputFile={name}.vhdl'.split())

def gen_mult(q):
    q_bits = ceil(log2(q))
    name = f'ConstMult_{q}_{q_bits}_{q_bits}'
    subprocess.run(
        f'flopoco IntConstMult wIn={q_bits} wOut={q_bits} n={q} name={name} frequency=0 outputFile={name}.vhdl'.split())
    
def gen_mult_decomp(q):
    if q == 3329:
        polyvec_shift = 10
    else:
        polyvec_shift = 11
    q_bits = ceil(log2(q))
    name = f'ConstMult_{q}_{polyvec_shift}_{polyvec_shift + q_bits}'
    subprocess.run(
        f'flopoco IntConstMult wIn={polyvec_shift} wOut={polyvec_shift + q_bits} n={q} name={name} outputFile=./vhdl/{name}.vhdl'.split())


# gen_recipt_mult(7681)
# gen_recipt_mult(3329)
# gen_mult(3329)
gen_mult_decomp(3329)
