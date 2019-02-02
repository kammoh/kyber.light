import  tiny_keccak

k = tiny_keccak.Keccak(rate = 200 - 256 // 4 , delim=0x06)
k = tiny_keccak.Keccak(rate = 200 , delim=0x06)

# k.py_update(b'hello')
# k.py_update(b' e')
# k.py_update(b'world')


# k.pad()
# k.xorin()
# k.slice_proc(0)
# k.rho(0)
# print('\n'.join(format(x, '016X') for x in k.state))
# print("\n\n")

def dump(sparse=True):
    from array import array

    mem = array('I', [0] * 208)

    # for i in range(0, 8):
    #     mem[i] = (k.state[0] >> (i*8)) & 0xff

    for j in range(0,13):
        if j == 0:
            s1 = "".zfill(64)
        else:
            s1 = list(reversed(bin(k.state[2* j - 1] )[2:].zfill(64)))
        s2 = list(reversed(bin(k.state[2* j] )[2:].zfill(64)))
        for i in range(0, 16):
            mem[j * 16 + i] = int(s2[4*i + 3]) * 128 + int(s1[4*i + 3]) * 64 + int(s2[4*i + 2]) * 32 + int(s1[4*i + 2]) * 16 + int(s2[4*i + 1]) * 8 + int(s1[4*i + 1]) * 4 + int(s2[4*i ]) * 2 + int(s1[4*i]) * 1

    for i in range(0, len(mem)):
        if (not sparse) or mem[i] != 0:
            print(f'ram[{i:3}]   {mem[i]:2X}')


# while(True):
#     k.slice_proc(round_cntr)
#     k.rho()
#     round_cntr += 1
#     if round_cntr == 23:
#         break

# k.slice_proc(3)

# k.slice_proc(2)
# k.rho()

for i in range(0,200):
    k.py_update(bytes([i]))
k.xorin()
dump(sparse=False)
k.keccakf()
# print("\n after 24 rounds:")
# # print('\n'.join(format(x, '016X') for x in k.state))
dump(sparse=False)

print('\n'.join(format(x, '016X') for x in k.state))



# print(k.py_finalize(32).hex())




