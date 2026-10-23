CREATE TABLE IF NOT EXISTS `mechanical_shops` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `logo_url` VARCHAR(255),
    `blip_sprite` INT(11) DEFAULT 1,
    `blip_color` INT(11) DEFAULT 0,
    `shop_location` JSON NOT NULL,
    `management_location` JSON NOT NULL,
    `type` ENUM('public', 'job_only') NOT NULL,
    `operation_type` ENUM('auto', 'manual') NOT NULL,
    `discord_webhook` VARCHAR(255),
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_shop_points` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `type` ENUM('catalog', 'service', 'spray', 'customer_garage', 'storage', 'car_lift', 'part_deposit', 'color_mixing', 'dyno_station') NOT NULL,
    `coords` JSON NOT NULL,
    `spawn_coords` JSON,
    `lift` JSON,
    `dyno` JSON,
    `prop` VARCHAR(100),
    `marker_enabled` TINYINT(1) DEFAULT 1,
    `enabled` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_shop_roles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `permissions` JSON NOT NULL,
    `is_default` TINYINT(1) DEFAULT 0,
    `is_owner` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shop employees
CREATE TABLE IF NOT EXISTS `mechanic_shop_employees` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `identifier` VARCHAR(100) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `role_id` INT(11),
    `role` VARCHAR(50) NOT NULL,
    `salary` INT(11) DEFAULT 0,
    `performance` INT(11) DEFAULT 100,
    `is_active` TINYINT(1) DEFAULT 1,
    `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_active` TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`role_id`) REFERENCES `mechanic_shop_roles`(`id`) ON DELETE SET NULL,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Financial Tables
-- ============================================

-- Shop finance (balance)
CREATE TABLE IF NOT EXISTS `mechanic_shop_finance` (
    `shop_id` INT(11) NOT NULL,
    `balance` INT(11) NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`shop_id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shop transactions
