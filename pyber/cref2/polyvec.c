#include <stdint.h>
#include "polyvec.h"
#include "poly.h"

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/*************
 * dump polyvec
 *************/
void polyvec_dump(const polyvec *pv) {
  int i;
  for (i = 0; i < KYBER_K; i++) {
    printf("    -- vec[%d]: ", i);
    poly_dump(&pv->vec[i]);
  }
}

void polyvec_freeze(polyvec *skpv){
  for (int i = 0; i < KYBER_K; i++) {
    poly_freeze(&skpv->vec[i]);
  }
}

/*************************************************
* Name:        polyvec_compress
*
* Description: Compress and serialize vector of polynomials
*
* Arguments:   - unsigned char *r: pointer to output byte array (needs space for KYBER_POLYVECCOMPRESSEDBYTES)
*              - const polyvec *a: pointer to input vector of polynomials
**************************************************/
void polyvec_compress(unsigned char *r, polyvec *a)
{
  int i,j,k;

  polyvec_csubq(a);

#if (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 352))
  uint16_t t[8];
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/8;j++)
    {
      for(k=0;k<8;k++)
        t[k] = ((((uint32_t)a->vec[i].coeffs[8*j+k] << 11) + KYBER_Q/2) / KYBER_Q) & 0x7ff;

      r[11*j+ 0] =  t[0] & 0xff;
      r[11*j+ 1] = (t[0] >>  8) | ((t[1] & 0x1f) << 3);
      r[11*j+ 2] = (t[1] >>  5) | ((t[2] & 0x03) << 6);
      r[11*j+ 3] = (t[2] >>  2) & 0xff;
      r[11*j+ 4] = (t[2] >> 10) | ((t[3] & 0x7f) << 1);
      r[11*j+ 5] = (t[3] >>  7) | ((t[4] & 0x0f) << 4);
      r[11*j+ 6] = (t[4] >>  4) | ((t[5] & 0x01) << 7);
      r[11*j+ 7] = (t[5] >>  1) & 0xff;
      r[11*j+ 8] = (t[5] >>  9) | ((t[6] & 0x3f) << 2);
      r[11*j+ 9] = (t[6] >>  6) | ((t[7] & 0x07) << 5);
      r[11*j+10] = (t[7] >>  3);
    }
    r += 352;
  }
#elif (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 320))
  uint16_t t[4];
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/4;j++)
    {
      for(k=0;k<4;k++)
        t[k] = ((((uint32_t)a->vec[i].coeffs[4*j+k] << 10) + KYBER_Q/2) / KYBER_Q) & 0x3ff;

      r[5*j+ 0] =  t[0] & 0xff;
      r[5*j+ 1] = (t[0] >>  8) | ((t[1] & 0x3f) << 2);
      r[5*j+ 2] = (t[1] >>  6) | ((t[2] & 0x0f) << 4);
      r[5*j+ 3] = (t[2] >>  4) | ((t[3] & 0x03) << 6);
      r[5*j+ 4] = (t[3] >>  2);
    }
    r += 320;
  }
#else
#error "KYBER_POLYVECCOMPRESSEDBYTES needs to be in {320*KYBER_K, 352*KYBER_K}"
#endif
}

