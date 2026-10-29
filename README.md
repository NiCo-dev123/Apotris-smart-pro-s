# Apotris Port for the Trimui Smart Pro S

<https://apotris.com>

Apotris is a block stacking game for the Gameboy Advance! It features satisfying graphics, responsive controls and a large amount of customization so that you can tailor the game to your preferences!

This project was (_almost_) fully handled by Codex Terra agent. I wanted to experiment with porting a game to a different hardware platform and get an idea of the project's difficulty.

Overall, it took me about 10 hours and a few weeks to have a working port. I was expecting the process to go faster, but it was a nice experiment.

## Download the port

You can download the port directly from the [Releases page](https://github.com/NiCo-dev123/Apotris-smart-pro-s/releases)

## Building the game

If you want to build the game by yourself, use the `scripts/` folder.

Run this command once to download the correct environment :

```
./scripts/setup-toolchain.sh
```

Run this command to build the project :

```
./scripts/build-tsps.sh
```

Finally, run this command to package the project into a port :

```
./package-tsps-port.sh
```

## Audio customization

### Supported music formats

Tracker formats are `.mod`, `.it`, `.xm`, and `.s3m`. Use lowercase extensions.

| Platform                                                | Music formats                                              |
| ------------------------------------------------------- | ---------------------------------------------------------- |
| Windows, Linux, macOS, Android, PortMaster, Switch, Web | Tracker formats, `.mp3`, `.ogg` (Vorbis), `.flac`, `.wav`  |
| Nintendo 3DS                                            | Tracker formats, `.ogg` (Vorbis or Opus), `.opus`, `.mp3`  |
| GBA                                                     | Tracker formats only (maximum 8 channels; 32 MB ROM limit) |

### Customizing audio

Close the game, then edit the audio folder:

- **PortMaster :** `assets/` beside the game. For Linux, use the extracted release rather than the AppImage.

Add songs directly to that folder, prefixing filenames with `MENU_` for menus or
`GAME_` for gameplay (e.g. `GAME_my_song.mp3`). Remove unwanted music files, or
disable tracks in **Settings > Audio > Track List**. To replace a sound effect,
replace its `.wav` file while keeping the exact filename. Restart to load changes.

**Android:** disable bundled tracks instead of deleting them, since missing files
are restored. Back up replacements: updates/re-extraction may overwrite them.

**GBA:** after editing, run `WINDOWS_build.bat` or `bash LINUX_or_MAC_build.sh`
(requires Python 3 on Linux/macOS) from the release folder to rebuild `Apotris.gba`.
See [the GBA release instructions](tools/README.txt) for hardware-specific patching.

**Source / Web builds:** edit `assets/`, update music entries in
`assets/meson.build`, and rebuild to package the changes.
