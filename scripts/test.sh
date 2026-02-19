#!/bin/bash

set -e # stop script when error occures
set -u # stop when undefined variable is used
#set -x # print all execution (good for debugging)

SCRIPT_FOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# find latest iOS SDK available
IOS_VERSION=$(xcrun simctl list | grep "\-\- iOS" | tail -1 | tr -d - | tr -d " " | tr -d "iOS")
# find the first simulator for this sdk
SIMULATOR=$(xcrun simctl list | grep "\-\- iOS ${IOS_VERSION} \-\-" -A 1 | tail -1 | sed -E 's/^[[:space:]]+//; s/\(.*//; s/[[:space:]]+$//')
DESTINATION="platform=iOS Simulator,OS=${IOS_VERSION},name=${SIMULATOR}"

echo "Default destination: ${DESTINATION}"

CONFIG_JSON=""

# Parse parameters of this script
while [[ $# -gt 0 ]]
do
	case "$1" in
		-destination)
			DESTINATION="$2"
			echo "Destination obtained as parameter: ${DESTINATION}"
			shift
			shift
			;;
		-config)
			CONFIG_JSON="$2"
			shift
			shift
			;;
		*)
			echo "Unknown parameter ${1}"
			exit 1
			;;
	esac
done

pushd "${SCRIPT_FOLDER}"
sh cart-update.sh
popd

pushd "${SCRIPT_FOLDER}/.."

rm -rf "build" # clear build folder

echo "${CONFIG_JSON}" > "WultraDigitalOnboardingTests/config.json"

xcrun xcodebuild \
	-derivedDataPath "build" \
    -project "WultraDigitalOnboarding.xcodeproj" \
    -scheme "WultraDigitalOnboardingTests" \
    -destination "${DESTINATION}" \
    -configuration "Debug" \
    -verbose \
    test

popd