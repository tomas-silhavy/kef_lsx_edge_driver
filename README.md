# KEF LSX SmartThings Edge Driver

A SmartThings Edge driver for controlling **KEF LSX (first generation)** speakers via local network communication.

KEF LSX protocol taken from https://github.com/basnijholt/aiokef

## Features

- **Power Control**: Turn speaker on/off via source on/off bit
- **Volume Control**: Set, increase, and decrease volume (0-100)
- **Source Switching**: Switch between audio inputs (wifi, bluetooth, aux, optical)
- **Playback Control**: Play/pause/stop (toggle based)
- **Standby Time**: Configure auto-standby timeout (20min, 60min, Never)
- **Status Monitoring**: Automatic polling every 30 seconds + manual refresh
- **Routine Support**: Execute multiple commands sequentially with proper timing

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

### Method 1:
1. Open 'Kef Connect' app
2. Klick on the 3 dots in upper right corner
3. Open 'Speaker Info' -> 'IP address'

### Method 2: Router Admin Page
1. Log into your router
2. Check DHCP client list
3. Look for device named "KEF LSX"
or
Use apps like Fing or nmap to scan your network for devices on port 50001.

### Recommended: Set Static IP
Configure a DHCP reservation in your router to prevent the IP from changing.

## Usage

### Power Control
- **On**: Restores last used source with saved on/off bit
- **Off**: Sets source on/off bit to false (speaker enters standby)
- **Preserves**: Source selection and standby time across power cycles

**Note**: KEF LSX v1 has no dedicated power command. Power is controlled via the source setting's on/off bit (byte value +128 when off).

### Volume Control
- Range: 0-100
- Volume up/down adjusts by 5 units
- Directly set via slider in SmartThings app

### Source Selection
Select from available input sources via SmartThings app.

### Standby Time Control
Configure automatic standby timeout in device settings:
- **20 minutes** (default)
- **60 minutes**  
- **Never**

**How it works:**
- Changes made in SmartThings are sent to speaker immediately
- Changes made in KEF Connect app are detected on next refresh
- Pull-to-refresh or wait 30 seconds to sync
- Check driver logs to see if speaker and preference are in sync

### Playback Control
- **Play/Pause**: Toggle playback state
- **Stop**: Stop playback
- State shows: playing, paused, or stopped
- Works best with wifi/bluetooth sources

**Note**: KEF LSX v1 provides limited playback state info. Controls are toggle-based.

### Status Refresh
- **Automatic**: Updates every 30 seconds
- **Manual**: Pull down to refresh in SmartThings app
- Updates volume, source, on/off state, and standby time

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
- Ensure no other app is connected to speaker simultaneously
- Wait 1-2 seconds between commands if testing manually
- Restart the speaker and retry

**Routines executing only first command:**
- This was a known issue, now fixed with command queue system
- All commands in a routine execute sequentially with proper delays

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
