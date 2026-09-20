--[[
    ====================================================
    INFOSYSTEM - ZENTRALRECHNER (Create: Avionics)
    ====================================================
    Liest Create: Avionics-Peripherals direkt ueber ihre IDs
    aus dem Wired-Modem-Netzwerk und zeigt die Werte auf dem
    Monitor an. Die IDs stehen in config.sensors.
]]--

-- ================= KONFIGURATION =================

local config = {
    monitorSide = nil,      -- z.B. "right" - nil = automatisch suchen
    activationSide = "right", -- Redstone-Signal zum Aktivieren der Anzeige
    textScale   = 0.5,      -- Textgroesse auf dem Monitor
    staleAfter  = 3,        -- Sekunden ohne erfolgreiches Lesen -> "Offline"
    refreshInterval = 0.5,

    -- IDs mit `peripheral.getNames()` im Terminal pruefen.
    -- Die Namen sind die Netzwerk-IDs des Wired-Modems, nicht Computer-IDs.
    sensors = {
        {
            name = "Motor Status",
            category = "STATUS",
            id = "Create_Speedometer_0",
            unit = "RPM",
            max = 256,
            read = function(peripheralObject)
                local speed = tonumber(peripheralObject.getSpeed()) or 0
                return math.abs(speed) > 0, 1
            end,
        },
        {
            name = "Motor Stress",
            category = "GAUGE",
            id = "Create_Stressometer_1",
            unit = "SU",
            read = function(peripheralObject)
                local stress = tonumber(peripheralObject.getStress()) or 0
                local capacity = tonumber(peripheralObject.getStressCapacity()) or 1
                return stress, math.max(1, capacity)
            end,
        },
        {
            name = "Fan Links Speed",
            category = "GAUGE",
            id = "Create_Speedometer_1",
            unit = "RPM",
            max = 256,
            read = function(peripheralObject)
                return math.abs(tonumber(peripheralObject.getSpeed()) or 0)
            end,
        },
        {
            name = "Fan Rechts Speed",
            category = "GAUGE",
            id = "Create_Speedometer_2",
            unit = "RPM",
            max = 256,
            read = function(peripheralObject)
                return math.abs(tonumber(peripheralObject.getSpeed()) or 0)
            end,
        },
    },

    -- Gauge-Groesse in Zeichen (Breite x Hoehe der "Kachel")
    gaugeWidth  = 16,
    gaugeHeight = 7,

    -- Ab welchem Fuellstand (0-1) die Warnfarben greifen
    warnAt      = 0.6,   -- gelb ab 60%
    critAt      = 0.85,  -- rot ab 85%
}

-- ================= PERIPHERIE =================

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
print("Monitor: " .. w .. "x" .. h)
print("Verfuegbare Peripherals im Netzwerk:")
for _, id in ipairs(peripheral.getNames()) do
    print("  " .. id .. " (" .. tostring(peripheral.getType(id)) .. ")")
end

-- ================= DATENHALTUNG =================

-- data[name] = { category, value, max, unit, lastUpdate, id, error }
local data = {}
local sensorPeripherals = {}

for _, sensor in ipairs(config.sensors) do
    sensorPeripherals[sensor.name] = peripheral.wrap(sensor.id)
    if not sensorPeripherals[sensor.name] then
        print("WARNUNG: Sensor-ID nicht gefunden: " .. sensor.id)
    end
end

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
    local accentColor = colorFor(name)

    centerTextInWidth(x0, width, y0, name, online and accentColor or colors.gray, colors.black)
    centerTextInWidth(x0, width, y0 + 2, "[" .. string.rep("=", filled) .. string.rep(".", barWidth - filled) .. "]", barColor, colors.black)

    local unit = entry.unit or ""
    local valueStr
    if online then
        valueStr = string.format("%.0f", value) .. (unit ~= "" and (" " .. unit) or "")
    else
        valueStr = "--"
    end
    centerTextInWidth(x0, width, y0 + 4, valueStr, online and colors.white or colors.gray, colors.black)
end

-- ================= SENSORWERTE LESEN =================

local function readSensors()
    local now = os.epoch("utc")
    for _, sensor in ipairs(config.sensors) do
        local peripheralObject = sensorPeripherals[sensor.name]
        local entry = data[sensor.name] or {
            name = sensor.name,
            category = sensor.category,
            unit = sensor.unit,
            max = sensor.max or 1,
        }

        if peripheralObject then
            local ok, value, max = pcall(sensor.read, peripheralObject)
            if ok and value ~= nil then
                entry.value = value
                entry.max = tonumber(max) or sensor.max or entry.max
                entry.lastUpdate = now
                entry.error = nil
            else
                entry.error = "Lesefehler"
            end
        else
            entry.error = "Nicht gefunden"
        end

        data[sensor.name] = entry
    end
end
-- ================= UI ZEICHNEN =================

local function draw()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    local active = redstone.getInput(config.activationSide)
    if not active then
        fillLine(1, colors.gray)
        centerText(1, "Unsinkbar 4", colors.white, colors.gray)
        centerText(math.floor(h / 2) - 1, "DISPLAY DEAKTIVIERT", colors.orange, colors.black)
        return
    end

    fillLine(1, colors.blue)
    centerText(1, "Unsinkbar 4", colors.white, colors.blue)

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
            local motorRunning = entry.value == true or (type(entry.value) == "number" and math.abs(entry.value) > 0)
            local statusColor = online and (motorRunning and colors.lime or colors.red) or colors.gray
            local statusText = online and (motorRunning and "LAEUFT" or "STOPP") or "WARTET"
            centerTextInWidth(x0, cardWidth - 1, y0, name, colors.orange, colors.black)
            centerTextInWidth(x0, cardWidth - 1, y0 + 2, statusText, statusColor, colors.black)
        else
            drawGauge(x0, y0, cardWidth - 1, config.gaugeHeight, entry, online)
        end
    end
end

local function refresh()
    while true do
        readSensors()
        draw()
        sleep(config.refreshInterval)
    end
end

draw()
parallel.waitForAny(refresh)
