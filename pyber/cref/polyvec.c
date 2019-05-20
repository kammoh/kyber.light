#include "polyvec.h"
#include "fips202.h"
#include "cbd.h"
#include "reduce.h"
#include <stdio.h>
#include <stdlib.h>

#define DEBUG

#if (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 352)) // (K x 256) x 13 bits -> (K x 256) x 11 bits -> (k x 352) x 8
/*************************************************
* Name:        polyvec_compress
*
* Description: Compress and serialize vector of polynomials
*
* Arguments:   - unsigned char *r: pointer to output byte array
*              - const polyvec *a: pointer to input vector of polynomials
**************************************************/
void polyvec_compress(unsigned char *r, const polyvec *a)
{
  int i,j,k;
  uint16_t t[8];
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/8;j++)
    {
      for(k=0;k<8;k++){
        uint32_t tt = (uint32_t)freeze(a->vec[i].coeffs[8 * j + k]);
        t[k] =((( tt << 11) + KYBER_Q / 2) / KYBER_Q) & 0x7ff;
        // printf("coeffs=%X t[k]=%X\n", tt, t[k]);
      }

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
}


void polyvec_compress_modified(unsigned char *r, const polyvec *a) {
  int i, j;
  uint16_t t, fr;

  //   int N = 21;

  //   uint32_t m_prime = (((uint64_t)1 << N) * ((1 << 13) - KYBER_Q)) / KYBER_Q
  //   + 1; // 18 bits
  //   // uint64_t m2 = m_prime * 256 * 7;
  //   printf("m_prime=%d\n", m_prime);
  //   for (int f = 0; f < KYBER_Q; ++f) {
  //     int t1 = (((f << 11) + KYBER_Q / 2) / KYBER_Q) & 0x7ff;

  //     int A = (((f + 1) & 0x1fff) << 11); // 3840;
  //     int tt = ((((uint64_t)((f + 1) << 3) | 7) * m_prime) >> (N - 8)) &
  //     0xfffff; // 16 bit * 18 bits int t2 = ((tt + (((A | 1792) - tt) >> 1))
  //     >> 12) & 0x7ff;

  //     printf("f=%d t1=%d\n", f, t1);
  //     if (t1 != t2) {
  //       printf("t1:%d != t2:%d  f=%d\n", t1, t2, f);
  //       exit(1);
  //     }
  //   }

  //   printf("all ok!!!\n");
  //   exit(0);
  uint16_t last_bits = 0;
  int num_bits = 0;
  for (i = 0; i < KYBER_K; i++) {
    for (j = 0; j < KYBER_N; j++) {

      fr = freeze(a->vec[i].coeffs[j]);
      t = ((((uint32_t)fr << 11) + KYBER_Q / 2) / KYBER_Q) &
          0x7ff; // 13:11 compress

      *r = ((t << num_bits) | last_bits) & 0xff;
      r += 1;
      last_bits = t >> (8 - num_bits);
      num_bits = 11 + num_bits - 8;

      if (num_bits >= 8) {
        *r = last_bits & 0xff;
        r += 1;
        last_bits >>= 8;
        num_bits -= 8;
      }
    }
  }
}

