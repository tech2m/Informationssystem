--[[
    ====================================================
    INFOSYSTEM - ZENTRALRECHNER (Server)
    ====================================================
    Empfaengt Sensordaten (Name, Kategorie, Wert, Max, Einheit)
    von einzelnen Client-Computern per rednet.receive()
    (Punkt-zu-Punkt, kein Broadcast) und stellt sie als
    runde Tacho-Gauges (z.B. fuer Create-RPM/Stress) auf
    einem Advanced Monitor dar.
]]--

-- ================= KONFIGURATION =================

local config = {
    modemSide   = "top",   -- Seite des Modems
    monitorSide = nil,      -- z.B. "right" - nil = automatisch suchen
    activationSide = "left", -- Redstone-Signal zum Aktivieren der Anzeige
    protocol    = "rsinfo", -- muss mit client.lua uebereinstimmen
    textScale   = 0.5,      -- Textgroesse auf dem Monitor
    staleAfter  = 15,       -- Sekunden ohne Update -> "Offline"

    -- Gauge-Groesse in Zeichen (Breite x Hoehe der "Kachel")
    gaugeWidth  = 16,
    gaugeHeight = 7,

    -- Ab welchem Fuellstand (0-1) die Warnfarben greifen
    warnAt      = 0.6,   -- gelb ab 60%
    critAt      = 0.85,  -- rot ab 85%
}

-- ================= PERIPHERIE =================

local modem = peripheral.wrap(config.modemSide)
if not modem then error("Kein Modem an Seite '" .. config.modemSide .. "' gefunden!") end
rednet.open(config.modemSide)

local monitor
if config.monitorSide then
    monitor = peripheral.wrap(config.monitorSide)
else
    monitor = peripheral.find("monitor")
end
if not monitor then error("Kein Monitor gefunden! Bitte anschliessen oder 'monitorSide' setzen.") end

monitor.setTextScale(config.textScale)
local w, h = monitor.getSize()

print("Zentralrechner gestartet.")
print("Eigene Computer-ID: " .. os.getComputerID())
print("(Diese ID in den Clients als 'centralID' eintragen)")
print("Protokoll: " .. config.protocol)
print("Monitor: " .. w .. "x" .. h)

-- ================= DATENHALTUNG =================

-- data[name] = { category, value, max, unit, lastUpdate, sender }
local data = {}

local categoryColors = {}
local palette = {
    colors.cyan, colors.orange, colors.lightBlue, colors.pink,
    colors.purple, colors.magenta,
}
local paletteIndex = 0

local function colorFor(category)
    if not categoryColors[category] then
        paletteIndex = paletteIndex + 1
        categoryColors[category] = palette[((paletteIndex - 1) % #palette) + 1]
    end
    return categoryColors[category]
end

-- ================= HILFSFUNKTIONEN =================

local function round(n)
    return math.floor(n + 0.5)
end

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
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(fg or colors.white)
    if #text > width then text = text:sub(1, width) end
    local x = x0 + math.max(0, math.floor((width - #text) / 2))
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function plot(x, y, char, fg, bg)
    if x < 1 or x > w or y < 1 or y > h then return end
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(fg)
    monitor.write(char)
end

local function thresholdColor(fraction, online)
    if not online then return colors.gray end
    if fraction >= config.critAt then return colors.red end
    if fraction >= config.warnAt then return colors.yellow end
    return colors.lime
end

-- ================= GAUGE ZEICHNEN =================
-- Zeichnet einen halbrunden Tacho (Dome-Form, Nadel am unteren Mittelpunkt)
-- x0,y0 = obere linke Ecke der Kachel, width/height = Kachelgroesse
local function drawGauge(x0, y0, width, height, entry, online)
    local name = entry.name or "Unbekannt"
    local value = tonumber(entry.value) or 0
    local max = tonumber(entry.max) or 15
    if max <= 0 then max = 1 end
    local fraction = math.max(0, math.min(1, value / max))
    local barWidth = math.max(8, width - 4)
    local filled = math.floor(barWidth * fraction + 0.5)
    local barColor = thresholdColor(fraction, online)

    centerTextInWidth(x0, width, y0, name, online and colors.white or colors.gray, colors.black)
    centerTextInWidth(x0, width, y0 + 2, "[" .. string.rep("=", filled) .. string.rep(".", barWidth - filled) .. "]", barColor, colors.black)

    local unit = entry.unit or ""
    local valueStr = online and string.format("%.0f", value) .. (unit ~= "" and (" " .. unit) or "") or "offline"
    centerTextInWidth(x0, width, y0 + 4, valueStr, online and colors.white or colors.gray, colors.black)
    centerTextInWidth(x0, width, y0 + 6, online and "ONLINE" or "OFFLINE", barColor, colors.black)
end

-- ================= UI ZEICHNEN =================

local function draw()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    local active = redstone.getInput(config.activationSide)
    if not active then return end

    fillLine(1, colors.blue)
    centerText(1, "MOTOR CONTROL // LIVE", colors.white, colors.blue)
    centerText(2, os.date("%d.%m.%Y  %H:%M:%S"), colors.lightGray, colors.black)

    if active then
        local now = os.epoch("utc")
        local cardWidth = math.max(16, math.floor(w / 2))
        local positions = {
            { "Motor Status", 1, 4 },
            { "Motor Stress", cardWidth + 1, 4 },
            { "Fan Links Speed", 1, 13 },
            { "Fan Rechts Speed", cardWidth + 1, 13 },
        }

        for _, item in ipairs(positions) do
            local name, x0, y0 = item[1], item[2], item[3]
            local entry = data[name] or { name = name, value = 0, max = 100, unit = "" }
            local online = entry.lastUpdate and (now - entry.lastUpdate) / 1000 <= config.staleAfter
            if name == "Motor Status" then
                centerTextInWidth(x0, cardWidth - 1, y0, name, colors.white, colors.black)
                centerTextInWidth(x0, cardWidth - 1, y0 + 2, online and (entry.value and "TRUE" or "FALSE") or "OFFLINE", online and (entry.value and colors.lime or colors.red) or colors.gray, colors.black)
                centerTextInWidth(x0, cardWidth - 1, y0 + 4, online and "DIGITAL STATUS" or "NO SIGNAL", colors.lightGray, colors.black)
            else
                drawGauge(x0, y0, cardWidth - 1, config.gaugeHeight, entry, online)
            end
        end
    end

    fillLine(h, colors.blue)
    centerTextInWidth(1, w, h, active and "ACTIVE  |  REDSTONE ON" or "STANDBY  |  REDSTONE OFF", colors.white, colors.blue)
end

-- ================= EMPFANGEN =================

local function listen()
    while true do
        local senderId, message, protocol = rednet.receive(config.protocol)
        if type(message) == "table" and message.name and message.category then
            data[message.name] = {
                name       = message.name,
                category   = message.category,
                value      = message.value,
                max        = message.max,
                unit       = message.unit,
                lastUpdate = os.epoch("utc"),
                sender     = senderId,
            }
            draw()
        end
    end
end

local function refresh()
    while true do
        sleep(1)
        draw()
    end
end

draw()
parallel.waitForAny(listen, refresh)