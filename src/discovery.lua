local log = require "log"
local discovery = {}

function discovery.handle_discovery(driver, opts, cont)
  log.info("KEF LSX discovery started - creating placeholder device")
  
  -- Generate a unique device network ID using timestamp
  local device_network_id = "KEF-LSX-" .. os.time()
  
  local metadata = {
    type = "LAN",
    device_network_id = device_network_id,
    label = "KEF LSX Speaker",
    profile = "kef-speaker",
    manufacturer = "KEF",
    model = "LSX",
    vendor_provided_label = "KEF LSX"
  }
  
  log.info("Creating KEF device with DNI: " .. device_network_id)
  
  local success, msg_or_device = pcall(driver.try_create_device, driver, metadata)
  if success then
    log.info("KEF LSX device created successfully - configure IP address in device settings")
  else
    log.error("Failed to create KEF device: " .. tostring(msg_or_device))
  end
end

return discovery
