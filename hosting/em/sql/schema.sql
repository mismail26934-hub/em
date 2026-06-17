-- Database setup for Fleet EM Dashboard (list1 / tb_list1)
-- Import via phpMyAdmin or: mysql -u root < hosting/em/sql/schema.sql

CREATE DATABASE IF NOT EXISTS `db_em`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

USE `db_em`;

CREATE TABLE IF NOT EXISTS `tb_list1` (
  `id_list1` int(100) NOT NULL AUTO_INCREMENT,
  `name_list1` text NOT NULL,
  `id_upload_list1` int(11) NOT NULL DEFAULT 1,
  `date_upload_list1` datetime NOT NULL,
  PRIMARY KEY (`id_list1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Satu baris aktif untuk file Excel list1 (opsional; upload akan INSERT jika kosong)
INSERT INTO `tb_list1` (`name_list1`, `id_upload_list1`, `date_upload_list1`)
SELECT '', 1, NOW()
WHERE NOT EXISTS (SELECT 1 FROM `tb_list1` LIMIT 1);
