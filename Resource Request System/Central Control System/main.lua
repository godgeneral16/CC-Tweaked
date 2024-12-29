-- Central Control System (CCS) main script
local version = "0.1.0-beta"
local tag = "RRS_CCS"

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found")
end

-- Load configuration
local config = {
    main_channel = 100,
    notify_channel = 101,
}

-- Open channels
modem.opem(config.main_channel)
modem.open(config.notify_channel)

-- Mock inventory
local inventory = {
    iron_ingot = 10000
}

-- Request handler
local function handleRequests(message, replyChannel)
    local station = message.station
    local items = message.items -- List of items to request

    print("Received request from " .. station)

    -- Process each item in the request
    for _, itemRequest in pairs(items) do
        local item = itemRequest.item
        local amount = itemRequest.amount

        print("Checking " .. amount .. " of " .. item)

        if inventory[item] and inventory[item] >= amount then
            inventory[item] = inventory[item] - amount
            print("Sending " .. amount .. " of " .. item .. " to " .. station)
        else
            response.status = "Failed"
            response.message = "Insuffucient stock for " .. item
            break
        end
    end

    modem.transmit(replyChannel, config.main_channel, response)

    -- Simulate dispatch logic
    if response.status == "Success" then
        print("All items dispatched to " .. station)
    else
        print("Failed to dispatch items to " .. station)
    end
end

-- Main loop
while true do
    local event, side, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == config.main_channel then
        handleRequests(message, replyChannel)
    end
end