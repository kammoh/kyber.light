from cffi import FFI
from pathlib import Path
ffibuilder = FFI()
ffibuilder2 = FFI()
import os

ROOT_DIR = Path(os.path.dirname(os.path.abspath(__file__)))

#print("Path(__file__)=", os.path.abspath(__file__))
# src_path = Path(ROOT_DIR).joinpath('cref')  # Path(__file__).parents[1].joinpath('kyber','ref')
src_path = Path(ROOT_DIR).joinpath('cref')
assert src_path.exists(), f"{src_path} does not exist"


ffibuilder.cdef(
"""
    #define KYBER_N 256
    #define KYBER_K 3
    #define KYBER_SYMBYTES 32
    #define KYBER_Q ...
    #define KYBER_ETA ...
    #define KYBER_INDCPA_BYTES ...
    #define KYBER_POLYBYTES ...
    #define KYBER_POLYVECBYTES ...
    #define KYBER_POLYVECCOMPRESSEDBYTES ...
    #define KYBER_POLYCOMPRESSEDBYTES ...
    #define KYBER_INDCPA_PUBLICKEYBYTES ...
    #define KYBER_INDCPA_MSGBYTES ...
    #define KYBER_PUBLICKEYBYTES ...
    #define KYBER_INDCPA_MSGBYTES ...
    #define KYBER_CIPHERTEXTBYTES ...
    #define KYBER_INDCPA_SECRETKEYBYTES ...
    
    typedef struct{
        uint16_t coeffs[KYBER_N];
    } poly;

    typedef struct{
        poly vec[KYBER_K];
    } polyvec;

    // ADDED FOR TESTING:
    void poly_getnoise_bytes(unsigned char *r, const unsigned char *seed, const unsigned char nonce);

    void cbd(poly *r, const unsigned char *buf); // sizeof(buf) = KYBER_ETA * KYBER_N / 4

    void poly_getnoise(poly *r, const unsigned char *seed, unsigned char nonce);
    void poly_frombytes(poly *r, const unsigned char *a);
    void poly_tobytes(unsigned char *r, const poly *a);
    void poly_frommsg(poly *r, const unsigned char msg[KYBER_SYMBYTES]);
    void poly_tomsg(unsigned char msg[KYBER_SYMBYTES], poly *a);
    void poly_compress(unsigned char *r, const poly *a);
    void poly_decompress(poly *r, const unsigned char *a);
    void poly_ntt(poly *r);
    void poly_invntt(poly *r);
    void poly_add(poly *r, const poly *a, const poly *b);
    void poly_sub(poly *r, const poly *a, const poly *b);

    // added by me:
    void polyvec_nega_mac(poly *r, const polyvec *a, const polyvec *b, int neg);
    void poly_freeze(poly *a);
    void at_pk_frombytes(polyvec *at, polyvec *pkpv, const unsigned char *bytes);
    void repack_at_pk(unsigned char *pk_at_bytes, const unsigned char *pk);
    void indcpa_enc_nontt(unsigned char *c, const unsigned char *m,
                      const unsigned char *pk_at_bytes,
                      const unsigned char *coins);

    void repack_sk_nontt(unsigned char *rsk, const unsigned char *sk);


    void indcpa_dec_nontt(unsigned char *m, const unsigned char *c,
                      const unsigned char *sk);


    int crypto_encrypt(unsigned char *c, unsigned long long *clen,
                   const unsigned char *m, unsigned long long mlen,
                   const unsigned char *pk);
    int crypto_encrypt_open(unsigned char *m, unsigned long long *mlen,
                        const unsigned char *c, unsigned long long clen,
                        const unsigned char *sk);
    int crypto_encrypt_keypair(unsigned char *pk, unsigned char *sk);



    void polyvec_pointwise_acc(poly *r, const polyvec *a, const polyvec *b);
    void polyvec_ntt(polyvec *r);
    void polyvec_invntt(polyvec *r);
    void polyvec_frombytes(polyvec *r, const unsigned char *a);
    void polyvec_tobytes(unsigned char *r, const polyvec *a);
    void polyvec_compress(unsigned char *r, const polyvec *a);
    void polyvec_decompress(polyvec *r, const unsigned char *a);
    void polyvec_add(polyvec *r, const polyvec *a, const polyvec *b);

    void gen_matrix(polyvec *a, const unsigned char *seed, int transposed);

    // modified to non-static
    void pack_pk(unsigned char *r, const polyvec *pk, const unsigned char *seed);
    void unpack_pk(polyvec *pk, unsigned char *seed, const unsigned char *packedpk);
    void pack_sk(unsigned char *r, const polyvec *sk);
    void unpack_sk(polyvec *sk, const unsigned char *packedsk);
    void pack_ciphertext(unsigned char *r, const polyvec *b, const poly *v);
    void unpack_ciphertext(polyvec *b, poly *v, const unsigned char *c);

    void indcpa_keypair(unsigned char *pk, unsigned char *sk);
    void indcpa_enc(unsigned char *c, const unsigned char *m, const unsigned char *pk, const unsigned char *coins);
    void indcpa_dec(unsigned char *m, const unsigned char *c, const unsigned char *sk);
""")

