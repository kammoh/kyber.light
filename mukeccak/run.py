from cocorun.sim import Ghdl
from cocorun.conf import Manifest
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
import os
import shutil


manifest = Manifest.load_from_file()

sim = Ghdl.from_manifest(manifest, 'keccak')


# sim.vcd_file = 'dump.ghw'
sim.run_test(test_modules=['keccak_core_tb'])


def synth_vivado(srcs, top):
    tcl = pathlib.Path('vivado').joinpath('vivado.tcl')

    cmd = ["vivado", "-mode", "tcl", "-nojournal", "-source", tcl, "-tclargs", "3", "4"]

    env={'VHDL_SRCS':(" ").join(srcs), 'TOP_MODULE':top}
    env.update(dict(os.environ))

    try:
        proc = subprocess.Popen(cmd, env=env)
        if proc.wait() != 0:
            print("There were some errors")
    except ValueError as e:
        print("got ", e)
        exit(1)


    # work_root = 'build'

    # files = [{
    #     'name': os.path.relpath(file_name, work_root),
    #     'file_type': 'vhdlSource-2008',
    #     'logical_name': 'work'
    # } for file_name in sources]

    # poc_files = [{
    #     'name': os.path.relpath(file_name, work_root),
    #     'file_type': 'vhdlSource-2008',
    #     'logical_name': 'PoC'
    # } for file_name in poc_srcs]

    # paramtypes = ['vlogdefine', 'vlogparam']
    # name = 'keccak_vivado_0'
    # tool = 'vivado'
    # tool_options = {
    #     'part': 'xc7a35tcsg324-1',
    # }

    # eda_api = {
    #     'files'        : files + poc_files,
    #     'name'         : 'keccak_project',
    #     # 'parameters'   : parameters,
    #     'toplevel'     : top
    # }

    # backend = get_edatool(tool)(eda_api=eda_api,work_root=work_root)
    # args = []
    # os.makedirs(work_root, exist_ok=True)
    # backend.configure(args)

    # backend.build()
    # backend.run(args)



synth_vivado(srcs, top)
