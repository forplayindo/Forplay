-- ============================================
-- Vehicle Data (Stance, Neon, Nitro, Oil, Traction)
-- ============================================
CREATE TABLE IF NOT EXISTS `mechanic_vehicle_data` (
    `plate` VARCHAR(20) NOT NULL,
    `stance_data` JSON,
    `neon_effect` VARCHAR(50) DEFAULT 'static',
    `neon_color` VARCHAR(20) DEFAULT '#FFFFFF',
    `neon_zones` JSON,
    `nitro_installed` TINYINT(1) DEFAULT 0,
    `nitro_fuel_current` INT(11) DEFAULT 0,
    `nitro_fuel_max` INT(11) DEFAULT 0,
    `nitro_bottles` JSON,
    `traction_min` FLOAT,
    `traction_max` FLOAT,
    `oil_quality` FLOAT DEFAULT 100.0,
    `oil_last_change_km` FLOAT DEFAULT 0.0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Tires Data
-- ============================================
CREATE TABLE IF NOT EXISTS `mechanic_vehicle_tires` (
    `plate` VARCHAR(20) NOT NULL,
    `wheel_index` INT(11) NOT NULL,
    `pressure` FLOAT DEFAULT 32.0,
    `tread` FLOAT DEFAULT 100.0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`, `wheel_index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_tire_bursts` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(20) NOT NULL,
    `wheel_index` INT(11) NOT NULL,
    `burst_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Order Installs
-- ============================================
CREATE TABLE IF NOT EXISTS `mechanic_order_installs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `order_id` INT(11) NOT NULL,
    `shop_id` INT(11) NOT NULL,
    `vehicle_net_id` INT(11),
    `status` VARCHAR(50) NOT NULL DEFAULT 'in_progress',
    `started_by` INT(11),
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`order_id`) REFERENCES `mechanic_orders`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Customer Vehicles
-- ============================================
CREATE TABLE IF NOT EXISTS `mechanic_customer_vehicles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `plate` VARCHAR(20) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;