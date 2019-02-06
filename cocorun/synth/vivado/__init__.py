
from jinja2 import Template, Environment, FileSystemLoader, select_autoescape
import subprocess
import logging
import os
import pathlib
from ...conf import *
from logging import log
import datetime
import shutil

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
log = logging.getLogger(__name__)

def _copy(self, target):
    assert self.is_file()
    shutil.copy(self, target)

def _copytree(self, target):
    assert self.is_file()
    shutil.copytree(self, target)

pathlib.Path.copy = _copy
pathlib.Path.copytree = _copytree

class SynthTool:
    pass

class Vivado(SynthTool):

    def __init__(self):
        self.manifest=None
        

    @classmethod
    def from_manifest(cls, manifest=None):
        this = cls()
        if manifest:
            this.manifest = manifest
        else:
            this.manifest = Manifest.load_from_file()
        return this

    def synth(self, top_module_name, target_freq):
        run_dir_name = f'synth.{self.__class__.__name__}.{top_module_name}_{datetime.datetime.now()}'.replace(' ', '_').replace(':', '_')
        run_path = pathlib.Path(run_dir_name)

        if not run_path.exists():
            run_path.mkdir(parents=True)
        if not run_path.is_dir():
            raise FileNotFoundError("run_dir is not a directory")

        source_path = pathlib.Path('sources')
        local_hdl_path = run_path.joinpath(source_path)
        
        
        # copy sources to build directory
        hdl_sources = self.manifest.hdl_sources(top_module_name)

        for i in range(len(hdl_sources)):
            src_path = pathlib.Path(hdl_sources[i].path)
            src_hierarchy = src_path.parent
            if src_hierarchy.is_absolute():
                src_hierarchy = src_hierarchy.relative_to(pathlib.Path.cwd())
            dst_hierarchy = local_hdl_path.joinpath(src_hierarchy)
            dst_rel_path = source_path.joinpath(src_hierarchy)
            
            dst_hierarchy.mkdir(parents=True, exist_ok=True)
            
            shutil.copy(src_path, dst_hierarchy)
            hdl_sources[i].path = str(dst_rel_path.joinpath(src_path.name))

        j2_env = Environment(loader=FileSystemLoader(THIS_DIR), trim_blocks=True, lstrip_blocks=True, autoescape=select_autoescape(['tcl']))

        scripts_relpath = pathlib.Path('scripts')
        tcl_file_relpath = scripts_relpath.joinpath('vivado.tcl')
        xdc_file_relpath = scripts_relpath.joinpath('clock.xdc')

        xdcs=[XdcSource(xdc_file_relpath)]

        tcl_template = j2_env.get_template('vivado.template.tcl')
        tcl = tcl_template.render(
            part='xc7z020clg484-1',top_module_name=top_module_name, hdl_sources=hdl_sources, 
            xdcs=xdcs, output_dir='.')

        clock_template = j2_env.get_template('clock.template.xdc')
        xdc = clock_template.render(period=1000/target_freq, name='clk', port_name='clk')

        tcl_path = run_path.joinpath(tcl_file_relpath)
        if not tcl_path.parent.exists():
            tcl_path.parent.mkdir(parents=True)

        with run_path.joinpath(tcl_file_relpath).open(mode='w') as tf:
            tf.write(tcl)

        with run_path.joinpath(xdc_file_relpath).open(mode='w') as xf:
            xf.write(xdc)

        cmd = ["vivado", "-mode", "tcl", "-nojournal", "-source", str(tcl_file_relpath)] # , "-tclargs", "3", "4"]

        print("running ", ' '.join(cmd))

        try:
            proc = subprocess.Popen(cmd, cwd=run_path)
            if proc.wait() != 0:
                log.error("There were some errors")
        except ValueError as e:
            print("Exception: ValueError ", e)




    
