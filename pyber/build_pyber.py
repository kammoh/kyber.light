from cffi import FFI
from pathlib import Path
ffibuilder = FFI()
import os

#print("Path(__file__)=", os.path.abspath(__file__))
src_path = Path('/Users/kamyar/source/pqc/kyber/ref') #Path(__file__).parents[1].joinpath('kyber','ref')
assert src_path.exists(), f"{src_path} does not exist"

ffibuilder.cdef(
"""
    #define KYBER_N 256
    #define KYBER_K 3
    #define KYBER_Q ...
    #define KYBER_ETA ...
    
    typedef struct{
        uint16_t coeffs[KYBER_N];
    } poly;

    typedef struct{
        poly vec[KYBER_K];
    } polyvec;


    void polyvec_nega_mac(poly *r, const polyvec *a, const polyvec *b, int neg);
""")

sources=[str(src) for src in src_path.glob("*.c") if src.name not in ["PQCgenKAT_kem.c", 'testvectors.c', 'kex.c', 'PQCgenKAT_encrypt.c', 'speed.c', 'test_kex.c', 'rng.c', 'precomp.gp.c']  ]

print(sources)

ffibuilder.set_source("_pyber",
f"""
    #include "{src_path}/poly.h"
    #include "{src_path}/polyvec.h"
""" +
"""

""",
    sources=sources,
    #[ str(src_path.joinpath(src)) for src in  ['reduce.c', 'precomp.c', 'ntt.c', 'cbd.c', 'poly.c', 'polyvec.c']],
    # libraries=['m']
    )

if __name__ == "__main__":
    ffibuilder.compile(verbose=True)