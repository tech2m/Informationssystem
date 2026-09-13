local mon = peripheral.find("monitor")

if not mon then
    print("Fehler: Kein Monitor gefunden!")
    return
end

-- Textgröße für gute Lesbarkeit der Tabs anpassen
mon.setTextScale(0.5)

local monName = peripheral.getName(mon)

-- Leitet die gesamte Multishell (inkl. Tab-Leiste) auf den Monitor um
-- und führt dort die Startbefehle aus
shell.run("monitor", monName, "multishell")
shell.run("bg", "Durchsagen")
shell.run("Motor")