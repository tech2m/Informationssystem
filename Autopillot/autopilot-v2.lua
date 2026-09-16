--[[
    AUTOPILOT FUER COMPUTERAFT / CREATE AERONAUTICS

    Sensoren und Aktoren werden als Redstone-Analogwerte angeschlossen.
    Die sechs Aufwaertspropeller werden je Seite zu einer Gruppe aus drei
    Propellern zusammengefasst. Die Gruppierung erfolgt ausserhalb dieses
    Computers, zum Beispiel ueber Redstone-Kabel.

    Vor dem Start die Seiten und das GPS-Ziel in CONFIG anpassen.
]]

local CONFIG = {
    modemSide = "top",
    protocol = "autopilot_control",
    gpsTimeout = 2,
    tick = 0.25,
    positionSamples = 3,
    arrivalRadius = 3,
    maxSpeed = 8,
    altitudeMax = 256,

    target = { x = 0, y = 100, z = 0 },

    -- Redstone-Relay-Endpunkte. Namen mit peripheral.getNames() pruefen.
    -- Jeder Relay kann mehrere Eintraege ueber seine eigenen Seiten bedienen.
    -- Fallback: Ein String wie "right" liest direkt am Computer.
    sensors = {
        gimbalRight = { relay = "redstone_relay_0", side = "right" },
        gimbalLeft = { relay = "redstone_relay_0", side = "left" },
        velocityForward = { relay = "redstone_relay_1", side = "front" },
        velocityReverse = { relay = "redstone_relay_1", side = "back" },
        altitude = { relay = "redstone_relay_2", side = "bottom" },
    },

    -- Ausgangs-Relay-Endpunkte. liftLeft/liftRight speisen jeweils drei Propeller.
    outputs = {
        thrustLeft = { relay = "redstone_relay_3", side = "left" },
        thrustRight = { relay = "redstone_relay_3", side = "right" },
        reverse = { relay = "redstone_relay_3", side = "back" },
        liftLeft = { relay = "redstone_relay_4", side = "left" },
        liftRight = { relay = "redstone_relay_4", side = "right" },
    },

    control = {
        cruiseThrottle = 8,
        turnGain = 5,
        gimbalTurnGain = 1.5,
        altitudeGain = 1.2,
        verticalDamping = 0.8,
        brakingGain = 1.0,
    },
}

local autopilotEnabled = true
local relayCache = {}

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function getEndpoint(endpoint)
    if type(endpoint) == "string" then
        return redstone, endpoint
    end
    if type(endpoint) ~= "table" or type(endpoint.relay) ~= "string" or type(endpoint.side) ~= "string" then
        return nil, nil
    end
    if not relayCache[endpoint.relay] then
        relayCache[endpoint.relay] = peripheral.wrap(endpoint.relay)
    end
    return relayCache[endpoint.relay], endpoint.side
end

local function readAnalog(endpoint)
    local relay, side = getEndpoint(endpoint)
    if not relay then return nil end
    local ok, value = pcall(relay.getAnalogInput, side)
    if not ok then return nil end
    return tonumber(value) or 0
end

local function readSensors()
    local result = {}
    for name, side in pairs(CONFIG.sensors) do
        result[name] = readAnalog(side)
        if result[name] == nil then return nil end
    end
    return result
end

local function writeOutput(endpoint, value)
    local relay, side = getEndpoint(endpoint)
    if not relay then return false end
    local ok = pcall(relay.setAnalogOutput, side, math.floor(clamp(value, 0, 15) + 0.5))
    return ok
end

local function validateEndpoint(endpoint, label)
    local relay, side = getEndpoint(endpoint)
    if not relay then
        error("Relay-Endpunkt fuer " .. label .. " nicht gefunden oder ungueltig")
    end
    if type(endpoint) == "table" and type(relay.getAnalogInput) ~= "function" then
        error("Peripheral '" .. endpoint.relay .. "' ist kein Redstone-Relay")
    end
    if not side then
        error("Keine Redstone-Seite fuer " .. label .. " konfiguriert")
    end
end

local function validateConfiguration()
    for name, endpoint in pairs(CONFIG.sensors) do
        validateEndpoint(endpoint, "Sensor " .. name)
    end
    for name, endpoint in pairs(CONFIG.outputs) do
        validateEndpoint(endpoint, "Ausgang " .. name)
    end
end

local function stopOutputs()
    for _, side in pairs(CONFIG.outputs) do
        writeOutput(side, 0)
    end
end

local function distanceToTarget(position)
    local dx = CONFIG.target.x - position.x
    local dy = CONFIG.target.y - position.y
    local dz = CONFIG.target.z - position.z
    return math.sqrt(dx * dx + dy * dy + dz * dz), dx, dy, dz
end

local function angleDifference(targetAngle, currentAngle)
    local difference = targetAngle - currentAngle
    while difference > math.pi do difference = difference - 2 * math.pi end
    while difference < -math.pi do difference = difference + 2 * math.pi end
    return difference
end

local function headingFromDelta(dx, dz)
    return math.atan(dx, dz)
end

local function getPosition()
    local x, y, z = gps.locate(CONFIG.gpsTimeout, false)
    if not x then return nil end
    return { x = x, y = y, z = z }
end

local function averageHeading(previous, current)
    local dx = current.x - previous.x
    local dz = current.z - previous.z
    if math.abs(dx) + math.abs(dz) < 0.05 then return nil end
    return headingFromDelta(dx, dz)
end

