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

    if unlocked then
        centerText(math.floor(h / 2), "FREIGEGEBEN - ENTER zum deaktivieren", colors.lime, colors.black)
        return
    end

    centerText(math.floor(h / 2) - 2, "PIN-FREIGABE", colors.lightBlue, colors.black)
    centerText(math.floor(h / 2) + 2, message, messageColor, colors.black)
end

-- Task 1: Die urspruengliche Hauptlogik & UI
local function mainLoop()
    while true do
        draw()

        if unlocked then
            while true do
                local event, key = os.pullEvent("key")
                if key == keys.enter then
                    unlocked = false
                    enteredPin = ""
                    message = "PIN EINGEBEN"
                    messageColor = colors.orange
                    break
                end
            end
        else
            term.setCursorPos(1, math.min(h, math.floor(h / 2) + 4))
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.black)
            local input = read("*")
            
            -- Falls waehrend der Eingabe von unten gesperrt wurde:
            if isLockedByRedstone() then
                unlocked = false
            elseif input == config.pin then
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
end

-- Task 2: Hintergrund-Ueberwachung der Redstone-Sperre
local function redstoneMonitor()
    while true do
        if isLockedByRedstone() and unlocked then
            unlocked = false
            -- Sendet ein kuenstliches Event, um blockierende read()- oder pullEvent()-Aufrufe sofort abzubrechen
            os.queueEvent("redstone_lock")
        end
        os.pullEvent("redstone")
    end
end

-- Beide Prozesse parallel ausfuehren
parallel.waitForAny(mainLoop, redstoneMonitor)