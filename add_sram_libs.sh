#!/bin/bash

for f in /src/saed_mc_v2_3_6/saed_mc/mc_*x*sp/SRAM*+(db|lib|lef|v|vhdl); do ln -s $f rtk/saed32/ ; done