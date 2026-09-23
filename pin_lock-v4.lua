--[[
    ====================================================
    PIN-FREIGABE (mit Redstone-Sperre von unten)
    ====================================================
    Gibt nach Eingabe eines korrekten PINs ein Redstone-Signal aus.
    ENTER im freigegebenen Zustand schaltet den Ausgang wieder aus.
    Ein Redstone-Signal von UNTEN sperrt das System automatisch.
]]--

local config = {
    outputSides = { "left", "right", "front", "back", "top", "bottom" },
    outputSignal = 15,        -- Signalstaerke bei korrektem PIN
    pin = "191014",          -- PIN hier aendern
    lockSide = "bottom"      -- Seite für das Redstone-Sperrsignal
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
    -- Signal nur ausgeben, wenn freigeschaltet UND KEIN Sperrsignal von unten anliegt
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

    -- Status 1: Von unten per Redstone gesperrt
    if isLockedByRedstone() then
        centerText(math.floor(h / 2), "SYSTEM GESPERRT", colors.red, colors.black)
        centerText(math.floor(h / 2) + 1, "(Redstone-Sperre aktiv)", colors.orange, colors.black)
        return
    end

    -- Status 2: Freigegeben
    if unlocked then
        centerText(math.floor(h / 2), "FREIGEGEBEN - ENTER zum deaktivieren", colors.lime, colors.black)
        return
    end

    -- Status 3: Warten auf PIN-Eingabe
    centerText(math.floor(h / 2) - 2, "PIN-FREIGABE", colors.lightBlue, colors.black)
    centerText(math.floor(h / 2) + 2, message, messageColor, colors.black)
end

-- Eigene Read-Funktion, die auf Redstone-Events reagiert
local function readPinWithRedstoneCheck()
    local input = ""
    local yPos = math.min(h, math.floor(h / 2) + 4)
    local xPos = math.max(1, math.floor((w - 10) / 2)) -- Zentroide Anzeige der Sternchen
    
    term.setCursorPos(xPos, yPos)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.write("PIN: ")
    
    while true do
        local event, p1 = os.pullEvent()
        
        if event == "redstone" then
            if isLockedByRedstone() then
                return nil -- Bricht die Eingabe ab, falls das Sperrsignal aktiviert wird
            end
        elseif event == "char" then
            if #input < 10 then
                input = input .. p1
                term.write("*")
            end
        elseif event == "key" then
            if p1 == keys.enter then
                return input
            elseif p1 == keys.backspace and #input > 0 then
                input = input:sub(1, -2)
                local x, y = term.getCursorPos()
                term.setCursorPos(x - 1, y)
                term.write(" ")
                term.setCursorPos(x - 1, y)
            end
        end
    end
end

-- Hauptschleife
while true do
    -- Falls Redstone-Sperre aktiv ist, Freigabe entziehen
    if isLockedByRedstone() then
        unlocked = false
    end

    draw()

    if isLockedByRedstone() then
        -- Warten bis sich der Redstone-Zustand an der Unterseite ändert
        os.pullEvent("redstone")
    elseif unlocked then
        -- Warten auf ENTER oder Redstone-Änderung
        local event, key = os.pullEvent()
        if event == "key" and key == keys.enter then
            unlocked = false
            enteredPin = ""
            message = "PIN EINGEBEN"
            messageColor = colors.orange
        elseif event == "redstone" and isLockedByRedstone() then
            unlocked = false
        end
    else
        -- PIN-Eingabe verarbeiten
        local input = readPinWithRedstoneCheck()
        if input ~= nil then
            if input == config.pin then
                unlocked = true
                message = "PIN KORREKT"
                messageColor = colors.lime
            else
                message = "FALSCHER PIN"
                messageColor = colors.red
            end
        end
    end
end