local version = "0.1.0-beta"
local tag = "RRS_Station"

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found")
end

-- Load configuration
local config = {
    main_channel = 100,
    notify_channel = 101,
    station_id = "station_1"
}

-- Open channels
modem.open(config.main_channel)
modem.open(config.notify_channel)

-- Send request for items
local function requestResources(items)
    print("Sending request to CCS")

    -- Create the message
    local requestMessage = {
        type = "request",
        station = config.station_id,
        items = items
    }

    -- Send the request message
    modem.transmit(config.main_channel, config.main_channel, requestMessage)
end

-- Handle responses and arrival notifications
local function handleResponses()
    while true do
        local event, side, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")

        if senderChannel == config.main_channel then
            if type(message) == "table" and message.type == "response" then
                if message.status == "Success" then
                    print("Request successful! " .. message.message)
                elseif message.status == "Failed" then
                    print("Request failed: " .. message.message)
                end
            end
        elseif senderChannel == config.notify_channel then
            if type(message) == "table" and message.type == "arrival" then
                print("Arrival notification: " .. message.station .. " received the following items:")

                for _, itemArrival in ipairs(message.items) do
                    print(itemArrival.amount .. "x " .. itemArrival.item)
                end
            end
        end
    end
end

-- Example request to send multiple items
local itemsToRequest = {
    { item = "iron_ingot", amount = 100 },
    { item = "mekanism_uranium", amount = 500 },
    { item = "gold_ingot", amount = 100 },
}

-- Request resources from Central Control
requestResources(itemsToRequest)

-- Handle responses and arrival notifications in parallel
handleResponses()