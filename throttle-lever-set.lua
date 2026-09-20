local throttleLever = peripheral.wrap("throttle_lever_2")
local throttleLever = peripheral.wrap("throttle_lever_1")

while true do
    for position = 0, 15 do
        throttleLever.setSignal(position)
        throttleLever2.setSignal(position)
        print("Throttle Lever: " .. position)
        sleep(0.01)
    end
end
