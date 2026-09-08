--[[
    ====================================================
    PIN-FREIGABE
    ====================================================
    Gibt nach Eingabe eines korrekten PINs ein Redstone-Signal aus.
    ENTER bestaetigt den PIN und schaltet frei.
    ENTER im freigegebenen Zustand schaltet den Ausgang wieder aus.
]]--

local config = {
    outputSide = "back",     -- Redstone-Ausgang
    outputSignal = 15,        -- Signalstaerke bei korrektem PIN
    pin = "191014",          -- PIN hier aendern
}

local w, h = term.getSize()
local enteredPin = ""
local unlocked = false
local message = "PIN EINGEBEN"
local messageColor = colors.lightBlue

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

local function setOutput()
    if unlocked then
        redstone.setAnalogOutput(config.outputSide, config.outputSignal)
    else
        redstone.setAnalogOutput(config.outputSide, 0)
    end
end

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()
    setOutput()

    fillLine(1, unlocked and colors.lime or colors.blue)
    centerText(1, "Status Dashboard", unlocked and colors.black or colors.white, unlocked and colors.lime or colors.blue)
    centerText(2, unlocked and "MOTOR FREIGEGEBEN" or "PIN-FREIGABE", colors.lightGray, colors.black)

    local pinDisplay = unlocked and "SIGNAL AKTIV" or "PIN: " .. string.rep("*", #enteredPin)
    centerText(math.max(4, math.floor(h / 2) - 5), pinDisplay, unlocked and colors.lime or colors.white, colors.black)
    centerText(math.max(5, math.floor(h / 2) - 3), message, messageColor, colors.black)
    fillLine(h, unlocked and colors.lime or colors.blue)
    centerText(h, unlocked and "AKTIV  |  ENTER ZUM BEENDEN" or "BEREIT  |  PIN EINGEBEN", colors.black, unlocked and colors.lime or colors.blue)
end

while true do
    draw()
    term.setCursorPos(1, math.min(h - 2, math.floor(h / 2) + 2))
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)

    if unlocked then
        read()
        unlocked = false
        enteredPin = ""
        message = "FREIGABE BEENDET"
        messageColor = colors.orange
    else
        local input = read("*")
        if input == config.pin then
            unlocked = true
            message = "PIN KORREKT"
            messageColor = colors.lime
        else
            message = "FALSCHER PIN"
            messageColor = colors.red
        end
        enteredPin = ""
    end
end
