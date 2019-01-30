from typing import List
from . import Sim
import pathlib
import subprocess
import os

class Ghdl(Sim):
    def __init__(self, vhdl_version: str, top: str):

        super(Ghdl, self).__init__(top=top)

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

        self.libs = set()

        self.warn_opts = ['-Wbinding', '-Wreserved', '-Wlibrary',
                          '-Wvital-generic', '-Wdelayed-checks', '-Wbody -Wspecs', '-Wunused']

        self.common_args = f'--work=work --workdir={self.workdir} --std={self.vhdl_version}'

        self.phases = {
            # 'import': '{cmd} -i {common_args} {opts} {sources}',
            # 'make': '{cmd} --gen-makefile {common_args} {opts} {warn_opts} {top} {gen} ',
            'run': '{cmd} -r {top} --vpi={vpi} {gen} {vcd_arg} --ieee-asserts=disable'
        }
        
    @classmethod
    def from_manifest(cls, manifest, module_name):
        mod=manifest.get_module(module_name)
        vhdl_version = mod.vhdl_version
        if not vhdl_version:
            vhdl_version = "08"
        sim = cls(vhdl_version=vhdl_version, top=mod.top)
        
        for file, library in manifest.module_dependencies(module_name).items():
            sim.add_source(file=file, library=library)
            
        return sim

        
    
    def libs_arg_str(self):
        return ' '.join(['-P' + p for p in self.libs ])

    def add_source(self, file, build_path=".", library=None):
        if library:
            lib_path=f'{build_path}/{library}/{self.vhdl_version}'
            pathlib.Path(lib_path).mkdir(parents=True, exist_ok=True)
            subprocess.run(f'ghdl -a --work={library} --workdir={lib_path} --std={self.vhdl_version} {file}'.split()).check_returncode()
            self.libs.add(lib_path)
        else:
            l = self.libs_arg_str()
            subprocess.run(f'ghdl -a --work=work --workdir={self.workdir} --std={self.vhdl_version} {l} {file}'.split()).check_returncode()

        #self.common_args = self.common_args + ' ' + f'-P{lib_path}'

    def run_test(self, test_modules: List[str], test_case: str = None):
        subprocess.run(f'ghdl -e --work=work --workdir={self.workdir} --std={self.vhdl_version} {self.libs_arg_str()} {self.top}'.split()).check_returncode()
        super(Ghdl, self).run_test(test_modules, test_case)


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
            return ""
        


__all__ = ['Ghdl']
