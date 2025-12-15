# KEF LSX Driver - Developer Documentation

Technical documentation for the KEF LSX (v1) SmartThings Edge driver.

## KEF LSX Protocol Specification

### Important Notice

This driver is designed for the **original KEF LSX (first generation)** speaker which uses a proprietary TCP socket protocol. 

**DO NOT confuse with:**
- KEF LSX II (second generation) - uses REST API
- KEF LS50 Wireless II - uses REST API
- Other KEF models with HTTP/REST interfaces

The original KEF LSX uses **raw TCP communication on port 50001** with a binary protocol.

## Connection Details

- **Protocol**: TCP Socket
- **Port**: 50001 (fixed, not configurable)
- **Transport**: Binary data stream
- **Socket Library**: `cosock.socket` (SmartThings Edge compatible)

## Binary Protocol Format

### Get Commands

Request format:
```
[71, COMMAND_CODE, 128]
```
- `71` = 'G' (Get command)
- `COMMAND_CODE` = what to query
- `128` = end marker

Response format:
```
[82, COMMAND_CODE, 129, VALUE, ...]
```
- `82` = 'R' (Response)
- `COMMAND_CODE` = echoed command code
- `129` = separator
- `VALUE` = returned value(s)

### Set Commands

Request format:
```
[83, COMMAND_CODE, 129, VALUE]
```
- `83` = 'S' (Set command)
- `COMMAND_CODE` = what to set
- `129` = middle marker
- `VALUE` = value to set

Success response:
```
[82, 17, 255]
```

## Command Codes

### Volume Control
- **Command Code**: `37` (0x25 = '%')
- **Get Volume**: `[71, 37, 128]`
- **Set Volume**: `[83, 37, 129, VOLUME]`
- **Range**: 0-100

Example:
```lua
-- Set volume to 50
local cmd = string.char(83, 37, 129, 50)
sock:send(cmd)
```

### Source Control
- **Command Code**: `48` (0x30 = '0')
- **Get Source**: `[71, 48, 128]`
- **Set Source**: `[83, 48, 129, SOURCE_CODE]`

### Playback Control
- **Command Code**: `49` (0x31 = '1')
- **Play/Pause**: `[83, 49, 129, 129]`
- **Next Track**: `[83, 49, 129, 130]`
- **Previous Track**: `[83, 49, 129, 131]`

## Source Code Mappings

### Base Source Codes

These are base codes for 20-minute standby with L/R orientation:

| Source | KEF Code | SmartThings ID |
|--------|----------|----------------|
| Wifi | 2 | wifi |
| Bluetooth | 9 | bluetooth |
| Aux | 10 | aux |
| Optical | 11 | optical |

### Standby Modifiers

Add these values to base codes to modify standby behavior:

- `+0` = 20 minute standby (default)
- `+16` = 60 minute standby
- `+32` = Never standby (always on)
- `+64` = R/L orientation swap

Examples:
- Wifi, 20min, L/R, ON: `2`
- Wifi, 60min, L/R, ON: `18` (2 + 16)
- Wifi, never, L/R, ON: `34` (2 + 32)
- Optical, 20min, R/L, ON: `75` (11 + 64)
- Bluetooth, never, L/R, ON: `41` (9 + 32)
- Wifi, 20min, L/R, OFF: `130` (2 + 128)
- Optical, 60min, L/R, OFF: `155` (11 + 16 + 128)

The driver uses the user's standby preference setting when sending commands.

## Implementation Details

### kef_api.lua

Core TCP communication module implementing the binary protocol.

**Key Functions:**

```lua
-- Send command and receive response
kef_api.send_command(device, command_bytes)

-- Volume operations
kef_api.get_volume(device)
kef_api.set_volume(device, volume)

-- Source operations
kef_api.get_source(device)
kef_api.set_source(device, source_name)

-- Playback controls
kef_api.play_pause(device)
kef_api.next_track(device)
kef_api.previous_track(device)

-- Status refresh
kef_api.refresh_status(device)
```

**Connection Management:**

The driver uses a command queue system to prevent concurrent TCP connections:
- One queue per device (stored per device ID)
- Commands are processed sequentially with 1-second delays
- Each command opens a fresh TCP connection
- Connections are closed after response
- 5-second timeout per command
- Automatic cleanup on command failure

**Queue Benefits:**
- Prevents "Connection refused" errors
- Eliminates race conditions
- Ensures reliable command execution in routines
- Allows multiple rapid commands (e.g., on + volume + source)

### command_handlers.lua

Maps SmartThings capabilities to KEF API calls.

**Capability Handlers:**

- `capability_switch.on` → Power on with last source/standby
- `capability_switch.off` → Power off (preserves source/standby)
- `capability_audio_volume.setVolume` → Set volume
- `capability_audio_volume.volumeUp` → Increase volume by 5
- `capability_audio_volume.volumeDown` → Decrease volume by 5
- `capability_media_input_source.setInputSource` → Switch source
- `capability_media_playback.play/pause/stop` → Playback control
- `capability_refresh.refresh` → Query current status

### Power Control Simulation

The KEF LSX v1 has **no dedicated power on/off command**. Power is controlled via the source setting's on/off bit:

