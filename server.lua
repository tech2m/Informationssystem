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
    monitor.setBackgroundColor(bg or colors.black)
    monitor.setTextColor(fg or colors.white)
    local x = math.max(1, math.floor((w - #text) / 2) + 1)
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function centerTextInWidth(x0, width, y, text, fg, bg)
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
    local name  = entry.name
    local value = entry.value or 0
    local max   = entry.max or 15
    if max <= 0 then max = 1 end
    local fraction = value / max
    if fraction < 0 then fraction = 0 end
    if fraction > 1 then fraction = 1 end

    -- Geometrie: X-Radius groesser als Y-Radius, da Zeichen hoeher als breit sind
    local radiusX = math.floor(width / 2) - 1
    local radiusY = math.max(2, math.floor(height / 2) - 1)
    local cx = x0 + math.floor(width / 2)
    local cy = y0 + radiusY + 1  -- Drehpunkt/Basis der Nadel

    -- Name ueber dem Gauge
    centerTextInWidth(x0, width, y0, name, online and colors.white or colors.gray, colors.black)

    -- Bogen von 180 Grad (links) ueber 270 Grad (oben) bis 360 Grad (rechts)
    local steps = 24
    for i = 0, steps do
        local angle = 180 + (180 * i / steps)
        local rad = math.rad(angle)
        local px = cx + round(math.cos(rad) * radiusX)
        local py = cy + round(math.sin(rad) * radiusY)
        local pointFraction = i / steps
        local lit = pointFraction <= fraction
        local col = lit and thresholdColor(pointFraction, online) or colors.gray
        plot(px, py, "\007", col, colors.black)
    end

    -- Nadel vom Mittelpunkt zum aktuellen Wert
    local needleAngle = math.rad(180 + 180 * fraction)
    local needleSteps = math.max(radiusX, radiusY)
    for i = 1, needleSteps do
        local t = i / needleSteps
        local px = cx + round(math.cos(needleAngle) * radiusX * t)
        local py = cy + round(math.sin(needleAngle) * radiusY * t)
        plot(px, py, "\007", online and colors.white or colors.gray, colors.black)
    end

    -- Drehpunkt
    plot(cx, cy, "\007", online and colors.lightGray or colors.gray, colors.black)

    -- Wert unter dem Gauge
    local unit = entry.unit or ""
    local valueStr
    if online then
        valueStr = string.format("%.0f", value) .. (unit ~= "" and (" " .. unit) or "")
    else
        valueStr = "offline"
    end
    centerTextInWidth(x0, width, y0 + height - 1, valueStr, thresholdColor(fraction, online), colors.black)
end

-- ================= UI ZEICHNEN =================

local function draw()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    -- Kopfzeile
    fillLine(1, colors.gray)
    centerText(1, "CREATE - INFORMATIONSSYSTEM", colors.white, colors.gray)
    fillLine(2, colors.black)
    centerText(2, os.date("%d.%m.%Y  %H:%M:%S"), colors.lightGray, colors.black)

    -- Nach Kategorie gruppieren
    local categories = {}
    local total = 0
    for name, d in pairs(data) do
        categories[d.category] = categories[d.category] or {}
        table.insert(categories[d.category], { name = name, d = d })
        total = total + 1
    end

    local sortedCats = {}
    for cat in pairs(categories) do table.insert(sortedCats, cat) end
    table.sort(sortedCats)

    if total == 0 then
        centerText(math.floor(h / 2), "Warte auf Daten von Sensoren...", colors.gray, colors.black)
    end

    local now = os.epoch("utc")
    local y = 4
    local perRow = math.max(1, math.floor(w / config.gaugeWidth))

    for _, cat in ipairs(sortedCats) do
        if y > h - 1 then break end

        local cc = colorFor(cat)
        monitor.setBackgroundColor(cc)
        monitor.setCursorPos(1, y)
        monitor.write(string.rep(" ", w))
        monitor.setTextColor(colors.black)
        monitor.setCursorPos(2, y)
        monitor.write(cat)
        y = y + 1

        local entries = categories[cat]
        table.sort(entries, function(a, b) return a.name < b.name end)

        local col = 0
        for _, entry in ipairs(entries) do
            if y + config.gaugeHeight - 1 > h then break end

            local x0 = col * config.gaugeWidth + 1
            local d = entry.d
            local ageSec = (now - d.lastUpdate) / 1000
            local online = ageSec <= config.staleAfter

            drawGauge(x0, y, config.gaugeWidth, config.gaugeHeight, d, online)

            col = col + 1
            if col >= perRow then
                col = 0
                y = y + config.gaugeHeight
            end
        end

        if col ~= 0 then
            y = y + config.gaugeHeight
        end
        y = y + 1
    end

    -- Fusszeile
    fillLine(h, colors.gray)
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(2, h)
    monitor.write("Geraete: " .. total)
    local idStr = "ID: " .. os.getComputerID()
    monitor.setCursorPos(w - #idStr - 1, h)
    monitor.write(idStr)
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