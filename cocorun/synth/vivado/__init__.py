
from jinja2 import Template, Environment, FileSystemLoader, select_autoescape
import subprocess
import logging
import os
import pathlib
from ...conf import *
from logging import log
import datetime
import shutil
from collections.abc import Iterable
import re

THIS_DIR = os.path.dirname(os.path.abspath(__file__))


def _copy(self, target):
    assert self.is_file()
    shutil.copy(self, target)


def _copytree(self, target):
    assert self.is_file()
    shutil.copytree(self, target)


pathlib.Path.copy = _copy
pathlib.Path.copytree = _copytree


def options_to_str(d):
    r = ""
    for k, v in d.items():
        if v:
            r += f'-{k} '
            if isinstance(v, dict):
                r += f'-{k} '.join([f'{x}={y}' for x, y in v.items()])
            elif isinstance(v, Iterable) and not isinstance(v, str):
                r += f'-{k} '.join(v)
            elif not isinstance(v, bool):
                r += f'{v} '
    return r


def parse_report(file, header):
    while True:
        line = file.readline()
        if not line:
            break
        if line.startswith('| ' + header):
            l = []
            for _ in range(2):
                while True:
                    line = file.readline()
                    if not line:
                        raise ParseException("End of file")
                    line = line.strip()
                    if len(line) > 1 and not line.startswith("--") and not line.startswith("| "):
                        break
                l.append(line.split())

            ret = {}
            for k, v in zip(l[0], l[1]):
                try:
                    v = float(v)
                except:
                    pass
                ret[k] = v
            return ret


class SynthTool:
    pass


class ParseException(Exception):
    pass


class Table():
    def __init__(self, name, header, data):
        self.name = name
        self.header = header
        self.data = data

# FIXME VERY BAD MESSY CODE WILL DEFINITLY BREAK TODO ******


def read_until(rf, pattern, g=1, anti_pattern=None, max_len=None):
    p = re.compile(pattern)
    if anti_pattern:
        ap = re.compile(anti_pattern)
    else:
        ap = None
    ret = []
    while True:
        line = rf.readline()
        if not line:
            return ret
        line = line.strip()
        if ap and len(ret) > 0 and ap.match(line):
            return ret
        l = []
        for i in p.finditer(line):
            l.append(i.group(g))
        if len(l) > 0:
            ret.append(l)
            if max_len and len(ret) >= max_len:
                return ret
        elif len(ret) > 0:
            return ret


