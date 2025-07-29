--[[---------------------------------------------------------------------------------------

	Wraith ARS 2X - ANPR System Client
	Created by WolfKnight
	
	ANPR (Automatic Number Plate Recognition) System Integration
	
---------------------------------------------------------------------------------------]]--

ANPR = {}

--[[----------------------------------------------------------------------------------
	ANPR Client Variables
----------------------------------------------------------------------------------]]--
ANPR.vars = {
    flaggedPlates = {},     -- Local cache of flagged plates
    recentReads = {},       -- Recent plate reads
    alerts = {},            -- Active alerts
    alertSound = true,      -- Play alert sounds
    autoFlag = false,       -- Auto flag mode
    lastAlert = 0,          -- Last alert timestamp
    lockedPlates = {}       -- Track ANPR locked plates {camera: plate}
}

--[[----------------------------------------------------------------------------------
	ANPR Client Functions
----------------------------------------------------------------------------------]]--

-- Initialize ANPR system
function ANPR:Initialize()
    self:RequestFlaggedPlates()
end

-- Request flagged plates from server
function ANPR:RequestFlaggedPlates()
    TriggerServerEvent("wk:getFlaggedPlates")
end

-- Request recent plate reads from server
function ANPR:RequestRecentReads(limit)
    limit = limit or 50
    TriggerServerEvent("wk:getRecentReads", limit)
end

-- Add a flagged plate
function ANPR:AddFlaggedPlate(plate, reason, severity)
    if not plate or plate == "" then
        UTIL:Notify("~r~Invalid plate number")
        return false
    end
    
    reason = reason or "Unknown"
    severity = severity or "MEDIUM"
    
    TriggerServerEvent("wk:addFlaggedPlate", plate:upper(), reason, severity)
    return true
end

-- Remove a flagged plate
function ANPR:RemoveFlaggedPlate(plate)
    if not plate or plate == "" then
        UTIL:Notify("~r~Invalid plate number")
        return false
    end
    
    TriggerServerEvent("wk:removeFlaggedPlate", plate:upper())
    return true
end

-- Check if a plate is flagged
function ANPR:IsPlateflagged(plate)
    return self.vars.flaggedPlates[plate:upper()]
end

-- Handle plate read from the radar system
function ANPR:HandlePlateRead(plate, camera)
    if not plate or plate == "" then return end
    
    plate = plate:upper()
    
    -- Check if this camera already has an ANPR lock active
    if self.vars.lockedPlates[camera] then
        return
    end
    
    -- Check if plate is flagged
    local flaggedInfo = self:IsPlateflagged(plate)
    if flaggedInfo then
        self:TriggerAlert(plate, flaggedInfo, camera)
    end
end

