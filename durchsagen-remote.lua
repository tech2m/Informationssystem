--[[
  Durchsagensystem - FERNBEDIENUNG
  ==================================
  Reines Bedien-Interface zum Abspielen/Stoppen von Durchsagen - spielt selbst
  KEINE Audiodaten ab und registriert sich NICHT als Receiver. Zeigt einfach
  die aktuell auf der Zentrale vorhandenen Durchsagen an und loest sie per
  Knopfdruck aus (genau wie trigger.lua, nur mit Touch-UI statt Redstone).

  Laeuft direkt auf dem eigenen Computerbildschirm.

  Benötigt:
    - Wireless Modem (bei Pocket Computer bereits eingebaut)
    - Die Bedienoberflaeche wird nicht auf einen externen Monitor umgeleitet.

  Sicherheit:
  Wie beim Redstone-Trigger wird ein geheimer Schluessel mitgesendet, den
  die Zentrale prueft (TRIGGER_KEY in central.lua). Es werden - wie im
  gesamten System - ausschliesslich gezielte Nachrichten per rednet.send()
  verschickt, kein Broadcast.
]]

local PROTOCOL = "durchsagen"
local CONFIG_FILE = "durchsagen_remote_config.txt"
local LIST_REFRESH_INTERVAL = 10 -- Sekunden zwischen automatischen Listen-Updates
local LIST_TIMEOUT = 5           -- Sekunden, die auf eine Antwort der Zentrale gewartet wird

-- ===================== Setup =====================

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
  error("Kein Wireless Modem gefunden!")
end
rednet.open(peripheral.getName(modem))

-- ===================== Konfiguration (einmalige Einrichtung) =====================

local function loadConfig()
  if fs.exists(CONFIG_FILE) then
    local f = fs.open(CONFIG_FILE, "r")
    local data = textutils.unserialize(f.readAll())
    f.close()
    return data
  end
  return nil
end

local function saveConfig(data)
  local f = fs.open(CONFIG_FILE, "w")
  f.write(textutils.serialize(data))
  f.close()
end

local config = loadConfig()

if not config then
  term.clear()
  term.setCursorPos(1, 1)
  print("=== Ersteinrichtung Fernbedienung ===")
  write("Computer-ID der Zentrale: ")
  local centralId = tonumber(read())
  write("Geheimer Schluessel (muss exakt mit TRIGGER_KEY in central.lua uebereinstimmen): ")
  local key = read()
  config = {centralId = centralId, key = key}
  saveConfig(config)
end

-- ===================== Zustand =====================

local files = {}
local statusLine = "Verbinde mit Zentrale..."
local buttons = {}
local w, h = term.getSize()

local function addButton(x1, y1, x2, y2, action, data)
  table.insert(buttons, {x1 = x1, y1 = y1, x2 = x2, y2 = y2, action = action, data = data})
end

local function sendTo(message)
  rednet.send(config.centralId, message, PROTOCOL)  -- gezielte Nachricht, KEIN Broadcast
end

local function requestList()
  statusLine = "Aktualisiere Liste..."
  sendTo({action = "list_request", key = config.key})
end

local function triggerPlay(filename)
  sendTo({action = "trigger", key = config.key, file = filename})
  statusLine = "Ausgeloest: " .. filename
end

local function triggerStop()
  sendTo({action = "trigger_stop", key = config.key})
  statusLine = "Stop gesendet."
end

-- ===================== UI =====================

local function drawUI()
  buttons = {}
  w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()

  term.setCursorPos(1, 1)
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.clearLine()
  term.write(" Durchsagen-Fernbedienung ")

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.lightGray)
  term.setCursorPos(1, 2)
  term.clearLine()
  term.write(statusLine)

  term.setTextColor(colors.yellow)
  term.setCursorPos(2, 4)
  term.write("Durchsagen:")

  local row = 5
  local maxRow = h - 4
  for _, name in ipairs(files) do
    if row > maxRow then break end
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2, row)
    local label = " " .. name .. " "
    local width = math.min(#label, w - 2)
    term.write(label:sub(1, width) .. string.rep(" ", math.max(0, w - 2 - width)))
    addButton(2, row, w - 1, row, "play", name)
    term.setBackgroundColor(colors.black)
    row = row + 1
  end

  if #files == 0 then
    term.setTextColor(colors.lightGray)
    term.setCursorPos(2, row)
    term.write("(keine Durchsagen gefunden oder noch keine Antwort)")
  end

  -- Aktionsleiste unten
  local by = h - 1
  term.setBackgroundColor(colors.red)
  term.setTextColor(colors.white)
  term.setCursorPos(2, by)
  term.write(" Stop ")
  addButton(2, by, 8, by, "stop")

  term.setBackgroundColor(colors.gray)
  term.setCursorPos(11, by)
  local refreshLabel = " Aktualisieren "
  term.write(refreshLabel)
  addButton(11, by, 11 + #refreshLabel - 1, by, "refresh")

  term.setBackgroundColor(colors.black)
end

local function handleClick(x, y)
  for _, b in ipairs(buttons) do
    if x >= b.x1 and x <= b.x2 and y == b.y1 then
      if b.action == "play" then
        triggerPlay(b.data)
      elseif b.action == "stop" then
        triggerStop()
      elseif b.action == "refresh" then
        requestList()
      end
      return
    end
  end
end

local function handleIncoming(senderId, message)
  if senderId ~= config.centralId or type(message) ~= "table" then return end

  if message.action == "list_response" then
    files = message.files or {}
    table.sort(files)
    statusLine = "Liste aktualisiert (" .. #files .. " Durchsagen)."
  end
end

-- ===================== Hauptschleifen =====================

local function networkLoop()
  while true do
    local senderId, message = rednet.receive(PROTOCOL, LIST_TIMEOUT)
    if senderId then
      handleIncoming(senderId, message)
    end
  end
end

local function refreshLoop()
  requestList()
  while true do
    sleep(LIST_REFRESH_INTERVAL)
    requestList()
  end
end

local function uiLoop()
  drawUI()
  while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "mouse_click" then
      handleClick(p2, p3)
      drawUI()
    elseif event == "durchsage_remote_tick" then
      drawUI()
    end
  end
end

local function tickLoop()
  while true do
    sleep(2)
    os.queueEvent("durchsage_remote_tick")
  end
end

parallel.waitForAny(networkLoop, refreshLoop, uiLoop, tickLoop)