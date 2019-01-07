import  tiny_keccak

k = tiny_keccak.Keccak(rate = 200 - 256 // 4 , delim=0x06)

# k.py_update(b'hello')
# k.py_update(b' e')
# k.py_update(b'world')


# k.pad()
# k.xorin()
k.slice_proc(0)
# k.rho(0)
# print('\n'.join(format(x, '016X') for x in k.state))
# print("\n\n")

def dump(sparse=True):
    from array import array

    mem = array('I', [0] * 200)

    for i in range(0, 8):
        mem[i] = (k.state[0] >> (i*8)) & 0xff

    for j in range(1,13):
        s1 = list(reversed(bin(k.state[2* j - 1] )[2:].zfill(64)))
        s2 = list(reversed(bin(k.state[2* j] )[2:].zfill(64)))
        for i in range(0, 16):
            mem[(j-1) * 16 + i + 8] = int(s2[4*i + 3]) * 128 + int(s1[4*i + 3]) * 64 + int(s2[4*i + 2]) * 32 + int(s1[4*i + 2]) * 16 + int(s2[4*i + 1]) * 8 + int(s1[4*i + 1]) * 4 + int(s2[4*i ]) * 2 + int(s1[4*i]) * 1

    for i in range(0, 200):
        if (not sparse) or mem[i] != 0:
            print(f'ram[{i:3}]   {mem[i]:2X}')


round_cntr = 0

# while(True):
#     k.slice_proc(round_cntr)
#     k.rho()
#     round_cntr += 1
#     if round_cntr == 23:
#         break

# k.slice_proc(3)

k.keccakf(False)
# print("\n after 24 rounds:")
# # print('\n'.join(format(x, '016X') for x in k.state))
dump(sparse=False)



# print(k.py_finalize(32).hex())




