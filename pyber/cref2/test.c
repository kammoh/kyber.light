#include "indcpa.h"
#include "ntt.h"
#include "poly.h"
#include "reduce.h"
#include "polyvec.h"
#include "rng.h"
#include "symmetric.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main2()
{

    polyvec bp, b1;
    poly r0, mp, r1;

    srand(time(NULL));

    // for (int j = 0; j < KYBER_N; j++) {
    //   r1.coeffs[j] = r0.coeffs[j] = rand() % KYBER_Q;
    // }
    // for(int i = 0 ; i < KYBER_K; i++) {
    //     for (int j = 0; j < KYBER_N; j++){
    //       a1.vec[i].coeffs[j] = 1; // (rand() % KYBER_Q);
    //       skpv.vec[i].coeffs[j] = a1.vec[i].coeffs[j] - KYBER_Q;
    //       //   b1.vec[i].coeffs[j] = bp.vec[i].coeffs[j] = rand() % KYBER_Q;
    //     }
    // }

    poly a, b;
    
    for (int i = 0; i < KYBER_N; i++) {
      a.coeffs[i] = b.coeffs[i] = rand() % KYBER_Q;
    }

    poly_ntt(&a);
    poly_invntt(&a);

    poly_montgomery_reduce(&a);
    poly_reduce(&a);

    // printf("a.coeffs[0]=%d b.coeffs[0]=%d\n", montgomery_reduce(a.coeffs[0]), b.coeffs[0]);

    // assert(montgomery_reduce(a.coeffs[0]) == b.coeffs[0]);

    for (int j = 0; j < KYBER_N; j++) {
      if(a.coeffs[j] != b.coeffs[j]){
        printf("[%d] a: %d != b: %d\n", j, a.coeffs[j], b.coeffs[j]);
        exit(1);
      }
    }

    //     for (int i = 0; i < KYBER_K; i++) {
    //   for (int j = 0; j < KYBER_N; j++) {
    //     if(a1.vec[i].coeffs[j] != skpv.vec[i].coeffs[j]){
    //       printf("[%d][%d] a1: %d != skpv: %d\n", i, j, a1.vec[i].coeffs[j],  skpv.vec[i].coeffs[j]);
    //     }
    //   }
    // }

    // polyvec_ntt(&bp);
    // polyvec_pointwise_acc(&mp, &skpv, &bp);
    // poly_invntt(&mp);
    // poly_freeze(&mp);

    // poly_sub(&r0, &r0, &mp);
    // poly_freeze(&r0);

    // // printf("r0:\n");
    // // poly_dump(&r0);

    // polyvec_invntt(&skpv);
    // polyvec_freeze(&skpv);

    // polyvec_nega_mac(&r1, &skpv, &b1, 1);

    // // printf("r1:\n");
    // // poly_dump(&r1);

    // for (int j = 0; j < KYBER_N; j++) {
    //   if(r1.coeffs[j] != r0.coeffs[j]){
    //     printf("[%d] r0: %d != r1: %d\n", j, r0.coeffs[j], r1.coeffs[j]);
    //   }
    // }


}

int main()
{
    
}