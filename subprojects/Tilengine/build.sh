#!/usr/bin/env bash

cd src
make clean
make
cd ..
sudo ./install
cp include/Tilengine.h /home/apostolos/Programming/GBA/apotris/include/.
cp lib/linux_x86_64/libTilengine.so /home/apostolos/Programming/GBA/apotris/lib/.
