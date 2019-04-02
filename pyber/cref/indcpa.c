#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "indcpa.h"
#include "poly.h"
#include "polyvec.h"
#include "randombytes.h"
#include "fips202.h"
#include "ntt.h"

/*************************************************
* Name:        pack_pk
*
* Description: Serialize the public key as concatenation of the
*              compressed and serialized vector of polynomials pk
*              and the public seed used to generate the matrix A.
*
* Arguments:   unsigned char *r:          pointer to the output serialized public key
*              const poly *pk:            pointer to the input public-key polynomial
*              const unsigned char *seed: pointer to the input public seed
**************************************************/
void pack_pk(unsigned char *r, const polyvec *pk, const unsigned char *seed)
{
  int i;
  polyvec_compress(r, pk);
  for(i=0;i<KYBER_SYMBYTES;i++)
    r[i+KYBER_POLYVECCOMPRESSEDBYTES] = seed[i];
}

/*************************************************
* Name:        unpack_pk
*
* Description: De-serialize and decompress public key from a byte array;
*              approximate inverse of pack_pk
*
* Arguments:   - polyvec *pk:                   pointer to output public-key vector of polynomials
*              - unsigned char *seed:           pointer to output seed to generate matrix A
*              - const unsigned char *packedpk: pointer to input serialized public key
**************************************************/
void unpack_pk(polyvec *pk, unsigned char *seed, const unsigned char *packedpk)
{
  int i;
  polyvec_decompress(pk, packedpk);

  for(i=0;i<KYBER_SYMBYTES;i++)
    seed[i] = packedpk[i+KYBER_POLYVECCOMPRESSEDBYTES];
}

/*************************************************
* Name:        pack_ciphertext
*
* Description: Serialize the ciphertext as concatenation of the
*              compressed and serialized vector of polynomials b
*              and the compressed and serialized polynomial v
*
* Arguments:   unsigned char *r:          pointer to the output serialized ciphertext
*              const poly *pk:            pointer to the input vector of polynomials b
*              const unsigned char *seed: pointer to the input polynomial v
**************************************************/
void pack_ciphertext(unsigned char *r, const polyvec *b, const poly *v)
{
  polyvec_compress(r, b);
  poly_compress(r+KYBER_POLYVECCOMPRESSEDBYTES, v);
}

/*************************************************
* Name:        unpack_ciphertext
*
* Description: De-serialize and decompress ciphertext from a byte array;
*              approximate inverse of pack_ciphertext
*
* Arguments:   - polyvec *b:             pointer to the output vector of polynomials b
*              - poly *v:                pointer to the output polynomial v
*              - const unsigned char *c: pointer to the input serialized ciphertext
**************************************************/
void unpack_ciphertext(polyvec *b, poly *v, const unsigned char *c)
{
  polyvec_decompress(b, c);
  poly_decompress(v, c+KYBER_POLYVECCOMPRESSEDBYTES);
}

/*************************************************
* Name:        pack_sk
*
* Description: Serialize the secret key
*
* Arguments:   - unsigned char *r:  pointer to output serialized secret key
*              - const polyvec *sk: pointer to input vector of polynomials (secret key)
**************************************************/
void pack_sk(unsigned char *r, const polyvec *sk)
{
  polyvec_tobytes(r, sk);
}

/*************************************************
* Name:        unpack_sk
*
* Description: De-serialize the secret key;
*              inverse of pack_sk
*
* Arguments:   - polyvec *sk:                   pointer to output vector of polynomials (secret key)
*              - const unsigned char *packedsk: pointer to input serialized secret key
**************************************************/
void unpack_sk(polyvec *sk, const unsigned char *packedsk)
{
  polyvec_frombytes(sk, packedsk);
}

#define gen_a(A,B)  gen_matrix((A),(B),0)
#define gen_at(A,B) gen_matrix((A),(B),1)