ffibuilder2.cdef(
"""
    #define KYBER_N 256
    #define KYBER_K 3
    #define KYBER_SYMBYTES 32
    #define KYBER_Q ...
    #define KYBER_ETA ...
    #define KYBER_INDCPA_BYTES ...
    #define KYBER_POLYBYTES ...
    #define KYBER_POLYVECBYTES ...
    #define KYBER_POLYVECCOMPRESSEDBYTES ...
    #define KYBER_POLYCOMPRESSEDBYTES ...
    #define KYBER_INDCPA_PUBLICKEYBYTES ...
    #define KYBER_INDCPA_MSGBYTES ...
    #define KYBER_PUBLICKEYBYTES ...
    #define KYBER_INDCPA_MSGBYTES ...
    #define KYBER_CIPHERTEXTBYTES ...
    #define KYBER_INDCPA_SECRETKEYBYTES ...
    
    typedef struct{
        int16_t coeffs[KYBER_N];
    } poly;

    typedef struct{
        poly vec[KYBER_K];
    } polyvec;

    void cbd(poly *r, const unsigned char *buf); // sizeof(buf) = KYBER_ETA * KYBER_N / 4

    void poly_getnoise(poly *r, const unsigned char *seed, unsigned char nonce);
    void poly_frombytes(poly *r, const unsigned char *a);
    void poly_tobytes(unsigned char *r, const poly *a);
    void poly_frommsg(poly *r, const unsigned char msg[KYBER_SYMBYTES]);
    void poly_tomsg(unsigned char msg[KYBER_SYMBYTES], poly *a);
    void poly_compress(unsigned char *r, const poly *a);
    void poly_decompress(poly *r, const unsigned char *a);
    void poly_ntt(poly *r);
    void poly_invntt(poly *r);
    void poly_add(poly *r, const poly *a, const poly *b);
    void poly_sub(poly *r, const poly *a, const poly *b);

    void repack_sk_nontt(unsigned char *rsk, const unsigned char *sk);
    void repack_at_pk(unsigned char *pk_at_bytes, const unsigned char *pk);

    // added by me:
    void poly_freeze(poly *a);

    void polyvec_pointwise_acc(poly *r, const polyvec *a, const polyvec *b);
    void polyvec_ntt(polyvec *r);
    void polyvec_invntt(polyvec *r);
    void polyvec_frombytes(polyvec *r, const unsigned char *a);
    void polyvec_tobytes(unsigned char *r, const polyvec *a);
    void polyvec_compress(unsigned char *r, const polyvec *a);
    void polyvec_decompress(polyvec *r, const unsigned char *a);
    void polyvec_add(polyvec *r, const polyvec *a, const polyvec *b);

    void gen_matrix(polyvec *a, const unsigned char *seed, int transposed);

    void indcpa_keypair(unsigned char *pk, unsigned char *sk);
    void indcpa_enc(unsigned char *c, const unsigned char *m, const unsigned char *pk, const unsigned char *coins);
    void indcpa_dec(unsigned char *m, const unsigned char *c, const unsigned char *sk);
""")

sources=[str(src) for src in src_path.glob("*.c") if src.name not in ['rng.c', "PQCgenKAT_kem.c", 'testvectors.c', 'kex.c', 'PQCgenKAT_encrypt.c', 'speed.c', 'test_kex.c', 'precomp.gp.c']  ]

print(sources)

ffibuilder.set_source("_pyber",
f"""
    #include "{src_path}/poly.h"
    #include "{src_path}/polyvec.h"
    #include "{src_path}/indcpa.h"
    #include "{src_path}/params.h"
    #include "{src_path}/reduce.h"
    #include "{src_path}/cbd.h"
    #include "{src_path}/ntt.h"
    #include "{src_path}/fips202.h"
    #include "{src_path}/rng.h"
""" +
"""

""",
    sources=sources,
    #[ str(src_path.joinpath(src)) for src in  ['reduce.c', 'precomp.c', 'ntt.c', 'cbd.c', 'poly.c', 'polyvec.c']],
    # libraries=['m']
    )

src_path = Path(ROOT_DIR).joinpath('cref2')
assert src_path.exists(), f"{src_path} does not exist"

sources = [str(src) for src in src_path.glob("*.c") if src.name not in ["PQCgenKAT_kem.c",
                                                                        'testvectors.c', 'kex.c', 'PQCgenKAT_encrypt.c', 'speed.c', 'test_kex.c', 'precomp.gp.c']]

ffibuilder2.set_source("_pyber2",
f"""
    #include "{src_path}/poly.h"
    #include "{src_path}/polyvec.h"
    #include "{src_path}/indcpa.h"
    #include "{src_path}/params.h"
    #include "{src_path}/reduce.h"
    #include "{src_path}/cbd.h"
    #include "{src_path}/ntt.h"
    #include "{src_path}/fips202.h"
    #include "{src_path}/rng.h"
""" +
"""

""",
    sources=sources,
    #[ str(src_path.joinpath(src)) for src in  ['reduce.c', 'precomp.c', 'ntt.c', 'cbd.c', 'poly.c', 'polyvec.c']],
    # libraries=['m']
    )

if __name__ == "__main__":
    ffibuilder.compile(verbose=False)
    ffibuilder2.compile(verbose=False)
