from cocorun.sim import Ghdl
from cocorun.synth.vivado import Vivado
from cocorun.conf import Manifest

manifest = Manifest.load_from_file()

sim = Ghdl.from_manifest(manifest, 'polyvec_mac')

sim.wave_dump = 'dump.ghw'
# sim.log_level = 'DEBUG'
sim.run_test(test_modules=['polyvec_mac_tb'])


# vivado = Vivado.from_manifest(manifest)

# vivado.synth('polyvec_mac', target_freq=200)