from _pyber import ffi
import _pyber.lib as pyber_clib
import random
from collections.abc import Iterable
from typing import List, Iterable as IterableType
import shutil
from math import log2, ceil
import os


KYBER_N = pyber_clib.KYBER_N
KYBER_K = pyber_clib.KYBER_K
KYBER_Q = pyber_clib.KYBER_Q
KYBER_ETA = pyber_clib.KYBER_ETA
KYBER_SYMBYTES = pyber_clib.KYBER_SYMBYTES


def getnoise_bytes(coins, nonce):
    coins = list(coins)
    print(f"getnoise_bytes[PYTHON] coins={[ hex(c) for c in coins]} nonce={nonce}")
    assert len(coins) == KYBER_SYMBYTES
    ccoins_buf = ffi.new(f'const unsigned char [{KYBER_SYMBYTES}]', coins)
    crbuf = ffi.new(f'unsigned char [{KYBER_ETA * KYBER_N // 4}]')
    pyber_clib.getnoise_bytes(crbuf, ccoins_buf, nonce)
    return list(crbuf)

class Polynomial():
    def __init__(self, coeffs: IterableType[int]):
        assert isinstance(coeffs, Iterable) and all(isinstance(c, int) for c in coeffs) and len(coeffs) == KYBER_N, "wrong argument type"
        self.coeffs = list(coeffs) # need to make a copy!!!

    @classmethod
    def cbd(cls, buf):
        buf = list(buf)
        buf_len = KYBER_ETA * KYBER_N // 4
        assert len(buf) == buf_len
        cbuf = ffi.new(f'const unsigned char [{buf_len}]', buf)
        cpoly = ffi.new('poly *')
        pyber_clib.cbd(cpoly, cbuf)
        return Polynomial.from_cpoly(cpoly)

    @classmethod
    def getnoise(cls, coins, nonce):
        coins = list(coins)
        assert len(coins) == KYBER_SYMBYTES
        ccoins_buf = ffi.new(f'const unsigned char [{KYBER_SYMBYTES}]', coins)
        cpoly = ffi.new('poly *')
        pyber_clib.poly_getnoise(cpoly, ccoins_buf, nonce)
        return Polynomial.from_cpoly(cpoly)

    @classmethod
    def random(cls, rnd=None):
        """create new Polynomial of order KYBER_N with random coefficients over Z/KYBER_Q """
        if not rnd:
            rnd = random.Random()
            rnd.seed(1)
        
        def random_word(min, max):
            return (rnd.randint(min, max))

        return cls(coeffs=[random_word(0, KYBER_Q - 1) for _ in range(KYBER_N)])
    
    @classmethod
    def from_cpoly(cls,cpoly):
        return cls(cpoly.coeffs)

    @classmethod
    def zero(cls):
        """create new Polynomial of order KYBER_N with all coefficients set to 0 """
        return cls(coeffs=[0 for _ in range(KYBER_N)])

    def __iter__(self):
        for c in self.coeffs:
            yield c

    def dump(self):
        term_width, _ = shutil.get_terminal_size()
        col = 0
        nibles = (int(ceil(log2(KYBER_Q))) + 3) // 4
        for c in self.coeffs:
            col += nibles + 1
            if col + nibles >= term_width:
                end = os.linesep
                col = 0
            else:
                end = " "
            print(f"{c:0>{nibles}X}", end=end)

        print("")

    def to_cpoly(self):
        return [list(self)]
    
    def __add__(self, other):
        """ add two Polynomials and return result """
        cpoly_a = ffi.new('poly *', self.to_cpoly())
        cpoly_b = ffi.new('poly *', other.to_cpoly())
        cpoly_r = ffi.new('poly *')

        pyber_clib.poly_add(cpoly_r, cpoly_a, cpoly_b)
        pyber_clib.poly_freeze(cpoly_r)

        return Polynomial.from_cpoly(cpoly_r)

    def __sub__(self, other):
        """ add two Polynomials and return result """
        cpoly_a = ffi.new('poly *', self.to_cpoly())
        cpoly_b = ffi.new('poly *', other.to_cpoly())
        cpoly_r = ffi.new('poly *')

        pyber_clib.poly_sub(cpoly_r, cpoly_a, cpoly_b)
        pyber_clib.poly_freeze(cpoly_r)

        return Polynomial.from_cpoly(cpoly_r)

    def __eq__(self, other):
        return self.coeffs == other.coeffs
        