local function calculateCommand(position, heading, sensor)
    local distance, dx, dy, dz = distanceToTarget(position)
    if distance <= CONFIG.arrivalRadius then
        return { left = 0, right = 0, reverse = 0, lift = 0, arrived = true }
    end

    local desiredHeading = headingFromDelta(dx, dz)
    local turn = angleDifference(desiredHeading, heading) * CONFIG.control.turnGain

    -- Die Gimbal-Differenz ist eine zusaetzliche, lokale Kurskorrektur.
    local gimbalBias = (sensor.gimbalRight - sensor.gimbalLeft) * CONFIG.control.gimbalTurnGain / 15
    turn = clamp(turn + gimbalBias, -CONFIG.control.turnGain, CONFIG.control.turnGain)

    local forwardSpeed = sensor.velocityForward - sensor.velocityReverse
    local throttle = CONFIG.control.cruiseThrottle - forwardSpeed * CONFIG.control.brakingGain
    throttle = clamp(throttle, 0, CONFIG.maxSpeed)
    if math.abs(angleDifference(desiredHeading, heading)) > math.pi * 0.55 then
        throttle = 0
    end

    local altitude = (sensor.altitude / 15) * CONFIG.altitudeMax
    local liftError = CONFIG.target.y - altitude
    local lift = liftError * CONFIG.control.altitudeGain
    lift = clamp(lift, -15, 15)

    return {
        left = throttle - turn,
        right = throttle + turn,
        reverse = 0,
        lift = math.max(0, lift),
        arrived = false,
    }
end

local function applyCommand(command)
    if command.arrived then
        stopOutputs()
        return
    end

    local left = clamp(command.left, 0, 15)
    local right = clamp(command.right, 0, 15)
    local reverse = 0
    if command.left < 0 or command.right < 0 then
        reverse = math.max(-command.left, -command.right)
    end

    writeOutput(CONFIG.outputs.thrustLeft, left)
    writeOutput(CONFIG.outputs.thrustRight, right)
    writeOutput(CONFIG.outputs.reverse, reverse)
    writeOutput(CONFIG.outputs.liftLeft, command.lift)
    writeOutput(CONFIG.outputs.liftRight, command.lift)
end

local function printStatus(position, command, message)
    local distance = distanceToTarget(position)
    term.clear()
    term.setCursorPos(1, 1)
    print("=== CREATE AERONAUTICS AUTOPILOT ===")
    print(message or "AKTIV")
    print(string.format("Position: %.1f / %.1f / %.1f", position.x, position.y, position.z))
    print(string.format("Ziel:     %.1f / %.1f / %.1f", CONFIG.target.x, CONFIG.target.y, CONFIG.target.z))
    print(string.format("Distanz:  %.1f", distance))
    print(string.format("Schub L/R: %.1f / %.1f", command.left, command.right))
    print(string.format("Lift: %.1f", command.lift))
end

local function commandLoop()
    local modem = peripheral.wrap(CONFIG.modemSide)
    if not modem then
        error("Kein Modem an Seite '" .. CONFIG.modemSide .. "' gefunden!")
    end
    rednet.open(CONFIG.modemSide)

    while true do
        local senderId, message = rednet.receive(CONFIG.protocol)
        if senderId and type(message) == "table" then
            if message.action == "set_target" then
                local x = tonumber(message.x)
                local y = tonumber(message.y)
                local z = tonumber(message.z)
                if x and y and z then
                    CONFIG.target.x = x
                    CONFIG.target.y = y
                    CONFIG.target.z = z
                    rednet.send(senderId, { action = "target_updated", target = CONFIG.target }, CONFIG.protocol)
                end
            elseif message.action == "start" then
                autopilotEnabled = true
                rednet.send(senderId, { action = "started" }, CONFIG.protocol)
            elseif message.action == "stop" then
                autopilotEnabled = false
                stopOutputs()
                rednet.send(senderId, { action = "stopped" }, CONFIG.protocol)
            end
        end
    end
end

local function run()
    local previousPosition = nil
    local heading = nil
    local sampleCount = 0

    while true do
        local position = getPosition()
        local sensor = readSensors()
        if not position or not sensor then
            stopOutputs()
            term.clear()
            term.setCursorPos(1, 1)
            print("AUTOPILOT: GPS oder Sensor nicht verfuegbar")
            print("Alle Ausgaenge wurden abgeschaltet.")
            sleep(CONFIG.tick)
        else
            if not autopilotEnabled then
                stopOutputs()
                printStatus(position, { left = 0, right = 0, lift = 0 }, "AUTOPILOT AUS - START ZUM FORTSETZEN")
                sleep(CONFIG.tick)
            elseif previousPosition then
                local newHeading = averageHeading(previousPosition, position)
                if newHeading then heading = newHeading end
            end
            if autopilotEnabled then previousPosition = position end

            if autopilotEnabled and heading then
                local command = calculateCommand(position, heading, sensor)
                applyCommand(command)
                printStatus(position, command, command.arrived and "ZIEL ERREICHT" or "AUTOPILOT AKTIV")
                if command.arrived then sleep(1) end
            else
                stopOutputs()
                sampleCount = sampleCount + 1
                printStatus(position, { left = 0, right = 0, lift = 0 },
                    "Kurs wird aus GPS-Bewegung ermittelt (" .. sampleCount .. ")")
            end
            sleep(CONFIG.tick)
        end
    end
end

validateConfiguration()

local ok, errorMessage = xpcall(function()
    parallel.waitForAny(run, commandLoop)
end, function(errorValue)
    stopOutputs()
    return errorValue
end)
if not ok then error(errorMessage) end