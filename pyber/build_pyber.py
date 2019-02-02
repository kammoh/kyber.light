from cffi import FFI
from pathlib import Path
ffibuilder = FFI()

ffibuilder.cdef("""
    #define KYBER_N 256
    #define KYBER_Q 7681
    #define KYBER_K 3

    typedef struct{
        uint16_t coeffs[KYBER_N];
    } poly;

    typedef struct{
        poly vec[KYBER_K];
    } polyvec;


    void polyvec_nega_mac(poly *r, const polyvec *a, const polyvec *b, int neg);
""")

src_path = Path.cwd().parents[1].joinpath('kyber','ref')

assert src_path.exists(), f"{src_path} does not exist"

sources=[str(src) for src in src_path.glob("*.c") if src.name not in ["PQCgenKAT_kem.c", 'testvectors.c', 'kex.c', 'PQCgenKAT_encrypt.c', 'speed.c', 'test_kex.c', 'rng.c', 'precomp.gp.c']  ]

print(sources)

ffibuilder.set_source("_pyber",  # name of the output C extension
f"""
    #include "{src_path}/poly.h"
    #include "{src_path}/polyvec.h"
""",
    sources=sources,
    #[str(src) for src in src_path.glob("*.c") if src.name not in ["PQCgenKAT_kem.c", 'testvectors.c', 'kex.c', 'PQCgenKAT_encrypt.c', 'speed.c', 'test_kex.c', 'rng.c']  ],
    #[ str(src_path.joinpath(src)) for src in  ['reduce.c', 'precomp.c', 'ntt.c', 'cbd.c', 'poly.c', 'polyvec.c']],   # includes pi.c as additional sources
    # libraries=['m']
    )    # on Unix, link with the math library

if __name__ == "__main__":
    ffibuilder.compile(verbose=True)