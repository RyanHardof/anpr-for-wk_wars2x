--[[---------------------------------------------------------------------------------------

	Wraith ARS 2X
	Created by WolfKnight
	
	For discussio    # Optional: Log to console if enabled
    if CONFIG.anpr_log_all_reads then
        # Logging disabled for clean operation
    endinformation on future updates, and more, join 
	my Discord: https://discord.gg/fD4e6WD 
	
	MIT License

	Copyright (c) 2020 WolfKnight

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

---------------------------------------------------------------------------------------]]--

-- Although there is only one export at the moment, more may be added down the line. 

--[[---------------------------------------------------------------------------------------
	ANPR System - Database and Storage
---------------------------------------------------------------------------------------]]--
-- ANPR Database - stores all plate reads and flagged plates
local anprDatabase = {
    flaggedPlates = {},     -- plates marked as stolen/wanted
    plateReads = {},        -- all plate reads with timestamps
    alerts = {}             -- active alerts
}

-- Load flagged plates from your existing database tables
function LoadFlaggedPlates()
    local query = [[
        SELECT DISTINCT 
            pv.plate,
            pv.citizenid,
            lpw.title as warrant_title,
            lpw.description as warrant_description,
            lpw.priority,
            lpw.warrant_status,
            lpw.created_by
        FROM player_vehicles pv
        JOIN lbtablet_police_warrants lpw ON pv.citizenid COLLATE utf8mb4_unicode_ci = lpw.linked_profile_id COLLATE utf8mb4_unicode_ci
        WHERE lpw.warrant_status = 'active'
    ]]
    
    local function processResults(result)
        if result and #result > 0 then
            for _, row in ipairs(result) do
                local severity = "MEDIUM"
                local reason = row.warrant_title or "Active Warrant"
                
                -- Set severity based on priority
                if row.priority == "high" then
                    severity = "HIGH"
                elseif row.priority == "critical" then
                    severity = "CRITICAL"
                elseif row.priority == "low" then
                    severity = "LOW"
                end
                
                -- Only use the warrant title, not the description
                -- if row.warrant_description and row.warrant_description ~= "" then
                --     reason = reason .. " - " .. row.warrant_description
                -- end
                
                anprDatabase.flaggedPlates[row.plate] = {
                    reason = reason,
                    severity = severity,
                    officer = row.created_by or "System",
                    citizenid = row.citizenid,
                    warrant_status = row.warrant_status,
                    timestamp = os.time()
                }
            end
            
            local count = 0
            for _ in pairs(anprDatabase.flaggedPlates) do count = count + 1 end
        else
            local testQuery1 = "SELECT COUNT(*) as count FROM lbtablet_police_warrants WHERE warrant_status = 'active'"
            local testQuery2 = "SELECT COUNT(*) as count FROM player_vehicles"
            
            if MySQL and MySQL.Async then
                MySQL.Async.fetchAll(testQuery1, {}, function(warrantResult)
                    -- Silent count check
                end)
                MySQL.Async.fetchAll(testQuery2, {}, function(vehicleResult)
                    -- Silent count check
                end)
            elseif exports.oxmysql then
                exports.oxmysql:execute(testQuery1, {}, function(warrantResult)
                    -- Silent count check
                end)
                exports.oxmysql:execute(testQuery2, {}, function(vehicleResult)
                    -- Silent count check
                end)
            end
        end
    end
    
    -- Check which MySQL system is available
    if MySQL and MySQL.Async then
        MySQL.Async.fetchAll(query, {}, processResults)
    elseif exports.oxmysql then
        exports.oxmysql:execute(query, {}, processResults)
    else
        print("^1[ANPR] ERROR: No MySQL system found! Please ensure mysql-async or oxmysql is installed.^0")
    end
end