/*************************************************
* Name:        gen_matrix
*
* Description: Deterministically generate matrix A (or the transpose of A)
*              from a seed. Entries of the matrix are polynomials that look
*              uniformly random. Performs rejection sampling on output of
*              SHAKE-128
*
* Arguments:   - polyvec *a:                pointer to ouptput matrix A
*              - const unsigned char *seed: pointer to input seed
*              - int transposed:            boolean deciding whether A or A^T is generated
**************************************************/
void gen_matrix(polyvec *a, const unsigned char *seed, int transposed) // Not static for benchmarking
{
  unsigned int pos=0, ctr;
  uint16_t val;
  unsigned int nblocks;
  const unsigned int maxnblocks=4;
  uint8_t buf[SHAKE128_RATE*maxnblocks];
  int i,j;
  uint64_t state[25]; // SHAKE state
  unsigned char extseed[KYBER_SYMBYTES+2];

  for(i=0;i<KYBER_SYMBYTES;i++)
    extseed[i] = seed[i];


  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_K;j++)
    {
      ctr = pos = 0;
      nblocks = maxnblocks;
      if(transposed)
      {
        extseed[KYBER_SYMBYTES]   = i;
        extseed[KYBER_SYMBYTES+1] = j;
      }
      else
      {
        extseed[KYBER_SYMBYTES]   = j;
        extseed[KYBER_SYMBYTES+1] = i;
      }

      shake128_absorb(state,extseed,KYBER_SYMBYTES+2);
      shake128_squeezeblocks(buf,nblocks,state);

      while(ctr < KYBER_N)
      {
        val = (buf[pos] | ((uint16_t) buf[pos+1] << 8)) & 0x1fff;
        if(val < KYBER_Q)
        {
            a[i].vec[j].coeffs[ctr++] = val;
        }
        pos += 2;

        if(pos > SHAKE128_RATE*nblocks-2)
        {
          nblocks = 1;
          shake128_squeezeblocks(buf,nblocks,state);
          pos = 0;
        }
      }
    }
  }
}

int crypto_encrypt_keypair(unsigned char *pk, unsigned char *sk) {
  indcpa_keypair(pk, sk);
  return 0;
}

/*************************************************
* Name:        indcpa_keypair
*
* Description: Generates public and private key for the CPA-secure
*              public-key encryption scheme underlying Kyber
*
* Arguments:   - unsigned char *pk: pointer to output public key (of length KYBER_INDCPA_PUBLICKEYBYTES bytes)
*              - unsigned char *sk: pointer to output private key (of length KYBER_INDCPA_SECRETKEYBYTES bytes)
**************************************************/
void indcpa_keypair(unsigned char *pk,
                   unsigned char *sk)
{
  polyvec a[KYBER_K], e, pkpv, skpv;
  unsigned char buf[KYBER_SYMBYTES+KYBER_SYMBYTES];
  unsigned char *publicseed = buf;
  unsigned char *noiseseed = buf+KYBER_SYMBYTES;
  int i;
  unsigned char nonce=0;

  randombytes(buf, KYBER_SYMBYTES);
  sha3_512(buf, buf, KYBER_SYMBYTES);

  gen_a(a, publicseed);

  for(i=0;i<KYBER_K;i++)
    poly_getnoise(skpv.vec+i,noiseseed,nonce++);

  polyvec_ntt(&skpv);

  for(i=0;i<KYBER_K;i++)
    poly_getnoise(e.vec+i,noiseseed,nonce++);

  // matrix-vector multiplication
  for(i=0;i<KYBER_K;i++)
    polyvec_pointwise_acc(&pkpv.vec[i],&skpv,a+i);

  polyvec_invntt(&pkpv);
  polyvec_add(&pkpv,&pkpv,&e);

  pack_sk(sk, &skpv);
  pack_pk(pk, &pkpv, publicseed);
}

int crypto_encrypt(unsigned char *c, unsigned long long *clen,
                   const unsigned char *m, unsigned long long mlen,
                   const unsigned char *pk) {
  printf("crypto_encrypt mlen=%lld\n", mlen);
  if (mlen != KYBER_INDCPA_MSGBYTES)
    return -1;

  unsigned char kr[2 * KYBER_SYMBYTES]; /* Will contain key, coins */
  unsigned char buf[2 * KYBER_SYMBYTES];

  randombytes(buf, KYBER_SYMBYTES);
  sha3_256(buf, buf, KYBER_SYMBYTES); /* Don't release system RNG output */

  sha3_256(buf + KYBER_SYMBYTES, pk,
           KYBER_PUBLICKEYBYTES); /* Multitarget countermeasure for coins +
                                     contributory KEM ??? TODO FIXME!!! */
  sha3_512(kr, buf, 2 * KYBER_SYMBYTES);

  indcpa_enc(c, m, pk,
             kr + KYBER_SYMBYTES); /* coins are in kr+KYBER_SYMBYTES */

  *clen = KYBER_CIPHERTEXTBYTES;
  return 0;
}

