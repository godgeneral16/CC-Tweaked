local monitorVersion = "0.1.0-beta"

dofile("/usr/apis/touchpoint.lua")
local monitor, monitorSide
local sizex, sizey, dim, oo, offy
local reactor

-- Stats
local coolantLevel = 0
local maxCoolantLevel = 0
local coolantFilledPercentage = 0
local temperature = 0
local fuelLevel = 0
local maxFuelLevel = 0
local fuelFilledPercentage = 0
local wasteLevel = 0
local wasteFilledPercentage = 0
local maxWasteLevel = 0
local fuelUsage = 0
local hotCoolant = 0 -- Steam produced by the reactor for turbines
local maxHotCoolant = 0
local hotCoolantFilledPercentage = 0
local burnRate = 0 -- Fuel burn rate


local graphsToDraw = {}

-- Graphs
local graphs = {
    "Coolant level",
    "Temperature",
    "Fuel level",
}

local XOffs =
{
    { 4, true},
    {27, true},
    {50, true},
    {73, true},
    {96, true},
}

-- Returns the side that a given peripheral type is connected to
local function getPeripheral(name)
    for i,v in pairs(peripheral.getNames()) do
        if (peripheral.getType(v) == name) then
            return v
        end
    end
    return ""
end

-- Draw a box with no fill
local function drawBox(size, xoff, yoff, color)
    if (monSide == nil) then
        return
    end
    local x,y = monitor.getCursorPos()
    monitor.setBackgroundColor(color)
    local horizLine = string.rep(" ", size[1])
    monitor.setCursorPos(xoff + 1, yoff + 1)
    monitor.write(horizLine)
    monitor.setCursorPos(xoff + 1, yoff + size[2])
    monitor.write(horizLine)

    -- Draw vertical lines
    for i=0, size[2] - 1 do
        monitor.setCursorPos(xoff + 1, yoff + i + 1)
        monitor.write(" ")
        monitor.setCursorPos(xoff + size[1], yoff + i +1)
        monitor.write(" ")
    end
    monitor.setCursorPos(x,y)
    monitor.setBackgroundColor(colors.black)
end

--Draw a filled box
local function drawFilledBox(size, xoff, yoff, colorOut, colorIn)
    if (monSide == nil) then
        return
    end
    local horizLine = string.rep(" ", size[1] - 2)
    drawBox(size, xoff, yoff, colorOut)
    local x,y = monitor.getCursorPos()
    monitor.setBackgroundColor(colorIn)
    for i=2, size[2] - 1 do
        monitor.setCursorPos(xoff + 2, yoff + i)
        monitor.write(horizLine)
    end
    monitor.setBackgroundColor(colors.black)
    monitor.setCursorPos(x,y)
end

--Draws text on the screen
local function drawText(text, x1, y1, backColor, textColor)
    if (monSide == nil) then
        return
    end
    local x, y = monitor.getCursorPos()
    monitor.setCursorPos(x1, y1)
    monitor.setBackgroundColor(backColor)
    monitor.setTextColor(textColor)
    monitor.write(text)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
    monitor.setCursorPos(x,y)
end

-- Reset monitor
local function resetMonitor()
    if (monitorSide == nil) then
        return
    end
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setTextScale(0.5)
    monitor.setCursorPos(1,1)
end

-- Initialize the monitor
local function initMonitor()
    monitorSide = getPeripheral("monitor")
    if (monitorSide == "" or monitorSide == nil) then
        error("No monitor found")
        monitorSide = nil
        return
    end

    monitor = peripheral.wrap(monitorSide)

    if monitor == nil then
        error("No monitor found")
        return
    end

    resetMonitor()
    t = touchpoint.new(monitor)
    sizex, sizey = monitor.getSize()
    oo = sizey - 37
    dim = sizex - 33

    if (sizex == 36) then
        dim = -1
    end
end

-- Detect the reactor
local function detectReactor()
    reactor = peripheral.find("fissionReactorLogicAdapter")
    if reactor then
        return true
    end

    return false
end

