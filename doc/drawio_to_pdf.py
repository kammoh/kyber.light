#!/usr/bin/env python3
import sys
import os
import subprocess
if len(sys.argv) < 2:
    print('missing filename argument')
    exit(1)

xml_file = sys.argv[1]
proc = subprocess.Popen(['xsltproc', 'diagrams.xsl', xml_file], stdout=subprocess.PIPE)

proc.wait()

for i,page in enumerate(proc.stdout):
    page = page.decode().strip()
    print(f"{i:2}: {page}")
    print(f'drawio-batch -d {i} {xml_file} {xml_file}_{page}.pdf')
    subprocess.run(['drawio-batch', '-d', f'{i}', xml_file, f'{xml_file}_{page}.pdf'])

