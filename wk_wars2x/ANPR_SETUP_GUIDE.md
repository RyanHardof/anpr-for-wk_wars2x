# ANPR System Setup and Testing Guide

## Overview
This ANPR (Automatic Number Plate Recognition) system has been integrated into your Wraith ARS 2X script. It automatically flags vehicles owned by people with active warrants in your `lbtablet_police_warrants` table.

## Installation Steps

### 1. Database Dependencies
**IMPORTANT:** Your server must have either `mysql-async` or `oxmysql` installed and running.

**For mysql-async:**
- Ensure `mysql-async` is in your server's `resources` folder
- Make sure it's started in your `server.cfg` before the wraith script

**For oxmysql:**
- Ensure `oxmysql` is in your server's `resources` folder
- Make sure it's started in your `server.cfg` before the wraith script
- In `fxmanifest.lua`, change the dependency from `"mysql-async"` to `"oxmysql"`

### 2. Resource Dependencies
In your `server.cfg`, make sure the MySQL resource starts before Wraith:
```
ensure mysql-async    # or oxmysql
ensure wk_wars2x
```

### 3. Database Table Requirements
The system uses your existing tables:
- `player_vehicles` - contains vehicle plates and owner citizenids
- `lbtablet_police_warrants` - contains active warrants

**Required columns:**
- `player_vehicles.plate` - vehicle license plate
- `player_vehicles.citizenid` - owner's citizen ID
- `lbtablet_police_warrants.linked_profile_id` - citizen ID with warrant
- `lbtablet_police_warrants.warrant_status` - must be 'active' for flagged plates

## Testing the System

### Step 1: Check MySQL System
Run this command in your server console:
```
anpr_debug
```

This will show you:
- Which MySQL system is being used
- How many flagged plates are currently loaded

### Step 2: Check Database Contents
Run these SQL queries in your database to verify data:

**Check for active warrants:**
```sql
SELECT COUNT(*) FROM lbtablet_police_warrants WHERE warrant_status = 'active';
```

**Check for owned vehicles:**
```sql
SELECT COUNT(*) FROM player_vehicles;
```

**Check for matching records (should find flagged plates):**
```sql
SELECT pv.plate, pv.citizenid, lpw.title 
FROM player_vehicles pv
JOIN lbtablet_police_warrants lpw ON pv.citizenid COLLATE utf8mb4_unicode_ci = lpw.linked_profile_id COLLATE utf8mb4_unicode_ci
WHERE lpw.warrant_status = 'active';
```

**Alternative query if you get collation errors:**
```sql
SELECT pv.plate, pv.citizenid, lpw.title 
FROM player_vehicles pv
JOIN lbtablet_police_warrants lpw ON BINARY pv.citizenid = BINARY lpw.linked_profile_id
WHERE lpw.warrant_status = 'active';
```

### Step 3: Add Test Data (if needed)
If you don't have test data, you can add some manually:

**Add a test warrant:**
```sql
INSERT INTO lbtablet_police_warrants (citizenid, linked_profile_id, title, description, warrant_status, priority, created_by)
VALUES ('TEST001', 'TEST001', 'Armed Robbery', 'Test warrant for ANPR testing', 'active', 'high', 'admin');
```

**Add a test vehicle:**
```sql
INSERT INTO player_vehicles (citizenid, plate, vehicle)
VALUES ('TEST001', 'TEST123', 'adder');
```

### Step 4: Manual Testing Commands

**Add a test flagged plate:**
```
anpr_test TEST123
```

**View all flagged plates:**
```
anpr_show
```

**Refresh flagged plates from database:**
```
anpr_refresh
```

### Step 5: In-Game Testing

1. **Add a test flagged plate:**
   ```
   anpr_test TEST123
   ```

2. **Spawn a vehicle with the test plate:**
   - Use `/car adder` or similar to spawn a vehicle
   - Change the plate to TEST123 using `/plate TEST123` or similar

3. **Get in a police vehicle with the radar:**
   - Spawn a police vehicle
   - Get in the driver's seat
   - The radar should automatically appear

4. **Test the ANPR system:**
   - Drive near the vehicle with the flagged plate
   - The radar should automatically detect and scan the plate
   - You should see:
     - A notification popup with the alert details
     - The plate automatically locks on the radar
     - An alert sound plays
     - Debug messages in F8 console

5. **Verify the alert:**
   - Check F8 console for `[ANPR DEBUG]` messages
   - The plate should be locked and highlighted on the radar
   - The alert notification should show warrant details

## Expected Behavior

### When a flagged plate is detected:
1. **Automatic Detection:** The plate reader automatically scans plates as you drive
2. **ANPR Check:** Each plate is checked against the flagged database
3. **Alert Triggered:** If flagged, shows notification with warrant details
4. **Sound Alert:** Plays "plate_hit" sound (configurable)
5. **Auto-Lock:** Automatically locks the plate on the radar (if enabled)
6. **Server Log:** Logs the alert to server console

### Alert Severity Levels:
- **LOW:** Shows alert, no auto-lock
- **MEDIUM:** Shows alert, auto-lock enabled
- **HIGH:** Shows alert, auto-lock enabled
- **CRITICAL:** Shows alert, auto-lock enabled

### Auto-Lock Behavior:
- When a flagged plate is detected, it automatically locks on the radar
- HIGH and CRITICAL severity plates also play the BOLO sound
- The lock stays active until manually unlocked or a new plate is scanned

### Debug Messages
The system provides extensive debug logging:
- Database connection status
- Query results
- Flagged plate additions
- Alert triggers
- Auto-lock events

## Troubleshooting

### No flagged plates found
1. Check if `anpr_debug` shows a MySQL system
2. Verify your database has active warrants
3. Check that `citizenid` values match between tables
4. Ensure `warrant_status` is exactly 'active' (case-sensitive)

### Plates not triggering alerts
1. Check plate formatting (uppercase vs lowercase)
2. Verify the plate reader is working normally
3. Check server console for error messages
4. Test with a manually added plate using `anpr_test`

### MySQL errors
1. Ensure mysql-async or oxmysql is installed
2. Check resource start order in server.cfg
3. Verify database connection settings
4. Look for connection errors in server console

### Collation errors
If you see "Illegal mix of collations" errors:
1. The tables have different character set collations
2. This is fixed automatically in the script using COLLATE
3. If issues persist, you can standardize your database collations:
   ```sql
   ALTER TABLE player_vehicles CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ALTER TABLE lbtablet_police_warrants CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

## Configuration Options

In `config.lua`, you can adjust:
- `anpr_enabled` - Enable/disable ANPR system
- `anpr_auto_lock` - Auto-lock flagged plates
- `anpr_alert_sound` - Enable alert sounds
- `anpr_refresh_interval` - How often to refresh flagged plates (minutes)

## Files Modified
- `sv_exports.lua` - Server-side ANPR logic
- `cl_anpr.lua` - Client-side alerts and auto-locking
- `config.lua` - ANPR configuration options
- `fxmanifest.lua` - MySQL dependency

## Support
If you encounter issues:
1. Check the server console for error messages
2. Run the debug commands to verify system status
3. Check that your database tables have the required data
4. Verify your MySQL system is properly installed and running
