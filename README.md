# KEF LSX SmartThings Edge Driver

A SmartThings Edge driver for controlling KEF LSX smart speakers.

## Features

- **Power Control**: Turn speaker on/off
- **Volume Control**: Set, increase, and decrease volume
- **Source Switching**: Switch between different audio inputs
- **Status Monitoring**: Query current speaker status

## Supported Sources

- wifi
- bluetooth
- tv
- optical
- coaxial
- analog

## Installation

1. Package and upload this driver to SmartThings
2. Add a new device using this driver:
   - Open SmartThings app
   - Tap **Add device** → **Scan nearby**
   - A KEF LSX Speaker device will be created automatically
3. Configure the speaker's IP address in device settings:
   - Open device settings in SmartThings app
   - Set "Speaker IP Address" (e.g., 192.168.1.100)
   - Optionally set "Speaker Port" (default: 80)
4. Control your KEF LSX speaker through SmartThings app

## Quick Start

### Adding Your First KEF Speaker

1. **Install the driver** on your SmartThings hub (via channel enrollment)
2. **In SmartThings app**: Devices → + → Scan nearby
3. **Device appears** as "KEF LSX Speaker"
4. **Configure IP**: Device Settings → Enter speaker's IP address
5. **Done!** Control speaker via app

## Configuration

The driver requires the following settings to be configured in the SmartThings app:

- **Speaker IP Address** (required): The local IP address of your KEF speaker
- **Speaker Port** (optional): HTTP port, defaults to 80

**Note**: Make sure your KEF speaker has a static IP address or DHCP reservation to prevent connection issues.

## Directory Structure

```
kef_driver/
├── config.yml              # Driver configuration
├── profiles/
│   └── kef-speaker.yml     # Device capability profile
└── src/
    ├── init.lua            # Main driver entry point
    ├── command_handlers.lua # Command implementations
    ├── kef_api.lua         # KEF API client
    ├── lifecycles.lua      # Device lifecycle handlers
    └── discovery.lua       # Device discovery (placeholder)
```

## API Reference

The driver uses the KEF HTTP API at `http://{speaker-ip}/api/`:

- `GET /api/getData` - Query speaker state
- `GET /api/setData` - Set speaker state

### Key API Paths

- `settings:/kef/host/speakerStatus` - Power status (standby/powerOn)
- `settings:/kef/play/physicalSource` - Input source
- `player:volume` - Volume level (0-100)

## Usage

### Power On/Off
- Turn on: Sets status to "powerOn"
- Turn off: Sets source to "standby"

### Volume Control
- Set volume: 0-100
- Volume up/down: Adjusts by 5 units

### Source Selection
Select from supported input sources via SmartThings app.

## Based On

- Python KEF API: `/home/blade/work/pykefcontrol/`
- SmartThings Sample Drivers: `/home/blade/smartthings/projects/SampleDrivers/`

## License

See LICENSE file for details.
