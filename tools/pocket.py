#!/usr/bin/env python3

import subprocess
import shutil
import sys


gba_fix, target_in, target_out = sys.argv[1:]

# Copy the input file to the output file
shutil.copyfile(target_in, target_out)

# Run gbafix with the provided arguments
subprocess.run(
    [sys.executable, gba_fix, target_out, '-tDRILL DOZER', '-cV49E', '-m01', '-r00'],
    check=True,
)