-- Save plate read to memory (simplified version without database logging)
function LogPlateRead(clientId, plate, location, camera, timestamp)
    local playerName = GetPlayerName(clientId)
    local coords = GetEntityCoords(GetPlayerPed(clientId))
    local locationStr = location or string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z)
    local readTimestamp = timestamp or os.time()
    
    local read = {
        plate = plate,
        officer = playerName,
        location = locationStr,
        camera = camera,
        timestamp = readTimestamp,
        serverId = clientId
    }
    
    table.insert(anprDatabase.plateReads, read)
    
    -- Keep only recent reads to prevent memory overflow
    if #anprDatabase.plateReads > CONFIG.anpr_max_recent_reads then
        table.remove(anprDatabase.plateReads, 1)
    end
    
    -- Optional: Log to console if enabled
    if CONFIG.anpr_log_all_reads then
        print(string.format("[ANPR] Plate read: %s by %s", plate, playerName))
    end
    
    -- Check if plate is flagged
    CheckFlaggedPlate(clientId, plate, camera)
end

-- Check if a plate is flagged and trigger appropriate response
function CheckFlaggedPlate(clientId, plate, camera)
    local flaggedInfo = anprDatabase.flaggedPlates[plate]
    
    if flaggedInfo then
        local playerName = GetPlayerName(clientId)
        local coords = GetEntityCoords(GetPlayerPed(clientId))
        local locationStr = string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z)
        
        -- Create alert
        local alert = {
            plate = plate,
            officer = playerName,
            reason = flaggedInfo.reason,
            severity = flaggedInfo.severity,
            timestamp = os.time(),
            serverId = clientId,
            camera = camera,
            location = locationStr
        }
        
        table.insert(anprDatabase.alerts, alert)
        
        -- Keep only recent alerts to prevent memory overflow
        if #anprDatabase.alerts > 100 then
            table.remove(anprDatabase.alerts, 1)
        end
        
        -- Trigger client alert
        TriggerClientEvent("wk:anprAlert", clientId, alert)
        
        -- Removed broadcast functionality - only individual alerts now
        -- if flaggedInfo.severity == "HIGH" or flaggedInfo.severity == "CRITICAL" then
        --     TriggerClientEvent("wk:anprBroadcast", -1, alert)
        -- end
        
        -- Log to server console (disabled for clean operation)
        -- print(string.format("[ANPR ALERT] %s detected flagged plate %s - %s", 
        --     playerName, plate, flaggedInfo.reason))
    end
end

--[[---------------------------------------------------------------------------------------
	ANPR System Exports
---------------------------------------------------------------------------------------]]--

--[[---------------------------------------------------------------------------------------
	Adds a plate to the flagged plates database (in-memory only)
	
	Parameters:
		plate: The license plate to flag
		reason: Reason for flagging (e.g., "Stolen Vehicle", "BOLO")
		severity: "LOW", "MEDIUM", "HIGH", or "CRITICAL"
		officer: Officer name who flagged the plate
---------------------------------------------------------------------------------------]]--
function AddFlaggedPlate(plate, reason, severity, officer)
    plate = plate:upper()
    reason = reason or "Unknown"
    severity = severity or "MEDIUM"
    officer = officer or "System"
    
    anprDatabase.flaggedPlates[plate] = {
        reason = reason,
        severity = severity,
        officer = officer,
        timestamp = os.time(),
        manual_flag = true
    }
    
    return true
end

--[[---------------------------------------------------------------------------------------
	Removes a plate from the flagged plates database (in-memory only)
	
	Parameters:
		plate: The license plate to remove from flags
---------------------------------------------------------------------------------------]]--
function RemoveFlaggedPlate(plate)
    plate = plate:upper()
    
    if anprDatabase.flaggedPlates[plate] then
        anprDatabase.flaggedPlates[plate] = nil
        return true
    end
    return false
end

--[[---------------------------------------------------------------------------------------
	Checks if a plate is flagged
	
	Parameters:
		plate: The license plate to check
	
	Returns:
		flaggedInfo: Table with flag information or nil if not flagged
---------------------------------------------------------------------------------------]]--
function IsPlateflagged(plate)
    return anprDatabase.flaggedPlates[plate]
end

--[[---------------------------------------------------------------------------------------
	Gets all flagged plates
	
	Returns:
		flaggedPlates: Table of all flagged plates
---------------------------------------------------------------------------------------]]--
function GetAllFlaggedPlates()
    return anprDatabase.flaggedPlates
end