-- Trigger an ANPR alert
function ANPR:TriggerAlert(plate, flaggedInfo, camera)
    local currentTime = GetGameTimer()
    
    -- Prevent spam alerts (minimum 5 seconds between same plate alerts)
    if currentTime - self.vars.lastAlert < (CONFIG.anpr_alert_cooldown * 1000) then
        return
    end
    
    self.vars.lastAlert = currentTime
    
    -- Get severity configuration
    local severityConfig = CONFIG.anpr_severity_config[flaggedInfo.severity] or CONFIG.anpr_severity_config["MEDIUM"]
    
    -- Create alert notification
    local severityColor = severityConfig.color or "~w~"
    local alertSound = severityConfig.alert_sound or "plate_hit"
    
    -- Show notification
    UTIL:Notify("~r~ANPR ALERT~n~" .. severityColor .. "Plate: " .. plate .. "~n~" .. 
               "~w~Reason: " .. flaggedInfo.reason .. "~n~" .. 
               "~w~Severity: " .. flaggedInfo.severity)
    
    -- Play alert sound
    if self.vars.alertSound and CONFIG.anpr_alert_sounds then
        PlaySoundFrontend(-1, alertSound, "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end
    
    -- Auto-lock the plate if enabled
    if CONFIG.anpr_auto_lock and severityConfig.auto_lock then
        -- Track this ANPR lock FIRST
        self.vars.lockedPlates[camera] = plate
        
        -- Use the existing plate reader lock function
        if READER then
            -- Set the flagged plate on the camera
            READER:SetPlate(camera, plate)
            -- Set a default plate index (0 is the standard plate style)
            READER:SetIndex(camera, 0)
            
            -- Force NUI update to display the plate
            READER:ForceNUIUpdate(false)
            
            -- Only lock if not already locked (since LockCam toggles)
            if not READER:GetCamLocked(camera) then
                -- Determine if we should play the BOLO sound for high severity
                local playBolo = flaggedInfo.severity == "HIGH" or flaggedInfo.severity == "CRITICAL"
                READER:LockCam(camera, true, playBolo)
            end
        end
        
        -- Also trigger server-side lock for logging
        TriggerServerEvent("wk:anprPlateLock", plate, camera, flaggedInfo.severity)
    end
end

-- Show ANPR management menu
function ANPR:ShowManagementMenu()
    -- This would integrate with your existing menu system
    -- For now, we'll use basic notifications
    UTIL:Notify("~b~ANPR System~n~~w~Use /anpr [add/remove/list] [plate] [reason]")
end

-- Clear ANPR lock when camera is manually unlocked
function ANPR:ClearLock(camera)
    if self.vars.lockedPlates[camera] then
        self.vars.lockedPlates[camera] = nil
    end
end

-- Clear all ANPR locks
function ANPR:ClearAllLocks()
    self.vars.lockedPlates = {}
end

--[[----------------------------------------------------------------------------------
	ANPR Commands for Testing
----------------------------------------------------------------------------------]]--

-- Test command to simulate a flagged plate detection
RegisterCommand("anpr_test_alert", function(source, args, rawCommand)
    local plate = args[1] or "TEST123"
    local camera = args[2] or "front"
    
    -- Create a fake flagged plate for testing
    local flaggedInfo = {
        reason = "Test Warrant - Armed Robbery",
        severity = "HIGH",
        officer = "Test Officer",
        citizenid = "TEST001",
        timestamp = os.time()
    }
    
    -- Add to local cache temporarily
    ANPR.vars.flaggedPlates[plate:upper()] = flaggedInfo
    
    -- Trigger the alert
    ANPR:TriggerAlert(plate:upper(), flaggedInfo, camera)
    
    UTIL:Notify("~g~ANPR Test~n~~w~Triggered alert for plate: " .. plate:upper())
end, false)

-- Command to check ANPR status
RegisterCommand("anpr_status", function(source, args, rawCommand)
    local count = 0
    for _ in pairs(ANPR.vars.flaggedPlates) do count = count + 1 end
    
    UTIL:Notify("~b~ANPR Status~n~~w~Flagged plates: " .. count .. "~n~" ..
               "Auto-lock: " .. (CONFIG.anpr_auto_lock and "ON" or "OFF") .. "~n~" ..
               "Alert sounds: " .. (CONFIG.anpr_alert_sounds and "ON" or "OFF"))
end, false)

--[[----------------------------------------------------------------------------------
	ANPR Integration with Existing Plate Reader
----------------------------------------------------------------------------------]]--

-- Initialize ANPR when the script starts
Citizen.CreateThread(function()
    while not READER do
        Citizen.Wait(100)
    end
    
    -- Initialize ANPR system
    ANPR:Initialize()
end)

--[[----------------------------------------------------------------------------------
	ANPR Network Events
----------------------------------------------------------------------------------]]--

-- Receive flagged plates from server
RegisterNetEvent("wk:receiveFlaggedPlates")
AddEventHandler("wk:receiveFlaggedPlates", function(flaggedPlates)
    ANPR.vars.flaggedPlates = flaggedPlates
    local count = 0
    for _ in pairs(flaggedPlates) do count = count + 1 end
    -- Removed notification: UTIL:Notify("~b~ANPR~n~~w~Loaded " .. count .. " flagged plates")
end)

-- Receive recent plate reads from server
RegisterNetEvent("wk:receiveRecentReads")
AddEventHandler("wk:receiveRecentReads", function(recentReads)
    ANPR.vars.recentReads = recentReads
    UTIL:Notify("~b~ANPR~n~~w~Loaded " .. #recentReads .. " recent reads")
end)

-- Receive ANPR notifications
RegisterNetEvent("wk:anprNotify")
AddEventHandler("wk:anprNotify", function(message, type)
    local color = "~w~"
    if type == "success" then
        color = "~g~"
    elseif type == "error" then
        color = "~r~"
    end
    
    UTIL:Notify("~b~ANPR~n~" .. color .. message)
end)

-- Receive ANPR alert
RegisterNetEvent("wk:anprAlert")
AddEventHandler("wk:anprAlert", function(alert)
    ANPR:TriggerAlert(alert.plate, alert, alert.camera)
end)

-- Removed ANPR broadcast functionality
-- RegisterNetEvent("wk:anprBroadcast")
-- AddEventHandler("wk:anprBroadcast", function(alert)
--     -- Only show if player is in a police vehicle
--     if PLY:VehicleStateValid() then
--         UTIL:Notify("~r~ANPR BROADCAST~n~" .. 
--                    "~w~Officer: " .. alert.officer .. "~n~" .. 
--                    "~w~Plate: " .. alert.plate .. "~n~" .. 
--                    "~w~Reason: " .. alert.reason)
--         
--         PlaySoundFrontend(-1, "POLICE_RADIO_CHATTER", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
--     end
-- end)

--[[----------------------------------------------------------------------------------
	ANPR Commands
----------------------------------------------------------------------------------]]--

-- ANPR management command
RegisterCommand("anpr", function(source, args, rawCommand)
    if not PLY:VehicleStateValid() then
        UTIL:Notify("~r~You must be in a police vehicle to use ANPR")
        return
    end
    
    if not args[1] then
        UTIL:Notify("~b~ANPR Commands:~n~" .. 
                   "~w~/anpr add [plate] [reason]~n~" .. 
                   "/anpr remove [plate]~n~" .. 
                   "/anpr list~n~" .. 
                   "/anpr reads~n~" .. 
                   "/anpr sound [on/off]")
        return
    end
    
    local command = args[1]:lower()
    
    if command == "add" then
        if not args[2] then
            UTIL:Notify("~r~Usage: /anpr add [plate] [reason]")
            return
        end
        
        local plate = args[2]:upper()
        local reason = table.concat(args, " ", 3) or "Unknown"
        
        ANPR:AddFlaggedPlate(plate, reason, "MEDIUM")
        
    elseif command == "remove" then
        if not args[2] then
            UTIL:Notify("~r~Usage: /anpr remove [plate]")
            return
        end
        
        local plate = args[2]:upper()
        ANPR:RemoveFlaggedPlate(plate)
        
    elseif command == "list" then
        ANPR:RequestFlaggedPlates()
        
    elseif command == "reads" then
        ANPR:RequestRecentReads(25)
        
    elseif command == "sound" then
        if args[2] and args[2]:lower() == "off" then
            ANPR.vars.alertSound = false
            UTIL:Notify("~b~ANPR~n~~w~Alert sounds disabled")
        else
            ANPR.vars.alertSound = true
            UTIL:Notify("~b~ANPR~n~~w~Alert sounds enabled")
        end
        
    else
        UTIL:Notify("~r~Unknown ANPR command: " .. command)
    end
end, false)

--[[----------------------------------------------------------------------------------
	ANPR Initialization
----------------------------------------------------------------------------------]]--

-- Initialize ANPR when resource starts
Citizen.CreateThread(function()
    Citizen.Wait(2000) -- Wait for other systems to load
    ANPR:Initialize()
end)
