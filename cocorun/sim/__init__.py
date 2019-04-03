import subprocess
import os
import sys
import re
from typing import Dict, List, Callable
import collections
import sysconfig
import cocotb
import platform
import pathlib
import logging
import asyncio

import colorlog

from ..conf import *




async def _read_stream(stream, cb):
    while True:
        line = await stream.readline()
        if line:
            cb(line)
        else:
            break


async def _stream_subprocess(cmd, env, stdout_cb, stderr_cb, pipe=False):
    if pipe:
        process = await asyncio.create_subprocess_exec(*cmd,
                                                       stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, env=env)

        await asyncio.wait([
            _read_stream(process.stdout, stdout_cb),
            _read_stream(process.stderr, stderr_cb)
        ])
    else:
        process = await asyncio.create_subprocess_exec(*cmd, env=env)

    return await process.wait()


def _async_execute(cmd, env, stdout_cb, stderr_cb):
    loop = asyncio.get_event_loop()

    rc = loop.run_until_complete(
        _stream_subprocess(
            cmd,
            env,
            stdout_cb,
            stderr_cb,
        ))
    # loop.close()
    return rc


class CommandRunner():
    def __init__(self, cmd, env, error_regex):
        self.error_regex = error_regex
        self.cmd = cmd
        self.env = env
        self.errors = 0

    # async def _read_stream(self, stream):
    #     while True:
    #         line = await stream.readline()
    #         if line:
    #             if self.error_regex.search(line):
    #                 self.errors += 1
    #             sys.stdout.write(line)
    #         else:
    #             break

    # async def _stream_subprocess(self):
    #     process = await asyncio.create_subprocess_exec(*self.cmd,
    #                                                     stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, env=self.env)

    #     await asyncio.wait([
    #         self._read_stream(process.stdout),
    #         self._read_stream(process.stderr)
    #     ])
    #     return await process.wait()

    def execute(self):
        self.errors = 0
        # loop = asyncio.get_event_loop()
        # rc = loop.run_until_complete(self._stream_subprocess())
        # loop.close()
        # def escape_ansi(line):
        #     ansi_escape = re.compile(r'(\x9B|\x1B\[)[0-?]*[ -/]*[@-~]')
        #     return ansi_escape.sub('', line)
        # proc = subprocess.Popen(self.cmd, env=self.env)
        # proc = subprocess.Popen(
        #     self.cmd, env=self.env, stdout=subprocess.PIPE, bufsize=1, universal_newlines=True)

        # for line in proc.stdout:
        #     if not line:
        #         break
        #     sys.stdout.write(line)
        #     if self.error_regex.search(line):
        #         self.errors += 1
        # proc.stdout.close()
        # rc = proc.wait()

        def _proc_stream(x):
            line = x.decode()
            print(line, end='')
            if self.error_regex.search(line):
                self.errors += 1
                #         self.errors += 1

        rc = _async_execute(self.cmd, self.env, _proc_stream, _proc_stream)

        return rc


