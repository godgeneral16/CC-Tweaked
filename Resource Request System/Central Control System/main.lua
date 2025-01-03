-- Central Control System (CCS) main script
local version = "0.1.0-beta"
local tag = "RRS_CCS"

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found")
end

-- Check for rsBridge
local rsBridge = peripheral.find("rsBridge")
if not rsBridge then
    error("No rsBridge found")
end

-- Load configuration
local config = {
    main_channel = 100,
    notify_channel = 101,
    update_channel = 102,
    ccs_channel = 4000 + os.getComputerID(), -- Unique channel for this CCS
    ccs_id = nil,
    ccs_registration = 800,
    loader_registration = 900 + os.getComputerID(), -- Unique loader registration channel
    registeredLoaders = {},
    ccs_list = {},
}

-- Open channels
modem.open(config.main_channel)
modem.open(config.notify_channel)
modem.open(config.update_channel)
modem.open(config.loader_registration)
modem.open(config.ccs_registration)
modem.open(config.ccs_channel)

local configFile = config.txt
-- Load config from file
local function loadConfig()
    if fs.exists(configFile) then
        local file = fs.open(configFile, "r")
        local data = textutils.unserialize(file.readAll())
        file.close()

        if data then
            config = data
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
local function initCCSConfig()
    if not config.ccs_id then
        term.setTextColor(colors.blue)
        print("Enter the CCS ID (must be unique):")
        term.setTextColor(colors.white)
        config.station_id = read()
        saveConfig()
        term.setTextColor(colors.green)
        print("CCS ID set to: " .. config.ccs_id)
        term.setTextColor(colors.white)
        sleep(1)
        term.clear()
        term.setCursorPos(1,1)
    end
end

-- Handle registration at Main Controller
local function registerCCS()
    local message = {
        type = "register_ccs",
        ccs_id = config.ccs_id,
        ccs_config = {
            channel = config.ccs_channel,
            loaders = config.registeredLoaders
        }
    }
    modem.transmit(config.ccs_registration, config.ccs_channel, message)
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

-- Loader config
local loaderConfigFile = "loader_config.txt"
local function loadLoaderConfig()
    if fs.exists(loaderConfigFile) then
        local file = fs.open(loaderConfigFile, "r")
        local data = textutils.unserialize(file.readAll())
        file.close()

        if data and data.registeredLoaders then
            config.registeredLoaders = data.registeredLoaders
        end
    end
end

-- Save loader config
local function saveToLoaderConfig()
    local file = fs.open(loaderConfigFile, "w")
    file.write(textutils.serialize({ registeredLoaders = config.registeredLoaders }))
    file.close()
end

-- Handle loader registration
local function handleLoaderRegistration(message, replyChannel)
    local loader_id = message.loader_id
    print("Received registration from loader " .. loader_id)
    if not config.registeredLoaders[loader_id] then
        config.registeredLoaders[loader_id] = { replyChannel = replyChannel }
        saveToLoaderConfig()
    else
        print("Loader " .. loader_id .. " already registered")
    end

    modem.transmit(replyChannel, config.main_channel, { status = "registered", message = "Loader registered" })
end

-- Send request to loaders
local function sendRequestToLoaders(loader, items)
    local message = {
        type = "request",
        items = items
    }

    -- Check if loader exists in registered loaders
    if config.registeredLoaders[loader] then
        modem.transmit(config.registeredLoaders[loader].replyChannel, config.main_channel, message)
    else
        print("Loader " .. loader .. " is not registered")
    end

end

-- Request handler
local function handleRequests(message, replyChannel)
    local station = message.station
    local items = message.items -- List of items to request

    print("Received request from " .. station)

    local successItems = {}
    local failedItems = {}
    local itemsToRequest = {}

    local availableItems = getAvailableItems()

    -- Process each item in the request
    for _, itemRequest in pairs(items) do
        local item = itemRequest.item
        local amount = itemRequest.amount
        local foundItem = findItemInStock(item, availableItems)
        local found = false

        print("Checking " .. amount .. " of " .. item)

        if foundItem and foundItem.amount >= amount then
            print("Sending " .. amount .. " of " .. item .. " to " .. station)
            table.insert(successItems, { item = item, amount = amount })
            table.insert(itemsToRequest, { item = foundItem, amount = amount })
        else
            local reason = foundItem and "Insufficient stock" or "Item not found"
            print("Failed to send " .. amount .. " of " .. item .. " to " .. station .. " - Reason: " .. reason)
            table.insert(failedItems, { item = item, amount = amount, reason = reason })
        end
    end

    local response = {
        type = "response",
        status = "Success",
        message = "Request successful",
        successItems = successItems,
        failedItems = failedItems
    }

    modem.transmit(replyChannel, config.main_channel, response)

    -- Send request to loaders
    sendRequestToLoaders("godgeneral_base", itemsToRequest)

    -- Simulate dispatch logic
    if #successItems > 0 then
        print("Successfully dispatched items to " .. station)
    end

    if #failedItems > 0 then
        print("Failed to dispatch items to " .. station)
        for _, failed in ipairs(failedItems) do
            print("Failed: " .. failed.amount .. " of " .. failed.item .. " - Reason: " .. (failed.reason or "Insufficient stock"))
        end
    end
end

-- Main loop
loadConfig()
initCCSConfig()
loadLoaderConfig()
registerCCS()
while true do
    local event, side, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
    if senderChannel == config.main_channel then
        term.setTextColor(colors.green)
        print("------------ New Request -------------")
        term.setTextColor(colors.white)
        handleRequests(message, replyChannel)
    elseif senderChannel == config.loader_registration then
        handleLoaderRegistration(message, replyChannel)
    end

    if senderChannel == config.update_channel then
        if message.type == "update_ccs_list" then
            config.ccs_list = message.ccs_list
        end
    end
end