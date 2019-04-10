#ifndef INDCPA_H
#define INDCPA_H

#include "poly.h"
#include "polyvec.h"
void indcpa_keypair(unsigned char *pk, unsigned char *sk);

void indcpa_enc(unsigned char *c, const unsigned char *m,
                const unsigned char *pk, const unsigned char *coins);

void indcpa_enc_nontt(unsigned char *c, const unsigned char *m,
                      const unsigned char *pk, const unsigned char *coins);

void indcpa_dec(unsigned char *m, const unsigned char *c,
                const unsigned char *sk);

void repack_sk_nontt(unsigned char *rsk, const unsigned char *sk);


void indcpa_dec_nontt(unsigned char *m, const unsigned char *c,
                      const unsigned char *sk);

void repack_at_pk(unsigned char *pk_at_bytes, const unsigned char *pk);

void indcpa_enc_nontt(unsigned char *c, const unsigned char *m,
                      const unsigned char *pk_at_bytes,
                      const unsigned char *coins);

void at_pk_frombytes(polyvec *at, polyvec *pkpv, const unsigned char *bytes);

void gen_matrix(polyvec *a, const unsigned char *seed, int transposed);

#endif
