from typing import List
from . import Sim
from ..conf import *
import pathlib
import subprocess
import os


def language_ghdl_version(language:str):
    vhdl_version = '08'
    if language:
        lang_version = language.split('.')
        if not lang_version or len(lang_version) == 0 or lang_version[0].lower() != "vhdl":
            raise Exception(f"Bad language {language}")
        if len(lang_version) > 1:
            if len(lang_version[1]) == 2:
                vhdl_version = lang_version[1]
            elif len(lang_version[1]) == 4 and (lang_version[1][:1] in ['19', '20'] ):
                vhdl_version = lang_version[1][2:4]
    return vhdl_version  

class Ghdl(Sim):
    def __init__(self, manifest: Manifest, build_path="."):

        super(Ghdl, self).__init__(manifest)

        self.build_path = build_path

        self.sim_name = 'ghdl'
        self.cmd = 'ghdl'
        self.top_lang = 'vhdl'
        self.work = 'work'
        self.opts = ['-fcaret-diagnostics', '-fdiagnostics-show-option', '-O3']

        self.wave_dump = None

        self.libs = set()

        self.warn_opts = ['-Wbinding', '-Wreserved', '-Wlibrary',
                          '-Wvital-generic', '-Wdelayed-checks', '-Wbody', '-Wspecs', '-Wunused']
    
    def libs_arg_str(self):
        return ' '.join(['-P' + p for p in self.libs ])

    def analyze(self, hdl: HdlSource):
        vhdl_version = language_ghdl_version(hdl.language)
        ## FIXME totally wrong!
        ## need to keep track of lib path of dependencies as a hierarchy
        if hdl.lib and hdl.lib.lower() != 'work':
            lib_path = pathlib.Path(self.build_path).joinpath(hdl.lib, vhdl_version)
            lib_path.mkdir(parents=True, exist_ok=True)
            subprocess.run(f'ghdl -a --work={hdl.lib} --workdir={lib_path} --std={vhdl_version} {hdl.path}'.split()).check_returncode()
            self.libs.add(str(lib_path))
        else:
            workdir = pathlib.Path(self.build_path).joinpath('work', vhdl_version)
            l = self.libs_arg_str()
            subprocess.run(f'ghdl -a --workdir={workdir} --std={vhdl_version} {l} {hdl.path}'.split()).check_returncode()

    def run_test(self, bundle_name, test_case: str = None):

        hdl_sources, mod = self.manifest.hdl_sources(bundle_name)

        top_module_name = mod.top

        print("top_module.tb_files=", mod.tb_files)

        test_modules = list(filter(lambda tb_file: tb_file.endswith(".py"), mod.tb_files))

        if len(test_modules) == 0:
            self.log.error(f"no python testbench found in Manifest for bundle {bundle_name}")
            exit(1)

        vhdl_version = language_ghdl_version(mod.language)
        work_path = f'work/{vhdl_version}'

        pathlib.Path(work_path).mkdir(parents=True, exist_ok=True)

        for hdl in hdl_sources:
            print(f"analyzing {hdl.path}")
            self.analyze(hdl)
        
        subprocess.run(f'ghdl -e --work=work --workdir={work_path} --std={vhdl_version} {self.libs_arg_str()} {top_module_name}'.split()).check_returncode()
        
        super(Ghdl, self).run_test('{cmd} -r ' + top_module_name + ' --vpi={vpi} {gen} {vcd_arg} --ieee-asserts=disable', top_module_name, test_modules, test_case)


    @property
    def vcd_arg(self):
        pre = None
        if self.wave_dump:
            if self.wave_dump.endswith('.vcd.gz'):
                pre = '--vcdgz='
            if self.wave_dump.endswith('.ghw'):
                pre = '--wave='
            elif self.wave_dump.endswith('.fst'):
                pre = '--fst='
            else:
                pre = '--vcd='
            # return self.vcd_arg + self.vcd_file + ' --write-wave-opt=wave.options'
        if pre:
            return pre + self.wave_dump  # + ' --write-wave-opt=wave.options'
        else:
            return ""
        


__all__ = ['Ghdl']
