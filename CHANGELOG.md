# Changelog

All notable changes to the KEF LSX SmartThings Edge Driver will be documented in this file.

## [2025-12-15] - Standby Time Preservation

### Fixed
- **Standby time handling**: Driver now preserves the speaker's standby time setting instead of forcing "never standby"
  - When switching sources, the current standby time is read and preserved
  - When turning on, the previous standby setting is restored
  - Default fallback is 20 minutes if no previous setting exists
  - Prevents unwanted changes to speaker's power-saving configuration

### Technical Details
- `set_source()` now queries current standby time before applying source change
- `power_on()` restores last known standby time (or defaults to 20 min)
- `power_off()` saves current standby time to persistent storage
- Standby time values: `nil` (never), `20` (20 minutes), `60` (60 minutes)

## [2025-12-14] - Initial Release

### Added
- Full SmartThings Edge driver for KEF LSX (v1) speakers
- TCP socket communication on port 50001
- Power on/off control (via source state manipulation)
- Volume control (0-100%)
- Input source switching (wifi, bluetooth, aux, optical)
- Playback controls (play/pause/stop via physical button)
- Automatic status polling every 30 seconds
- Pull-to-refresh support in SmartThings app
- Command queueing to prevent connection conflicts
- Manual device discovery (IP configuration in settings)

### Features
- **Protocol**: Binary TCP protocol matching aiokef Python library
- **Sources**: Wifi (Spotify Connect), Bluetooth, Aux, Optical
- **Playback State Detection**: Queries actual play/pause state from speaker
- **Routine Support**: Multiple commands execute sequentially with proper timing
- **Connection Management**: 1-second delays between commands prevent "connection refused" errors
- **Status Preservation**: Remembers last source and power state across power cycles

### Known Limitations
- No true power off (KEF LSX v1 doesn't support it - uses source state instead)
- USB source not supported (not available on KEF LSX v1)
- Playback controls trigger play/pause toggle (speaker doesn't report detailed playback info)
