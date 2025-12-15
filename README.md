# KEF LSX SmartThings Edge Driver

A SmartThings Edge driver for controlling **KEF LSX (first generation)** speakers via local network communication.

## Features

- **Power Control**: Turn speaker on/off (volume-based simulation)
- **Volume Control**: Set, increase, and decrease volume (0-100)
- **Source Switching**: Switch between audio inputs
- **Status Monitoring**: Query current speaker status

## Supported Sources

- **wifi** - Network streaming
- **bluetooth** - Bluetooth audio
- **aux** - Auxiliary input
- **optical** - Optical digital input

**Note**: This driver is for the original KEF LSX (v1) which uses TCP socket communication on port 50001. It does NOT support KEF LSX II or LS50 Wireless II models.

## Installation & Setup

### Step 1: Install the Driver

Install via SmartThings channel enrollment or upload the driver package to your hub.

### Step 2: Add Device

1. Open **SmartThings app**
2. Go to **Devices** tab
3. Tap **+** (Add device)
4. Select **Scan nearby**
5. Wait a few seconds - a "KEF LSX Speaker" device will appear

### Step 3: Configure IP Address

1. Open the device in SmartThings app
2. Tap **⋮** (3-dot menu) → **Settings**
3. Enter your speaker's **IP Address** (e.g., 192.168.0.184)
4. Tap **Save**

The driver will automatically connect and refresh the speaker status.

## Finding Your Speaker's IP Address

### Method 1: Router Admin Page
1. Log into your router
2. Check DHCP client list
3. Look for device named "KEF LSX"

### Method 2: Network Scanner
Use apps like Fing or nmap to scan your network for devices on port 50001.

### Recommended: Set Static IP
Configure a DHCP reservation in your router to prevent the IP from changing.

## Usage

### Power Control
- **On**: Sets source to last used input (or wifi by default)
- **Off**: Sets volume to 0, speaker auto-enters standby

**Note**: KEF LSX v1 has no dedicated power off command. The driver simulates power control via volume.

### Volume Control
- Range: 0-100
- Volume up/down adjusts by 5 units
- Directly set via slider in SmartThings app

### Source Selection
Select from available input sources via SmartThings app. The driver automatically configures "never standby" mode when switching sources.

### Status Refresh
Tap refresh to query current volume and source from the speaker.

## Troubleshooting

**Device not responding:**
- Verify IP address is correct in device settings
- Ping the speaker IP from your network
- Ensure speaker is powered on and connected to network
- Check that SmartThings hub and speaker are on same network

**IP address keeps changing:**
- Set up DHCP reservation in your router
- Use the speaker's MAC address to assign a fixed IP

**Commands not working:**
- Check driver logs: `smartthings edge:drivers:logcat`
- Verify port 50001 is accessible
- Restart the speaker and retry

## Directory Structure

```
kef_lsx_edge_driver/
├── config.yml              # Driver configuration
├── profiles/
│   └── kef-speaker.yml     # Device capability profile
└── src/
    ├── init.lua            # Main driver entry point
    ├── command_handlers.lua # Command implementations
    ├── kef_api.lua         # KEF TCP protocol client
    ├── lifecycles.lua      # Device lifecycle handlers
    └── discovery.lua       # Device discovery handler
```

## Technical Details

See [DEVELOPER.md](DEVELOPER.md) for technical documentation including:
- KEF LSX TCP protocol specification
- Binary command format
- Source code mappings
- API implementation details

## License

See LICENSE file for details.