--[[---------------------------------------------------------------------------------------
	Gets recent plate reads
	
	Parameters:
		limit: Number of recent reads to return (default: 50)
	
	Returns:
		plateReads: Table of recent plate reads
---------------------------------------------------------------------------------------]]--
function GetRecentPlateReads(limit)
    limit = limit or 50
    local recentReads = {}
    local count = 0
    
    for i = #anprDatabase.plateReads, 1, -1 do
        if count >= limit then break end
        table.insert(recentReads, anprDatabase.plateReads[i])
        count = count + 1
    end
    
    return recentReads
end

--[[---------------------------------------------------------------------------------------
	Gets active ANPR alerts
	
	Returns:
		alerts: Table of active alerts
---------------------------------------------------------------------------------------]]--
function GetActiveAlerts()
    return anprDatabase.alerts
end

--[[---------------------------------------------------------------------------------------
	Manually trigger an ANPR plate read (for external systems)
	
	Parameters:
		clientId: The client ID
		plate: The license plate that was read
		camera: Camera that read the plate ("front" or "rear")
		location: Optional location description
---------------------------------------------------------------------------------------]]--
function TriggerPlateRead(clientId, plate, camera, location)
    if not clientId or not plate or not camera then
        return false
    end
    
    local coords = GetEntityCoords(GetPlayerPed(clientId))
    local locationStr = location or string.format("%.2f, %.2f", coords.x, coords.y)
    
    LogPlateRead(clientId, plate, locationStr, camera, os.time())
    
    -- Trigger the existing plate lock if it's a flagged plate
    local flaggedInfo = anprDatabase.flaggedPlates[plate]
    if flaggedInfo then
        TogglePlateLock(clientId, camera, true, flaggedInfo.severity == "HIGH" or flaggedInfo.severity == "CRITICAL")
    end
    
    return true
end

--[[---------------------------------------------------------------------------------------
	Search plate reads by criteria
	
	Parameters:
		criteria: Table with search criteria (plate, officer, timeFrom, timeTo)
	
	Returns:
		results: Table of matching plate reads
---------------------------------------------------------------------------------------]]--
function SearchPlateReads(criteria)
    local results = {}
    
    for _, read in ipairs(anprDatabase.plateReads) do
        local match = true
        
        if criteria.plate and not string.find(read.plate:upper(), criteria.plate:upper()) then
            match = false
        end
        
        if criteria.officer and not string.find(read.officer:upper(), criteria.officer:upper()) then
            match = false
        end
        
        if criteria.timeFrom and read.timestamp < criteria.timeFrom then
            match = false
        end
        
        if criteria.timeTo and read.timestamp > criteria.timeTo then
            match = false
        end
        
        if match then
            table.insert(results, read)
        end
    end
    
    return results
end

--[[---------------------------------------------------------------------------------------
	Original plate lock function - Enhanced with ANPR logging
---------------------------------------------------------------------------------------]]--

--[[---------------------------------------------------------------------------------------
	Locks the designated plate reader camera for the given client. 
	Enhanced with ANPR logging functionality.

	Parameters:
		clientId:
			The id of the client
		cam:
			The camera to lock, either "front" or "rear"
		beepAudio:
			Play an audible beep, either true or false
		boloAudio:
			Play the bolo lock sound, either true or false
		plateText:
			Optional - the plate text to log (for ANPR integration)
---------------------------------------------------------------------------------------]]--
function TogglePlateLock( clientId, cam, beepAudio, boloAudio, plateText )
	TriggerClientEvent( "wk:togglePlateLock", clientId, cam, beepAudio, boloAudio )
	
	-- Log plate read if plate text is provided
	if plateText then
		local coords = GetEntityCoords(GetPlayerPed(clientId))
		local location = string.format("%.2f, %.2f", coords.x, coords.y)
		LogPlateRead(clientId, plateText, location, cam, os.time())
	end
end

--[[---------------------------------------------------------------------------------------
	ANPR System Events
---------------------------------------------------------------------------------------]]--

-- Client requests to add a flagged plate
RegisterNetEvent("wk:addFlaggedPlate")
AddEventHandler("wk:addFlaggedPlate", function(plate, reason, severity)
    local source = source
    local playerName = GetPlayerName(source)
    
    if AddFlaggedPlate(plate, reason, severity, playerName) then
        TriggerClientEvent("wk:anprNotify", source, "Plate " .. plate .. " flagged successfully", "success")
    else
        TriggerClientEvent("wk:anprNotify", source, "Failed to flag plate " .. plate, "error")
    end
end)

