#!/usr/bin/env python3
from pprint import pprint
import pathlib
from cocorun.sim.ghdl import Ghdl
from cocorun.synth.vivado import Vivado
from cocorun.synth.synopsys_dc import DesignCompiler
from cocorun.conf import Manifest
from random import randint, shuffle


manifest = Manifest.load_from_file()

manifest.parser.add_argument('--synth', dest='synth', action='store',
                             help='Run synthesis flow <synth>')
manifest.parser.add_argument('--debug', dest='debug', action='store_const', const=True, default=False,
                             help='turn debug on')

manifest.parser.add_argument('bundle_name', action='store',
                             help='target bundle name in Manifest')
manifest.parser.add_argument('--sim-dump', dest='sim_dump', action='store_const', const=True, default=False, help='dump wave in simulation')

args = manifest.parser.parse_args()


if args.synth:
    if args.synth == 'vivado':
        vivado = Vivado.from_manifest(manifest)

        frequency = 125  # Mhz

        vivado.run_flow(args.bundle_name, target_frequency=frequency,
                        part='xc7a100tcsg324-1', synth_directive='AreaOptimized_high', opt_directive='ExploreWithRemap')

        summary = vivado.lastrun_timing_summary()
        pprint(summary)
        wns = summary['WNS(ns)']
        if wns <= 0:
            vivado.log.error("Timing not met!")
            vivado.log.error(
                f"Frequency to try next: {1000.0/(1000.0/frequency - wns ):.3f} Mhz")
        else:
            vivado.log.info(f"Suggested frequency to try: {1000.0/(1000.0/frequency - wns ):.3f} Mhz")
            vivado.lastrun_print_utilization()
    elif args.synth == 'dc':
        synth = DesignCompiler.from_manifest(manifest)

        synth.run_flow(args.bundle_name, target_frequency=800)

else:

    sim = Ghdl(manifest, log_level='DEBUG' if args.debug else 'INFO')
    if args.sim_dump:
        sim.wave_dump = args.bundle_name + "_dump.ghw"
    
    if args.bundle_name == "asymmetric_fifo":
        for in_width in [8]: # [randint(1,13) for _ in range (10) ]:
            print("in_width =", in_width)
            l = [4] #[x for x in range(1, 33) ]
            shuffle(l)
            print(l)
            for out_width in l:
                sim.generics = {'G_IN_WIDTH': in_width,
                                'G_OUT_WIDTH': out_width}
                sim.run_test(args.bundle_name)
    else:
        sim.run_test(args.bundle_name)
