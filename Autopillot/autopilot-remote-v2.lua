--[[
    FERNBEDIENUNG FUER DEN CREATE-AERONAUTICS-AUTOPILOTEN
    Laeuft auf einem Computer mit Bildschirm/Terminal und Wireless-Modem.
]]

local CONFIG = {
    modemSide = "top",
    activationSide = "bottom",
    serverId = 0, -- ID des Computers, auf dem autopilot-v1.lua laeuft
    protocol = "autopilot_control",
    step = 10,
    target = { x = 0, y = 100, z = 0 },
}

local buttons = {}
local status = "Bereit"
local width, height

local function clearButtons()
    buttons = {}
end

local function addButton(x1, y1, x2, y2, action, value)
    buttons[#buttons + 1] = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, action = action, value = value }
end

local function fillLine(y, background)
    term.setBackgroundColor(background)
    term.setCursorPos(1, y)
    term.clearLine()
end

local function centerText(y, text, foreground, background)
    text = tostring(text or "")
    term.setBackgroundColor(background or colors.black)
    term.setTextColor(foreground or colors.white)
    term.setCursorPos(math.max(1, math.floor((width - #text) / 2) + 1), y)
    term.write(text:sub(1, width))
end

local function drawButton(x, y, buttonWidth, label, background, foreground, action, value)
    term.setBackgroundColor(background)
    term.setTextColor(foreground)
    term.setCursorPos(x, y)
    term.write(string.rep(" ", buttonWidth))
    term.setCursorPos(x + math.max(0, math.floor((buttonWidth - #label) / 2)), y)
    term.write(label:sub(1, buttonWidth))
    addButton(x, y, x + buttonWidth - 1, y, action, value)
end

local function drawAxis(row, name, value)
    local buttonWidth = math.max(8, math.floor((width - 12) / 4))
    local x = 2
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(x, row)
    term.write(name .. ":")
    x = 9
    drawButton(x, row, buttonWidth, "-" .. CONFIG.step, colors.gray, colors.white, "change", {axis = name, delta = -CONFIG.step})
    x = x + buttonWidth + 1
    drawButton(x, row, buttonWidth, string.format("%d", value), colors.blue, colors.white, "edit", name)
    x = x + buttonWidth + 1
    drawButton(x, row, buttonWidth, "+" .. CONFIG.step, colors.gray, colors.white, "change", {axis = name, delta = CONFIG.step})
    x = x + buttonWidth + 1
    drawButton(x, row, buttonWidth, "EINGABE", colors.orange, colors.black, "edit", name)
end

local function isActive()
    return redstone.getInput(CONFIG.activationSide)
end

local function draw()
    width, height = term.getSize()
    clearButtons()
    term.setBackgroundColor(colors.black)
    term.clear()

    fillLine(1, colors.blue)
    centerText(1, "AUTOPILOT FERNBEDIENUNG", colors.white, colors.blue)

    if not isActive() then
        clearButtons()
        centerText(math.floor(height / 2) - 1, "DISPLAY DEAKTIVIERT", colors.orange, colors.black)
        fillLine(height, colors.gray)
        centerText(height, "STANDBY", colors.white, colors.gray)
        return
    end

    centerText(2, status, colors.lightGray, colors.black)

    term.setTextColor(colors.yellow)
    term.setCursorPos(2, 4)
    term.write("ZIELPOSITION")
    drawAxis(6, "X", CONFIG.target.x)
    drawAxis(8, "Y", CONFIG.target.y)
    drawAxis(10, "Z", CONFIG.target.z)

    local actionY = math.min(height - 3, 13)
    drawButton(2, actionY, math.max(12, math.floor(width / 2) - 3), "ZIEL UEBERNEHMEN", colors.lime, colors.black, "send")
    drawButton(math.floor(width / 2) + 1, actionY, math.max(12, math.floor(width / 2) - 2), "NOT-AUS", colors.red, colors.white, "stop")
    local controlY = math.min(height - 2, 15)
    drawButton(2, controlY, math.max(12, math.floor(width / 2) - 3), "AUTOPILOT START", colors.green, colors.black, "start")
    drawButton(math.floor(width / 2) + 1, controlY, math.max(12, math.floor(width / 2) - 2), "AUS", colors.gray, colors.white, "stop")

    fillLine(height, colors.blue)
    centerText(height, "AUTOPILOT SERVER #" .. CONFIG.serverId, colors.white, colors.blue)
end

local function setAxis(axis, value)
    value = tonumber(value)
    if not value then
        status = "Ungueltige Eingabe fuer " .. axis
        return
    end
    CONFIG.target[axis:lower()] = math.floor(value + 0.5)
end

local function editAxis(axis)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(2, height - 1)
    term.clearLine()
    term.write(axis .. " eingeben: ")
    setAxis(axis, read())
end

local function send(message)
    rednet.send(CONFIG.serverId, message, CONFIG.protocol)
end

local function handleButton(button)
    if button.action == "change" then
        local axis = button.value.axis:lower()
        CONFIG.target[axis] = CONFIG.target[axis] + button.value.delta
        status = "Wert geaendert"
    elseif button.action == "edit" then
        editAxis(button.value)
        status = "Wert geaendert"
    elseif button.action == "send" then
        send({ action = "set_target", x = CONFIG.target.x, y = CONFIG.target.y, z = CONFIG.target.z })
        status = "Ziel an Server gesendet"
    elseif button.action == "stop" then
        send({ action = "stop" })
        status = "NOT-AUS gesendet"
    elseif button.action == "start" then
        send({ action = "start" })
        status = "Autopilot gestartet"
    end
end

local modem = peripheral.wrap(CONFIG.modemSide)
if not modem then error("Kein Modem an Seite '" .. CONFIG.modemSide .. "' gefunden!") end
rednet.open(CONFIG.modemSide)

while true do
    draw()
    local event, _, x, y = os.pullEvent()
    if event == "mouse_click" or event == "monitor_touch" then
        if isActive() then
            for _, button in ipairs(buttons) do
                if x >= button.x1 and x <= button.x2 and y >= button.y1 and y <= button.y2 then
                    handleButton(button)
                    break
                end
            end
        end
    elseif event == "key" and x == keys.q then
        break
    end
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)