class Sim(object):
    def __init__(self, manifest: Manifest, log_level='INFO'):
        self.manifest = manifest
        self.sim_name = self.__class__.__name__

        handler = colorlog.StreamHandler()
        handler.setFormatter(colorlog.ColoredFormatter(
            "%(name)s: %(log_color)s[%(levelname)s]%(reset)s %(message)s"))
        self.log = colorlog.getLogger(self.sim_name)
        self.log.addHandler(handler)
        self.log_level = log_level
        self.log.setLevel(self.log_level)

        prefix_dir = os.environ.get('COCOTB', os.path.dirname(cocotb.__file__))
        self.log.debug(f'Using cocotb at {prefix_dir}')
        share_dir = os.path.join(prefix_dir, 'share')
        lib_dir = os.path.join(share_dir, 'lib')
        platform_libs_dir = os.path.join(
            lib_dir, 'build', 'libs', platform.machine())
        self.cocotb_path = prefix_dir
        self.top_lang = ''
        self.seed = None
        self.python_lib_path = sysconfig.get_config_var('LIBDIR')
        self.python_include_path = sysconfig.get_config_var('INCLUDEPY')
        self.python_bin = sys.executable
        dyn_lib_nam = sysconfig.get_config_vars('LIBRARY')[0][:-2]
        dyn_libs = [f for ext in ['dylib', 'dll', 'so'] for f in pathlib.Path(
            self.python_lib_path).glob(dyn_lib_nam + '.' + ext)]
        self.python_dyn_lib = str(dyn_libs[0])
        self.vpi_dir = platform_libs_dir
        self.vpi = os.path.join(platform_libs_dir, 'cocotb.vpi')

        need_to_build_vpi = True  # FIXME

        if need_to_build_vpi:
            # TODO FIXME Move eslewhere
            make_cmd = f'make SIM={self.sim_name} COCOTB_SHARE_DIR={share_dir} PYTHON_INCLUDEDIR={self.python_include_path} PYTHON_LIBDIR={self.python_lib_path} PYTHON_DYN_LIB={self.python_dyn_lib} PYTHON_BIN={self.python_bin} ARCH={platform.machine()} -C {lib_dir} vpi_lib'
            self.log.info("Building VPI...")
            self.log.debug(f'running {make_cmd}')
            proc = subprocess.Popen(make_cmd.split())
            if proc.wait() != 0:
                raise RuntimeError()

    # def get_top(self):
    #     if self.top:
    #         if type(self.top) is tuple:
    #             return self.top
    #         else:
    #             return (self.top, '')
    #     return ('', '')
    @classmethod
    def format(cls, string, **kwargs):
        class SafeDict(dict):
            def __missing__(self, key):
                return '{' + key + '}'

            def __getitem__(self, key):
                value = super().__getitem__(key)
                if value:
                    if isinstance(value, list):
                        value = ' '.join(value)
                    return value
                else:
                    return ' '

        return string.format_map(SafeDict(**kwargs))

    @property
    def vcd_arg(self):
        return ''

    # FIXME BROKEN

    def run_cmd(self, command: str, config: Dict[str, str], env: Dict[str, str] = os.environ):
        command = self.format(command, **config)
        regex = re.compile("(\{.*\})")
        match = regex.match(command)
        if match:
            for unsub_arg in match.groups():
                self.log.error(f'No value provided for argument {unsub_arg}')
            exit(1)
        cmd = command.split()
        err_regex = re.compile(r"ERROR\s+(\s*(\x9B|\x1B\[)[0-?]*[ -/]*[@-~]?)*Failed")
        runner = CommandRunner(cmd, env, err_regex)
        self.log.debug('running ' + ' '.join(cmd))  # to get rid of spurious whitespace
        rc = runner.execute()
        if rc:
            raise ValueError(
                "Non-zero return code {}".format(rc))
        if runner.errors:
            pl = 's' if runner.errors > 1 else ''
            raise ValueError(
                f"Received {runner.errors} error{pl} in stdout")

    def execute_test(self, cmd, run_config):
        # run_config = dict(run_config)

        run_config['vpi'] = self.vpi

        tmods = []
        for py in run_config['test_modules']:
            if not py.endswith(".py"):
                py += ".py"
            path = pathlib.Path(py)
            if not path.exists():
                raise FileNotFoundError(
                    f"test module {py}: file {py}.py not found")
            tmods.append(str(path.with_suffix("")).replace(os.sep, '.'))

        env = dict(os.environ)
        env['PATH'] += ":/usr/local/bin"
        env['PYTHONPATH'] = ':'.join(
            [self.vpi_dir, self.cocotb_path, os.getcwd()])
        env['LD_LIBRARY_PATH'] = ':'.join([self.vpi_dir, self.python_lib_path])
        env['MODULE'] = ','.join(tmods)
        test_case = run_config.get('test_case', None)
        if test_case:
            env['TESTCASE'] = test_case
        if self.seed:
            env['RANDOM_SEED'] = self.seed

        # TODO what about top_arch? Do we need this AT ALL?!
        env['TOPLEVEL'] = run_config['top_module_name']

        env['TOPLEVEL_LANG'] = self.top_lang
        env['COCOTB_LOG_LEVEL'] = self.log_level if self.log_level else 'INFO'

        if not self.log_level or self.log_level in ['INFO', 'WARNING', 'ERROR']:
            env['COCOTB_REDUCED_LOG_FMT'] = 'true'
        self.log.debug(
            f"sys.stdout.isatty()={sys.stdout.isatty()} GUI={env.get('GUI', '<Not-set>')}")
        env['COCOTB_ANSI_OUTPUT'] = '1'  # str(int(os.isatty(1)))
        env['COCOTB_SIM'] = '1'

        try:
            self.run_cmd(cmd, run_config, env)
        except ValueError as e:
            print(f"execute_test failed: {' '.join(e.args)}")


__all__ = ['Sim']
