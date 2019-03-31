
from jinja2 import Template, Environment, FileSystemLoader, select_autoescape
import subprocess
import logging
import os
import pathlib
from logging import log
import datetime
import shutil
import re
import math


def create_sim_model(word_count, width):
    run_path = pathlib.Path('vhdl')
    entity_name = f'SRAM1RW{word_count}x{width}'
    j2_env = Environment(loader=FileSystemLoader(str(run_path) ), trim_blocks=True,
                         lstrip_blocks=True, autoescape=select_autoescape(['vhdl']))

    vhdl_template = 'SRAM1RW.template.vhdl'

    vhdl_template = j2_env.get_template(vhdl_template)

    addr_bits = math.ceil(math.log2(word_count))
    content = vhdl_template.render(addr_bits=addr_bits, data_bits=width, entity_name=entity_name)

    with run_path.joinpath(f'{entity_name}.vhdl').open(mode='w') as tf:
        tf.write(content)


create_sim_model(1024, 8)
create_sim_model(256, 8)
create_sim_model(64, 8)
