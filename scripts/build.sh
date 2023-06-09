#!/bin/bash

set -e # stop sript when error occures
set -u # stop when undefined variable is used
#set -x # print all execution (good for debugging)

SCRIPT_FOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "${SCRIPT_FOLDER}"
sh cart-update.sh
popd

pushd "${SCRIPT_FOLDER}/.."

xcrun xcodebuild \
    -project "WultraDigitalOnboarding.xcodeproj" \
    -scheme "WultraDigitalOnboarding" \
    -configuration "Release" \
    -sdk "iphonesimulator" \
    build

popd