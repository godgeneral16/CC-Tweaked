-- Loader main script
local version = "0.1.0-beta"
local tag = "RRS_Loader"

local wirelessModem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not wirelessModem then
    error("No wireless modem found")
end

local wiredModem = peripheral.find("modem", function(_, m) return not m.isWireless() end)
if not wiredModem then
    error("No wired modem found")
end

-- Check for rsBridge
local rsBridge = peripheral.find("rsBridge")
if not rsBridge then
    error("No rsBridge found")
end

-- Load configuration
local configFile = "config.txt"
local config = {
    main_channel = 100,
    notify_channel = 101,
    reply_channel = os.getComputerID() + 1001,
    loader_registration = 900,
    loader_id = nil
}

-- Open channels
wirelessModem.open(config.main_channel) -- Open main channel
wirelessModem.open(config.notify_channel) -- Open notify channel
wirelessModem.open(config.reply_channel) -- Open reply channel specifically for this station

-- Load config from file
local function loadConfig()
    if fs.exists(configFile) then
        local file = fs.open(configFile, "r")
        local data = textutils.unserialize(file.readAll())
        file.close()

        if data and data.loader_id then
            config.loader_id = data.loader_id
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
    if not config.loader_id then
        term.setTextColor(colors.blue)
        print("Enter the loader ID:")
        term.setTextColor(colors.white)
        config.loader_id = read()
        saveConfig()
        print("Loader ID set to: " .. config.loader_id)
        sleep(1)
        term.clear()
        term.setCursorPos(1,1)
    end
end

-- Register loader with CCS
local function registerLoader()
    local message = {
        type = "register_loader",
        loader_id = config.loader_id
    }

    -- Send registration message to CCS
    wirelessModem.transmit(config.loader_registration, config.reply_channel, message)
    print("Loader " .. config.loader_id .. " registered with CCS")
end

-- load available items
local function getAvailableItems()
    local items = rsBridge.listItems()
    if not items then
        print("Failed to fetch items from RS Network")
        return
    end

    return items
end

-- Normalize an item string
local function normalizeItemName(name)
    -- Remove namespace (anything before and including ':')
    name = name:match(":(.*)") or name
    -- Remove brackets and spaces, then lowercase
    return name:lower():gsub("[%[%]]", ""):gsub(" ", "_")
end

-- Find an item in available stock
local function findItemInStock(requestedItem, availableItems)
    local normalizedRequested = normalizeItemName(requestedItem)

    for _, availableItem in pairs(availableItems) do
        local normalizedName = normalizeItemName(availableItem.name)
        local normalizedDisplayName = normalizeItemName(availableItem.displayName)

        if normalizedRequested == normalizedName or normalizedRequested == normalizedDisplayName then
            return availableItem
        end
    end

    return nil
end

local function handleResponses()
    while true do
        local event, side, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")

        if senderChannel == config.reply_channel then
            if message.type == "request" then
                print("Received request from CCS")
                local items = message.items
                for _, item in ipairs(items) do
                    print("Requesting item: " .. item.item.name)
                end
            end

            if message.type == "registered" then
                print("Loader " .. config.loader_id .. " registered with CCS")
            end
        end
    end
end

-- Main loop
loadConfig()
initStationConfig()

registerLoader()
handleResponses()