from _pyber import ffi
import _pyber.lib as pyber_clib


KYBER_N = pyber_clib.KYBER_N
KYBER_K = pyber_clib.KYBER_K


__all__=['polyvec_nega_mac', 'KYBER_N', 'KYBER_K']

def polyvec_nega_mac(pr, pa, pb, subtract=False):
    print(f"KYBER_N={KYBER_N} KYBER_K={KYBER_K}")

    def to_poly(p):
        print(type(p))
        return [ [ [[x] for x in p] ] ]

    
    def to_polyvec(pv):
        print('pv: ',type(pv[0]))
        return [ to_poly(p) for p in pv ]

    poly_a = ffi.new('polyvec *')
    poly_b = ffi.new('polyvec *')
    poly_r = ffi.new('poly *')

    for k in range(KYBER_K):
        for i in range(KYBER_N):
            if k == 0:
                poly_r.coeffs[i] = pr[i]
            poly_a.vec[k].coeffs[i] = pa[k][i]
            poly_b.vec[k].coeffs[i] = pb[k][i]
    pyber_clib.polyvec_nega_mac(poly_r, poly_a, poly_b, 1 if subtract else 0)
    pr = []
    for i in range(KYBER_N):
        pr.append(poly_r.coeffs[i])

    return pr


if __name__ == '__main__':
    a = []
    b = []
    r = []
    for k in range(KYBER_K):
        p1 = []
        p2 = []
        for i in range(KYBER_N):
            p1.append(k*256 + i)
            p2.append(k*256 + i)
        a.append(p1)
        b.append(p2)

    for i in range(KYBER_N):
        r.append(255 - i)


    rr = polyvec_nega_mac(r, a, b)


    for x in rr:
        print(f"{x:0>4X}", end=' ')

    print()
