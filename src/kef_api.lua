local log = require "log"
local socket = require "cosock.socket"
local capabilities = require "st.capabilities"

local kef_api = {}

-- KEF LSX Protocol Constants
local PORT = 50001
local TIMEOUT = 5

-- Command queue per device
local command_queues = {}

-- Command codes
local CMD_GET = string.char(71)  -- 'G'
local CMD_SET = string.char(83)  -- 'S'
local CMD_END_GET = string.char(128)
local CMD_MID_SET = string.char(129)

-- Control codes
local CODE_VOLUME = string.char(37)  -- '%'
local CODE_SOURCE = string.char(48)  -- '0'
local CODE_CONTROL = string.char(49)  -- '1'

-- Response codes
local RESPONSE_OK = string.char(82, 17, 255)

-- Source mappings (base codes for 20min standby, L/R)
local KEF_SOURCES = {
  Wifi = 2,
  Bluetooth = 9,
  Aux = 10,
  Opt = 11
}

-- SmartThings to KEF source name mapping
local ST_TO_KEF_SOURCE = {
  wifi = "Wifi",
  bluetooth = "Bluetooth",
  aux = "Aux",
  optical = "Opt"
}

-- KEF to SmartThings source name mapping
local KEF_TO_ST_SOURCE = {
  Wifi = "wifi",
  Bluetooth = "bluetooth",
  Aux = "aux",
  Opt = "optical"
}

-- Reverse mapping for decoding
local KEF_SOURCE_NAMES = {}
for kef_name, code in pairs(KEF_SOURCES) do
  KEF_SOURCE_NAMES[code] = kef_name
end

-- Standby modifiers
local STANDBY_20MIN = 0
local STANDBY_60MIN = 16
local STANDBY_NEVER = 32

local function get_device_ip(device)
  local ip = device.preferences.ipAddress
  if not ip or ip == "" then
    ip = device:get_field("ip_address") or device.device_network_id
  end
  return ip
end

local function get_device_port(device)
  return PORT  -- KEF LSX always uses port 50001
end

-- Queue command execution to avoid connection conflicts
local function queue_command(device, command_fn)
  local device_id = device.id
  
  -- Initialize queue for this device if needed
  if not command_queues[device_id] then
    command_queues[device_id] = {
      queue = {},
      processing = false
    }
  end
  
  local queue = command_queues[device_id]
  
  -- Add command to queue
  table.insert(queue.queue, command_fn)
  
  -- Process queue if not already processing
  if not queue.processing then
    queue.processing = true
    
    local function process_next()
      if #queue.queue > 0 then
        local next_cmd = table.remove(queue.queue, 1)
        
        -- Execute command
        next_cmd()
        
        -- Wait 1 second before next command
        device.thread:call_with_delay(1, function()
          process_next()
        end)
      else
        queue.processing = false
      end
    end
    
    process_next()
  end
end

