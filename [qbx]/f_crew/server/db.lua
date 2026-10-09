-- Skema database f_crew. Keanggotaan tidak disimpan di sini: itu milik qbx_core (player_groups).
local db = {}

function db.ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_gangs (
            id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
            name         VARCHAR(32)  NULL,
            label        VARCHAR(32)  NOT NULL,
            tag          VARCHAR(12)  NOT NULL DEFAULT 'gang',
            description  VARCHAR(255) NOT NULL DEFAULT '',
            color        VARCHAR(7)   NOT NULL DEFAULT '#8e44ad',
            recruit      VARCHAR(8)   NOT NULL DEFAULT 'apply',
            max_members  SMALLINT UNSIGNED NOT NULL DEFAULT 20,
            grades       VARCHAR(255) NOT NULL DEFAULT '[]',
            radio        SMALLINT UNSIGNED NULL,
            garage       VARCHAR(160) NULL,
            announcement VARCHAR(600) NOT NULL DEFAULT '',
            announced_at INT UNSIGNED NOT NULL DEFAULT 0,
            owner        VARCHAR(50)  NOT NULL,
            created_at   INT UNSIGNED NOT NULL,
            last_active  INT UNSIGNED NOT NULL,
            total_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            UNIQUE KEY uq_name (name),
            UNIQUE KEY uq_label (label)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    -- kolom tambahan untuk tabel yang dibuat versi sebelumnya (peringkat antar gang)
    local hasTotal = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'crew_gangs' AND COLUMN_NAME = 'total_seconds'
    ]])
    if (hasTotal or 0) == 0 then
        MySQL.query.await('ALTER TABLE crew_gangs ADD COLUMN total_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0')
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_applications (
            id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            gang       VARCHAR(32)  NOT NULL,
            citizenid  VARCHAR(50)  NOT NULL,
            name       VARCHAR(64)  NOT NULL DEFAULT '',
            kind       VARCHAR(8)   NOT NULL,
            message    VARCHAR(255) NOT NULL DEFAULT '',
            created_at INT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            INDEX idx_gang (gang),
            INDEX idx_cid (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_playtime (
            gang      VARCHAR(32)  NOT NULL,
            citizenid VARCHAR(50)  NOT NULL,
            name      VARCHAR(64)  NOT NULL DEFAULT '',
            seconds   INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (gang, citizenid),
            INDEX idx_gang_seconds (gang, seconds)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_bank_log (
            id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            gang       VARCHAR(32)  NOT NULL,
            name       VARCHAR(64)  NOT NULL DEFAULT '',
            kind       VARCHAR(12)  NOT NULL,
            amount     BIGINT UNSIGNED NOT NULL,
            note       VARCHAR(64)  NOT NULL DEFAULT '',
            created_at INT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            INDEX idx_gang_id (gang, id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

return db
