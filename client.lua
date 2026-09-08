--[[
    ====================================================
    INFOSYSTEM - CLIENT (Sender)
    ====================================================
    Liest an einem oder mehreren Redstone-Eingängen die
    analoge Signalstärke (0-15) aus und sendet sie per
    rednet.send() DIREKT (kein rednet.broadcast!) an den
    Zentralrechner.

    Jeder Sensor hat einen Namen, eine Kategorie und einen
    "max"-Wert: die reale Skala, die der Redstone-Wert 0-15
    darstellen soll (z.B. eine Create-Stress-Anzeige, die
    per Redstone-Link/Schwellenwertschalter auf 0-15 gemappt
    wurde, aber eigentlich bis 4096 SU geht).

    Benötigt: Ender-/Wireless-/Kabel-Modem am Computer.
]]--

-- ================= KONFIGURATION =================

local config = {
    -- Seite, an der das Modem hängt
    modemSide = "back",

    -- ID des Zentralrechners (im Zentral-Programm wird die
    -- eigene ID beim Start ausgegeben -> hier eintragen!)
    centralID = 0,

    -- Rednet-Protokoll (muss mit server.lua übereinstimmen)
    protocol = "rsinfo",

    -- Sendeintervall in Sekunden
    interval = 2,

    -- Ein Computer kann mehrere Sensoren melden.
    -- side  = Redstone-Seite, an der der Analog-Wert anliegt
    -- name  = Anzeigename auf dem Gauge
    -- category = Gruppierung auf dem Zentralrechner
    -- max   = realer Maximalwert, den "15" darstellen soll
    -- unit  = Einheit fürs Label (z.B. "RPM", "SU")
    sensors = {
        { side = "top", name = "Antrieb 1", category = "RPM", max = 256, unit = "RPM" },
        -- weitere Sensoren einfach hinzufügen:
        -- { side = "bottom", name = "Muehle Stress", category = "Stress", max = 4096, unit = "SU" },
        -- { side = "left",   name = "Presse",        category = "RPM",    max = 128,  unit = "RPM" },
    },
}

-- ================= INITIALISIERUNG =================

if not peripheral.isPresent(config.modemSide) then
    error("Kein Modem an Seite '" .. config.modemSide .. "' gefunden!")
end

rednet.open(config.modemSide)
print("Modem geoeffnet auf: " .. config.modemSide)
print("Eigene Computer-ID: " .. os.getComputerID())

if config.centralID == 0 then
    print("")
    print("!!! ACHTUNG: 'centralID' in der Konfiguration ist")
    print("    noch nicht gesetzt. Bitte die ID des")
    print("    Zentralrechners eintragen. !!!")
end

print("")
print("Sende Daten fuer " .. #config.sensors .. " Sensor(en) an Zentralrechner #" .. config.centralID)
print("Protokoll: " .. config.protocol .. " | Intervall: " .. config.interval .. "s")
print("--------------------------------------------------")

-- ================= HAUPTSCHLEIFE =================

while true do
    for _, sensor in ipairs(config.sensors) do
        local ok, raw = pcall(redstone.getAnalogInput, sensor.side)

        if ok then
            -- Redstone-Wert (0-15) auf den realen Maximalwert hochrechnen
            local max = sensor.max or 15
            local scaledValue = (raw / 15) * max

            local message = {
                name = sensor.name,
                category = sensor.category,
                value = scaledValue,   -- bereits umgerechneter Anzeigewert
                max = max,             -- reale Skala fuer das Gauge
                unit = sensor.unit,
                rawRedstone = raw,     -- Rohwert 0-15 zur Kontrolle
                sender = os.getComputerID(),
                timestamp = os.epoch("utc"),
            }

            -- Direktes Senden (KEIN Broadcast!)
            rednet.send(config.centralID, message, config.protocol)

            print(os.date("%H:%M:%S") .. "  " .. sensor.name ..
                  " [" .. sensor.category .. "] = " ..
                  string.format("%.0f", scaledValue) .. " " .. (sensor.unit or "") ..
                  " (Redstone: " .. raw .. ")")
        else
            print("Fehler beim Lesen von Seite '" .. sensor.side .. "'")
        end
    end

    sleep(config.interval)
end