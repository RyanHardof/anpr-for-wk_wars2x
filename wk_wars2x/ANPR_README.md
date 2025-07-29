# ANPR System Documentation
## Wraith ARS 2X - Automatic Number Plate Recognition

### Overview
The ANPR (Automatic Number Plate Recognition) system extends the existing Wraith ARS 2X radar system to automatically detect and alert officers to flagged license plates. This system integrates seamlessly with the existing plate reader functionality.

### Features
- **Real-time Plate Detection**: Automatically scans plates as they appear on the radar
- **Flagged Plate Database**: Maintain a database of stolen, wanted, or suspicious vehicles
- **Alert System**: Immediate notifications when flagged plates are detected
- **Severity Levels**: Different alert types (LOW, MEDIUM, HIGH, CRITICAL)
- **Auto-locking**: Automatically lock flagged plates in the reader
- **Broadcasting**: High-severity alerts broadcast to all units
- **Command Interface**: Easy-to-use commands for managing flagged plates

### Configuration Options (config.lua)

```lua
-- Enable/disable ANPR system
CONFIG.anpr_enabled = true

-- Auto-lock flagged plates when detected
CONFIG.anpr_auto_lock = true

-- Play alert sounds
CONFIG.anpr_alert_sounds = true

-- Minimum time between alerts for same plate (seconds)
CONFIG.anpr_alert_cooldown = 5

-- Broadcast high-severity alerts to all units
CONFIG.anpr_broadcast_high_severity = true

-- Log all plate reads to server console
CONFIG.anpr_log_all_reads = false

-- Maximum recent reads to keep in memory
CONFIG.anpr_max_recent_reads = 1000
```

### Commands

#### `/anpr add [plate] [reason]`
Add a plate to the flagged database
- **Example**: `/anpr add ABC123 Stolen Vehicle`
- **Plate**: License plate number (automatically converted to uppercase)
- **Reason**: Reason for flagging (optional, defaults to "Unknown")

#### `/anpr remove [plate]`
Remove a plate from the flagged database
- **Example**: `/anpr remove ABC123`

#### `/anpr list`
Request current flagged plates from server
- Shows count of flagged plates loaded

#### `/anpr reads`
Request recent plate reads
- Shows last 25 plate reads

#### `/anpr sound [on/off]`
Toggle alert sounds on/off
- **Example**: `/anpr sound off`

### Severity Levels

#### LOW
- **Color**: White
- **Auto-lock**: No
- **Broadcast**: No
- **Sound**: Confirm beep
- **Use**: Minor infractions, expired registration

#### MEDIUM
- **Color**: Yellow
- **Auto-lock**: Yes
- **Broadcast**: No
- **Sound**: Radar sweep
- **Use**: Traffic violations, minor warrants

#### HIGH
- **Color**: Orange
- **Auto-lock**: Yes
- **Broadcast**: Yes
- **Sound**: Alarm clock
- **Use**: Stolen vehicles, serious crimes

#### CRITICAL
- **Color**: Red
- **Auto-lock**: Yes
- **Broadcast**: Yes
- **Sound**: Alarm clock
- **Use**: Armed and dangerous, manhunt suspects

### Server Exports

#### `AddFlaggedPlate(plate, reason, severity, officer)`
Add a flagged plate programmatically
```lua
exports['wk_wars2x']:AddFlaggedPlate("ABC123", "Stolen Vehicle", "HIGH", "Officer Smith")
```

#### `RemoveFlaggedPlate(plate)`
Remove a flagged plate
```lua
exports['wk_wars2x']:RemoveFlaggedPlate("ABC123")
```

#### `IsPlateragged(plate)`
Check if a plate is flagged
```lua
local flagged = exports['wk_wars2x']:IsPlateragged("ABC123")
```

#### `GetAllFlaggedPlates()`
Get all flagged plates
```lua
local plates = exports['wk_wars2x']:GetAllFlaggedPlates()
```

#### `TriggerPlateRead(clientId, plate, camera, location)`
Manually trigger a plate read
```lua
exports['wk_wars2x']:TriggerPlateRead(source, "ABC123", "front", "Downtown")
```

### Integration with External Systems

The ANPR system can be integrated with:
- **CAD Systems**: Import/export flagged plates
- **Databases**: Store plate reads and flags in MySQL/SQLite
- **Discord Webhooks**: Send alerts to Discord channels
- **ESX/QBCore**: Integrate with player data

### Example Database Integration

```lua
-- Example MySQL integration
function LoadFlaggedPlatesFromDB()
    MySQL.Async.fetchAll('SELECT * FROM flagged_plates', {}, function(result)
        for _, plate in ipairs(result) do
            AddFlaggedPlate(plate.plate, plate.reason, plate.severity, plate.officer)
        end
    end)
end

-- Save plate read to database
function SavePlateReadToDB(plateData)
    MySQL.Async.execute('INSERT INTO plate_reads (plate, officer, location, timestamp) VALUES (?, ?, ?, ?)', {
        plateData.plate,
        plateData.officer,
        plateData.location,
        plateData.timestamp
    })
end
```

### Network Events

#### Client Events
- `wk:anprAlert` - Triggered when flagged plate detected
- `wk:anprBroadcast` - High-severity alert broadcast
- `wk:anprNotify` - General ANPR notifications
- `wk:receiveFlaggedPlates` - Receive flagged plates list
- `wk:receiveRecentReads` - Receive recent plate reads

#### Server Events
- `wk:addFlaggedPlate` - Add flagged plate
- `wk:removeFlaggedPlate` - Remove flagged plate
- `wk:getFlaggedPlates` - Request flagged plates
- `wk:getRecentReads` - Request recent reads

### Troubleshooting

#### ANPR Not Working
1. Check `CONFIG.anpr_enabled = true` in config.lua
2. Ensure you're in a valid police vehicle
3. Check server console for ANPR initialization message
4. Verify `cl_anpr.lua` is loaded in fxmanifest.lua

#### No Alerts for Flagged Plates
1. Check plate exists in flagged database with `/anpr list`
2. Verify alert sounds are enabled with `/anpr sound on`
3. Check alert cooldown hasn't been triggered
4. Ensure plate reader is functioning normally

#### Commands Not Working
1. Must be in a police vehicle to use ANPR commands
2. Check for typos in plate numbers
3. Verify proper command syntax

### Development Notes

#### Adding New Features
- Alert system is modular and can be extended
- Database functions can be swapped for different storage systems
- Client-side hooks allow for custom UI integration
- Server exports provide external system integration

#### Performance Considerations
- Plate reads are cached to reduce server load
- Alert cooldowns prevent spam
- Database queries should be optimized for large datasets
- Consider cleanup routines for old plate reads

### Support and Updates

For support, feature requests, or bug reports:
- Join the Discord: https://discord.gg/fD4e6WD
- Check for updates regularly
- Review configuration options for new features

---

*This ANPR system is designed to enhance police roleplay while maintaining realism and performance. All features are configurable and can be adapted to different server requirements.*