**Power Off:**
```lua
-- Set source with is_on=false (adds 128 to source code)
kef_api.power_off(device)
-- Preserves current source and standby setting
device:emit_event(capabilities.switch.switch.off())
```

**Power On:**
```lua
-- Set source with is_on=true (uses last known source)
kef_api.power_on(device)
-- Restores last source and standby setting
device:emit_event(capabilities.switch.switch.on())
```

### Standby Time Control

The driver now supports full standby time management:

**Source Byte Encoding:**
- Base source code (2=wifi, 9=bluetooth, 10=aux, 11=optical)
- `+0` = 20 minute standby
- `+16` = 60 minute standby  
- `+32` = Never standby
- `+64` = R/L orientation swap
- `+128` = Power off bit (is_on=false)

**User Control:**
- Standby time preference in device settings (20min/60min/Never)
- Changes sent to speaker immediately via `set_standby_time()`
- Refresh reads current speaker setting and logs if preference doesn't match
- All commands use preference value to maintain consistency

### Discovery Process

When user taps "Scan nearby" in SmartThings app:

1. `discovery.handle_discovery()` is called
2. Driver creates a placeholder device with unique ID
3. Device appears in app without IP configured
4. User configures IP in device settings
5. `lifecycles.device_info_changed()` detects IP change
6. Driver automatically refreshes status

Device Network ID format: `KEF-LSX-{timestamp}`

## Testing & Validation

### Tested Commands

All commands have been validated with actual KEF LSX v1 speaker:

✅ **Get Volume** - Returns current volume 0-100  
✅ **Set Volume** - Changes volume successfully  
✅ **Get Source** - Returns current source code  
✅ **Set Source** - Switches input successfully  
✅ **TCP Connection** - Stable and reliable  

### Example Test Session

```bash
# Connect to speaker
nc 192.168.0.184 50001

# Get volume (send bytes: 71, 37, 128)
# Response: 82, 37, 129, 65, 48 → Volume = 65

# Set volume to 30 (send bytes: 83, 37, 129, 30)
# Response: 82, 17, 255 → Success!

# Get source (send bytes: 71, 48, 128)
# Response: 82, 48, 129, 75, 100 → Source = 75 (Optical, R/L, 20min)
```

## SmartThings Capabilities Used

```yaml
capabilities:
  - switch                    # Power on/off
  - audioVolume              # Volume control
  - mediaInputSource         # Source switching
  - mediaPlayback            # Play/pause/stop
  - refresh                  # Status refresh
```

## Preferences (User Settings)

```yaml
preferences:
  - name: ipAddress
    title: Speaker IP Address
    type: string
    required: true
  - name: standbyTime
    title: Standby Time
    type: enumeration
    options: [20, 60, never]
    default: 20
```

**How Preferences Work:**
- `ipAddress`: User configures speaker IP, driver connects on save
- `standbyTime`: User sets desired timeout, sent to speaker on change
- Changes detected via `infoChanged` lifecycle event
- Preference is authoritative - all commands use this value

## Known Limitations

1. **No true power state query** - KEF LSX v1 doesn't have a power status command, only source on/off bit
2. **Limited sources** - Only 4 sources available (wifi, bluetooth, aux, optical) - USB not supported
3. **Playback controls** - Toggle only (no detailed playback state from speaker)
4. **No status notifications** - Speaker doesn't push updates, polling via refresh every 30 seconds
5. **Connection limit** - Only one TCP connection at a time, enforced by queue system

## Driver Deployment

### Packaging
```bash
smartthings edge:drivers:package
```

### Channel Assignment
```bash
smartthings edge:channels:assign <driver-id> --channel <channel-id>
```

### View Logs
```bash
smartthings edge:drivers:logcat <driver-id>
```

## Source Code Structure

```
src/
├── init.lua                 # Driver initialization
│   ├── Registers capability handlers
│   ├── Registers lifecycle handlers
│   └── Sets up discovery
│
├── kef_api.lua             # TCP protocol implementation
│   ├── Binary command encoding/decoding
│   ├── Socket communication
│   ├── Command queue management
│   └── Source/volume translation
│
├── command_handlers.lua    # Capability command handlers
│   ├── Power on/off (simulated)
│   ├── Volume control
│   ├── Source switching
│   └── Refresh
│
├── lifecycles.lua         # Device lifecycle events
│   ├── device_added()
│   ├── device_init()
│   ├── device_removed()
│   └── device_info_changed()
│
└── discovery.lua          # Device discovery
    └── handle_discovery() # Creates placeholder device
```

## Error Handling

The driver includes comprehensive error handling:

- **Connection failures**: Logged with IP and port details
- **Invalid responses**: Logged with raw response bytes
- **Missing IP**: Gracefully handles unconfigured devices
- **Timeout**: 5-second timeout on all socket operations
- **Queue errors**: Automatic cleanup on command failure

## Performance Considerations

- **Command queue**: Prevents connection conflicts
- **Fresh connections**: Each command uses new TCP connection
- **Timeout management**: 5-second limit prevents hanging
- **Minimal polling**: Only refreshes on user request or setting change

## References

- SmartThings Edge Driver Documentation: https://developer.smartthings.com/
- KEF LSX v1 Protocol: Reverse engineered from https://github.com/basnijholt/aiokef
- LuaSocket (cosock): SmartThings Edge compatible socket library
