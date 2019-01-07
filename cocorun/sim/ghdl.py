from typing import List
from . import Sim
import pathlib
import subprocess
import os

class Ghdl(Sim):
    def __init__(self, vhdl_version: str = '08'):

        super(Ghdl, self).__init__()

        self.sim_name = 'ghdl'
        self.cmd = 'ghdl'
        self.top_lang = 'vhdl'
        self.work = 'work'
        self.opts = ['-fcaret-diagnostics', '-fdiagnostics-show-option', '-O3']
        self.vhdl_version = vhdl_version

        work_path = f'work/{self.vhdl_version}'

        pathlib.Path(work_path).mkdir(parents=True, exist_ok=True)
        self.workdir = work_path

        self.vcd_file = None

        self.libs = []

        self.warn_opts = ['-Wbinding', '-Wreserved', '-Wlibrary',
                          '-Wvital-generic', '-Wdelayed-checks', '-Wbody -Wspecs', '-Wunused']

        self.common_args = f'--work=work --workdir={self.workdir} --std={self.vhdl_version}'

        self.phases = {
            # 'import': '{cmd} -i {common_args} {opts} {sources}',
            # 'make': '{cmd} --gen-makefile {common_args} {opts} {warn_opts} {top} {gen} ',
            'run': '{cmd} -r {top} --vpi={vpi} {gen} {vcd_arg} --ieee-asserts=disable'
        }
    
    def libs_arg_str(self):
        return ' '.join(['-P' + p for p in self.libs ])
    
    def add_sources(self, sources):
        l = self.libs_arg_str()
        for source in sources:
            subprocess.run(f'ghdl -a --work=work --workdir={self.workdir} --std={self.vhdl_version} {l} {source}'.split()).check_returncode()
    
    def add_library(self, name, path, sources):
        lib_path=f'{path}/{name}/{self.vhdl_version}'
        pathlib.Path(lib_path).mkdir(parents=True, exist_ok=True)
        for source in sources:
            subprocess.run(f'ghdl -a --work={name} --workdir={lib_path} --std={self.vhdl_version} {source}'.split()).check_returncode()
        self.libs.append(lib_path)
        #self.common_args = self.common_args + ' ' + f'-P{lib_path}'

    def run_test(self, top, test_modules: List[str], test_case: str = None):
        subprocess.run(f'ghdl -e --work=work --workdir={self.workdir} --std={self.vhdl_version} {self.libs_arg_str()} {top}'.split()).check_returncode()
        super(Ghdl, self).run_test(top, test_modules, test_case)


    @property
    def vcd_arg(self):
        pre = None
        if self.vcd_file:
            if self.vcd_file.endswith('.vcd.gz'):
                pre = '--vcdgz='
            if self.vcd_file.endswith('.ghw'):
                pre = '--wave='
            elif self.vcd_file.endswith('.fst'):
                pre = '--fst='
            else:
                pre = '--vcd='
            # return self.vcd_arg + self.vcd_file + ' --write-wave-opt=wave.options'
        if pre:
            return pre + self.vcd_file  # + ' --write-wave-opt=wave.options'
        else:
            return None
        


__all__ = ['Ghdl']
