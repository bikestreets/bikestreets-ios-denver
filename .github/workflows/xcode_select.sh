#!/bin/bash
set -e
echo "Selecting Xcode for environment"

printenv

sudo xcode-select -p
sudo xcode-select -s /Applications/Xcode_15.0.app
