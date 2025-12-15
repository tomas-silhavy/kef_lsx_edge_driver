local capabilities = require "st.capabilities"
local log = require "log"
local kef_api = require "kef_api"

local lifecycles = {}

function lifecycles.added(driver, device)
  log.info("[" .. device.id .. "] Adding KEF LSX device")
  
  device:emit_event(capabilities.switch.switch.off())
  device:emit_event(capabilities.audioVolume.volume(50))
  
  local supported_sources = {
    "wifi",
    "bluetooth",
    "aux",
    "optical"
  }
  device:emit_event(capabilities.mediaInputSource.supportedInputSources(supported_sources))
  device:emit_event(capabilities.mediaInputSource.inputSource("wifi"))
  
  -- Initialize playback status (start as stopped)
  device:emit_event(capabilities.mediaPlayback.playbackStatus("stopped"))
  
  -- Set supported playback commands
  device:emit_event(capabilities.mediaPlayback.supportedPlaybackCommands({"play", "pause", "stop"}))
end

function lifecycles.init(driver, device)
  log.info("[" .. device.id .. "] Initializing KEF LSX device")
  device:online()
  
  -- Check if IP address is configured
  local ip = device.preferences.ipAddress
  if ip and ip ~= "" then
    log.info("IP address configured, refreshing status")
    kef_api.refresh_status(device)
    
    -- Set up periodic refresh every 30 seconds
    device.thread:call_on_schedule(30, function()
      kef_api.refresh_status(device)
    end, "refresh_poll")
  else
    log.warn("IP address not configured yet - please set it in device settings")
  end
end

function lifecycles.removed(driver, device)
  log.info("[" .. device.id .. "] Removing KEF LSX device")
end

function lifecycles.doConfigure(driver, device)
  log.info("[" .. device.id .. "] Device refresh triggered")
  kef_api.refresh_status(device)
end

function lifecycles.infoChanged(driver, device, event, args)
  log.info("[" .. device.id .. "] Device info changed")
  
  if args.old_st_store.preferences.ipAddress ~= device.preferences.ipAddress then
    log.info("IP address changed, refreshing status")
    kef_api.refresh_status(device)
  end
  
  if args.old_st_store.preferences.standbyTime ~= device.preferences.standbyTime then
    log.info("Standby time preference changed to: " .. device.preferences.standbyTime)
    kef_api.set_standby_time(device, device.preferences.standbyTime)
  end
end

return lifecycles
