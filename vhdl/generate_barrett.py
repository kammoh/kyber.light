#!/usr/bin/env python3

from os import path, getcwd
from math import floor, log2, ceil
from subprocess import run
import argparse
from jinja2 import Environment, FileSystemLoader, Template

import pysmt
from pysmt.shortcuts import SBV, Symbol, is_valid, Equals, Solver, BVLShr, BVUDiv, BV
from pysmt.typing import BV16, INT, BVType

parser = argparse.ArgumentParser(description='Generate Barrett reduction and division module in VHDL')
parser.add_argument('M', help='constant modulus')
parser.add_argument('--with-quotient', dest='generate_quotient', required=False, action='store_const', const=True, default=False, help='generate quotient')
parser.add_argument('--test-only', dest='test_only', required=False, action='store_const', const=True, default=False, help='don\'t generate the vhdl files, only run cocotb test')
parser.add_argument('--pipeline-levels', dest='pipeline_levels', required=False, type=int, default=2, help='number of pipeline stages')

args = parser.parse_args()


def log2ceil(x): return ceil(log2(x))


M = int(args.M)
n = log2ceil(M)
generate_quotient = args.generate_quotient
generate_vhdl = not args.test_only

print(f'generating reduction module for M={M} ({n}-bit output, {2*n}-bit input)')

print(f"M={M} n={n} bits")

i = 0  # i >= 0

prod_bits = log2ceil((M-1)**2)
gamma = prod_bits - n

def find_ab():
  for a in range(1, n+1 + 1):
    # a - b > 0, n + b > 0
    for b in range(-2, -n, -1):
      bad = False
      for U in range((1 << prod_bits) - M, (1 << prod_bits) - 1):
        q = U // M
        Ul = U >> (n+b)
        mu = 2**(n+a) // M
        q_hat = (Ul * mu) >> (a - b)
        e = q - q_hat
        if e > 1:
          bad = True
          break
      if not bad:
        print(f"a={a} b={b}")
        return (a, b)
# a = 12 #n + 1 + i

def solve_ab(M):
    n = log2ceil(M)

    with Solver() as solver:
      width = max(2*n + 1, n + 2 + n + 2 + 1)

      u = Symbol('u', BVType(width))
      q = Symbol('q', BVType(width))
      for alpha in range(n - 3, 2*n):
        for beta in range(0, -n, -1):
            mu = 2**(n+alpha) // M

            uh = BVLShr(u, n + beta)

            q_hat = BVLShr(uh * mu, alpha - beta)

            solver.add_assertion(u <= (2**(2*n)-1))
            solver.add_assertion(q <= ((2**(2*n) - 1) // M))
            solver.add_assertion(u >= q * M)
            r = u - q * M
            solver.add_assertion(r < M)

            e = q - q_hat
            solver.add_assertion(e > BV(1, width))
            res = solver.solve()
            if not res:
                print(f"[] alpha={alpha} beta={beta}")
                return alpha, beta
            # else:
            #     print(
            #         f"alpha={alpha} beta={beta} {res}: u={solver.get_value(u)} e={solver.get_value(e)} q={solver.get_value(q)} q_hat={solver.get_value(q_hat)}, uh={solver.get_value(uh)} mu={mu}")
                
a,b = solve_ab(M)

# # TODO FIXME 
# print("--- TODO: FIXME! REMEMBER TO FIX a,b SOLVER")

# if M == 12289:
#     a = 14

# b=-1

assert a - b > 0
assert n + b > 0

mu = 2**(n+a) // M
mu_bits = log2ceil(mu)

uh_bits = n - b 
q_hat_bits = n + mu_bits - a
ul_bits = q_hat_bits

entity_name = f'barrett_{M}'
vhdl = []

flopoco = f'/Volumes/src/vhdl/arith/flopoco.orig/build/flopoco'
# flopoco_mult = 'IntConstMultOptTernary'  # 'IntConstMultOpt'
flopoco_mult = 'IntConstMultShiftAddOptTernary'


pipeline_levels = args.pipeline_levels
pipelined_mult = False

out_regs = pipeline_levels >= 3

mult_in_port = 'x_in0'
mult1_out_port = f'x_out0_c{mu}'
mult2_out_port = f'x_out0_c{M}'


template = Template('''
''')







vdhl_sources = []

# print(f"generating multiplier by mu={mu} with {n - b}-bit input")
ent_name = f'{flopoco_mult}_{mu}_{n - b}'
vhdl_file = f'{ent_name}.vhdl'
# Uh * mu
n_param = 'constant'
if generate_vhdl:
  run([flopoco, flopoco_mult, f'{n_param}={mu}', f'wIn={uh_bits}',
      f'outputFile={vhdl_file}', f'name={ent_name}', f'frequency=0'], check=True)
vdhl_sources.append(vhdl_file)

ent_name = f'{flopoco_mult}_{M}_{q_hat_bits}'
vhdl_file = f'{ent_name}.vhdl'
# q_hat * M
if generate_vhdl:
  run([flopoco, flopoco_mult, f'{n_param}={M}', f'wIn={q_hat_bits}', f'wOut={n+1}',
      f'outputFile={vhdl_file}', f'name={ent_name}', f'frequency=0'], check=True)
vdhl_sources.append(vhdl_file)



vhdl_file = f'{entity_name}.vhdl'

if generate_vhdl:
  env = Environment(loader=FileSystemLoader('templates'))

  template = env.get_template('barrett.vhdl.jinja2')

  rendered_vhdl = template.render(dict(globals()))
  
  with open(vhdl_file, 'w') as outfile:
    outfile.write(rendered_vhdl)
    
vdhl_sources.append(vhdl_file)




vdhl_sources = [path.join(getcwd(), src) for src in vdhl_sources ]
run(['make', '-C', 'tb', f'VHDL_SOURCES={" ".join(vdhl_sources)}',
     f'TOPLEVEL={entity_name}', 'MODULE=barrett_tb'], check=True)

# run(['make', '-C', 'tb', 'yosys', f'VHDL_SOURCES={" ".join(vdhl_sources)}', f'TOPLEVEL={entity_name}', 'MODULE=tb.barrett_tb'])
