# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.3] - 2024-07-14
### Added
- Fix false TimeOut Errors

## [1.5.2] - 2024-01-15
### Added
- Add type for isPrinterConnected

## [1.5.1] - 2024-01-10
### Fixed
- Add better error handling

## [1.5.0] - 2024-01-05
### Fixed
- Fix example App
- Update android files
### Changed
- New publishing process

## [1.4.42] - 2023-12-20
### Fixed
- Fix error in Printer class, devices were duplicated
- Persist printer connected

## [1.4.41] - 2023-12-15
### Added
- Support Spanish language
### Fixed
- Synchronize printer once the scan has been restarted

## [1.3.41] - 2023-12-01
### Added
- Automatic Bluetooth Device Scanning: Implemented continuous scanning for nearby Bluetooth devices to improve device discovery without manual intervention
- Added background listening for Bluetooth device connections and disconnections, ensuring real-time updates for device availability

### Changed
- Code Quality Enhancements: Refactored Bluetooth scanning logic to optimize memory usage and prevent potential memory leaks
- Improved thread management to prevent excessive thread creation during Bluetooth operations
- Applied coding best practices, including proper resource management and context handling, to improve maintainability and performance

## [0.3.41] - 2023-11-15
### Changed
- Dynamically disconnect the current printer when the user selects a different one
- Change the color and update the state once the printer is disconnected

## [0.2.41] - 2023-11-10
### Changed
- Update view based on printer state

## [0.1.41] - 2023-11-05
### Fixed
- Avoid duplicate devices
- Improve list devices example

## [0.0.41] - 2023-10-20
### Added
- Include ZebraUtilPlugin.java in the repository

## [0.0.40] - 2023-10-15
### Changed
- Upgrade dependencies
- Enhance code quality and eliminate unnecessary code

## [0.0.39] - 2023-10-10
### Changed
- Updated native code

## [0.0.38] - 2023-10-05
### Fixed
- Fix bug in getting instance
- Improve performance for request local network

## [0.0.34] - 2023-09-30
### Added
- Request access for local network in iOS