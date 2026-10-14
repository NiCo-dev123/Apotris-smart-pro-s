#!/usr/bin/env python3

import subprocess
import sys


def main(argv):
    # Assign command line arguments to variables
    makerom, input_file, output_file, gbafix = argv[1:]

    # Make the base GBA rom using the Python that runs this wrapper.
    subprocess.run([sys.executable, makerom, input_file, output_file], check=True)

    # Fix as valid ROM
    subprocess.run(
        [sys.executable, gbafix, output_file, '-tAPOTRIS', '-c2ATE', '-m00', '-r04'],
        check=True,
    )


if __name__ == '__main__':
    sys.exit(main(sys.argv))
