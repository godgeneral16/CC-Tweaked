-- Main Controller of the Resource Request System
-- This program is responsible for managing the different systems of the Resource Request System.
-- It provides a centralized controller for setting and updating the RRS configuration, as well as
-- managing new Central Control Systems (CCS)
-- It will register new CCSs and update all CCSs, Stations and Loaders with the latest channels and configurations.

local version = "0.1.0-beta"
local tag = "RRS_Main"

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found")
end

-- Load configuration
local configFile = "global_config.txt"
local config = {
    main_controller_channels = {
        main_channel = 100,
        notify_channel = 101,
        update_channel = 102,
        reply_channel = os.getComputerID() + 1001,
        ccs_registration = 800,
        station_registration = 801,
        loader_registration = 900,
    }
    global_config = {},
    ccs_list = {},
    ccs_mapping = {},
}

-- Open channels
for _, channel in pairs(config.main_controller_channels) do
    modem.open(channel)
end

-- Load config from file
local function loadConfig()
    if fs.exists(configFile) then
        local file = fs.open(configFile, "r")
        local data = textutils.unserialize(file.readAll())
        file.close()

        if data then
            config.global_config = data.global_config or {}
            config.ccs_list = data.ccs_list or {}
            config.ccs_mapping = data.ccs_mapping or {}
        end
    end
end

-- Save config to file
local function saveConfig()
    local file = fs.open(configFile, "w")
    file.write(textutils.serialize(config))
    file.close()
end

-- Initialize main config
local function initGlobalConfig()
    if not config.global_config then
        config.global_config = {}
        saveConfig()
    end

    if not config.ccs_list then
        config.ccs_list = {}
        saveConfig()
    end

    if not config.ccs_mapping then
        config.ccs_mapping = {}
        saveConfig()
    end
end

-- Handle CCS registration
-- @param ccs_id: string, the ID of the CCS
-- @param ccs_config: table, the configuration of the CCS
local function handleCCSRegistration(ccs_id, ccs_config)
    if not ccs_id or not ccs_config then
        print("Invalid CCS registration, make sure ccs_id and ccs_config are provided")
    end

    config.ccs_list[ccs_id] = ccs_config
    saveConfig()
    sendCCSUpdate() -- Send update to all systems
end

-- Send ccs update to all systems
local function sendCCSUpdate()
    local message = {
        type = "update_ccs_list",
        ccs_list = config.ccs_list
    }

    modem.transmit(config.main_controller_channels.update_channel, config.main_controller_channels.reply_channel, message)
end

-- Set mapping of stations, ccs and loaders
local function setMapping()
    local message = {
        type = "set_mapping",
        mapping = config.ccs_mapping
    }

    modem.transmit(config.main_controller_channels.update_channel, config.main_controller_channels.reply_channel, message)
end

-- Update mapping
local function updateMapping()
    config.ccs_mapping = {}
    for ccs_id, ccs_config in pairs(config.ccs_list) do
        for _, station_id in pairs(ccs_config.stations) do
            config.ccs_mapping[station_id] = ccs_id
        end
        for _, loader_id in pairs(ccs_config.loaders) do
            config.ccs_mapping[loader_id] = ccs_id
        end
    end
    saveConfig()
end

-- Main loop
local function main()
    loadConfig()
    initGlobalConfig()

    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if channel == config.main_controller_channels.ccs_registration then
            -- Handle CCS registration
            local ccs_id = message.ccs_id
            local ccs_config = message.ccs_config
            handleCCSRegistration(ccs_id, ccs_config)
        end
    end
end

main()