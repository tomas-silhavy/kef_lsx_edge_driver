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
- Wifi, 20min, L/R: `2`
- Wifi, 60min, L/R: `18` (2 + 16)
- Wifi, never, L/R: `34` (2 + 32)
- Optical, 20min, R/L: `75` (11 + 64)
- Bluetooth, never, L/R: `41` (9 + 32)

The driver uses "never standby" mode by default when switching sources (adds 32 to base code).

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
- One queue per device
- Commands are processed sequentially
- Each command opens a fresh TCP connection
- Connections are closed after response
- 5-second timeout per command

### command_handlers.lua

Maps SmartThings capabilities to KEF API calls.

**Capability Handlers:**

- `capability_switch.on` → Power on (volume-based simulation)
- `capability_switch.off` → Power off (volume to 0)
- `capability_audio_volume.setVolume` → Set volume
- `capability_audio_volume.volumeUp` → Increase volume by 5
- `capability_audio_volume.volumeDown` → Decrease volume by 5
- `capability_media_input_source.setInputSource` → Switch source
- `capability_refresh.refresh` → Query current status

### Power Control Simulation

The KEF LSX v1 has **no dedicated power on/off command**. The driver simulates power states:

**Power Off:**
```lua
-- Set volume to 0, speaker auto-enters standby
kef_api.set_volume(device, 0)
device:emit_event(capabilities.switch.switch.off())
```

**Power On:**
```lua
-- Restore last source (or default to wifi)
local last_source = device:get_field("last_source") or "wifi"
kef_api.set_source(device, last_source)
device:emit_event(capabilities.switch.switch.on())
```

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
  - refresh                  # Status refresh
```

## Preferences (User Settings)

```yaml
preferences:
  - name: ipAddress
    title: Speaker IP Address
    type: string
    required: true
```

The driver previously had a port preference but it was removed since KEF LSX v1 always uses port 50001.

## Known Limitations

1. **No true power state** - KEF LSX v1 doesn't report power on/off, only current source and volume
2. **Limited sources** - Only 4 sources available (wifi, bluetooth, aux, optical)
3. **Playback controls** - Only work with streaming sources (wifi/bluetooth)
4. **No status notifications** - Speaker doesn't push updates, must poll via refresh

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
- KEF LSX v1 Protocol: Reverse engineered from pykefcontrol
- LuaSocket (cosock): SmartThings Edge compatible socket library