class PolynomialVector():
    def __init__(self, polys: IterableType[Polynomial]):
        assert isinstance(polys, Iterable) and all(isinstance(p, Polynomial) for p in polys) and len(polys) == KYBER_K, "wrong argument type"
        self.polys = polys

    @classmethod
    def random(cls, rnd=None):
        return cls(polys=[Polynomial.random(rnd) for _ in range(KYBER_K)])

    @classmethod
    def zero(cls):
        return cls(polys=[Polynomial.zero() for _ in range(KYBER_K)])

    def __iter__(self):
        for p in self.polys:
            yield from list(p) # flatten

    def dump(self):
        for i, p in enumerate(self.polys):
            print(f" Poly[{i}]:")
            p.dump()

    def to_cpolyvec(self):
        return [[p.to_cpoly() for p in self.polys]]

    def __mul__(self, other):
        cpolyvec_a = ffi.new('polyvec *', self.to_cpolyvec())
        cpolyvec_b = ffi.new('polyvec *', other.to_cpolyvec())
        cpoly_r = ffi.new('poly *')

        pyber_clib.polyvec_ntt(cpolyvec_a)
        pyber_clib.polyvec_ntt(cpolyvec_b)
        pyber_clib.polyvec_pointwise_acc(cpoly_r, cpolyvec_a, cpolyvec_b)
        pyber_clib.poly_invntt(cpoly_r)

        return Polynomial.from_cpoly(cpoly_r)



def polyvec_nega_mac(p_r: Polynomial, pv_a: PolynomialVector, pv_b: PolynomialVector, subtract=False) -> Polynomial:
    """ 

        @returns: Polynomial  (pv_a * pv_b - p_r) if subtract:True else (pv_a * pv_b + p_r) 
    """
    assert isinstance(p_r, Polynomial) and isinstance(
        pv_a, PolynomialVector) and isinstance(pv_b, PolynomialVector)


    cpolyvec_a = ffi.new('polyvec *', pv_a.to_cpolyvec())
    cpolyvec_b = ffi.new('polyvec *', pv_b.to_cpolyvec())
    cpoly_r = ffi.new('poly *', p_r.to_cpoly())

    pyber_clib.polyvec_nega_mac(cpoly_r, cpolyvec_a, cpolyvec_b, 1 if subtract else 0)

    return Polynomial(cpoly_r.coeffs) # need to copy!!!



__all__ = ['polyvec_nega_mac', 'KYBER_N',
           'KYBER_K', 'KYBER_Q', 'KYBER_ETA', 'Polynomial', 'PolynomialVector', "getnoise_bytes"]


if __name__ == '__main__':
    # r2 = Polynomial.cbd(range(KYBER_ETA * KYBER_N // 4))
    # r2.dump()

    coins = [0 for _ in range(KYBER_SYMBYTES)]
    nonce = 0
    # r3 = Polynomial.getnoise(coins, 0)
    # r3.dump()
    l1 = getnoise_bytes(coins, nonce)
    print(l1)

    exit(0)

    a = PolynomialVector.random()
    # print("a--------")
    # a.dump()
    b = PolynomialVector.random()
    # print("\nb--------")
    # b.dump()
    r = Polynomial.random()
    # print("r--------")
    # r.dump()

    exp = polyvec_nega_mac(r, a, b)
    print("a*b + r --------")
    # exp.dump()

    # e2 = (a * b) + r
    # e2.dump()
    # assert exp == e2

    exp = polyvec_nega_mac(r, a, b, subtract=True)
    e2 = r - (a * b)

    exp.dump()
    e2.dump()
    assert exp == e2
