local log = require "log"
local capabilities = require "st.capabilities"
local kef_api = require "kef_api"

local command_handlers = {}

function command_handlers.handle_switch_on(driver, device, command)
  log.info("[" .. device.id .. "] Switch ON command received")
  kef_api.power_on(device)
end

function command_handlers.handle_switch_off(driver, device, command)
  log.info("[" .. device.id .. "] Switch OFF command received")
  kef_api.power_off(device)
end

function command_handlers.handle_set_volume(driver, device, command)
  local volume = command.args.volume
  log.info("[" .. device.id .. "] Set volume to: " .. tostring(volume))
  kef_api.set_volume(device, volume)
end

function command_handlers.handle_volume_up(driver, device, command)
  log.info("[" .. device.id .. "] Volume UP command received")
  
  local current_volume = device:get_latest_state("main", capabilities.audioVolume.ID, capabilities.audioVolume.volume.NAME) or 50
  local new_volume = math.min(100, current_volume + 5)
  
  if kef_api.set_volume(device, new_volume) then
    device:emit_event(capabilities.audioVolume.volume(new_volume))
  else
    log.error("Failed to increase volume")
  end
end

function command_handlers.handle_volume_down(driver, device, command)
  log.info("[" .. device.id .. "] Volume DOWN command received")
  
  local current_volume = device:get_latest_state("main", capabilities.audioVolume.ID, capabilities.audioVolume.volume.NAME) or 50
  local new_volume = math.max(0, current_volume - 5)
  
  if kef_api.set_volume(device, new_volume) then
    device:emit_event(capabilities.audioVolume.volume(new_volume))
  else
    log.error("Failed to decrease volume")
  end
end

function command_handlers.handle_set_input_source(driver, device, command)
  local source = command.args.mode
  log.info("[" .. device.id .. "] Set input source to: " .. tostring(source))
  kef_api.set_source(device, source)
end

function command_handlers.handle_refresh(driver, device, command)
  log.info("[" .. device.id .. "] Refresh command received")
  kef_api.refresh_status(device)
end

function command_handlers.handle_play(driver, device, command)
  log.info("[" .. device.id .. "] Play command received")
  if kef_api.play_pause(device) then
    device:emit_event(capabilities.mediaPlayback.playbackStatus("playing"))
  end
end

function command_handlers.handle_pause(driver, device, command)
  log.info("[" .. device.id .. "] Pause command received")
  if kef_api.play_pause(device) then
    device:emit_event(capabilities.mediaPlayback.playbackStatus("paused"))
  end
end

function command_handlers.handle_stop(driver, device, command)
  log.info("[" .. device.id .. "] Stop command received")
  if kef_api.play_pause(device) then
    device:emit_event(capabilities.mediaPlayback.playbackStatus("stopped"))
  end
end

return command_handlers
