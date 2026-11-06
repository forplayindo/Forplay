-- Ganti domain email HP: @forplay.com -> @4play.com (configs/mail.lua Domain = '4play.com').
-- Jalankan SEKALI di database Qbox_A058BF saat server MATI (sebelum start dengan config baru),
-- supaya tidak ada yang sempat mendaftar alamat @4play.com yang bentrok dengan akun lama.
-- Mengganti substring '@forplay.com' di semua kolom teks/JSON pada database ini
-- (akun mail, sesi, saved emails, akun app lain, isi pesan, kontak, dll). Password tidak terpengaruh.

DELIMITER //
DROP PROCEDURE IF EXISTS f_ganti_domain_4play //
CREATE PROCEDURE f_ganti_domain_4play()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE t VARCHAR(128);
    DECLARE c VARCHAR(128);
    DECLARE cur CURSOR FOR
        SELECT col.TABLE_NAME, col.COLUMN_NAME
        FROM information_schema.COLUMNS col
        JOIN information_schema.TABLES tb
          ON tb.TABLE_SCHEMA = col.TABLE_SCHEMA AND tb.TABLE_NAME = col.TABLE_NAME
        WHERE col.TABLE_SCHEMA = DATABASE()
          AND tb.TABLE_TYPE = 'BASE TABLE'
          AND col.DATA_TYPE IN ('char', 'varchar', 'tinytext', 'text', 'mediumtext', 'longtext', 'json');
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;
    loop_cols: LOOP
        FETCH cur INTO t, c;
        IF done THEN LEAVE loop_cols; END IF;
        SET @q = CONCAT('UPDATE `', t, '` SET `', c, '` = REPLACE(`', c, '`, ''@forplay.com'', ''@4play.com'') WHERE `', c, '` LIKE ''%@forplay.com%''');
        PREPARE s FROM @q;
        EXECUTE s;
        SET @n = ROW_COUNT();
        IF @n > 0 THEN
            SELECT t AS tabel, c AS kolom, @n AS baris_diubah;
        END IF;
        DEALLOCATE PREPARE s;
    END LOOP;
    CLOSE cur;
END //
DELIMITER ;

CALL f_ganti_domain_4play();
DROP PROCEDURE f_ganti_domain_4play;
