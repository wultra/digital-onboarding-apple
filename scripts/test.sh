#!/bin/bash

set -e # stop script when error occures
set -u # stop when undefined variable is used
#set -x # print all execution (good for debugging)

SCRIPT_FOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
XCODE_PROJECT="WultraDigitalOnboarding.xcodeproj"
XCODE_SCHEME="WultraDigitalOnboardingTests"
BUILD_FOLDER="build"

# Function that resolves the best available simulator for the test run
function getSimulatorDestination {
  local scriptUrl="https://raw.githubusercontent.com/wultra/wultra-infrastructure/refs/heads/mobile/mobile/utils/ios-get-simulator/v1/get-ios-sim.js"
  curl -fsSL "${scriptUrl}" | node - -p "${SCRIPT_FOLDER}/.." "${XCODE_PROJECT}" "${XCODE_SCHEME}"
}

CONFIG_JSON=""

# Parse parameters of this script
while [[ $# -gt 0 ]]
do
	case "$1" in
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

# Resolve the newest available iOS Simulator destination through the shared Node helper.
echo "Resolving the best simulator for the ${XCODE_SCHEME}..."
DESTINATION=$(getSimulatorDestination)

echo "Simulator to use: ${DESTINATION}"

pushd "${SCRIPT_FOLDER}/.."

rm -rf "${BUILD_FOLDER}" # clear build folder

echo "${CONFIG_JSON}" > "WultraDigitalOnboardingTests/config.json"

# print xc tests logs
printLogs() {
	SEARCH_DIR="${BUILD_FOLDER}/Logs/Test"

	if [ ! -d "${SEARCH_DIR}" ]; then
	  echo "Directory ${SEARCH_DIR} does not exist."
	  exit 1
	fi

	find "${SEARCH_DIR}" -type d -name "*.xcresult" | while read -r bundle; do
	  echo "XCRESULT: ${bundle}"
	  xcrun xcresulttool get --path "${bundle}" --format json --legacy
	done
}

# make sure that we search for log files even on exit
trap printLogs EXIT

echo "Resolving Swift Package Manager dependencies"

xcrun xcodebuild \
  -derivedDataPath "${BUILD_FOLDER}" \
  -project "${XCODE_PROJECT}" \
  -scheme "${XCODE_SCHEME}" \
  -resolvePackageDependencies

echo "Starting the test"

xcrun xcodebuild \
  -derivedDataPath "${BUILD_FOLDER}" \
  -project "${XCODE_PROJECT}" \
  -scheme "${XCODE_SCHEME}" \
  -destination "${DESTINATION}" \
  -parallel-testing-enabled NO \
  -configuration "Debug" \
  test

popd
