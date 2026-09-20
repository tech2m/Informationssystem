-- Bewegt einen Create: Avionics Throttle Lever dauerhaft von 0 bis 15.

local CONFIG = {
    peripheralId = "throttle_lever_2",
    interval = 0.2,
}

local throttleLever = peripheral.wrap(CONFIG.peripheralId)
if not throttleLever then
    error("Throttle Lever nicht gefunden: " .. CONFIG.peripheralId)
end

while true do
    for position = 0, 15 do
        throttleLever.setSignal(position)
        print("Throttle Lever: " .. position)
        sleep(CONFIG.interval)
    end
end
