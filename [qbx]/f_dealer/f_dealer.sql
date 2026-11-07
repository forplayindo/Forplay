-- f_dealer: tabel dealer kendaraan (aman dijalankan berulang, IF NOT EXISTS)

CREATE TABLE IF NOT EXISTS `f_dealer_vehicles` (
    `model` VARCHAR(60) NOT NULL,
    `category` VARCHAR(30) NOT NULL,
    `price` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `added_by` VARCHAR(100) NULL,
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `f_dealer_requests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `model` VARCHAR(60) NOT NULL,
    `ticket` VARCHAR(40) NOT NULL,
    `status` ENUM('pending','approved','rejected','claimed') NOT NULL DEFAULT 'pending',
    `reason` VARCHAR(255) NULL,
    `decided_by` VARCHAR(100) NULL,
    `plate` VARCHAR(10) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `decided_at` TIMESTAMP NULL DEFAULT NULL,
    `claimed_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizenid`),
    KEY `idx_status` (`status`),
    KEY `idx_ticket` (`ticket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- OPSIONAL: tabel kredit dealer lama (f_vehicleshop) sudah tidak dipakai.
-- Cek dulu isinya: SELECT COUNT(*) FROM `vehicle_financing`;
-- Kalau 0 / tidak ada cicilan aktif, boleh dihapus:
-- DROP TABLE IF EXISTS `vehicle_financing`;
