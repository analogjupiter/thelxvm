#!/usr/bin/env bash
set -e
dub test :vm
dub test :assembler
dub test :debugger
dub test :emulator
