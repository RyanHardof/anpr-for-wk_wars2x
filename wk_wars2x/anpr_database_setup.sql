-- ANPR System Database Setup
-- Run this SQL script to create the required tables for the ANPR system

-- Table to store all plate reads
CREATE TABLE IF NOT EXISTS `anpr_plate_reads` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(12) NOT NULL,
    `officer_name` VARCHAR(255) NOT NULL,
    `server_id` INT NOT NULL,
    `location` VARCHAR(255),
    `camera` ENUM('front', 'rear') NOT NULL,
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `coords_x` FLOAT,
    `coords_y` FLOAT,
    `coords_z` FLOAT,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_timestamp` (`timestamp`),
    INDEX `idx_officer` (`officer_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table to store manually flagged plates (separate from warrant-based flags)
CREATE TABLE IF NOT EXISTS `anpr_flagged_plates` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(12) NOT NULL UNIQUE,
    `reason` TEXT NOT NULL,
    `severity` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') DEFAULT 'MEDIUM',
    `officer` VARCHAR(255) NOT NULL,
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `status` ENUM('active', 'inactive') DEFAULT 'active',
    INDEX `idx_plate` (`plate`),
    INDEX `idx_status` (`status`),
    INDEX `idx_severity` (`severity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table to store ANPR alerts/hits
CREATE TABLE IF NOT EXISTS `anpr_alerts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(12) NOT NULL,
    `officer_name` VARCHAR(255) NOT NULL,
    `server_id` INT NOT NULL,
    `reason` TEXT NOT NULL,
    `severity` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') DEFAULT 'MEDIUM',
    `camera` ENUM('front', 'rear') NOT NULL,
    `location` VARCHAR(255),
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `coords_x` FLOAT,
    `coords_y` FLOAT,
    `coords_z` FLOAT,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_timestamp` (`timestamp`),
    INDEX `idx_severity` (`severity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Optional: Create view for easy flagged plate management
CREATE OR REPLACE VIEW `anpr_all_flagged_plates` AS
SELECT 
    ov.plate,
    ov.citizenid,
    lpw.title as reason,
    CASE 
        WHEN lpw.priority = 'low' THEN 'LOW'
        WHEN lpw.priority = 'high' THEN 'HIGH'
        WHEN lpw.priority = 'critical' THEN 'CRITICAL'
        ELSE 'MEDIUM'
    END as severity,
    lpw.created_by as officer,
    lpw.created_at as timestamp,
    'warrant' as source_type,
    lpw.warrant_status as status
FROM owned_vehicles ov
JOIN lbtablet_police_warrants lpw ON ov.citizenid = lpw.linked_profile_id
WHERE lpw.warrant_status = 'active'

UNION ALL

SELECT 
    afp.plate,
    NULL as citizenid,
    afp.reason,
    afp.severity,
    afp.officer,
    afp.timestamp,
    'manual' as source_type,
    afp.status
FROM anpr_flagged_plates afp
WHERE afp.status = 'active';

-- Optional: Create indexes for better performance on existing tables
-- (Only run if you haven't already optimized these tables)
-- ALTER TABLE `owned_vehicles` ADD INDEX IF NOT EXISTS `idx_plate` (`plate`);
-- ALTER TABLE `lbtablet_police_warrants` ADD INDEX IF NOT EXISTS `idx_linked_profile` (`linked_profile_id`);
-- ALTER TABLE `lbtablet_police_warrants` ADD INDEX IF NOT EXISTS `idx_status` (`warrant_status`);

-- Example queries to test the system:

-- 1. Get all currently flagged plates
-- SELECT * FROM anpr_all_flagged_plates;

-- 2. Get recent plate reads
-- SELECT * FROM anpr_plate_reads ORDER BY timestamp DESC LIMIT 50;

-- 3. Get all ANPR alerts from today
-- SELECT * FROM anpr_alerts WHERE DATE(timestamp) = CURDATE() ORDER BY timestamp DESC;

-- 4. Get statistics
-- SELECT 
--     COUNT(*) as total_reads,
--     COUNT(DISTINCT plate) as unique_plates,
--     COUNT(DISTINCT officer_name) as active_officers
-- FROM anpr_plate_reads 
-- WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR);

-- 5. Get flagged plate hit rate
-- SELECT 
--     afp.plate,
--     afp.reason,
--     COUNT(aa.id) as hit_count,
--     MAX(aa.timestamp) as last_hit
-- FROM anpr_all_flagged_plates afp
-- LEFT JOIN anpr_alerts aa ON afp.plate = aa.plate
-- GROUP BY afp.plate, afp.reason
-- ORDER BY hit_count DESC;

-- Sample data for testing (remove in production)
-- INSERT INTO anpr_flagged_plates (plate, reason, severity, officer) VALUES 
-- ('TEST123', 'Test Vehicle - Remove in Production', 'MEDIUM', 'System'),
-- ('DEMO456', 'Demo Plate - Remove in Production', 'HIGH', 'System');

-- Note: The ANPR system will automatically create these tables when it starts,
-- but you can run this script manually for initial setup or troubleshooting.
