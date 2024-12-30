local version = "0.1.0-beta"
local tag = "RRS_Station"

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found")
end

-- Load configuration
local configFile = "config.txt"
local config = {
    main_channel = 100,
    notify_channel = 101,
    reply_channel = os.getComputerID() + 1001
    station_id = nil
}

-- Open channels
modem.open(config.main_channel) -- Open main channel
modem.open(config.notify_channel) -- Open notify channel
modem.open(config.reply_channel) -- Open reply channel specifically for this station

-- Load config from file
local function loadConfig()
    if fs.exists(configFile) then
        local file = fs.open(configFile, "r")
        local data = textutils.unserialize(file.readAll())
        file.close()

        if data and data.station_id then
            config.station_id = data.station_id
        end
    end
end

-- Save config to file
local function saveConfig()
    local file = fs.open(configFile, "w")
    file.write(textutils.serialize(config))
    file.close()
end

-- Initialize station config
local function initStationConfig()
    if not config.station_id then
        term.setTextColor(colors.blue)
        print("Enter the station ID:")
        term.setTextColor(colors.white)
        config.station_id = read()
        saveConfig()
        print("Station ID set to: " .. config.station_id)
        sleep(1)
        term.clear()
        term.setCursorPos(1,1)
    end
end

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
    modem.transmit(config.main_channel, config.reply_channel, requestMessage)
end

-- Handle responses and arrival notifications
local function handleResponses()
    while true do
        local event, side, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")

        if senderChannel == config.reply_channel then
            term.clear()
            term.setCursorPos(1,1)
            if type(message) == "table" and message.type == "response" then
                if #message.successItems > 0 then
                    print(" ")
                    print(" ")
                    term.setTextColor(colors.green)
                    print("Request succeeded, received the following items:")
                    term.setTextColor(colors.white)
                    print("--------------------------")
                    for _, successItems in ipairs(message.successItems) do
                        print(successItems.amount .. "x " .. successItems.item)
                    end
                end
                if #message.failedItems > 0 then
                    print(" ")
                    print(" ")
                    term.setTextColor(colors.red)
                    print("Request failed for the following items:")
                    term.setTextColor(colors.white)
                    print("--------------------------")
                    for _, failedItems in ipairs(message.failedItems) do
                        io.write(failedItems.amount .. "x " .. failedItems.item .. " - ")
                        term.setTextColor(colors.yellow)
                        io.write(failedItems.reason)
                        term.setTextColor(colors.white)
                        print()
                    end
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

-- Ask user for items to request
local function getUserInput()
    local items = {}
    while true do
        term.setTextColor(colors.blue)
        print("Enther the item you want to request (or type 'done' to finish):")
        print("(use correct item names, eg. 'minecraft:iron_ingot')")
        term.setTextColor(colors.white)
        local itemName = read()
        if itemName == "done" then
            break
        end

        print()
        term.setTextColor(colors.blue)
        print("How many " .. itemName .. " do you want to request?")
        term.setTextColor(colors.white)
        local amount = tonumber(read())
        if not amount or amount <= 0 then
            print("Invalid amount, please enter a number greater than 0")
        else
            table.insert(items, { item = itemName, amount = amount })
        end
        term.setTextColor(colors.yellow)
        print("Added " .. amount .. "x " .. itemName .. " to the request")
        sleep(1)
        term.clear()
        term.setCursorPos(1,1)
    end

    return items
end

-- Main program
loadConfig()
initStationConfig()

while true do
    -- Example request to send multiple items
    local itemsToRequest = getUserInput()

    -- Request resources from Central Control
    if #itemsToRequest > 0 then
        requestResources(itemsToRequest)
        handleResponses()
    end
end