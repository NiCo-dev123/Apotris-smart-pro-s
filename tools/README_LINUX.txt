The game requires GLIBC >= 2.38 to run.

Installation
------------
Extract this archive and run:
    ./Apotris

To install a .desktop entry (launcher) and icon system-wide:
    sudo cp Apotris.desktop /usr/share/applications/
    sudo cp Apotris.png /usr/share/icons/hicolor/512x512/apps/

An AppImage is also available. Make it executable and run:
    chmod +x Apotris-*.AppImage
    ./Apotris-*.AppImage

Customizing audio
-----------------
Close the game, then add or remove music directly in assets/ beside Apotris.
Supported formats: .mod, .it, .xm, .s3m, .mp3, .ogg (Vorbis), .flac, .wav.
Use lowercase extensions and prefix filenames with MENU_ for menus or GAME_ for gameplay.
To replace a sound effect, replace its .wav file with one of the exact same name.
Restart to load changes. Preview or disable songs in Settings > Audio > Track List.
For editable assets, use this extracted release rather than the AppImage.
