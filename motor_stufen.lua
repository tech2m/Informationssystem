--[[
    ====================================================
    MOTOR-STEUERUNG
    ====================================================
    Waehlt eine Motorstufe von 1 bis 4 ueber den Monitor.
    Die gewaehlte Stufe wird als Redstone-Analogsignal ausgegeben.
    Ohne Aktivierungssignal bleibt die Ausgabe auf 0.
]]--

local config = {
    monitorSide = nil,       -- nil = Advanced Monitor automatisch suchen
    activationSide = "left", -- Redstone-Eingang zum Aktivieren
    outputSide = "right",    -- Redstone-Ausgang fuer Stufe 1 bis 4
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
local selectedLevel = 1
local outputEnabled = false

local palette = {
    colors.cyan,
    colors.lime,
    colors.yellow,
    colors.orange,
}

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

local function isActive()
    return redstone.getInput(config.activationSide)
end

local function setOutput()
    if isActive() and outputEnabled then
        redstone.setAnalogOutput(config.outputSide, selectedLevel)
    else
        redstone.setAnalogOutput(config.outputSide, 0)
    end
end

local function drawLevelButton(level, x0, width, y)
    local selected = level == selectedLevel
    local color = palette[level]
    local background = selected and color or colors.gray
    local foreground = selected and colors.black or colors.white
    fillLine(y, background)
    centerTextInWidth(x0, width, y, "STUFE " .. level, foreground, background)
end

local function drawOffButton(x0, width, y)
    local background = outputEnabled and colors.gray or colors.red
    local foreground = outputEnabled and colors.white or colors.black
    fillLine(y, background)
    centerTextInWidth(x0, width, y, "AUS", foreground, background)
end

local function draw()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    if not isActive() then
        redstone.setAnalogOutput(config.outputSide, 0)
        fillLine(1, colors.gray)
        centerText(1, "Motor Steuerung", colors.white, colors.gray)
        centerText(math.floor(h / 2) - 1, "DISPLAY DEAKTIVIERT", colors.orange, colors.black)
        fillLine(h, colors.gray)
        centerTextInWidth(1, w, h, "STANDBY", colors.white, colors.gray)
        return
    end

    setOutput()
    fillLine(1, colors.blue)
    centerText(1, "Motor Steuerung", colors.white, colors.blue)

    local contentWidth = math.max(16, math.floor(w / 2))
    local startX = math.floor((w - contentWidth) / 2) + 1
    local startY = math.max(4, math.floor(h / 2) - 3)
    for level = 1, 4 do
        drawLevelButton(level, startX, contentWidth, startY + (level - 1) * 2)
    end
    drawOffButton(startX, contentWidth, startY + 8)

    fillLine(h, colors.blue)
    centerTextInWidth(1, w, h, "AKTIV", colors.white, colors.blue)
end

local function refresh()
    while true do
        draw()
        sleep(1)
    end
end

local function handleTouch()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if (not config.monitorSide or side == config.monitorSide) and isActive() then
            local contentWidth = math.max(16, math.floor(w / 2))
            local startX = math.floor((w - contentWidth) / 2) + 1
            local startY = math.max(4, math.floor(h / 2) - 3)
            if x >= startX and x < startX + contentWidth then
                for level = 1, 4 do
                    local buttonY = startY + (level - 1) * 2
                    if y == buttonY or y == buttonY + 1 then
                        selectedLevel = level
                        outputEnabled = true
                        setOutput()
                        draw()
                        break
                    end
                end
                local offY = startY + 8
                if y == offY or y == offY + 1 then
                    outputEnabled = false
                    setOutput()
                    draw()
                end
            end
        end
    end
end

draw()
parallel.waitForAny(refresh, handleTouch)
