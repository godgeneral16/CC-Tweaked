local monitor = peripheral.find("monitor")
local reactor = peripheral.wrap("back")

-- Get monitor size
local width, height = monitor.getSize()

-- Set the text scale
monitor.setTextScale(1)

-- Get Reactor Status
local function reportReactorStatus()
    local status = reactor.getStatus()
    status = status and "Online" or "Offline"

    if status == "Offline" then
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Reactor is ")
        term.setTextColor(colors.red)
        term.write(status)
    else
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Reactor is ")
        term.setTextColor(colors.green)
        term.write(status)
    end
end

-- Get Reactor Energy Stats

-- Run the program
while true do
    reportReactorStatus()
    sleep(1)
end