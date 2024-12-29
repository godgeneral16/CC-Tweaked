local version = "0.1.0-beta"
local tag = "RRS_Station"

local basalt = require("basalt")

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

-- List of all available items (replace with actual items from your system)
local allItems = {
    "minecraft:iron_ingot", "minecraft:gold_ingot", "mekanism:uranium_ingot",
    "villagers:villager_hat", "minecraft:diamond", "minecraft:netherite_ingot"
}

-- Function to send the request to the Central Control System
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

-- Function to update the item list based on search input
local function updateItemList(query)
    local matches = {}
    for _, item in ipairs(allItems) do
        if string.match(item:lower(), query:lower()) then
            table.insert(matches, item)
        end
    end

    if #matches == 0 then
        return {"No matching items."}
    else
        return matches
    end
end

-- Function to handle item selection and amount input
local function handleItemSelection(selectedItem, selectedItems, screen)
    -- Ask for amount
    local amountInput = screen:addTextInput("Enter amount for " .. selectedItem, 1, 12, 10, 3)
    local confirmButton = screen:addButton("Confirm", 12, 12, 10, 3)

    confirmButton:onClick(function()
        local amount = tonumber(amountInput:getText())
        if amount and amount > 0 then
            table.insert(selectedItems, { name = selectedItem, amount = amount })
            print("Added " .. selectedItem .. " x" .. amount)
            amountInput:clearText()  -- Clear the input field after confirmation
        else
            print("Invalid amount entered.")
        end
    end)
end

-- Main function to start Basalt GUI
local function startGUI()
    local screen = basalt.createWindow()

    -- Search input for items
    local searchInput = screen:addTextInput("Search for an item", 1, 1, 20, 3)

    -- Search button
    local searchButton = screen:addButton("Search", 22, 1, 8, 3)

    -- Listbox for search results
    local itemList = screen:addListBox("", 1, 5, 30, 6)

    -- Table to store selected items
    local selectedItems = {}

    -- Function to update the item list when search button is pressed
    searchButton:onClick(function()
        local query = searchInput:getText()
        local matches = updateItemList(query)
        itemList:setItems(matches)
    end)

    -- Handle list box item selection
    itemList:onSelect(function(selectedItem)
        handleItemSelection(selectedItem, selectedItems, screen)
    end)

    -- Button to send the request
    local requestButton = screen:addButton("Send Request", 1, 18, 30, 3)
    requestButton:onClick(function()
        if #selectedItems == 0 then
            print("No items selected!")
        else
            -- Send the request with the selected items
            requestResources(selectedItems)
            selectedItems = {}  -- Clear the selection after sending
            print("Request sent!")
        end
    end)

    -- Show the screen
    screen:show()

    -- Main loop to process events
    while true do
        screen:processEvents()
    end
end

-- Function to handle responses and item arrivals
local function handleResponses()
    while true do
        local event, side, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")

        if senderChannel == config.main_channel then
            if type(message) == "table" and message.type == "response" then
                if #message.successItems > 0 then
                    print(" ")
                    print(" ")
                    term.setTextColor(colors.green)
                    print("Request succeeded, received the following items:")
                    term.setTextColor(colors.white)
                    print("--------------------------")
                    for _, successItem in ipairs(message.successItems) do
                        print(successItem.amount .. "x " .. successItem.item)
                    end
                end
                if #message.failedItems > 0 then
                    print(" ")
                    print(" ")
                    term.setTextColor(colors.red)
                    print("Request failed for the following items:")
                    term.setTextColor(colors.white)
                    print("--------------------------")
                    for _, failedItem in ipairs(message.failedItems) do
                        io.write(failedItem.amount .. "x " .. failedItem.item .. " - ")
                        term.setTextColor(colors.yellow)
                        io.write(failedItem.reason)
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

-- Start the GUI and handle responses in parallel
parallel.waitForAny(startGUI, handleResponses)