-- Client requests to remove a flagged plate
RegisterNetEvent("wk:removeFlaggedPlate")
AddEventHandler("wk:removeFlaggedPlate", function(plate)
    local source = source
    
    if RemoveFlaggedPlate(plate) then
        TriggerClientEvent("wk:anprNotify", source, "Plate " .. plate .. " removed from flags", "success")
    else
        TriggerClientEvent("wk:anprNotify", source, "Plate " .. plate .. " was not flagged", "error")
    end
end)

-- Client requests flagged plates list
RegisterNetEvent("wk:getFlaggedPlates")
AddEventHandler("wk:getFlaggedPlates", function()
    local source = source
    TriggerClientEvent("wk:receiveFlaggedPlates", source, GetAllFlaggedPlates())
end)

-- Client requests recent plate reads
RegisterNetEvent("wk:getRecentReads")
AddEventHandler("wk:getRecentReads", function(limit)
    local source = source
    TriggerClientEvent("wk:receiveRecentReads", source, GetRecentPlateReads(limit))
end)

-- Handle ANPR plate lock from client
RegisterNetEvent("wk:anprPlateLock")
AddEventHandler("wk:anprPlateLock", function(plate, camera, severity)
    local source = source
    local playerName = GetPlayerName(source)
    
    -- Lock processing (debug output disabled for clean operation)
    
    -- Trigger the plate lock with appropriate sounds
    local playBolo = severity == "HIGH" or severity == "CRITICAL"
    TogglePlateLock(source, camera, true, playBolo, plate)
end)

-- Initialize ANPR system on resource start
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Wait for database to be ready
        Citizen.Wait(2000)
        
        -- Load flagged plates from existing database
        LoadFlaggedPlates()
        
        -- Set up periodic refresh (every 5 minutes)
        Citizen.CreateThread(function()
            while true do
                local refreshInterval = (CONFIG and CONFIG.anpr_refresh_interval) or 5
                Citizen.Wait(refreshInterval * 60000) -- Convert minutes to milliseconds
                RefreshFlaggedPlates()
            end
        end)
    end
end)

-- Add refresh command for admins
RegisterCommand("anpr_refresh", function(source, args, rawCommand)
    if source == 0 then -- Console only
        RefreshFlaggedPlates()
        print("[ANPR] Flagged plates refreshed manually")
    end
end, true)

-- Test command to manually add a flagged plate for testing
RegisterCommand("anpr_test", function(source, args, rawCommand)
    if source == 0 then -- Console only
        if args[1] then
            local testPlate = args[1]:upper()
            AddFlaggedPlate(testPlate, "Test Warrant - Remove Later", "HIGH", "System Test")
            print("[ANPR TEST] Added test plate:", testPlate)
        else
            print("[ANPR TEST] Usage: anpr_test [plate]")
        end
    end
end, true)

-- Command to show current flagged plates
RegisterCommand("anpr_show", function(source, args, rawCommand)
    if source == 0 then -- Console only
        local count = 0
        print("[ANPR] Current flagged plates:")
        for plate, info in pairs(anprDatabase.flaggedPlates) do
            count = count + 1
            print(string.format("  %s - %s (%s)", plate, info.reason, info.severity))
        end
        if count == 0 then
            print("  No flagged plates found")
        end
    end
end, true)

-- Debug command to check MySQL system and flagged plates
RegisterCommand("anpr_debug", function(source, args, rawCommand)
    if source == 0 then -- Console only
        -- Check MySQL system availability
        if MySQL and MySQL.Async then
            print("[ANPR] MySQL system: mysql-async (available)")
        elseif exports.oxmysql then
            print("[ANPR] MySQL system: oxmysql (available)")
        else
            print("[ANPR] MySQL system: NONE FOUND!")
        end
        
        -- Show current flagged plates count
        local count = 0
        for _ in pairs(anprDatabase.flaggedPlates) do count = count + 1 end
        print(string.format("[ANPR] Current flagged plates: %d", count))
    end
end, true)

--[[---------------------------------------------------------------------------------------
	Periodic Functions
---------------------------------------------------------------------------------------]]--
-- Refresh flagged plates every 5 minutes to catch new warrants
function RefreshFlaggedPlates()
    LoadFlaggedPlates()
end