#!/usr/bin/env python3
"""Run ROM-wrapper regressions: python3 tests/test-gba-build-tools.py.

Uses temporary files and fake tools; no GBA toolchain or existing build needed.
"""

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import call, patch


TOOLS = Path(__file__).resolve().parents[1] / 'tools'
FLAGS = ['-tAPOTRIS', '-c2ATE', '-m00', '-r04']


class BuildToolsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='apotris build tools ')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.elf = self.root / 'Apotris.elf'
        self.base = self.root / 'Apotris-base.gba'
        self.audio = self.root / 'audio.gbfs'
        self.rom = self.root / 'Apotris.gba'
        self.elf.write_bytes(b'original ELF')
        self.base.write_bytes(b'base ROM')
        self.audio.write_bytes(b'audio')
        self.makerom = self.root / 'makerom.py'
        self.makerom.write_text(
            'from pathlib import Path\n'
            'import sys\n'
            'source, target = sys.argv[1:]\n'
            'Path(target).write_bytes(Path(source).read_bytes())\n'
        )
        self.gbafix = self.root / 'gbafix.py'
        self.gbafix.write_text(
            'from pathlib import Path\n'
            'import json, sys\n'
            'Path(sys.argv[1]).with_suffix(".args.json").write_text('
            'json.dumps(sys.argv[1:]))\n'
        )

    def run_wrapper(self, name, *args):
        return subprocess.run(
            [sys.executable, str(TOOLS / name), *map(str, args)],
            capture_output=True,
            text=True,
        )

    def base_args(self):
        return ['makeBase.py', str(self.makerom), str(self.elf),
                str(self.base), str(self.gbafix)]

    def final_args(self):
        return ['gbaBuild.py', 'padbin', '256', str(self.base),
                str(self.audio), '0x400000', str(self.rom), str(self.gbafix)]

    def test_base_uses_python_and_preserves_input_with_spaced_paths(self):
        result = self.run_wrapper('makeBase.py', *self.base_args()[1:])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.elf.read_bytes(), b'original ELF')
        self.assertEqual(self.base.read_bytes(), b'original ELF')
        self.assertEqual(
            json.loads(self.base.with_suffix('.args.json').read_text()),
            [str(self.base), *FLAGS],
        )

    def test_base_stops_when_makerom_fails(self):
        main = runpy.run_path(str(TOOLS / 'makeBase.py'))['main']
        with patch('subprocess.run', side_effect=subprocess.CalledProcessError(7, 'makerom')) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                main(self.base_args())
        run.assert_called_once_with(
            [sys.executable, str(self.makerom), str(self.elf), str(self.base)],
            check=True,
        )

    def test_base_rejects_flattened_tool_commands_before_running(self):
        main = runpy.run_path(str(TOOLS / 'makeBase.py'))['main']
        for prefix in ([sys.executable], ['meson.exe', 'runpython']):
            args = ['makeBase.py', *prefix, str(self.makerom), str(self.elf),
                    str(self.base), *prefix, str(self.gbafix)]
            with self.subTest(prefix=prefix), patch('subprocess.run') as run:
                with self.assertRaises(ValueError):
                    main(args)
                run.assert_not_called()

    def test_final_pads_concatenates_and_runs_gbafix_with_python(self):
        main = runpy.run_path(str(TOOLS / 'gbaBuild.py'))['main']
        with patch('subprocess.run') as run:
            main(self.final_args())
        self.assertEqual(self.rom.read_bytes(), b'base ROMaudio')
        self.assertEqual(run.call_args_list, [
            call(['padbin', '256', str(self.base)], check=True),
            call(['padbin', '0x400000', str(self.rom)], check=True),
            call([sys.executable, str(self.gbafix), str(self.rom), *FLAGS], check=True),
        ])

    def test_final_stops_when_initial_padding_fails(self):
        main = runpy.run_path(str(TOOLS / 'gbaBuild.py'))['main']
        with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, 'padbin')) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                main(self.final_args())
        self.assertEqual(run.call_count, 1)
        self.assertFalse(self.rom.exists())

    def test_final_stops_when_final_padding_fails(self):
        main = runpy.run_path(str(TOOLS / 'gbaBuild.py'))['main']
        with patch('subprocess.run', side_effect=[None, subprocess.CalledProcessError(1, 'padbin')]) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                main(self.final_args())
        self.assertEqual(run.call_count, 2)

    def test_pocket_uses_python_and_preserves_input(self):
        result = self.run_wrapper('pocket.py', self.gbafix, self.base, self.rom)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.base.read_bytes(), b'base ROM')
        self.assertEqual(self.rom.read_bytes(), b'base ROM')
        self.assertEqual(
            json.loads(self.rom.with_suffix('.args.json').read_text()),
            [str(self.rom), '-tDRILL DOZER', '-cV49E', '-m01', '-r00'],
        )

    def test_soundbank_passes_unquoted_archive_path_and_propagates_failure(self):
        defaults = self.root / 'sound effects.txt'
        defaults.write_text('SFX_BEEP\n')
        gbfs = str(self.root / 'native tools' / 'gbfs.exe')
        argv = ['buildSoundbank.py', 'default', 'mmutil', gbfs, str(defaults)]

        def make_soundbank(command):
            (self.root / 'soundbank.h').write_text('#define SFX_BEEP 0\n')
            (self.root / 'soundbank.bin').write_bytes(b'soundbank')
            return 0

        original_directory = Path.cwd()
        os.chdir(self.root)
        try:
            for failure in (None, subprocess.CalledProcessError(1, gbfs)):
                with self.subTest(failure=failure is not None), \
                        patch.object(sys, 'argv', argv), \
                        patch('os.system', side_effect=make_soundbank), \
                        patch('subprocess.run', side_effect=failure) as run, \
                        redirect_stdout(io.StringIO()):
                    if failure is None:
                        runpy.run_path(str(TOOLS / 'buildSoundbank.py'), run_name='__main__')
                    else:
                        with self.assertRaises(subprocess.CalledProcessError):
                            runpy.run_path(str(TOOLS / 'buildSoundbank.py'), run_name='__main__')
                    run.assert_called_once_with(
                        [gbfs, 'audio.gbfs', 'soundbank.bin', 'effect_locations.bin'],
                        check=True,
                    )
        finally:
            os.chdir(original_directory)

    def test_gbafix_failures_make_wrappers_fail(self):
        self.gbafix.write_text('import sys\nsys.exit(9)\n')
        for name, args in (
            ('makeBase.py', self.base_args()[1:]),
            ('pocket.py', [self.gbafix, self.base, self.rom]),
        ):
            with self.subTest(wrapper=name):
                result = self.run_wrapper(name, *args)
                self.assertNotEqual(result.returncode, 0)
        main = runpy.run_path(str(TOOLS / 'gbaBuild.py'))['main']
        with patch('subprocess.run', side_effect=[None, None, subprocess.CalledProcessError(9, 'gbafix')]):
            with self.assertRaises(subprocess.CalledProcessError):
                main(self.final_args())


if __name__ == '__main__':
    unittest.main()