class Vivado(SynthTool):

    def __init__(self):
        self.manifest = None
        self.lastrun_path = None
        self.log = logging.getLogger(self.__class__.__name__)
        console = logging.StreamHandler()
        formatter = logging.Formatter('%(name)-12s: %(levelname)-8s %(message)s')
        console.setFormatter(formatter)
        self.log.addHandler(console)

    @classmethod
    def from_manifest(cls, manifest=None):
        this = cls()
        if manifest:
            this.manifest = manifest
        else:
            this.manifest = Manifest.load_from_file()
        return this

    def lastrun_timing_summary(self):
        log_path = self.lastrun_path.joinpath('reports').joinpath('post_route_timing_summary.rpt')
        with log_path.open('r') as repf:
            intra_clock = parse_report(repf, 'Intra Clock Table')
            return intra_clock

    # FIXME VERY MESSY CODE PARSE USING PROPER MEANS
    ## FIXME TODO ###
    def report_utilization(self, path):
        tables = {}
        if not path:
            if not self.lastrun_path:
                print(f"No lastrun_path available. Run flow or manulally specify synthesis path")
                exit(1)
            path = self.lastrun_path
        elif not isinstance(path, pathlib.Path):
            path = pathlib.Path(path)
        with path.joinpath('reports').joinpath('post_route_util.rpt').open() as rf:
            while True:
                # try:
                table_name = read_until(rf, r'^\d+\.\s+(\w.*)', max_len=1)
                if len(table_name) == 0:
                    break
                table_name = table_name[0][0]
                headers = read_until(rf, r'\s+(\w[\w\s]*\w)\s+\|', max_len=1)
                if len(headers) == 0:
                    break
                header = headers[0]

                data_rows = read_until(rf, r'\s+([\w\*]|\w[^\|]*[\w\*])\s+\|', anti_pattern=r'^(\+[\-]+)+\+')
                tables[table_name] = Table(table_name, header, data_rows)

        return tables

    def print_utilization(self, path=None):
        tables = self.report_utilization(path)
        w = [24, 11]
        print(f"| {'Resource':<{w[0]}} | {'Utilization':<{w[1]}} |")
        print(f"|{'-' * (w[0]+2)}|{'-' * (w[1]+2)}|")
        for table_name in ['Slice Logic', 'Memory', 'DSP']:
            for row in tables[table_name].data:
                if row[1] != "0":
                    print(f"| {row[0]:<{w[0]}} | {row[1]:<{w[1]}} |")

    def run_flow(self, mm, target_frequency, part, **kwargs):

        hdl_sources, mod = self.manifest.hdl_sources(mm)

        top_module_name = mod.top
        if not target_frequency:
            target_frequency = mod.frequency

        synth_options = {
            'top': top_module_name,
            'part': part,
            'quiet': kwargs.pop('synth_quiet', False),
            'resource_sharing': kwargs.pop('synth_resource_sharing', None),
            'retiming': kwargs.pop('synth_retiming', True),
            'directive': kwargs.pop('synth_directive', None),
            'flatten_hierarchy': kwargs.pop('flatten_hierarchy', 'rebuilt'),
            'generics': kwargs.pop('generics', None)
        }
        opt_options = {
            'directive': kwargs.pop('opt_directive', None),
            'quiet': kwargs.pop('opt_quiet', False),
        }

        phys_opt_options = {
            'retime': True,
            'hold_fix': True,
            'rewire': True
        }

        synth_prefix = 'synth_'
        opt_prefix = 'opt_'
        place_prefix = 'place_'
        route_prefix = 'route_'
        phys_opt_prefix = 'phys_opt_'

        for arg, value in kwargs:
            if arg.startswith(synth_prefix):
                synth_options[arg[len(synth_prefix)]:] = value
            elif arg.startswith(opt_prefix):
                opt_options[arg[len(opt_prefix)]:] = value
            elif arg.startswith(phys_opt_prefix):
                phys_opt_options[arg[len(phys_opt_prefix)]:] = value
        
        synth_subdir = f'synth_run'
        run_dir_name = f'{self.__class__.__name__}.{top_module_name}_{datetime.datetime.now()}'.replace(
            ' ', '.').replace(':', '.')
        run_path = pathlib.Path(synth_subdir).joinpath(run_dir_name)

        if not run_path.exists():
            run_path.mkdir(parents=True)
        if not run_path.is_dir():
            raise FileNotFoundError("run_dir is not a directory")

        source_path = pathlib.Path('sources')
        local_hdl_path = run_path.joinpath(source_path)

        # copy sources to build directory

        if not hdl_sources or len(hdl_sources) < 1:
            self.log.error("No HDL source files specified!")
            exit(1)

        for hdl in hdl_sources:
            src_path = pathlib.Path(hdl.path)
            src_hierarchy = src_path.parent
            if src_hierarchy.is_absolute():
                src_hierarchy = src_hierarchy.relative_to(pathlib.Path.cwd())
            dst_hierarchy = local_hdl_path.joinpath(src_hierarchy)
            dst_rel_path = source_path.joinpath(src_hierarchy)

            dst_hierarchy.mkdir(parents=True, exist_ok=True)

            shutil.copy(src_path, dst_hierarchy)
            hdl.path = str(dst_rel_path.joinpath(src_path.name))

        print("HDL SOURCES:")
        for hdl in hdl_sources:
            library = hdl.lib
            if not library:
                library = 'None'
            print(f"{hdl.language:10} {library:10} {hdl.path}")

        j2_env = Environment(loader=FileSystemLoader(
            THIS_DIR), trim_blocks=True, lstrip_blocks=True, autoescape=select_autoescape(['tcl']))

        scripts_relpath = pathlib.Path('scripts')
        tcl_file_relpath = scripts_relpath.joinpath('vivado.tcl')
        xdc_file_relpath = scripts_relpath.joinpath('clock.xdc')

        xdcs = [XdcSource(xdc_file_relpath)]

        tcl_template = j2_env.get_template('vivado.template.tcl')
        tcl = tcl_template.render(
            top_module_name=top_module_name, hdl_sources=hdl_sources,
            xdcs=xdcs, output_dir='.', part=part, synth_options=options_to_str(synth_options),
            opt_options=options_to_str(opt_options))

        clock_template = j2_env.get_template('clock.template.xdc')
        xdc = clock_template.render(
            period=1000/target_frequency, name='clk', port_name='clk')

        tcl_path = run_path.joinpath(tcl_file_relpath)
        if not tcl_path.parent.exists():
            tcl_path.parent.mkdir(parents=True)

        with run_path.joinpath(tcl_file_relpath).open(mode='w') as tf:
            tf.write(tcl)

        with run_path.joinpath(xdc_file_relpath).open(mode='w') as xf:
            xf.write(xdc)

        cmd = ["vivado", "-mode", "batch", "-nojournal",
               "-source", str(tcl_file_relpath)]  # , "-tclargs", "3", "4"] "-notrace",

        quiet = False

        if quiet:
            cmd.append("-notrace")

        print("running ", ' '.join(cmd))

        try:
            proc = subprocess.Popen(cmd, cwd=run_path)
            if proc.wait() != 0:
                self.log.error("There were some errors")
        except ValueError as e:
            print("Exception: ValueError ", e)

        self.lastrun_path = run_path
