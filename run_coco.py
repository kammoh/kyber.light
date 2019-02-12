#!/usr/bin/env python3
from pprint import pprint
import pathlib
from cocorun.sim import Ghdl
from cocorun.synth.vivado import Vivado
from cocorun.conf import Manifest


manifest = Manifest.load_from_file()

manifest.parser.add_argument('--synth', dest='synth', action='store_const', const=True, default=False,
                             help='action to perform')
manifest.parser.add_argument('--mod', dest='bundle_name', action='store', help='target bundle name in Manifest', required=True)
manifest.parser.add_argument('--sim-dump', dest='sim_dump', action='store_const', const=True, default=False, help='dump wave in simulation')

args = manifest.parser.parse_args()


if args.synth:
    vivado = Vivado.from_manifest(manifest)

    frequency = 170  # Mhz

    vivado.run_flow(args.bundle_name, target_frequency=frequency,
                    part='xc7z020clg400-1', synth_directive='AreaOptimized_high', opt_directive='ExploreWithRemap')

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

else:
    sim = Ghdl(manifest)
    # sim.log_level = 'DEBUG'
    if args.sim_dump:
        sim.wave_dump = args.bundle_name + "_dump.ghw"
    sim.run_test(args.bundle_name)
