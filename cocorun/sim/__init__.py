import subprocess
import os,os.path
import re
import sys
from typing import Dict, List, Callable
import collections
import sysconfig
import cocotb
import platform
import pathlib

class Sim(object):
    def __init__(self,top):
        self.sim_name = self.__class__.__name__
        self.cmd = None
        self.warn_opts = None
        self.work = None
        prefix_dir = os.environ.get('COCOTB', os.path.dirname(cocotb.__file__))
        share_dir = os.path.join(prefix_dir, 'share')
        lib_dir = os.path.join(share_dir, 'lib')
        platform_libs_dir = os.path.join(lib_dir, 'build','libs', platform.machine())
        self.cocotb_path = prefix_dir
        self.top = top
        self.top_lang=''
        self.seed=None
        self.log_level=None
        self.phases = collections.OrderedDict()
        self.python_lib_path = sysconfig.get_config_var('LIBDIR')
        self.python_include_path = sysconfig.get_config_var('INCLUDEPY')
        self.python_bin = sys.executable
        dyn_lib_nam = sysconfig.get_config_vars('LIBRARY')[0][:-2]
        dyn_libs = [ f for ext in ['dylib','dll', 'so'] for f in pathlib.Path(self.python_lib_path).glob(dyn_lib_nam + '.' + ext)]
        self.python_dyn_lib = dyn_libs[0]
        self.vpi_dir = platform_libs_dir
        self.vpi = os.path.join(platform_libs_dir, 'cocotb.vpi')
        self.opts=[]
        self.generics=collections.OrderedDict()
        self.workdir='.'
        self.common_args=''

        make_cmd = f'make SIM={self.sim_name} SIM_ROOT={share_dir} PYTHON_INCLUDEDIR={self.python_include_path} PYTHON_DYN_LIB={self.python_dyn_lib} PYTHON_BIN={self.python_bin} ARCH={platform.machine()} -C {lib_dir} vpi_lib'
        # print('running', make_cmd)
        proc = subprocess.Popen(make_cmd.split())
        print("building VPI:")
        if proc.wait() != 0:
            raise RuntimeError()
        

    def get_top(self):
        if self.top:
            if type(self.top) is tuple:
                return self.top
            else:
                return (self.top, '')
        return ('', '')
    
    @property
    def vcd_arg(self):
        return ''


    def run_cmd(self, cmd: str, env: Dict[str, str]=os.environ):
        (top, top_arch) = self.get_top()
        if self.top and type(self.top) is tuple:
            (top, top_arch) = self.top
        
        generics_arg = ' '.join([ f'-g{k}={v}' for k, v in self.generics.items() ])
        
        opts = ' '.join(self.opts)
                
        cmd = cmd.format(cmd=self.cmd, gen = generics_arg, vcd_arg=self.vcd_arg, 
                         warn_opts=' '.join(self.warn_opts),work=self.work, top=top, opts=opts, 
                         vpi=self.vpi, top_arch=top_arch, workdir=self.workdir, common_args=self.common_args)
        cmd = cmd.split()
        # print("running: {}".format(' '.join(cmd)))
        proc = subprocess.Popen(cmd, env=env) #, stdout=subprocess.PIPE
#         proc = subprocess.run(cmd, env=env)
#         print("result:", proc.stdout.decode(), proc.stderr.decode(), proc.returncode)
        saw_error = False        

        # def escape_ansi(line):
        #     ansi_escape = re.compile(r'(\x9B|\x1B\[)[0-?]*[ -/]*[@-~]')
        #     return ansi_escape.sub('', line)
        
        # while True:
        #     line = proc.stdout.readline()
        #     if line:
        #         line = line.decode()
        #         sys.stdout.write(line)
        #         if re.search(r"ERROR\s+(\s*(\x9B|\x1B\[)[0-?]*[ -/]*[@-~]?)*Failed", line):
        #             saw_error = True
        #     else:
        #         break
        
        proc.wait()
        
        if saw_error:
            raise ValueError("Got Error in output! Returncode={}".format(proc.returncode))
            
        return proc
    
    def run_test(self, test_modules: List[str], test_case: str = None):
        assert isinstance(test_modules, list), "test_modules needs to be a list of strings" 
        
        if isinstance(test_modules, str):
            test_modules = test_modules.split(",")
        
        for py in test_modules:
            if not pathlib.Path(py + ".py").exists():
                raise FileNotFoundError(f"test module {py}: file {py}.py not found")
        
        env=dict(os.environ)
        env['PATH'] += ":/usr/local/bin"
        env['PYTHONPATH'] = ':'.join([self.vpi_dir, self.cocotb_path, os.getcwd()])
        env['LD_LIBRARY_PATH']= ':'.join([self.vpi_dir, self.python_lib_path])
        env['MODULE'] = ','.join(test_modules)
        if test_case:
            env['TESTCASE'] = test_case
        if self.seed:
            env['RANDOM_SEED'] = self.seed
        
        env['TOPLEVEL'] = self.top # TODO what about top_arch? Do we need this AT ALL?!
        
        env['TOPLEVEL_LANG'] = self.top_lang
        env['COCOTB_LOG_LEVEL'] = self.log_level if self.log_level else 'INFO'
        env['COCOTB_REDUCED_LOG_FMT'] = 'true'
        print(f"sys.stdout.isatty()={sys.stdout.isatty()}")
        env['COCOTB_ANSI_OUTPUT'] = '1' #str(int(os.isatty(1)))
        env['COCOTB_SIM'] = '1'
        
        
        for name, cmd in self.phases.items():
            proc = self.run_cmd(cmd, env)
            if proc.returncode != 0:
                raise ValueError(f"{name} failed. \n command={' '.join(proc.args)} \n returncode={proc.returncode}")
 

from .ghdl import Ghdl
           
__all__ = [
    'Ghdl'
    ]
        