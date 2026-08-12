# Welcome to the Wultra Digital Onboarding SDK Apple repository!

In this file, you'll find topics that help with local setup, running tests, creating pull requests, and preparing a new release.

## Table of Contents

- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Running Tests](#running-tests)
- [Creating a Pull Request](#creating-a-pull-request)
- [Preparing a New Release](#preparing-a-new-release)

## Getting Started

> [!WARNING]
> If you're not a Wultra employee or contractor, please fill out the [Wultra Contributor License Agreement](https://forms.gle/r715RoVDoji4GD7K7) before you start contributing.

Before you start development, make sure you have the following prerequisites:

- macOS machine
- latest [Xcode](https://developer.apple.com/xcode/) installed
- [CocoaPods](https://guides.cocoapods.org/using/getting-started.html) installed (`brew install cocoapods`)

The project resolves its dependencies (PowerAuth mobile SDK and WultraPowerAuthNetworking) through Swift Package Manager. To resolve them before building, run this command in the project root:

```bash
xcrun xcodebuild -project WultraDigitalOnboarding.xcodeproj -scheme WultraDigitalOnboarding -resolvePackageDependencies
```

Xcode also resolves the packages automatically when you open the project.

CI uses the Xcode selected in `scripts/xcodeselect.sh`. Local development should use the latest Xcode as well.

## Project Structure

The most important files and directories are:

```text
digital-onboarding-apple/
├── .github/                            # GitHub workflows and contribution docs
├── docs/                               # Public documentation published to developers portal
├── Package.swift                       # Swift Package Manager definition file
├── README.md                           # Project overview
├── scripts/                            # Build, lint, test, and release scripts
├── Sources/                            # SDK sources
├── WultraDigitalOnboarding.podspec     # CocoaPods definition file
├── WultraDigitalOnboarding.xcodeproj   # Xcode project file
├── WultraDigitalOnboarding.xcworkspace # Xcode workspace
└── WultraDigitalOnboardingTests/       # Unit and integration tests
    ├── config.json                     # Test environment configuration
    ├── Readme.md                       # Description of the config file
    └── Other test files...
```

## Running Tests

Before you run tests, make sure:

- `WultraDigitalOnboardingTests/config.json` is configured correctly. See `WultraDigitalOnboardingTests/Readme.md` for the file format.
- Swift Package Manager dependencies are resolved (Xcode resolves them automatically, or run `xcrun xcodebuild -project WultraDigitalOnboarding.xcodeproj -scheme WultraDigitalOnboardingTests -resolvePackageDependencies`).
- latest Xcode is selected.

> [!NOTE]
> You can run tests from Xcode by selecting the `WultraDigitalOnboardingTests` scheme.

To run tests from the command line:

```bash
./scripts/test.sh
```

To pass config JSON from CI or another source:

```bash
./scripts/test.sh -config "$CONFIG_JSON"
```

The test script writes the provided JSON into `WultraDigitalOnboardingTests/config.json` before running tests.

## Creating a Pull Request

> [!WARNING]
> Before you create a pull request, make sure:
>
> - an issue exists for the change
> - all tests are passing
> - `sh scripts/swiftlint.sh` does not report issues

1. If you're not a Wultra employee or contractor, fork the repository and work in your fork.
2. Create a branch named `issues/issue-number-short-description`, for example `issues/123-fix-status-docs`.
3. Make your changes and commit them with a clear commit message.
4. Push the branch to the remote repository.
5. Create a pull request targeting the `develop` branch.
6. Reference the related issue in the pull request description using `#issue-number`.
7. If you're not a Wultra employee or contractor, wait for a Wultra team member to approve workflows to run.
8. If you're a Wultra employee or contractor, wait for workflows to pass and request review.

## Preparing a New Release

> [!WARNING]
> This section is intended for Wultra employees and contractors only.

### Release streams

- `develop` is the development branch
- release branches use the format `release/a.b.x`, for example `release/2.0.x`
- release branch history should stay linear
- changes to a release branch should go through pull requests and be squash-merged

### Release versioning

The version number has format `major.minor.patch`, for example `2.0.0`.

- increment `major` for larger milestones or major compatibility changes
- increment `minor` for new features or API changes
- increment `patch` for bug fixes only

### Each release should include

- updated `WultraDigitalOnboarding.podspec`
- updated `docs/Changelog.md`
- updated `docs/SDK-Integration.md` when version examples or compatibility information change
- updated migration guide or other public documentation if the release changes the public API

You can use:

```bash
./scripts/prepare-release.sh VERSION
```

Optional flags:

- `-c` or `--commit` to create a commit and tag
- `-p` or `--push` to push tags
- `-r` or `--release` to run CocoaPods release steps

### Example release flow

1. Create an issue for the release.
2. Make or update the target `release/a.b.x` branch from `develop`.
3. Create a working branch, for example `issues/65-prepare-release-2_0_0`.
4. Update all files required for the release.
5. Run tests and SwiftLint.
6. Run `./scripts/prepare-release.sh VERSION`.
7. Create a pull request into the target `release/a.b.x` branch.
8. After approval, squash-merge the pull request.
9. Publish the tag and create the GitHub release.
10. Verify the CocoaPods release and public documentation updates.