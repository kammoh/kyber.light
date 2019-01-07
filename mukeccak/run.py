from cocorun.sim.ghdl import Ghdl
import os

# os.system('ghdl --remove --std=08 --work=PoC --workdir=PoC/PoC/08')
# os.system('mkdir -p PoC/PoC/08')
# os.system('rm -rf PoC/PoC/08/*')
# os.system('cat poc.files | xargs ghdl -i --std=08 --work=PoC --workdir=PoC/PoC/08')
# # os.system('ghdl --gen-makefile --std=08 --work=PoC --workdir=PoC/PoC/08 ocram_sp > Makefile.poc')
# os.system('ghdl --gen-makefile --std=08 --work=work --workdir=work -PPoC/PoC/08 > Makefile')
# os.system('make')

import tiny_keccak

sim = Ghdl(vhdl_version="08")
sim.add_library(name='PoC', path='./PoC', sources=[
    'PoC/src/common/my_config.vhdl', 'PoC/src/common/my_project.vhdl', 'PoC/src/common/utils.vhdl', 'PoC/src/common/config.vhdl', 'PoC/src/common/strings.vhdl', 
    'PoC/src/common/vectors.vhdl', 
    'PoC/src/mem/mem.pkg.vhdl', 'PoC/src/mem/ocram/ocram_sp.vhdl',  'PoC/src/mem/ocram/ocram.pkg.vhdl', 
    ])


sim.add_sources(sources=['keccak_pkg.vhdl', 'rho_rom.vhdl',  'controller.vhdl',  'iota_lut.vhdl', 'shift_reg.vhdl', 'slice_unit.vhdl',  'datapath.vhdl',  'keccak_core.vhdl'])
sim.vcd_file='dump.ghw'
sim.run_test(top='keccak_core', test_modules=['tests'])