-- Draw fuel levels
local function drawFuelLevel(xoff)
    local srf = sizey - 9
    local off = xoff
    local right = off + 19 < dim
    local poff = right and off + 15 or off - 6

    drawBox({15, srf + 2}, off -1, 4, colors.gray)
    local fuel = math.floor(fuelLevel / maxFuelLevel * srf)
    drawFilledBox({13, srf}, off, 5, colors.red, colors.red)
    local rndpw = rnd(fuelFilledPercentage, 2)
    local color = (rndpw < maxb and rndpw > minb) and colors.green or (rndpw >= maxb and colors.orange or colors.blue)
    if (fuel > 0) then
        drawFilledBox({13, fuel + 1}, off, srf + 4 - fuel, color, color)
    end

    drawText(string.format(right and "%.2f%%" or "%5.2f%%", rndpw), poff, srf + 5 - fuel, colors.black, color)
    drawText("Fuel Level", off + 1, 4, colors.black, colors.orange)
    drawText("Fuel", off + 1, srf + 5 - fuel, fuel > 0 and color or colors.red, colors.black)
end

local function drawGraph(name, offset)
    if (name == "Fuel Level") then
        drawFuelLevel(offset)
    end
end

local function drawGraphs()
    for i,v in pairs(graphsToDraw) do
        if (v + 15 < dim) then
            drawGraph(i,v)
        end
    end
end

local function drawStatus()
    if (dim <= -1) then
        return
    end
    drawBox({dim, sizey - 2},
            1, 1, colors.lightBlue)
    drawText(" Reactor Graphs ", dim - 18, 2,
            colors.black, colors.lightBlue)
    drawGraphs()
end

local function drawScene()
    if (monitorSide == nil) then
        return
    end

    drawStatus()
end

-- Update stats
local function updateStats()
    coolantLevel = reactor.getCoolant().amount
    maxCoolantLevel = reactor.getCoolantCapacity()
    coolantFilledPercentage = string.format("%.2f", reactor.getCoolantFilledPercentage() * 100)

    temperature = reactor.getTemperature()

    fuelLevel = reactor.getFuel().amount
    maxFuelLevel = reactor.getFuelCapacity()
    fuelFilledPercentage = string.format("%.2f", reactor.getFuelFilledPercentage() * 100)

    wasteLevel = reactor.getWaste().amount
    maxWasteLevel = reactor.getWasteCapacity()
    wasteFilledPercentage = string.format("%.2f", reactor.getWasteFilledPercentage() * 100)

    burnRate = reactor.getBurnRate()
    fuelUsage = reactor.getFuelConsumedLastTick()

    hotCoolant = reactor.getHeatedCoolant().amount
    hotCoolantMax = reactor.getHeatedCoolantCapacity()
    hotCoolantFilledPercentage = string.format("%.2f", reactor.getHeatedCoolantFilledPercentage() * 100)
end

-- Timer function
local function startTimer(ticksToUpdate, callback)
    local timeToUpdate = ticksToUpdate * 0.05
    local id = os.startTimer(timeToUpdate)
    local fun = function(event)
        if (event[1] == "timer" and event[2] == id) then
            id = os.startTimer(timeToUpdate)
            callback()
        end
    end
    return fun
end

-- Main loop
local function loop()
    local ticksToUpdateStats = 20
    local ticksToRedraw = 20

    local updateStatsTick = startTime(
        ticksToUpdateStats,
        function()
            updateStats()
        end
    )

    local redrawTick = startTimer(
        ticksToRedraw,
        function()
            drawScene()
        end
    )

    local handleResize = function(event)
        if (event[1] == "monitor_resize") then
            initMonitor()
        end
    end

    while true do
        local event = (monitorSide == nil) and { os.pullEvent() }
        updateStatsTick(event)
        handleResize(event)
        redrawTick(event)
    end
end

-- Main function
local function main()
    resetMonitor()
    local reactorDetected = false
    while (not reactorDetected) do
        reactorDetected = detectReactor()
        if (not reactorDetected) then
            print("Reactor not found. Please make sure a reactor is connected!")
            sleep(1)
        end
    end

    print("Reactor detected! Proceeding with initialization...")

    print("Loading configuration...")

    Print("Configuration loaded! Starting monitor...")
    initMonitor()

    print("Writing config to disk...")
    -- saveToConfig()

    print("Reactor initialized! Starting monitoring...")
    sleep(2)

    term.clear()
    term.setCursorPos(1, 1)

    print("Reactor Monitor is now running!")

    loop()
end
-- Run the program
main()

print("Script exited!")
sleep(1)