/*************************************************
* Name:        indcpa_enc
*
* Description: Encryption function of the CPA-secure
*              public-key encryption scheme underlying Kyber.
*
* Arguments:   - unsigned char *c:          pointer to output ciphertext (of length KYBER_INDCPA_BYTES bytes)
*              - const unsigned char *m:    pointer to input message (of length KYBER_INDCPA_MSGBYTES bytes)
*              - const unsigned char *pk:   pointer to input public key (of length KYBER_INDCPA_PUBLICKEYBYTES bytes)
*              - const unsigned char *coin: pointer to input random coins used as seed (of length KYBER_SYMBYTES bytes)
*                                           to deterministically generate all randomness
**************************************************/
void indcpa_enc(unsigned char *c,
               const unsigned char *m,
               const unsigned char *pk,
               const unsigned char *coins)
{
  polyvec sp, pkpv, ep, at[KYBER_K], bp;
  poly v, msg_poly, epp;
  unsigned char seed[KYBER_SYMBYTES];
  int i;
  unsigned char nonce=0;

  unsigned char c_prime[KYBER_CIPHERTEXTBYTES];

  unsigned char pk_at_bytes[KYBER_POLYVECBYTES * (KYBER_K + 1)];

  repack_at_pk(pk_at_bytes, pk);

  indcpa_enc_nontt(c_prime, m, pk_at_bytes, coins);

  unpack_pk(&pkpv, seed, pk);

  poly_frommsg(&msg_poly, m);

  polyvec_ntt(&pkpv);

  gen_at(at, seed);

  for(i=0;i<KYBER_K;i++)
    poly_getnoise(sp.vec+i,coins,nonce++);

  polyvec_ntt(&sp);

  for(i=0;i<KYBER_K;i++)
    poly_getnoise(ep.vec+i,coins,nonce++);

  // matrix-vector multiplication
  for(i=0;i<KYBER_K;i++)
    polyvec_pointwise_acc(&bp.vec[i],&sp,at+i);

  polyvec_invntt(&bp);
  polyvec_add(&bp, &bp, &ep);

  polyvec_pointwise_acc(&v, &pkpv, &sp);
  poly_invntt(&v);

  poly_getnoise(&epp,coins,nonce++);

  poly_add(&v, &v, &epp);
  poly_add(&v, &v, &msg_poly);

  pack_ciphertext(c, &bp, &v);

  if (memcmp(c, c_prime, KYBER_CIPHERTEXTBYTES)) {
    printf("\n [ **** Scheiße! **** ] \n  enc don't match!\n");
    // for(int i = 0; i < KYBER_CIPHERTEXTBYTES; i++){
    //   printf(" %d|%d", c[i], c_prime[i]);
    // }

    // printf("\n");

    exit(1);
  } else {
    // printf("indcpa_enc MATCH\n");
  }
}

void unpack_pk_at_nontt(polyvec *pkpv_p, polyvec *at,
                        const unsigned char *pk) {
  unsigned char seed[KYBER_SYMBYTES];
  unpack_pk(pkpv_p, seed, pk);
  gen_at(at, seed);

  for (int i = 0; i < KYBER_K; i++) {
    polyvec_invntt(&at[i]);
  }
}

/**
 ** unpack pk to (pk, at) in time domain and repack as bytes
 ** "packed_bytes" must be KYBER_POLYVECBYTES * (KYBER_K + 1) bytes
 **/
//
void repack_at_pk(unsigned char *pk_at_bytes, const unsigned char *pk) {
  polyvec pkpv, at[KYBER_K];

  unpack_pk_at_nontt(&pkpv, at, pk);
  
  for (int i = 0; i < KYBER_K; i++) {
    polyvec_tobytes(pk_at_bytes + i * KYBER_POLYVECBYTES, &at[i]);
  }
  polyvec_tobytes(pk_at_bytes + KYBER_K * KYBER_POLYVECBYTES, &pkpv);
}

