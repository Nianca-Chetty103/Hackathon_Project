CREATE DATABASE IF NOT EXISTS eduvos_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE eduvos_db;

CREATE TABLE IF NOT EXISTS students (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(100) NOT NULL,
  surname VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  student_number VARCHAR(100) NOT NULL,
  phone_number VARCHAR(25) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_students_email (email),
  UNIQUE KEY uq_students_number (student_number)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lecturers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(100) NOT NULL,
  surname VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  lecturer_number VARCHAR(100) NOT NULL,
  phone_number VARCHAR(25) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_lecturers_email (email),
  UNIQUE KEY uq_lecturers_number (lecturer_number)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admins (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(201) NOT NULL,
  email VARCHAR(254) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admins_email (email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auth_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_role ENUM('student', 'lecturer', 'admin') NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auth_tokens_hash (token_hash),
  KEY idx_auth_tokens_account (account_role, account_id),
  KEY idx_auth_tokens_expires_at (expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS account_settings (
  account_role ENUM('student', 'lecturer', 'admin') NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  dark_mode TINYINT(1) NOT NULL DEFAULT 0,
  notifications_enabled TINYINT(1) NOT NULL DEFAULT 1,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (account_role, account_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_role ENUM('student', 'lecturer', 'admin') NOT NULL,
  owner_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(150) NOT NULL,
  description TEXT NOT NULL,
  price DECIMAL(10, 2) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_products_created_at (created_at),
  KEY idx_products_owner (owner_role, owner_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_images (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT UNSIGNED NOT NULL,
  image_path VARCHAR(255) NOT NULL,
  mime_type VARCHAR(50) NOT NULL,
  file_size INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_product_images_product (product_id),
  CONSTRAINT fk_product_image_product
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS services (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_role ENUM('student', 'lecturer', 'admin') NOT NULL,
  owner_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(150) NOT NULL,
  description TEXT NOT NULL,
  price DECIMAL(10, 2) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_services_created_at (created_at),
  KEY idx_services_owner (owner_role, owner_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS communities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  description VARCHAR(500) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_communities_name (name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS community_memberships (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  community_id BIGINT UNSIGNED NOT NULL,
  account_role ENUM('student', 'lecturer', 'admin') NOT NULL,
  account_id BIGINT UNSIGNED NOT NULL,
  joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_community_member (community_id, account_role, account_id),
  KEY idx_community_membership_account (account_role, account_id),
  CONSTRAINT fk_membership_community
    FOREIGN KEY (community_id) REFERENCES communities (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS community_updates (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  community_id BIGINT UNSIGNED NOT NULL,
  message VARCHAR(1000) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_community_updates_recent (community_id, created_at),
  CONSTRAINT fk_community_update_community
    FOREIGN KEY (community_id) REFERENCES communities (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS business_ideas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_role ENUM('student', 'lecturer', 'admin') NOT NULL,
  owner_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(150) NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_business_ideas_created_at (created_at),
  KEY idx_business_ideas_owner (owner_role, owner_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bursaries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  company_name VARCHAR(200) NOT NULL,
  name VARCHAR(200) NOT NULL,
  details TEXT NOT NULL,
  application_url VARCHAR(2048) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_bursaries_created_at (created_at)
) ENGINE=InnoDB;

INSERT INTO communities (name, description)
VALUES
  ('Entrepreneurship Club', 'Meet founders, share ideas, and learn how to get started.'),
  ('Creative Arts Collective', 'A home for makers, performers, designers, and storytellers.'),
  ('Coding & Tech Society', 'Build projects together and explore the latest in tech.')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT INTO community_updates (community_id, message)
SELECT id, 'Pitch practice is happening Thursday at 16:00 in the hub.'
FROM communities
WHERE name = 'Entrepreneurship Club'
  AND NOT EXISTS (
    SELECT 1 FROM community_updates
    WHERE community_id = communities.id
      AND message = 'Pitch practice is happening Thursday at 16:00 in the hub.'
  );

INSERT INTO community_updates (community_id, message)
SELECT id, 'Open mic sign-ups are open for next week.'
FROM communities
WHERE name = 'Creative Arts Collective'
  AND NOT EXISTS (
    SELECT 1 FROM community_updates
    WHERE community_id = communities.id
      AND message = 'Open mic sign-ups are open for next week.'
  );

INSERT INTO community_updates (community_id, message)
SELECT id, 'Join the beginner-friendly app workshop this Friday.'
FROM communities
WHERE name = 'Coding & Tech Society'
  AND NOT EXISTS (
    SELECT 1 FROM community_updates
    WHERE community_id = communities.id
      AND message = 'Join the beginner-friendly app workshop this Friday.'
  );
