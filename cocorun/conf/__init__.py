import logging
from os.path import join, dirname
import pathlib
import glob
import json
from collections import OrderedDict
import argparse


class HdlLibrary:
    def __init__(self, name, path, language=None):
        self.name = name
        self.path = path
        self.language = language

class HdlSource():
    def __init__(self, path, language, lib= 'work'):
        self.path = path
        self.language = language
        self.lib = lib

class XdcSource():
    def __init__(self, path):
        self.path = path

class Module:
    def __init__(self, name, d):
        def get_as_list(key, is_file_list=True):
            val_list = d.get(key,[])
            if not isinstance(val_list, list):
                val_list = [val_list]
            ret_list = []
            for item in val_list:
                if is_file_list:
                    p = join(self.path, item)
                    if '*' in item:
                        g = glob.glob(p)
                        if not g or len(g) == 0:
                            raise FileNotFoundError("pattern " + p + " did not match any files")
                        ret_list += g
                    else:
                        if not pathlib.Path(p).exists():
                            raise FileNotFoundError("file " + p + " not found")
                        ret_list.append(p)
                else:
                    ret_list.append(item)
            return ret_list
        
        self.name = name
        self.vhdl_version = d.get('vhdl_version',  None) # FIXME -> language REMOVE
        self.language = d.get('language',  'vhdl.2008')
        self.library = d.get('library',  None)
        self.path = d.get('path', ".")
        self.tb_files = get_as_list('tb_files')
        self.sim_files = get_as_list('files.sim')
        files = get_as_list('files')
        self.files = [f for f in files if not f in self.tb_files]
        
        self.top = d.get('top', None)
        self.tb_top = d.get('tb_top', None)
        self.depends = get_as_list('depends', False)
        self.tb_configs = d.get('tb_configs', [])




class Manifest:
    def __init__(self, manifest_dict):
        self.parser = argparse.ArgumentParser(description='CocoRun')
        self.log = logging.getLogger(__name__)
        modules = manifest_dict['modules']
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
    
    
    def module_dependencies(self, module_name, sim = True):
        deps = OrderedDict()
        
        def add_dependencies_rec(module_name):
            mod = module_name
            if isinstance(mod, str):
                try:
                    mod = self.get_module(module_name)
                except KeyError:
                    self.log.error(f'dependency {module_name} does not exist in Manifest' )
                    exit(1)
            
            for dep in mod.depends or []:
                add_dependencies_rec(dep)
            
            if sim:
                for file in mod.sim_files:
                    deps[file] = mod.library
                    
            for file in mod.files:
                deps[file] = mod.library
            
                
        add_dependencies_rec(module_name)
        
        return deps

    def hdl_sources(self, top_module_name, sim = True):
        ret = []
        module = self.get_module(top_module_name)

        for path, lib in self.module_dependencies(top_module_name, sim).items():
            ret.append(HdlSource(path=path, lib=lib, language=module.language) )

        return ret, module