-- Create and send TCP command
local function send_command(device, command)
  local ip = get_device_ip(device)
  if not ip or ip == "" then
    log.error("Cannot send command - IP address not configured")
    return nil
  end
  
  local port = get_device_port(device)
  log.debug(string.format("Connecting to %s:%d", ip, port))
  
  local sock = socket.tcp()
  sock:settimeout(TIMEOUT)
  
  local ok, err = sock:connect(ip, port)
  if not ok then
    log.error(string.format("Connection failed: %s", tostring(err)))
    sock:close()
    return nil
  end
  
  log.debug(string.format("Sending command: %s", table.concat({string.byte(command, 1, #command)}, ", ")))
  
  local sent, send_err = sock:send(command)
  if not sent then
    log.error(string.format("Send failed: %s", tostring(send_err)))
    sock:close()
    return nil
  end
  
  -- Set short timeout for non-blocking receive
  sock:settimeout(1)
  
  -- Read whatever is available (KEF responses are 3-5 bytes)
  local response, recv_err, partial = sock:receive(5)
  sock:close()
  
  -- Use response or partial data
  response = response or partial
  
  if not response or response == "" then
    log.error(string.format("Receive failed: %s", tostring(recv_err)))
    return nil
  end
  
  log.debug(string.format("Response: %s", table.concat({string.byte(response, 1, #response)}, ", ")))
  
  return response
end

-- Get volume (0-100)
function kef_api.get_volume(device)
  local command = CMD_GET .. CODE_VOLUME .. CMD_END_GET
  local response = send_command(device, command)
  
  if response and #response >= 4 then
    local volume = string.byte(response, 4)
    log.debug(string.format("Volume: %d", volume))
    return volume
  end
  
  return nil
end

-- Set volume (0-100) - queued
function kef_api.set_volume(device, volume)
  volume = math.max(0, math.min(100, volume))
  
  queue_command(device, function()
    local command = CMD_SET .. CODE_VOLUME .. CMD_MID_SET .. string.char(volume)
    local response = send_command(device, command)
    
    -- Check if response contains success bytes (may have duplicates)
    if response and string.find(response, RESPONSE_OK, 1, true) then
      log.info(string.format("Volume set to %d", volume))
      device:emit_event(capabilities.audioVolume.volume(volume))
    else
      log.error("Failed to set volume")
    end
  end)
end

-- Decode source code to name and standby time
local function decode_source(code)
  -- Check if speaker is off (code > 128)
  local is_on = code <= 128
  local base = code % 128
  
  -- Remove R/L orientation bit
  local orientation = "L/R"
  if base >= 64 then
    base = base - 64
    orientation = "R/L"
  end
  
  -- Detect standby time
  local standby_time = 20
  if base >= 32 then
    base = base - 32
    standby_time = nil  -- Never
  elseif base >= 16 then
    base = base - 16
    standby_time = 60
  end
  
  local kef_source_name = KEF_SOURCE_NAMES[base]
  local st_source_name = KEF_TO_ST_SOURCE[kef_source_name] or "wifi"
  
  return st_source_name, standby_time, orientation, is_on
end

-- Encode source name to KEF code
local function encode_source(st_source_name, standby_time, orientation, is_on)
  -- Convert SmartThings source name to KEF source name
  local kef_source_name = ST_TO_KEF_SOURCE[st_source_name]
  if not kef_source_name then
    log.error(string.format("Unknown SmartThings source: %s", st_source_name))
    return nil
  end
  
  local code = KEF_SOURCES[kef_source_name]
  if not code then
    log.error(string.format("Unknown KEF source: %s", kef_source_name))
    return nil
  end
  
  -- Add standby modifier (default to None for always on)
  standby_time = standby_time or nil
  if standby_time == 60 then
    code = code + STANDBY_60MIN
  elseif standby_time == nil then
    code = code + STANDBY_NEVER
  end
  -- else: 20min is default (code + 0)
  
  -- Add orientation (default L/R)
  if orientation == "R/L" then
    code = code + 64
  end
  
  -- Add power state (if off, add 128)
  if not is_on then
    code = code + 128
  end
  
  return code
end

-- Get source
function kef_api.get_source(device)
  local command = CMD_GET .. CODE_SOURCE .. CMD_END_GET
  local response = send_command(device, command)
  
  if response and #response >= 4 then
    local source_code = string.byte(response, 4)
    local st_source_name, standby_time, orientation, is_on = decode_source(source_code)
    log.debug(string.format("Source: %s (KEF code: %d), Standby: %s min, Orientation: %s, Is On: %s", 
      st_source_name, source_code, tostring(standby_time), orientation, tostring(is_on)))
    return st_source_name, standby_time, orientation, is_on
  end
  
  return nil
end

-- Set standby time on speaker - queued
function kef_api.set_standby_time(device, standby_pref)
  queue_command(device, function()
    -- First get current source and power state
    local st_source, _, _, is_on = kef_api.get_source(device)
    
    if not st_source then
      log.error("Failed to get current source for standby time change")
      return
    end
    
    -- Convert preference to standby value
    local standby_time
    if standby_pref == "never" then
      standby_time = nil
    elseif standby_pref == "60" then
      standby_time = 60
    else
      standby_time = 20
    end
    
    -- Set source with new standby time (preserve is_on state)
    local source_code = encode_source(st_source, standby_time, "L/R", is_on)
    if not source_code then
      log.error("Failed to encode standby time change")
      return
    end
    
    local command = CMD_SET .. CODE_SOURCE .. CMD_MID_SET .. string.char(source_code)
    local response = send_command(device, command)
    
    if response and string.find(response, RESPONSE_OK, 1, true) then
      log.info(string.format("Standby time set to: %s", standby_pref))
      device:set_field("last_standby_time", standby_time, {persist = true})
    else
      log.error("Failed to set standby time on speaker")
    end
  end)
end

-- Set source (preserves standby setting) - queued
function kef_api.set_source(device, st_source_name)
  queue_command(device, function()
    -- ALWAYS use standby from speaker (updated on refresh), fallback to preference
    local standby_time = device:get_field("last_standby_time")
    
    if standby_time == nil and not device:get_field("last_standby_time_set") then
      -- First time: use preference as initial value
      local standby_pref = device.preferences.standbyTime
      if standby_pref == "never" then
        standby_time = nil
      elseif standby_pref == "60" then
        standby_time = 60
      else
        standby_time = 20  -- default
      end
      log.debug("Using preference for initial standby time")
    else
      log.debug(string.format("Using speaker's standby time: %s", tostring(standby_time)))
    end
    
    -- Turn on with preserved standby setting
    local source_code = encode_source(st_source_name, standby_time, "L/R", true)
    if not source_code then
      return
    end
    
    local command = CMD_SET .. CODE_SOURCE .. CMD_MID_SET .. string.char(source_code)
    local response = send_command(device, command)
    
    -- Check if response contains success bytes
    if response and string.find(response, RESPONSE_OK, 1, true) then
      log.info(string.format("Source set to %s (standby: %s min)", st_source_name, tostring(standby_time)))
      device:emit_event(capabilities.mediaInputSource.inputSource(st_source_name))
      device:emit_event(capabilities.switch.switch.on())
    else
      log.error("Failed to set source")
    end
  end)
end

-- Power on (turn on current source without changing it) - queued
function kef_api.power_on(device)
  queue_command(device, function()
    -- Get current source (even if off)
    local st_source, current_standby, _, is_on = kef_api.get_source(device)
    
    if is_on then
      log.info("Speaker already on")
      device:emit_event(capabilities.switch.switch.on())
      return
    end
    
    -- Use current source or fallback to saved/wifi
    local target_source = st_source or device:get_field("last_source") or "wifi"
    
    -- Preserve standby time: use current, saved, preference, or default to 20
    local target_standby = current_standby
    if not target_standby then
      target_standby = device:get_field("last_standby_time")
      
      if not target_standby then
        local standby_pref = device.preferences.standbyTime
        if standby_pref == "never" then
          target_standby = nil
        elseif standby_pref == "60" then
          target_standby = 60
        else
          target_standby = 20  -- default
        end
      end
    end
    
    -- Turn on with current source and standby (is_on=true)
    local source_code = encode_source(target_source, target_standby, "L/R", true)
    if not source_code then
      log.error("Failed to encode power on command")
      return
    end
    
    local command = CMD_SET .. CODE_SOURCE .. CMD_MID_SET .. string.char(source_code)
    local response = send_command(device, command)
    
    if response and string.find(response, RESPONSE_OK, 1, true) then
      log.info(string.format("Power on successful (source: %s, standby: %s min)", target_source, tostring(target_standby)))
      device:emit_event(capabilities.switch.switch.on())
      device:emit_event(capabilities.mediaInputSource.inputSource(target_source))
    else
      log.error("Failed to power on")
    end
  end)
  
  return true
end

-- Power off (set source with is_on=false flag, adds 128 to source code)
function kef_api.power_off(device)
  -- Get current source (with delay handled by callback)
  device.thread:call_with_delay(0, function()
    local st_source, current_standby, _, is_on = kef_api.get_source(device)
    if st_source and is_on then
      device:set_field("last_source", st_source, {persist = true})
      device:set_field("last_standby_time", current_standby, {persist = true})
    end
    
    -- Wait 1 second before sending power off command
    device.thread:call_with_delay(1, function()
      local target_source = st_source or device:get_field("last_source") or "wifi"
      local target_standby = current_standby
      
      if not st_source then
        target_standby = device:get_field("last_standby_time")
      end
      
      -- Encode with is_on=false (adds 128 to code)
      local source_code = encode_source(target_source, target_standby, "L/R", false)
      if not source_code then
        log.error("Failed to encode power off command")
        return
      end
      
      local command = CMD_SET .. CODE_SOURCE .. CMD_MID_SET .. string.char(source_code)
      local response = send_command(device, command)
      
      if response and string.find(response, RESPONSE_OK, 1, true) then
        log.info("Power off successful")
        device:emit_event(capabilities.switch.switch.off())
      else
        log.error("Failed to power off")
      end
    end)
  end)
  
  return true  -- Return immediately, actual work happens async
end

-- Check if speaker is "on"
function kef_api.is_on(device)
  local _, _, _, is_on = kef_api.get_source(device)
  return is_on or false
end

-- Get playback state
function kef_api.get_playback_state(device)
  local command = CMD_GET .. CODE_CONTROL .. CMD_END_GET
  local response = send_command(device, command)
  
  if response and #response >= 4 then
    local state_code = string.byte(response, 4)
    -- 0 = paused, 1 = playing (based on Python library)
    local is_playing = (state_code == 1)
    log.debug(string.format("Playback state: %s (code: %d)", is_playing and "playing" or "paused", state_code))
    return is_playing
  end
  
  return nil
end

-- Refresh status (use sequential queries with proper timing)
function kef_api.refresh_status(device)
  log.debug("Starting status refresh...")
  
  -- Get volume
  local volume = kef_api.get_volume(device)
  if volume then
    device:emit_event(capabilities.audioVolume.volume(volume))
    device:online()  -- Mark device as online
    log.debug("Volume updated")
  else
    log.warn("Failed to get volume - device may be offline")
    return  -- Don't continue if speaker is not responding
  end
  
  -- Wait 1 second before next query
  device.thread:call_with_delay(1, function()
    -- Get source, standby time, and power state
    local st_source, standby_time, _, is_on = kef_api.get_source(device)
    if st_source then
      device:emit_event(capabilities.mediaInputSource.inputSource(st_source))
      
      -- Save standby time from speaker (this is the source of truth)
      device:set_field("last_standby_time", standby_time, {persist = true})
      
      -- Log the actual standby time from speaker and compare to preference
      local standby_desc
      if standby_time == nil then
        standby_desc = "Never"
      elseif standby_time == 60 then
        standby_desc = "60 minutes"
      else
        standby_desc = "20 minutes"
      end
      
      local pref_desc
      if device.preferences.standbyTime == "never" then
        pref_desc = "Never"
      elseif device.preferences.standbyTime == "60" then
        pref_desc = "60 minutes"
      else
        pref_desc = "20 minutes"
      end
      
      if standby_desc ~= pref_desc then
        log.warn(string.format("Standby mismatch - Speaker: %s, Preference: %s", standby_desc, pref_desc))
      else
        log.info(string.format("Standby time: %s (in sync)", standby_desc))
      end
      
      if is_on then
        device:emit_event(capabilities.switch.switch.on())
        log.debug("Power ON, checking playback...")
        
        -- Wait before checking playback
        device.thread:call_with_delay(1, function()
          local is_playing = kef_api.get_playback_state(device)
          if is_playing ~= nil then
            if is_playing then
              device:emit_event(capabilities.mediaPlayback.playbackStatus("playing"))
            else
              device:emit_event(capabilities.mediaPlayback.playbackStatus("paused"))
            end
          else
            device:emit_event(capabilities.mediaPlayback.playbackStatus("paused"))
          end
        end)
      else
        device:emit_event(capabilities.switch.switch.off())
        device:emit_event(capabilities.mediaPlayback.playbackStatus("stopped"))
      end
    end
  end)
end

-- Playback control
function kef_api.play_pause(device)
  local command = CMD_SET .. CODE_CONTROL .. CMD_MID_SET .. string.char(129)
  local response = send_command(device, command)
  return response and string.find(response, RESPONSE_OK, 1, true) ~= nil
end

function kef_api.next_track(device)
  local command = CMD_SET .. CODE_CONTROL .. CMD_MID_SET .. string.char(130)
  local response = send_command(device, command)
  return response and string.find(response, RESPONSE_OK, 1, true) ~= nil
end

function kef_api.prev_track(device)
  local command = CMD_SET .. CODE_CONTROL .. CMD_MID_SET .. string.char(131)
  local response = send_command(device, command)
  return response and string.find(response, RESPONSE_OK, 1, true) ~= nil
end

return kef_api