// deserialize:
void at_pk_frombytes(polyvec *at, polyvec *pkpv, const unsigned char *bytes) {
  
  for (int i = 0; i < KYBER_K; i++) {
    polyvec_frombytes(&at[i], bytes + i * KYBER_POLYVECBYTES);
  }
  polyvec_frombytes(pkpv, bytes + KYBER_K * KYBER_POLYVECBYTES);
}
void indcpa_enc_nontt(unsigned char *c, const unsigned char *m,
                          const unsigned char *pk_at_bytes, const unsigned char *coins) {
  polyvec s_pv, pkpv, at[KYBER_K], b_pv;
  poly v, msg_poly;

  at_pk_frombytes(at, &pkpv, pk_at_bytes);

  printf("-- pkpv:\n");
  polyvec_print(&pkpv);

  printf("\n\n-- at:\n");
  for(int i =0; i < KYBER_K; i++){
    printf("\n ---- [%d] \n", i);
    polyvec_print(&at[i]);
  }

      //-----------------------------------------
      unsigned char nonce = 0;
  for (int i = 0; i < KYBER_K; i++){
    poly_getnoise(s_pv.vec + i, coins, nonce++);
  }

  printf("\n\n-- s:\n");
  polyvec_print(&s_pv);

    for (int i = 0; i < KYBER_K; i++)
        poly_getnoise(b_pv.vec + i, coins, nonce++);

    printf("\n\n-- b:\n");
    polyvec_print(&b_pv);


    poly_getnoise(&v, coins, nonce++);

    printf("\n\n-- v:\n");
    poly_print(&v);
    //-----------------------------------------

    // printf("======unpacked pk:\n");
    // printf("   ===pk.seed:\n");
    // for(i=0; i< KYBER_SYMBYTES; ++i){
    //   printf("%X ", seed[i]);
    // }
    // printf("\n");
    // printf("   ===pk.pkpv:\n");
    // polyvec_print(&pkpv);

    for (int i = 0; i < KYBER_K; i++)
      polyvec_nega_mac(&b_pv.vec[i], at + i, &s_pv, 0);

    printf("\n\n-- b after MAC:\n");
    polyvec_print(&b_pv);

    polyvec_nega_mac(&v, &pkpv, &s_pv, 0);

    printf("\n\n-- V after MAC:\n");
    poly_print(&v);

    poly_frommsg(&msg_poly, m);
    poly_add(&v, &v, &msg_poly);

    // printf("======c.v:\n");
    // poly_print(&v);

    pack_ciphertext(c, &b_pv, &v);
}

int crypto_encrypt_open(unsigned char *m, unsigned long long *mlen,
                        const unsigned char *c, unsigned long long clen,
                        const unsigned char *sk) {
  if (clen != KYBER_CIPHERTEXTBYTES) {
    return -1;
  }

  *mlen = KYBER_INDCPA_MSGBYTES;

  indcpa_dec(m, c, sk);

  return 0;
}

void indcpa_dec_x(unsigned char *m, const unsigned char *c,
                const unsigned char *sk);
/*************************************************
* Name:        indcpa_dec
*
* Description: Decryption function of the CPA-secure
*              public-key encryption scheme underlying Kyber.
*
* Arguments:   - unsigned char *m:        pointer to output decrypted message (of length KYBER_INDCPA_MSGBYTES)
*              - const unsigned char *c:  pointer to input ciphertext (of length KYBER_INDCPA_BYTES)
*              - const unsigned char *sk: pointer to input secret key (of length KYBER_INDCPA_SECRETKEYBYTES)
**************************************************/
void indcpa_dec(unsigned char *m,
               const unsigned char *c,
               const unsigned char *sk)
{
  polyvec bp, skpv;
  poly v, mp;

  unpack_ciphertext(&bp, &v, c);
  unpack_sk(&skpv, sk);

  polyvec_ntt(&bp);

  polyvec_pointwise_acc(&mp,&skpv,&bp);
  poly_invntt(&mp);

  poly_sub(&mp, &mp, &v);

  poly_tomsg(m, &mp);


  unsigned char m2 [KYBER_SYMBYTES];
  indcpa_dec_x(m2, c, sk);

  if (memcmp(m, m2, KYBER_SYMBYTES) ){
      fprintf(stderr, "decrypted messages DO NOT MATCH!\n");
      exit(1);
  } else {
    //   printf("DEC MATCH\n");
  }
}

void indcpa_dec_x(unsigned char *m, const unsigned char *c,
                const unsigned char *sk) {
  polyvec bp, skpv;
  poly v;

  unpack_ciphertext(&bp, &v, c);
  
  unpack_sk(&skpv, sk);
  polyvec_invntt(&skpv);

  polyvec_nega_mac(&v, &skpv, &bp, 1); // v <- skpv*bp - v

  poly_tomsg_nofreeze(m, &v);
}