/*************************************************
* Name:        polyvec_decompress
*
* Description: De-serialize and decompress vector of polynomials;
*              approximate inverse of polyvec_compress
*
* Arguments:   - polyvec *r:       pointer to output vector of polynomials
*              - unsigned char *a: pointer to input byte array (of length KYBER_POLYVECCOMPRESSEDBYTES)
**************************************************/
void polyvec_decompress(polyvec *r, const unsigned char *a)
{
  int i,j;
#if (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 352))
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/8;j++)
    {
      r->vec[i].coeffs[8*j+0] =  (((a[11*j+ 0]       | (((uint32_t)a[11*j+ 1] & 0x07) << 8)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+1] = ((((a[11*j+ 1] >> 3) | (((uint32_t)a[11*j+ 2] & 0x3f) << 5)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+2] = ((((a[11*j+ 2] >> 6) | (((uint32_t)a[11*j+ 3] & 0xff) << 2) | (((uint32_t)a[11*j+ 4] & 0x01) << 10)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+3] = ((((a[11*j+ 4] >> 1) | (((uint32_t)a[11*j+ 5] & 0x0f) << 7)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+4] = ((((a[11*j+ 5] >> 4) | (((uint32_t)a[11*j+ 6] & 0x7f) << 4)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+5] = ((((a[11*j+ 6] >> 7) | (((uint32_t)a[11*j+ 7] & 0xff) << 1) | (((uint32_t)a[11*j+ 8] & 0x03) <<  9)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+6] = ((((a[11*j+ 8] >> 2) | (((uint32_t)a[11*j+ 9] & 0x1f) << 6)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+7] = ((((a[11*j+ 9] >> 5) | (((uint32_t)a[11*j+10] & 0xff) << 3)) * KYBER_Q) + 1024) >> 11;
    }
    a += 352;
  }
#elif (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 320))
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/4;j++)
    {
      r->vec[i].coeffs[4*j+0] =  (((a[5*j+ 0]       | (((uint32_t)a[5*j+ 1] & 0x03) << 8)) * KYBER_Q) + 512) >> 10;
      r->vec[i].coeffs[4*j+1] = ((((a[5*j+ 1] >> 2) | (((uint32_t)a[5*j+ 2] & 0x0f) << 6)) * KYBER_Q) + 512) >> 10;
      r->vec[i].coeffs[4*j+2] = ((((a[5*j+ 2] >> 4) | (((uint32_t)a[5*j+ 3] & 0x3f) << 4)) * KYBER_Q) + 512) >> 10;
      r->vec[i].coeffs[4*j+3] = ((((a[5*j+ 3] >> 6) | (((uint32_t)a[5*j+ 4] & 0xff) << 2)) * KYBER_Q) + 512) >> 10;
    }
    a += 320;
  }
#else
#error "KYBER_POLYVECCOMPRESSEDBYTES needs to be in {320*KYBER_K, 352*KYBER_K}"
#endif
}

/*************************************************
* Name:        polyvec_tobytes
*
* Description: Serialize vector of polynomials
*
* Arguments:   - unsigned char *r: pointer to output byte array (needs space for KYBER_POLYVECBYTES)
*              - const polyvec *a: pointer to input vector of polynomials 
**************************************************/
void polyvec_tobytes(unsigned char *r, polyvec *a)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_tobytes(r+i*KYBER_POLYBYTES, &a->vec[i]);
}

/*************************************************
* Name:        polyvec_frombytes
*
* Description: De-serialize vector of polynomials;
*              inverse of polyvec_tobytes
*
* Arguments:   - unsigned char *r: pointer to output byte array
*              - const polyvec *a: pointer to input vector of polynomials (of length KYBER_POLYVECBYTES)
**************************************************/
void polyvec_frombytes(polyvec *r, const unsigned char *a)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_frombytes(&r->vec[i], a+i*KYBER_POLYBYTES);
}

/*************************************************
* Name:        polyvec_ntt
*
* Description: Apply forward NTT to all elements of a vector of polynomials
*
* Arguments:   - polyvec *r: pointer to in/output vector of polynomials
**************************************************/
void polyvec_ntt(polyvec *r)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_ntt(&r->vec[i]);
}
void polyvec_nttx(polyvec *r)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_nttx(&r->vec[i]);
}

/*************************************************
* Name:        polyvec_invntt
*
* Description: Apply inverse NTT to all elements of a vector of polynomials
*
* Arguments:   - polyvec *r: pointer to in/output vector of polynomials
**************************************************/
void polyvec_invntt(polyvec *r)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_invntt(&r->vec[i]);
}

/*************************************************
* Name:        polyvec_pointwise_acc
*
* Description: Pointwise multiply elements of a and b and accumulate into r
*
* Arguments: - poly *r:          pointer to output polynomial
*            - const polyvec *a: pointer to first input vector of polynomials
*            - const polyvec *b: pointer to second input vector of polynomials
**************************************************/
void polyvec_pointwise_acc(poly *r, const polyvec *a, const polyvec *b)
{
  int i;
  poly t;

  poly_basemul(r, &a->vec[0], &b->vec[0]);
  for(i=1;i<KYBER_K;i++) {
    poly_basemul(&t, &a->vec[i], &b->vec[i]);
    poly_add(r, r, &t);
  }

  poly_reduce(r);
}

/*************************************************
* Name:        polyvec_reduce
*
* Description: Applies Barrett reduction to each coefficient 
*              of each element of a vector of polynomials
*              for details of the Barrett reduction see comments in reduce.c
*
* Arguments:   - poly *r:       pointer to input/output polynomial
**************************************************/
void polyvec_reduce(polyvec *r)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_reduce(&r->vec[i]);
}
void polyvec_montgomery_reduce(polyvec *r)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_montgomery_reduce(&r->vec[i]);
}

/*************************************************
* Name:        polyvec_csubq
*
* Description: Applies conditional subtraction of q to each coefficient 
*              of each element of a vector of polynomials
*              for details of conditional subtraction of q see comments in reduce.c
*
* Arguments:   - poly *r:       pointer to input/output polynomial
**************************************************/
void polyvec_csubq(polyvec *r)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_csubq(&r->vec[i]);
}

/*************************************************
* Name:        polyvec_add
*
* Description: Add vectors of polynomials
*
* Arguments: - polyvec *r:       pointer to output vector of polynomials
*            - const polyvec *a: pointer to first input vector of polynomials
*            - const polyvec *b: pointer to second input vector of polynomials
**************************************************/
void polyvec_add(polyvec *r, const polyvec *a, const polyvec *b)
{
  int i;
  for(i=0;i<KYBER_K;i++)
    poly_add(&r->vec[i], &a->vec[i], &b->vec[i]);
}

void polyvec_nega_mac(poly *r, const polyvec *a, const polyvec *b, int neg) {
  int a_idx, sgn;
  int aa, bb;

  //   printf("\n--- a: --- \n");
  //   polyvec_print(a);
  //   printf("\n--- b: --- \n");
  //   polyvec_print(b);
  //   printf("\n--- r (in): --- \n");
  //   poly_print(r);

  for (int r_idx = 0; r_idx < KYBER_N; r_idx++) {
    int ri = r->coeffs[r_idx];
    for (int k = 0; k < KYBER_K; k++) {
      for (int b_idx = 0; b_idx < KYBER_N; b_idx++) {
        if (r_idx - b_idx < 0) {
          a_idx = r_idx - b_idx + KYBER_N;
          sgn = neg ? 1 : -1;
        } else {
          a_idx = r_idx - b_idx;
          sgn = neg ? -1 : +1;
        }
        aa = (int)a->vec[k].coeffs[a_idx];
        bb = (int)b->vec[k].coeffs[b_idx];

        if (aa < 0 || bb < 0 || ri < 0 || aa >= KYBER_Q || bb >= KYBER_Q) {
          printf("aa=%d bb=%d ri=%d\n", aa, bb, ri);
          exit(1);
        }

        ri += sgn * ((aa * bb) % KYBER_Q);

        while (ri < 0) {
          ri = KYBER_Q + ri;
        } 
        while (ri >= KYBER_Q) {
          ri = ri - KYBER_Q;
        }
      }
    }

    r->coeffs[r_idx] = ri;
  }

  //   printf("\n--- r (out): --- \n");
  //   poly_print(r);
}