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
    loader_registration = 900,
    registeredLoaders = {}
}

-- Open channels
modem.open(config.main_channel)
modem.open(config.notify_channel)
modem.open(config.loader_registration)

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

local function saveToLoaderConfig()
    local file = fs.open(loaderConfigFile, "w")
    file.write(textutils.serialize({ registeredLoaders = config.registeredLoaders }))
    file.close()
end

-- Handle loader registration
local function handleLoaderRegistration(message, replyChannel)
    local loader_id = message.loader_id
    print("Received registration from loader " .. loader_id)
    config.registeredLoaders[loader_id] = {
        replyChannel = replyChannel
    }
    saveToLoaderConfig()

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
        modem.transmit(config.registerdLoaders[loader].replyChannel, config.main_channel, message)
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
    sendRequestToLoaders("godgeneral_base", successItems)

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
loadLoaderConfig()
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
end