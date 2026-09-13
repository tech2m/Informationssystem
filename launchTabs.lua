local mon = peripheral.find("monitor")

if not mon then
    print("Fehler: Kein Advanced Monitor gefunden!")
    return
end

-- Textgröße anpassen (0.5 ist ideal für Tabs)
mon.setTextScale(0.5)

local monName = peripheral.getName(mon)

-- 1. Tab: Öffnet "Motor" als Hauptprogramm auf dem Monitor
-- 2. Tab: Öffnet "Durchsagen" im Hintergrund
shell.run("bg", "Durchsagen")
shell.run("monitor", monName, "Motor")