local version = "0.1.0-beta"

local http = require("http")
local fs = require("fs")

-- Github information
local github_base_url = "https://raw.github.com/godgeneral16/CC-Tweaked/main/Resource%20Request%20System/"
local ccs_file_path = "Station%20System/main.lua" -- Central Control System
local station_file_path = "Central%20Control%20System/main.lua" -- Station System

-- Paths
local ccs_path = "Resource Request System/CCS/main.lua"
local station_path = "Resource Request System/Station/main.lua"

-- Download files from Github
local function downloadFile(url, savePath)
    local response = http.get(url)
    if response then
        local file = fs.open(savePath, "w")
        file.write(response.readAll())
        file.close()
        print("Downloaded " .. savePath)
    else
        print("Failed to download " .. savePath)
    end
end

-- Function to handle installation
local function installSoftware(softwareType)
    local url
    local path

    if softwareType == "CCS" then
        url = github_base_url .. ccs_file_path
        path = ccs_path
    elseif softwareType == "Station" then
        url = github_base_url .. station_file_path
        path = station_path
    else
        print("Invalid software type, please specify 'CCS' or 'Station'")
        return
    end

    -- Check if file already exists
    if fs.exists(path) then
        print(path .. " already exists, Do you want to overwrite it? (y/n)")
        local answer = io.read()
        if answer:lower() ~= "yes" then
            print("Installation cancelled")
            return
        end
    end

    -- Ask user if he wants to run it as startup.lua
    print("Do you want to run this software on startup? (y/n)")
    local runOnStartup = io.read()
    if runOnStartup:lower() == "yes" then
        local startupPath = "startup.lua"
        local startupFile = fs.open(startupPath, "w")
        startupFile.write("shell.run(\"" .. path .. "\")")
        startupFile.close()
        print("Startup script created successfully")
    end

    -- Download and install
    downloadFile(url, path)
    print(softwareType .. " installed successfully")
end

-- Ask user which software to install
print("Which software would you like to install? Available options are:")
print(" - CCS (Central Control System)")
print(" - Station (Station System)")
local softwareChoice = io.read()

installSoftware(softwareChoice)