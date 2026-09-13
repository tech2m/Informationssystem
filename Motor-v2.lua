--[[
    ====================================================
    MOTOR-STEUERUNG
    ====================================================
    Waehlt eine Motorstufe von 1 bis 4 ueber den Computerbildschirm.
    Die gewaehlte Stufe wird als Redstone-Analogsignal ausgegeben.
    Ohne Aktivierungssignal bleibt die Ausgabe auf 0.
]]--

local config = {
    activationSide = "left", -- Redstone-Eingang zum Aktivieren
    outputSide = "right",    -- Redstone-Ausgang fuer Stufe 1 bis 4
}

local w, h = term.getSize()
local selectedLevel = 1
local outputEnabled = false

local palette = {
    colors.cyan,
    colors.lime,
    colors.yellow,
    colors.orange,
}

local function fillLine(y, bg)
    term.setBackgroundColor(bg)
    term.setCursorPos(1, y)
    term.write(string.rep(" ", w))
end

local function centerText(y, text, fg, bg)
    text = tostring(text or "")
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    local x = math.max(1, math.floor((w - #text) / 2) + 1)
    term.setCursorPos(x, y)
    term.write(text)
end

local function centerTextInWidth(x0, width, y, text, fg, bg)
    text = tostring(text or "")
    if #text > width then text = text:sub(1, width) end
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    local x = x0 + math.max(0, math.floor((width - #text) / 2))
    term.setCursorPos(x, y)
    term.write(text)
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
    term.setBackgroundColor(colors.black)
    term.clear()

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

local function handleKey()
    while true do
        local _, key = os.pullEvent("key")
        if isActive() then
            if key == keys.one then
                selectedLevel = 1
                outputEnabled = true
            elseif key == keys.two then
                selectedLevel = 2
                outputEnabled = true
            elseif key == keys.three then
                selectedLevel = 3
                outputEnabled = true
            elseif key == keys.four then
                selectedLevel = 4
                outputEnabled = true
            elseif key == keys.zero then
                outputEnabled = false
            end
            setOutput()
            draw()
        end
    end
end

draw()
parallel.waitForAny(refresh, handleKey)