CREATE TABLE IF NOT EXISTS `mechanic_shop_transactions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `amount` INT(11) NOT NULL,
    `type` ENUM('income', 'expense') NOT NULL,
    `description` VARCHAR(255),
    `performed_by` VARCHAR(100),
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Pricing Tables
-- ============================================

-- Shop custom prices
CREATE TABLE IF NOT EXISTS `mechanic_shop_prices` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `mod_id` INT(11),
    `mod_index` INT(11),
    `category` VARCHAR(50),
    `reference_number` VARCHAR(100),
    `price` INT(11) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_reference` (`reference_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Shop price limits (min/max ranges)
CREATE TABLE IF NOT EXISTS `mechanic_shop_price_limits` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `target` VARCHAR(100) NOT NULL,
    `min_price` INT(11) NOT NULL DEFAULT 0,
    `max_price` INT(11) NOT NULL DEFAULT 999999,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_target` (`target`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Order Tables
-- ============================================

-- Customer orders (work orders)
CREATE TABLE IF NOT EXISTS `mechanic_orders` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `order_number` VARCHAR(20) NOT NULL UNIQUE,
    `customer_id` INT(11),
    `customer_name` VARCHAR(100),
    `vehicle_plate` VARCHAR(20),
    `vehicle_name` VARCHAR(100),
    `parts` JSON NOT NULL,
    `notes` TEXT,
    `total_price` INT(11) NOT NULL,
    `status` ENUM('pending', 'started', 'completed', 'cancelled', 'paid') NOT NULL DEFAULT 'pending',
    `created_by` INT(11),
    `started_by` INT(11),
    `started_at` TIMESTAMP NULL,
    `completed_at` TIMESTAMP NULL,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_order_number` (`order_number`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Supplier orders (parts orders from suppliers)
CREATE TABLE IF NOT EXISTS `mechanic_supplier_orders` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `order_number` VARCHAR(20) NOT NULL UNIQUE,
    `supplier_code` VARCHAR(10) NOT NULL,
    `items` JSON NOT NULL,
    `total_price` INT(11) NOT NULL,
    `status` ENUM('pending', 'delivered', 'collected') NOT NULL DEFAULT 'pending',
    `created_by` INT(11),
    `delivered_at` TIMESTAMP NULL,
    `collected_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_order_number` (`order_number`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Invoice Tables
-- ============================================

-- Invoices
CREATE TABLE IF NOT EXISTS `mechanic_invoices` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `invoice_number` VARCHAR(20) NOT NULL UNIQUE,
    `order_id` INT(11),
    `customer_id` INT(11),
    `customer_name` VARCHAR(100),
    `vehicle_plate` VARCHAR(20),
    `vehicle_name` VARCHAR(100),
    `items` JSON NOT NULL,
    `notes` TEXT,
    `total_price` INT(11) NOT NULL,
    `status` ENUM('draft', 'sent', 'unpaid', 'paid', 'declined') NOT NULL DEFAULT 'draft',
    `payment_method` ENUM('cash', 'bank'),
    `created_by` INT(11),
    `sent_at` TIMESTAMP NULL,
    `paid_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`order_id`) REFERENCES `mechanic_orders`(`id`) ON DELETE SET NULL,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_invoice_number` (`invoice_number`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Storage Tables
-- ============================================

-- Shop storage (items)
CREATE TABLE IF NOT EXISTS `mechanic_shop_storage` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `metadata` JSON,
    `quantity` INT(11) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Vehicle Upgrades
-- ============================================

-- Shop vehicle upgrades (purchased vehicles)
CREATE TABLE IF NOT EXISTS `mechanic_shop_vehicle_upgrades` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `upgrade_id` VARCHAR(50) NOT NULL,
    `model` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `price` INT(11) NOT NULL,
    `interaction_location` JSON,
    `vehicle_spawn_location` JSON,
    `marker_enabled` TINYINT(1) DEFAULT 0,
    `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`),
    INDEX `idx_upgrade_id` (`upgrade_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Air Compressors
-- ============================================

-- Shop air compressors
CREATE TABLE IF NOT EXISTS `mechanic_shop_air_compressors` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `coords` JSON NOT NULL,
    `heading` FLOAT DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`shop_id`) REFERENCES `mechanic_shops`(`id`) ON DELETE CASCADE,
    INDEX `idx_shop_id` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Repair History
-- ============================================

-- Vehicle repair history
CREATE TABLE IF NOT EXISTS `mechanic_repair_history` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `vehicle_plate` VARCHAR(20),
    `vehicle_vin` VARCHAR(20),
    `vehicle_model` VARCHAR(100),
    `repair_target` ENUM('engine', 'body') NOT NULL,
    `procedure_id` VARCHAR(50),
    `procedure_label` VARCHAR(100),
    `health_before` INT(11),
    `health_after` INT(11),
    `cost` INT(11) DEFAULT 0,
    `repaired_by` VARCHAR(100),
    `repaired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_vehicle_plate` (`vehicle_plate`),
    INDEX `idx_vehicle_vin` (`vehicle_vin`),
    INDEX `idx_repaired_at` (`repaired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mechanic_admins` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(100) NOT NULL UNIQUE,
    `name` VARCHAR(100),
    `is_admin` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Insert Default Admin (Optional)
-- ============================================
-- Uncomment and modify to add your admin
-- INSERT INTO `mechanic_admins` (`identifier`, `name`, `is_admin`) 
-- VALUES ('license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Admin Name', 1);

-- ============================================
-- Insert Default Shop (Optional - for testing)
-- ============================================
-- Uncomment to create a test shop
-- INSERT INTO `mechanic_shops` (`name`, `description`, `shop_location`, `management_location`, `type`, `operation_type`) 
-- VALUES ('Test Mechanic Shop', 'A test shop for development', 
--         '{"x": 0.0, "y": 0.0, "z": 0.0, "heading": 0.0}',
--         '{"x": 0.0, "y": 0.0, "z": 0.0, "heading": 0.0}',
--         'job_only', 'auto');

