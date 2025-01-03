-- Central Control System (CCS) main script for mapping
local version = "0.1.0-beta"
local tag = "RRS_CCS-mapping"

local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then
    error("No wireless modem found")
end

local config = {}

local configFile = "config.txt"

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

-- Configure mapping for CCS
local function configureMapping()
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.blue)
    print("Central Control System Mapping")
    term.setTextColor(colors.white)
    print("-----------------------------")
    print()
    print("Current mapping:")
    for ccs_id, loader_id in pairs(config.loader_mapping or {}) do
        term.setTextColor(colors.purple)
        io.write(ccs_id)
        term.setTextColor(colors.white)
        io.write(" " .. string.char(26) .. " ")
        term.setTextColor(colors.yellow)
        print(loader_id)
        term.setTextColor(colors.white)
        print()
    end

    term.setTextColor(colors.yellow)
    print("Enter CCS ID to configure (or 'exit' to exit):")
    term.setTextColor(colors.white)
    -- print list of CCSs
    for ccs_id, _ in pairs(config.ccs_list) do
        print(" - " .. ccs_id)
    end
    local ccs_id = read()
    if ccs_id:lower() == "exit" then
        term.setTextColor(colors.blue)
        print("Rebooting system to start main script")
        sleep(2)
        reboot()
    end

    if not config.ccs_list[ccs_id] then
        print("CCS not found")
        sleep(1)
        configureMapping()
        return
    end

    term.setTextColor(colors.yellow)
    print("Enter loader ID to map to " .. ccs_id .. ":")
    term.setTextColor(colors.white)

    -- print list of loaders
    for loader_id, _ in pairs(config.registeredLoaders) do
        print(" - " .. loader_id)
    end

    local loader_id = read()

    if not config.registeredLoaders[loader_id] then
        print("Loader not found")
        sleep(1)
        configureMapping()
        return
    end

    config.loader_mapping = config.loader_mapping or {}
    config.loader_mapping[ccs_id] = loader_id
    saveConfig()
    io.write("Mapping updated: ")
    term.setTextColor(colors.purple)
    io.write(ccs_id)
    term.setTextColor(colors.white)
    io.write(" " .. string.char(26) .. " ")
    term.setTextColor(colors.yellow)
    print(loader_id)
    term.setTextColor(colors.white)
    print()
    sleep(1)
    configureMapping()
end

-- Main loop
local function main()
    loadConfig()
    -- Check if config exists
    if config then
        configureMapping()
    else
        error("No configuration found, please run the main script first")
    end
end

main()
