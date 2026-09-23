--[[
    ====================================================
    PIN-FREIGABE
    ====================================================
    Gibt nach Eingabe eines korrekten PINs ein Redstone-Signal aus.
    ENTER bestaetigt den PIN und schaltet frei.
    ENTER im freigegebenen Zustand schaltet den Ausgang wieder aus.
]]--

local config = {
    outputSides = { "left", "right", "front", "back", "top", "bottom" },
    outputSignal = 15,        -- Signalstaerke bei korrektem PIN
    pin = "191014",          -- PIN hier aendern
    lockSide = "bottom"      -- Seite fuer das Redstone-Sperrsignal
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

local function fillLine(y, bg)
    term.setBackgroundColor(bg)
    term.setCursorPos(1, y)
    term.write(string.rep(" ", w))
end

local function isLockedByRedstone()
    return redstone.getInput(config.lockSide)
end

local function setOutput()
    local signal = (unlocked and not isLockedByRedstone()) and config.outputSignal or 0
    for _, side in ipairs(config.outputSides) do
        redstone.setAnalogOutput(side, signal)
    end
end

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()
    setOutput()

    fillLine(1, colors.gray)
    centerText(1, "Schiff Tommy", colors.white, colors.gray)

    if unlocked and not isLockedByRedstone() then
        centerText(math.floor(h / 2), "FREIGEGEBEN - ENTER zum deaktivieren", colors.lime, colors.black)
        return
    end

    centerText(math.floor(h / 2) - 2, "PIN-FREIGABE", colors.lightBlue, colors.black)
    centerText(math.floor(h / 2) + 2, message, messageColor, colors.black)

    -- Stellt den Cursor exakt an die Stelle der originalen read()-Eingabe
    local inputY = math.min(h, math.floor(h / 2) + 4)
    term.setCursorPos(1, inputY)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.write(string.rep("*", #enteredPin))
end

-- Hauptschleife
while true do
    if isLockedByRedstone() then
        unlocked = false
    end

    draw()

    local event, p1 = os.pullEvent()

    if event == "redstone" then
        if isLockedByRedstone() then
            unlocked = false
            enteredPin = ""
        end
    elseif event == "char" and not unlocked and not isLockedByRedstone() then
        enteredPin = enteredPin .. p1
    elseif event == "key" then
        if p1 == keys.enter then
            if unlocked then
                unlocked = false
                enteredPin = ""
                message = "PIN EINGEBEN"
                messageColor = colors.orange
            elseif not isLockedByRedstone() then
                if enteredPin == config.pin then
                    unlocked = true
                    message = "PIN KORREKT"
                    messageColor = colors.lime
                else
                    message = "FALSCHER PIN"
                    messageColor = colors.red
                end
                enteredPin = ""
            end
        elseif p1 == keys.backspace and #enteredPin > 0 and not unlocked then
            enteredPin = enteredPin:sub(1, -2)
        end
    end
end