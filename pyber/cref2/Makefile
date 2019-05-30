CC=/usr/bin/gcc
LDFLAGS=-L/usr/local/Cellar/openssl/1.0.2r/lib -lssl -lcrypto
CFLAGS=-I/usr/local/Cellar/openssl/1.0.2r/include

SOURCES= cbd.c fips202.c indcpa.c kem.c ntt.c poly.c polyvec.c reduce.c verify.c symmetric-fips202.c
HEADERS= api.h cbd.h fips202.h indcpa.h ntt.h params.h poly.h polyvec.h reduce.h rng.h verify.h symmetric.h

PQCgenKAT_kem: $(HEADERS) $(SOURCES) PQCgenKAT_kem.c
	$(CC) -o $@ $(SOURCES) PQCgenKAT_kem.c $(CFLAGS) $(LDFLAGS)

test_kyber768: $(SOURCES) $(HEADERS) test_kyber.c randombytes.c randombytes.h
	$(CC) $(CFLAGS) $(LDFLAGS) -DKYBER_K=3 $(SOURCES) randombytes.c test_kyber.c -o test_kyber768

test: $(HEADERS) $(SOURCES) test.c
	$(CC) -o $@ $(SOURCES) test.c $(CFLAGS) $(LDFLAGS)

.PHONY: clean

clean:
	-rm PQCgenKAT_kem

