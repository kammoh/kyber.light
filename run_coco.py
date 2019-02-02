from cocorun.sim import Ghdl
from cocorun.conf import Manifest


manifest = Manifest.load_from_file()

sim = Ghdl.from_manifest(manifest, 'polyvec_mac')


sim.wave_dump = 'dump.ghw'
sim.run_test(test_modules=['polyvec_mac_tb'])
