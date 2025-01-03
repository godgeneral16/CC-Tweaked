local version = "0.1.0-beta"

-- Github information
local github_base_url = "https://raw.github.com/godgeneral16/CC-Tweaked/main/Resource%20Request%20System/"
local ccs_file_path = "Central%20Control%20System/main.lua" -- Central Control System
local loader_mapping_path = "Central%20Control%20System/mapping.lua" -- Central Control System Mapping
local station_file_path = "Station%20System/main.lua" -- Station System
local loader_file_path = "Loader%20System/main.lua" -- Loader System
local main_controller_file_path = "Main%20Controller/main.lua" -- Main Controller

-- Paths
local ccs_path = "Resource_Request_System/CCS/"
local station_path = "Resource_Request_System/Station/"
local loader_path = "Resource_Request_System/Loader/"
local main_controller_path = "Resource_Request_System/Main_Controller/"

local file_name = "main.lua"
local mapping_name = "mapping.lua"

-- Function to log progress
local function logProgress(message, logType)
    if logType == nil then
        logType = "INFO"
        logColor = colors.blue
    elseif logType == "ERROR" then
        logColor = colors.red
    end

    term.write("[")
    term.setTextColor(logColor)
    term.write(logType)
    term.setTextColor(colors.white)
    term.write("] ")
    term.setTextColor(colors.yellow)
    term.write(message)
    term.setTextColor(colors.white)
    print()
end

local function createDirectory(path)
    local dirs ={}
    for dir in path:gmatch("[^/]+") do
        table.insert(dirs, dir)
    end

    local currentPath = ""
    for i, dir in ipairs(dirs) do
        logProgress("Checking if directory " .. currentPath .. dir .. " exists")
        currentPath = currentPath .. dir
        if not fs.exists(currentPath) then
            fs.makeDir(currentPath)
            logProgress("Created directory " .. currentPath)
        end
        currentPath = currentPath .. "/"
    end
end

-- Download files from Github
local function downloadFile(url, savePath, fileName)
    createDirectory(savePath)
    logProgress("Downloading " .. savePath)
    local response = http.get(url)
    if response then
        local file = fs.open(savePath .. fileName, "w")
        file.write(response.readAll())
        file.close()
        logProgress("Downloaded " .. savePath)
    else
        logProgress("Failed to download " .. savePath, "ERROR")
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
    elseif softwareType == "Loader" then
        url = github_base_url .. loader_file_path
        path = loader_path
    elseif softwareType == "Main" then
        url = github_base_url .. main_controller_file_path
        path = main_controller_path
    else
        print("Please select a valid option")
        return
    end

    term.setTextColor(colors.blue)
    print("Installing ")
    term.setTextColor(colors.green)
    io.write(softwareType)
    term.setTextColor(colors.white)
    print()

    -- Check if file already exists
    if fs.exists(path) then
        print(path .. " already exists, Do you want to overwrite it? (y/n)")
        local answer = io.read()
        if answer:lower() ~= "y" then
            print("Installation cancelled")
            return
        end
    end

    -- Ask user if he wants to run it as startup.lua
    print("Do you want to run this software on startup? (y/n)")
    local runOnStartup = io.read()
    if runOnStartup:lower() == "y" then
        local startupPath = "startup.lua"
        local startupFile = fs.open(startupPath, "w")
        startupFile.write("shell.run(\"" .. path .. file_name .. "\")")
        startupFile.close()
        logProgress("Startup file created")
    end

    -- Download and install
    downloadFile(url, path, file_name)
    if softwareType == "CCS" then
        downloadFile(github_base_url .. loader_mapping_path, ccs_path, mapping_name)
    end
    logProgress("Installation completed")
end

-- Ask user which software to install
term.setTextColor(colors.blue)
print("Which program would you like to install? Available options are:")
term.setTextColor(colors.white)
print(" - Main (Main Controller)")
term.setTextColor(colors.red)
print("Note: Install only one Main Controller")
term.setTextColor(colors.white)
print()
print(" - CCS (Central Control System)")
print(" - Station (Station System)")
print(" - Loader (Loader System)")
local softwareChoice = io.read()
term.clear()

installSoftware(softwareChoice)