/*************************************************
* Name:        polyvec_decompress
*
* Description: De-serialize and decompress vector of polynomials;
*              approximate inverse of polyvec_compress
*
* Arguments:   - polyvec *r:       pointer to output vector of polynomials
*              - unsigned char *a: pointer to input byte array
**************************************************/
void polyvec_decompress(polyvec *r, const unsigned char *a)
{
  int i,j;
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/8;j++)
    {
      r->vec[i].coeffs[8*j+0] =  (((a[11*j+ 0]       | (((uint32_t)a[11*j+ 1] & 0x07) << 8)) * KYBER_Q) +1024) >> 11;
      r->vec[i].coeffs[8*j+1] = ((((a[11*j+ 1] >> 3) | (((uint32_t)a[11*j+ 2] & 0x3f) << 5)) * KYBER_Q) +1024) >> 11;
      r->vec[i].coeffs[8*j+2] = ((((a[11*j+ 2] >> 6) | (((uint32_t)a[11*j+ 3] & 0xff) << 2) |  (((uint32_t)a[11*j+ 4] & 0x01) << 10)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+3] = ((((a[11*j+ 4] >> 1) | (((uint32_t)a[11*j+ 5] & 0x0f) << 7)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+4] = ((((a[11*j+ 5] >> 4) | (((uint32_t)a[11*j+ 6] & 0x7f) << 4)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+5] = ((((a[11*j+ 6] >> 7) | (((uint32_t)a[11*j+ 7] & 0xff) << 1) |  (((uint32_t)a[11*j+ 8] & 0x03) <<  9)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+6] = ((((a[11*j+ 8] >> 2) | (((uint32_t)a[11*j+ 9] & 0x1f) << 6)) * KYBER_Q) + 1024) >> 11;
      r->vec[i].coeffs[8*j+7] = ((((a[11*j+ 9] >> 5) | (((uint32_t)a[11*j+10] & 0xff) << 3)) * KYBER_Q) + 1024) >> 11;
    }
    a += 352;
  }
}

#elif (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 320))

void polyvec_compress(unsigned char *r, const polyvec *a)
{
  int i,j,k;
  uint16_t t[4];
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/4;j++)
    {
      for(k=0;k<4;k++)
        t[k] = ((((uint32_t)freeze(a->vec[i].coeffs[4*j+k]) << 10) + KYBER_Q/2)/ KYBER_Q) & 0x3ff;

      r[5*j+ 0] =  t[0] & 0xff;
      r[5*j+ 1] = (t[0] >>  8) | ((t[1] & 0x3f) << 2);
      r[5*j+ 2] = (t[1] >>  6) | ((t[2] & 0x0f) << 4);
      r[5*j+ 3] = (t[2] >>  4) | ((t[3] & 0x03) << 6);
      r[5*j+ 4] = (t[3] >>  2);
    }
    r += 320;
  }
}

void polyvec_decompress(polyvec *r, const unsigned char *a)
{
  int i,j;
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
}

#elif (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 288))

void polyvec_compress(unsigned char *r, const polyvec *a)
{
  int i,j,k;
  uint16_t t[8];
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/8;j++)
    {
      for(k=0;k<8;k++)
        t[k] = ((((uint32_t)freeze(a->vec[i].coeffs[8*j+k]) << 9) + KYBER_Q/2)/ KYBER_Q) & 0x1ff;

      r[9*j+ 0] =  t[0] & 0xff;
      r[9*j+ 1] = (t[0] >>  8) | ((t[1] & 0x7f) << 1);
      r[9*j+ 2] = (t[1] >>  7) | ((t[2] & 0x3f) << 2);
      r[9*j+ 3] = (t[2] >>  6) | ((t[3] & 0x1f) << 3);
      r[9*j+ 4] = (t[3] >>  5) | ((t[4] & 0x0f) << 4);
      r[9*j+ 5] = (t[4] >>  4) | ((t[5] & 0x07) << 5);
      r[9*j+ 6] = (t[5] >>  3) | ((t[6] & 0x03) << 6);
      r[9*j+ 7] = (t[6] >>  2) | ((t[7] & 0x01) << 7);
      r[9*j+ 8] = (t[7] >>  1);
    }
    r += 288;
  }
}

void polyvec_decompress(polyvec *r, const unsigned char *a)
{
  int i,j;
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N/8;j++)
    {
      r->vec[i].coeffs[8*j+0] =  (((a[9*j+ 0]       | (((uint32_t)a[9*j+ 1] & 0x01) << 8)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+1] = ((((a[9*j+ 1] >> 1) | (((uint32_t)a[9*j+ 2] & 0x03) << 7)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+2] = ((((a[9*j+ 2] >> 2) | (((uint32_t)a[9*j+ 3] & 0x07) << 6)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+3] = ((((a[9*j+ 3] >> 3) | (((uint32_t)a[9*j+ 4] & 0x0f) << 5)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+4] = ((((a[9*j+ 4] >> 4) | (((uint32_t)a[9*j+ 5] & 0x1f) << 4)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+5] = ((((a[9*j+ 5] >> 5) | (((uint32_t)a[9*j+ 6] & 0x3f) << 3)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+6] = ((((a[9*j+ 6] >> 6) | (((uint32_t)a[9*j+ 7] & 0x7f) << 2)) * KYBER_Q) + 256) >> 9;
      r->vec[i].coeffs[8*j+7] = ((((a[9*j+ 7] >> 7) | (((uint32_t)a[9*j+ 8] & 0xff) << 1)) * KYBER_Q) + 256) >> 9;
    }
    a += 288;
  }
}


#elif (KYBER_POLYVECCOMPRESSEDBYTES == (KYBER_K * 256))

void polyvec_compress(unsigned char *r, const polyvec *a)
{
  int i,j,k;
  uint16_t t;
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N;j++)
    {
      r[j] = ((((uint32_t)freeze(a->vec[i].coeffs[j]) << 8) + KYBER_Q/2)/ KYBER_Q) & 0xff;
    }
    r += 256;
  }
}

void polyvec_decompress(polyvec *r, const unsigned char *a)
{
  int i,j;
  for(i=0;i<KYBER_K;i++)
  {
    for(j=0;j<KYBER_N;j++)
    {
      r->vec[i].coeffs[j] = ((a[j] * KYBER_Q) + 128) >> 8;
    }
    a += 256;
  }
}

#else
  #error "Unsupported compression of polyvec"
#endif

/*************************************************
* Name:        polyvec_tobytes
*
* Description: Serialize vector of polynomials
*
* Arguments:   - unsigned char *r: pointer to output byte array
*              - const polyvec *a: pointer to input vector of polynomials
**************************************************/
void polyvec_tobytes(unsigned char *r, const polyvec *a)
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
*              - const polyvec *a: pointer to input vector of polynomials
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
  int i,j;
  uint16_t t;
  for(j=0;j<KYBER_N;j++)
  {
    t = montgomery_reduce(4613* (uint32_t)b->vec[0].coeffs[j]); // 4613 = 2^{2*18} % q
    r->coeffs[j] = montgomery_reduce(a->vec[0].coeffs[j] * t);
    for(i=1;i<KYBER_K;i++)
    {
      t = montgomery_reduce(4613* (uint32_t)b->vec[i].coeffs[j]);
      r->coeffs[j] += montgomery_reduce(a->vec[i].coeffs[j] * t);
    }
    r->coeffs[j] = barrett_reduce(r->coeffs[j]);
  }
}

#include <assert.h>
#include <stdlib.h>

// negacyclic school-book polynomial-vector multiply-accumulate
void polyvec_nega_mac(poly *r, const polyvec *a, const polyvec *b, int neg) {
  int a_idx, sgn;
  int aa, bb;

//   printf("\n--- a: --- \n");
//   polyvec_print(a);
//   printf("\n--- b: --- \n");
//   polyvec_print(b);
//   printf("\n--- r (in): --- \n");
//   poly_print(r);
  printf("polyvec_nega_mac\n");
  for (int r_idx = 0; r_idx < KYBER_N; r_idx++) {
    int ri = r->coeffs[r_idx];
    for (int k = 0; k < KYBER_K; k++) {
      for (int b_idx = 0; b_idx < KYBER_N; b_idx++) {
        if (r_idx - b_idx < 0 ) {
          a_idx = r_idx - b_idx + KYBER_N;
          sgn = neg ? 1 : -1;
        } else {
          a_idx = r_idx - b_idx;
          sgn = neg ? -1 : +1;
        }
        aa = (int)a->vec[k].coeffs[a_idx];
        bb = (int)b->vec[k].coeffs[b_idx];

        ri += sgn * ((aa * bb) % KYBER_Q);

        if (ri < 0) {
          ri = KYBER_Q + ri;
        } else if (ri >= KYBER_Q) {
          ri =  ri - KYBER_Q;
        }
      }
    }

    r->coeffs[r_idx] = (uint16_t)(ri);
  }

//   printf("\n--- r (out): --- \n");
//   poly_print(r);
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
