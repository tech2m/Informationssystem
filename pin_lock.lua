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

    if unlocked then
        centerText(math.floor(h / 2), "FREIGEGEBEN - ENTER zum deaktivieren", colors.lime, colors.black)
        return
    end

    centerText(math.floor(h / 2) - 2, "PIN-FREIGABE", colors.lightBlue, colors.black)
    centerText(math.floor(h / 2), "PIN: " .. string.rep("*", #enteredPin), colors.white, colors.black)
    centerText(math.floor(h / 2) + 2, message, messageColor, colors.black)
end

while true do
    draw()

    if unlocked then
        while true do
            local event, key = os.pullEvent("key")
            if key == keys.enter then
                unlocked = false
                enteredPin = ""
                message = "FREIGABE BEENDET"
                messageColor = colors.orange
                break
            end
        end
    else
        term.setCursorPos(1, math.min(h, math.floor(h / 2) + 4))
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
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
