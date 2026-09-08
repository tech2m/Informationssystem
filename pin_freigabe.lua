--[[
    ====================================================
    PIN-FREIGABE
    ====================================================
    Gibt nach Eingabe eines korrekten PINs ein Redstone-Signal aus.
    ENTER bestaetigt den PIN und schaltet frei.
    ENTER im freigegebenen Zustand schaltet den Ausgang wieder aus.
]]--

local config = {
    monitorSide = nil,        -- nil = Advanced Monitor automatisch suchen
    outputSide = "back",     -- Redstone-Ausgang
    outputSignal = 15,        -- Signalstaerke bei korrektem PIN
    pin = "191014",             -- PIN hier aendern
    textScale = 0.5,
}

local monitor
if config.monitorSide then
    monitor = peripheral.wrap(config.monitorSide)
else
    monitor = peripheral.find("monitor")
end
if not monitor then error("Kein Monitor gefunden!") end

monitor.setTextScale(config.textScale)
local w, h = monitor.getSize()
local enteredPin = ""
local unlocked = false
local message = "PIN EINGEBEN"
local messageColor = colors.lightBlue

local function fillLine(y, bg)
    monitor.setBackgroundColor(bg)
    monitor.setCursorPos(1, y)
    monitor.write(string.rep(" ", w))
end

local function centerText(y, text, fg, bg)
    text = tostring(text or "")
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(fg or colors.white)
    local x = math.max(1, math.floor((w - #text) / 2) + 1)
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function centerTextInWidth(x0, width, y, text, fg, bg)
    text = tostring(text or "")
    if #text > width then text = text:sub(1, width) end
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(fg or colors.white)
    local x = x0 + math.max(0, math.floor((width - #text) / 2))
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function setOutput()
    if unlocked then
        redstone.setAnalogOutput(config.outputSide, config.outputSignal)
    else
        redstone.setAnalogOutput(config.outputSide, 0)
    end
end

local function buttonLayout()
    local buttonWidth = math.max(8, math.floor(w / 3) - 2)
    local gap = 1
    local totalWidth = buttonWidth * 3 + gap * 2
    local startX = math.max(1, math.floor((w - totalWidth) / 2) + 1)
    local startY = math.max(6, math.floor(h / 2) - 3)
    return buttonWidth, gap, startX, startY
end

local function drawButton(label, x, y, width, background, foreground)
    monitor.setBackgroundColor(background)
    monitor.setTextColor(foreground)
    monitor.setCursorPos(x, y)
    monitor.write(string.rep(" ", width))
    centerTextInWidth(x, width, y, label, foreground, background)
end

local function draw()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    setOutput()

    fillLine(1, unlocked and colors.lime or colors.blue)
    centerText(1, "Status Dashboard", unlocked and colors.black or colors.white, unlocked and colors.lime or colors.blue)
    centerText(2, unlocked and "MOTOR FREIGEGEBEN" or "PIN-FREIGABE", colors.lightGray, colors.black)

    local pinDisplay = unlocked and "SIGNAL AKTIV" or string.rep("*", #enteredPin)
    centerText(math.max(4, math.floor(h / 2) - 5), pinDisplay, unlocked and colors.lime or colors.white, colors.black)
    centerText(math.max(5, math.floor(h / 2) - 3), message, messageColor, colors.black)

    local buttonWidth, gap, startX, startY = buttonLayout()
    local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "ENTER" }
    for index, key in ipairs(keys) do
        local row = math.floor((index - 1) / 3)
        local column = (index - 1) % 3
        local x = startX + column * (buttonWidth + gap)
        local y = startY + row * 2
        local background = key == "ENTER" and colors.lime or (key == "C" and colors.orange or colors.gray)
        local foreground = (key == "ENTER" or key == "C") and colors.black or colors.white
        if key == "ENTER" and unlocked then background = colors.red end
        drawButton(key, x, y, buttonWidth, background, foreground)
    end

    fillLine(h, unlocked and colors.lime or colors.blue)
    centerTextInWidth(1, w, h, unlocked and "AKTIV" or "BEREIT", colors.black, unlocked and colors.lime or colors.blue)
end

local function handleKey(key)
    if key == "C" then
        if unlocked then
            unlocked = false
            enteredPin = ""
            message = "FREIGABE BEENDET"
            messageColor = colors.orange
        else
            enteredPin = ""
            message = "PIN EINGEBEN"
            messageColor = colors.lightBlue
        end
    elseif key == "ENTER" then
        if unlocked then
            unlocked = false
            enteredPin = ""
            message = "FREIGABE BEENDET"
            messageColor = colors.orange
        elseif enteredPin == config.pin then
            unlocked = true
            enteredPin = ""
            message = "PIN KORREKT"
            messageColor = colors.lime
        else
            enteredPin = ""
            message = "FALSCHER PIN"
            messageColor = colors.red
        end
    elseif not unlocked and #enteredPin < 12 then
        enteredPin = enteredPin .. key
        message = "PIN EINGEBEN"
        messageColor = colors.lightBlue
    end
    setOutput()
    draw()
end

local function handleTouch()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if not config.monitorSide or side == config.monitorSide then
            local buttonWidth, gap, startX, startY = buttonLayout()
            for index, key in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "ENTER" }) do
                local row = math.floor((index - 1) / 3)
                local column = (index - 1) % 3
                local buttonX = startX + column * (buttonWidth + gap)
                local buttonY = startY + row * 2
                if x >= buttonX and x < buttonX + buttonWidth and (y == buttonY or y == buttonY + 1) then
                    handleKey(key)
                    break
                end
            end
        end
    end
end

draw()
handleTouch()
