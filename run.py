from os.path import join, dirname
from vunit import VUnit

src_path = join(dirname(__file__) , "vhdl")

ui = VUnit.from_argv()
ui.add_osvvm()
ui.add_verification_components()
ui.enable_check_preprocessing()

module="barret_reduce"

lib = ui.add_library(module + "_lib")
lib.add_source_files(join(src_path, "*.vhd"))


ui.main()
