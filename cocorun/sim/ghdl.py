from typing import List
from ..sim import Sim
from ..conf import *
from typing import Dict
import pathlib
import subprocess
import os


def language_ghdl_version(language: str):
    vhdl_version = '08'
    if language:
        lang_version = language.split('.')
        if not lang_version or len(lang_version) == 0 or lang_version[0].lower() != "vhdl":
            raise Exception(
                f"Language {language} is not supported by this simulator")
        if len(lang_version) > 1:
            if len(lang_version[1]) == 2:
                vhdl_version = lang_version[1]
            elif len(lang_version[1]) == 4 and (lang_version[1][:1] in ['19', '20']):
                vhdl_version = lang_version[1][2:4]
    return vhdl_version


class Ghdl(Sim):
    def __init__(self, manifest: Manifest, log_level='INFO', build_path="."):

        super().__init__(manifest, log_level)

        self.build_path = build_path

        self.sim_name = 'ghdl'
        self.cmd = 'ghdl'
        self.top_lang = 'vhdl'
        self.work = 'work'
        self.generics = None
        self.warn_args = ['-fcaret-diagnostics', '-fdiagnostics-show-option']
        # --warn-library --warn-default-binding --warn-binding --warn-reserved --warn-nested-comment --warn-parenthesis --warn-vital-generic --warn-delayed-checks --warn-body ' + \
        #'--warn-specs --warn-runtime-error --warn-shared --warn-hide --warn-unused --warn-others --warn-pure --warn-static -fcolor-diagnostics -fdiagnostics-show-option -fcaret-diagnostics'
        self.optimize_args = '-O3'
        self.wave_dump = None
        self.vpi_trace = None
        self.libs = dict()

    def libs_arg_str(self):
        return ' '.join(['-P' + str(path) for lib, path in self.libs.items() if lib != 'work'])

    def analyze(self, hdl: HdlSource, sim_config: Dict):
        vhdl_std = language_ghdl_version(hdl.language)

        work = hdl.lib
        if not hdl.lib or hdl.lib.lower() == 'work':
            work = 'work'

        lib_path = pathlib.Path(self.build_path).joinpath(work, vhdl_std)

        if not work in self.libs:
            lib_path.mkdir(parents=True, exist_ok=True)
            self.libs[work] = lib_path

        assert lib_path.exists() and lib_path.is_dir(
        ), f'Folder {lib_path} should have been created'

        libs_arg = self.libs_arg_str()  # first get list of all previously added libs

        analyze_config = {
            'work': work,
            'workdir': str(lib_path),
            'vhdl_std': vhdl_std,
            'libs_arg': libs_arg,
            'hdl_path': hdl.path,
        }

        sim_config = dict(sim_config)  # create a local copy
        # update with local (per hdl) settings
        sim_config.update(analyze_config)

        self.run_cmd(
            'ghdl -a --work={work} --workdir={workdir} --std={vhdl_std} {libs_arg} {warn_args} {optimize_args} {hdl_path}', sim_config)

    def run_test(self, bundle_name, test_case: str = None):

        hdl_sources, mod = self.manifest.hdl_sources(bundle_name)

        top_module_name = mod.top

        print("top_module.tb_files=", mod.tb_files)

        test_modules = list(
            filter(lambda tb_file: tb_file.endswith(".py"), mod.tb_files))

        if len(test_modules) == 0:
            self.log.error(
                f"no python testbench found in Manifest for bundle {bundle_name}")
            exit(1)

        vhdl_std = language_ghdl_version(mod.language)
        work = 'work'
        vpi_trace = 'trace.vpi'

        sim_config = {
            'cmd': self.cmd,
            'top_module_name': top_module_name,
            'gen': [f'-g{k}={v}' for k, v in self.generics.items()] if self.generics else None,
            'vcd_arg': self.vcd_arg,
            'vpi_trace': f'--vpi-trace={vpi_trace}' if vpi_trace else None,
            'work': work,
            'workdir': f'{work}/{vhdl_std}',
            'vhdl_std': vhdl_std,
            'warn_args': self.warn_args,
            'optimize_args': self.optimize_args,
            'test_modules': test_modules,
            'test_case': test_case,
        }

        for hdl in hdl_sources:
            self.log.info(f"analyzing {hdl.path}")
            self.analyze(hdl, sim_config)

        sim_config['lib_args'] = self.libs_arg_str() # updated list of libs
        elab_command = 'ghdl -e --work={work} --workdir={workdir} --std={vhdl_std} {warn_args} {optimize_args} {lib_args} {top_module_name}'
        run_command = '{cmd} -r {top_module_name} --vpi={vpi} {vpi_trace} {gen} {vcd_arg} --ieee-asserts=disable'

        self.run_cmd(elab_command, sim_config)
        super(Ghdl, self).run_test(run_command, sim_config)

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
