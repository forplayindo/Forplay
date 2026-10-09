-- =========================================
-- Economy Dashboard - Database Installation
-- =========================================
-- Version: 1.0.0
-- Run this SQL file to create all required tables
-- Compatible with MySQL 5.7+ and MariaDB 10.2+
-- =========================================

-- =========================================
-- Core Tables
-- =========================================

-- Transaction log (main table - will grow large)
CREATE TABLE IF NOT EXISTS `economy_transactions` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `transaction_type` ENUM('faucet', 'sink', 'transfer') NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    `subcategory` VARCHAR(100) DEFAULT NULL,
    `amount` BIGINT NOT NULL,
    `player_from` VARCHAR(50) DEFAULT NULL,
    `player_to` VARCHAR(50) DEFAULT NULL,
    `money_type` ENUM('cash', 'bank', 'dirty', 'crypto') DEFAULT 'cash',
    `balance_after` BIGINT DEFAULT NULL,
    `reason` VARCHAR(255) DEFAULT NULL,
    `metadata` JSON DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX `idx_transaction_type` (`transaction_type`),
    INDEX `idx_category` (`category`),
    INDEX `idx_player_from` (`player_from`),
    INDEX `idx_player_to` (`player_to`),
    INDEX `idx_money_type` (`money_type`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_type_created` (`transaction_type`, `created_at`),
    INDEX `idx_category_created` (`category`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily snapshots for historical charts
CREATE TABLE IF NOT EXISTS `economy_daily_snapshots` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `snapshot_date` DATE NOT NULL,
    `total_cash` BIGINT DEFAULT 0,
    `total_bank` BIGINT DEFAULT 0,
    `total_dirty` BIGINT DEFAULT 0,
    `total_crypto` BIGINT DEFAULT 0,
    `total_wealth` BIGINT DEFAULT 0,
    `total_players` INT DEFAULT 0,
    `active_players` INT DEFAULT 0,
    `total_faucets` BIGINT DEFAULT 0,
    `total_sinks` BIGINT DEFAULT 0,
    `net_flow` BIGINT DEFAULT 0,
    `transaction_count` INT DEFAULT 0,
    `faucet_breakdown` JSON DEFAULT NULL,
    `sink_breakdown` JSON DEFAULT NULL,
    `top_earners` JSON DEFAULT NULL,
    `top_spenders` JSON DEFAULT NULL,
    `wealth_brackets` JSON DEFAULT NULL,
    `gini_coefficient` DECIMAL(5,4) DEFAULT NULL,
    `inflation_index` DECIMAL(10,4) DEFAULT NULL,
    `economy_score` TINYINT UNSIGNED DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY `uk_snapshot_date` (`snapshot_date`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Player economy profiles
CREATE TABLE IF NOT EXISTS `economy_player_profiles` (
    `citizenid` VARCHAR(50) PRIMARY KEY,
    `player_name` VARCHAR(100) DEFAULT NULL,
    `total_earned` BIGINT DEFAULT 0,
    `total_spent` BIGINT DEFAULT 0,
    `total_received` BIGINT DEFAULT 0,
    `total_sent` BIGINT DEFAULT 0,
    `primary_income_source` VARCHAR(100) DEFAULT NULL,
    `primary_expense_sink` VARCHAR(100) DEFAULT NULL,
    `peak_wealth` BIGINT DEFAULT 0,
    `peak_wealth_date` DATE DEFAULT NULL,
    `first_seen` TIMESTAMP NULL DEFAULT NULL,
    `last_transaction` TIMESTAMP NULL DEFAULT NULL,
    `transaction_count` INT DEFAULT 0,
    `flag_status` ENUM('none', 'flagged', 'reviewed', 'cleared') DEFAULT 'none',
    `flag_reason` VARCHAR(255) DEFAULT NULL,
    `flag_date` TIMESTAMP NULL DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX `idx_flag_status` (`flag_status`),
    INDEX `idx_total_earned` (`total_earned`),
    INDEX `idx_last_transaction` (`last_transaction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- Alert System
-- =========================================

CREATE TABLE IF NOT EXISTS `economy_alerts` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `alert_type` VARCHAR(50) NOT NULL,
    `severity` ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
    `player_id` VARCHAR(50) DEFAULT NULL,
    `player_name` VARCHAR(100) DEFAULT NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `data` JSON DEFAULT NULL,
    `status` ENUM('new', 'reviewed', 'resolved', 'dismissed') DEFAULT 'new',
    `reviewed_by` VARCHAR(50) DEFAULT NULL,
    `reviewed_at` TIMESTAMP NULL DEFAULT NULL,
    `resolution_notes` TEXT DEFAULT NULL,
    `discord_sent` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX `idx_status` (`status`),
    INDEX `idx_alert_type` (`alert_type`),
    INDEX `idx_severity` (`severity`),
    INDEX `idx_player_id` (`player_id`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- Admin System
-- =========================================

CREATE TABLE IF NOT EXISTS `economy_admin_log` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `admin_id` VARCHAR(50) NOT NULL,
    `admin_name` VARCHAR(100) DEFAULT NULL,
    `action` VARCHAR(50) NOT NULL,
    `target_player` VARCHAR(50) DEFAULT NULL,
    `target_name` VARCHAR(100) DEFAULT NULL,
    `money_type` VARCHAR(20) DEFAULT NULL,
    `amount` BIGINT DEFAULT NULL,
    `old_value` BIGINT DEFAULT NULL,
    `new_value` BIGINT DEFAULT NULL,
    `reason` VARCHAR(255) DEFAULT NULL,
    `metadata` JSON DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX `idx_admin_id` (`admin_id`),
    INDEX `idx_action` (`action`),
    INDEX `idx_target_player` (`target_player`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- Inflation Tracking
-- =========================================

-- Price history for tracked items
CREATE TABLE IF NOT EXISTS `economy_price_history` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `item_name` VARCHAR(100) NOT NULL,
    `price` BIGINT NOT NULL,
    `logged_by` VARCHAR(50) DEFAULT NULL,
    `source` VARCHAR(100) DEFAULT 'manual',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX `idx_item_name` (`item_name`),
    INDEX `idx_created_at` (`created_at`),
    INDEX `idx_item_created` (`item_name`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daily inflation snapshots
CREATE TABLE IF NOT EXISTS `economy_inflation_snapshots` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `snapshot_date` DATE NOT NULL,
    `cpi_value` DECIMAL(10, 2) NOT NULL DEFAULT 100.00,
    `inflation_rate` DECIMAL(5, 2) DEFAULT 0.00,
    `basket_data` JSON DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY `uk_snapshot_date` (`snapshot_date`),
    INDEX `idx_snapshot_date` (`snapshot_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================
-- Configuration Storage
-- =========================================

CREATE TABLE IF NOT EXISTS `economy_config` (
    `key` VARCHAR(100) PRIMARY KEY,
    `value` TEXT NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default config values
INSERT INTO `economy_config` (`key`, `value`) VALUES
    ('last_snapshot_date', '2000-01-01'),
    ('last_cleanup_date', '2000-01-01'),
    ('inflation_baseline', '100.00'),
    ('schema_version', '1.0.0')
ON DUPLICATE KEY UPDATE `key` = `key`;

-- =========================================
-- Stored Procedures
-- =========================================

-- Procedure to clean up old transactions (optional maintenance)
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS `economy_cleanup_old_transactions`(IN retention_days INT)
BEGIN
    DELETE FROM `economy_transactions` 
    WHERE `created_at` < DATE_SUB(NOW(), INTERVAL retention_days DAY);
    
    UPDATE `economy_config` 
    SET `value` = CURDATE() 
    WHERE `key` = 'last_cleanup_date';
END //
DELIMITER ;

-- =========================================
-- Installation Complete
-- =========================================
-- Tables created:
--   - economy_transactions        (transaction log)
--   - economy_daily_snapshots     (historical data)
--   - economy_player_profiles     (player stats)
--   - economy_alerts              (alert system)
--   - economy_admin_log           (admin audit trail)
--   - economy_price_history       (inflation tracking)
--   - economy_inflation_snapshots (CPI data)
--   - economy_config              (settings storage)
-- =========================================
