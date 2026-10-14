#!/usr/bin/env python3

import subprocess
import sys


def main(argv):
    # Assign command line arguments to variables
    padbin, pad_size_1, gba_file, audio_file, pad_size_2, target_out, gbafix = argv[1:]

    # Pad the GBA file to a certain size
    subprocess.run([padbin, pad_size_1, gba_file], check=True)

    # Concatenate the GBA file with an audio file
    with open(target_out, 'wb') as outfile:
        for fname in [gba_file, audio_file]:
            with open(fname, 'rb') as infile:
                outfile.write(infile.read())

    # Pad the resulting file to a certain size
    subprocess.run([padbin, pad_size_2, target_out], check=True)

    # Fix as valid ROM
    subprocess.run(
        [sys.executable, gbafix, target_out, '-tAPOTRIS', '-c2ATE', '-m00', '-r04'],
        check=True,
    )


if __name__ == '__main__':
    sys.exit(main(sys.argv))
