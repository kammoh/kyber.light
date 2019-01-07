from cocorun.sim.ghdl import Ghdl
import os
import subprocess
import pathlib

# os.system('ghdl --remove --std=08 --work=PoC --workdir=PoC/PoC/08')
# os.system('mkdir -p PoC/PoC/08')
# os.system('rm -rf PoC/PoC/08/*')
# os.system('cat poc.files | xargs ghdl -i --std=08 --work=PoC --workdir=PoC/PoC/08')
# # os.system('ghdl --gen-makefile --std=08 --work=PoC --workdir=PoC/PoC/08 ocram_sp > Makefile.poc')
# os.system('ghdl --gen-makefile --std=08 --work=work --workdir=work -PPoC/PoC/08 > Makefile')
# os.system('make')

import tiny_keccak


poc_srcs = [
    'PoC/src/common/my_config.vhdl', 'PoC/src/common/my_project.vhdl', 'PoC/src/common/utils.vhdl', 'PoC/src/common/config.vhdl', 'PoC/src/common/strings.vhdl', 
    'PoC/src/common/vectors.vhdl', 
    'PoC/src/mem/mem.pkg.vhdl', 'PoC/src/mem/ocram/ocram_sp.vhdl',  'PoC/src/mem/ocram/ocram.pkg.vhdl', 
    ]

sim = Ghdl(vhdl_version="08")
sim.add_library(name='PoC', path='./PoC', sources=poc_srcs)

srcs = sources=['keccak_pkg.vhdl', 'rho_rom.vhdl',  'controller.vhdl',  'iota_lut.vhdl', 'shift_reg.vhdl', 'slice_unit.vhdl',  'datapath.vhdl',  'keccak_core.vhdl']

sim.add_sources(srcs)
sim.vcd_file='dump.ghw'
sim.run_test(top='keccak_core', test_modules=['tests'])

def synth_vivado(srcs, top):
    tcl = pathlib.Path('../vivado').join('vivado.tcl')
    
    cmd = ["vivado", "-mode", "tcl", "-nojournal", "-source", tcl, "-tclargs", "3", "4"]
    
    env={'VHDL_SRCS':(" ").join(srcs), 'TOP_MODULE':top}
    env.update(dict(os.environ))
    
    try:
        proc = subprocess.Popen(cmd, env=env)
        if proc.wait() != 0:
            logger.error("There were some errors")
    except ValueError as e:
        print("got ", e.message)
        exit(1)

# synth_vivado(srcs, 'keccak_core')
        
        