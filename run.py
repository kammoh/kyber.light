from os.path import join, dirname
from vunit import VUnit, VUnitCLI
import logging
import subprocess
import os
import glob
import multiprocessing
import json

logger = logging.getLogger(__name__)
    
class Module:
    def __init__(self, name, d):
        def get_as_list(key, is_file_list=True):
            val_list = d.get(key,[])
            if not isinstance(val_list, list):
                val_list = [val_list]
            ret_list = []
            for item in val_list:
                if is_file_list:
                    ret_list += glob.glob(join(self.path,item))
                else:
                    ret_list.append(item)
            print('get_as_list ', key, ' ret=', ret_list)
            return ret_list
        
        self.name = name
        self.library_name = d.get('library_name',  None)
        self.path = d.get('path', ".")
        self.files = get_as_list('files')
        self.tb_files = get_as_list('tb_files')
        self.top = d.get('top', None)
        self.tb_top = d.get('tb_top', None)
        self.depends = get_as_list('depends', False)
        self.tb_configs = d.get('tb_configs', [])


class Manifest:
    def __init__(self, mani_dict):
        modules = mani_dict['modules']
        self.modules = {}
        for id, m in modules.items():
            self.modules[id] = Module(id, m)

    @classmethod
    def load_from_file(self, filename = 'Manifest.json'):
        with open(filename, 'r') as file:
            content = json.load(file)
            return Manifest(content)
    
    def get_module(self, mod_name):
        return self.modules[mod_name]
    
    def add_module(self, vu, module, libname, add_tb=True):
        print("add_moduke ", module.name)
        lib_name = libname
        if module.library_name:
            lib_name = module.library_name
        lib = vu.add_library(lib_name, allow_duplicate=True)
        
        for file in module.files:
            logger.info("adding file %s", file)
            lib.add_source_files(file)


        
        if add_tb and module.tb_top:
            for tb in module.tb_files:
                logger.info("adding testbench file %s", tb)
                lib.add_source_files(tb)
            
            try:
                testbench = lib.entity(module.tb_top)
                if module.tb_configs:
                    for cfg in module.tb_configs:
                        testbench.add_config(str(cfg), cfg)
            except:
                logger.warning("Failed to get or configure testbench {} from VUnit".format(module.tb_top))
        
        if module.depends != None:
            for dep in module.depends:
                self.add_module(vu, self.get_module(dep), libname, add_tb=False)
            
    
    def module_files(self, module_name):
        mod = self.get_module(module_name)
        dep_files = mod.files
        
        if mod.depends != None:
            for dep in mod.depends:
                dep_files += self.module_files(dep)
        return dep_files
    

def synth_vivado(srcs, top):
    tcl = join('vhdl', 'vivado.tcl')
    
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


if __name__ == '__main__':
    cli = VUnitCLI()
    
    cli.parser.add_argument('--module', action='append', dest='modules', default=None, help='set top module to <MODULE>')
    cli.parser.add_argument('--synth', dest='synth', default=None, help='Synthesize using tool <TOOL>')
    
    cli.parser.set_defaults(num_threads=multiprocessing.cpu_count())
    
    args = cli.parse_args()
    
    vu = VUnit.from_args(args=args)
        
    vu.add_osvvm()
    vu.add_verification_components()
    
#     vu.enable_check_preprocessing()
#     vu.enable_location_preprocessing()
    
    manifest = Manifest.load_from_file()
    

    
    ghdl_flags = ['--warn-reserved', '--warn-default-binding', '--warn-binding', '--warn-reserved', '--warn-nested-comment', '--warn-parenthesis', '--warn-vital-generic', 
                  '--warn-delayed-checks', '--warn-body', '--warn-specs', '--warn-runtime-error', '--warn-shared', '--warn-hide', '--warn-unused', '--warn-others', 
                  '--warn-pure', '--warn-static', '-fcolor-diagnostics', '-fdiagnostics-show-option', '-fcaret-diagnostics' ]
    
    
       
    modules = []
    if args.modules == None:
        modules = manifest.modules.values()
    else:    
        for m in args.modules:
            if m in manifest.modules:
                modules.append(manifest.modules.get(m))
            else:
                logger.error("Module {} not defined in Manifest".format(m))
                exit(1)
    
    for top_module in modules:
        print(top_module.name, top_module.top, len(top_module.tb_files), top_module.tb_top)
        if top_module.top and len(top_module.tb_files) > 0 and top_module.tb_top:
            
            manifest.add_module(vu, top_module, top_module.name + '_lib' )
                    
            if args.synth != None:
                file_list = manifest.module_files(top_module.name) # FIXME TODO
                synth_vivado(srcs=file_list , top=top_module.top)
            else:
                

                    
                vu.set_sim_option("ghdl.elab_flags", ["-O3", "-Wbinding", "-Wreserved", "-Wlibrary", "-Wvital-generic", "-Wdelayed-checks", "-Wbody", "-Wspecs", "-Wunused"] + ghdl_flags, allow_empty=True)
                vu.main()
        else:
            logger.warning("top_module: {} does not have tb_files or tb_top set.. skipping".format(top_module.name))
            
