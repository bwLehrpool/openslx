#!/bin/ash

mkdir -p ~/.kde/share/config

cat >~/.kde/share/config/nepomukserverrc <<HERE
[Basic Settings]
Start Nepomuk=false
HERE

mkdir -p ~/.config/akonadi

cat >~/.config/akonadi/akonadiserverrc <<HERE
[QMYSQL]
StartServer=false
HERE

