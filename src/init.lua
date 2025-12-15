local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

local discovery = require "discovery"
local command_handlers = require "command_handlers"
local lifecycles = require "lifecycles"

local kef_driver = Driver("kef-lsx", {
  discovery = discovery.handle_discovery,
  lifecycle_handlers = lifecycles,
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = command_handlers.handle_switch_on,
      [capabilities.switch.commands.off.NAME] = command_handlers.handle_switch_off,
    },
    [capabilities.audioVolume.ID] = {
      [capabilities.audioVolume.commands.setVolume.NAME] = command_handlers.handle_set_volume,
      [capabilities.audioVolume.commands.volumeUp.NAME] = command_handlers.handle_volume_up,
      [capabilities.audioVolume.commands.volumeDown.NAME] = command_handlers.handle_volume_down,
    },
    [capabilities.mediaInputSource.ID] = {
      [capabilities.mediaInputSource.commands.setInputSource.NAME] = command_handlers.handle_set_input_source,
    },
    [capabilities.mediaPlayback.ID] = {
      [capabilities.mediaPlayback.commands.play.NAME] = command_handlers.handle_play,
      [capabilities.mediaPlayback.commands.pause.NAME] = command_handlers.handle_pause,
      [capabilities.mediaPlayback.commands.stop.NAME] = command_handlers.handle_stop,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = command_handlers.handle_refresh,
    },
  }
})

kef_driver:run()
