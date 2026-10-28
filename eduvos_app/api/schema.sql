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

CREATE TABLE IF NOT EXISTS investors (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(100) NOT NULL,
  surname VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone_number VARCHAR(25) NOT NULL,
  company_name VARCHAR(200) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_investors_email (email)
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
  account_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
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
  account_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
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

CREATE TABLE IF NOT EXISTS service_images (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  service_id BIGINT UNSIGNED NOT NULL,
  image_path VARCHAR(255) NOT NULL,
  mime_type VARCHAR(50) NOT NULL,
  file_size INT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_service_image_service (service_id),
  CONSTRAINT fk_service_image_service
    FOREIGN KEY (service_id) REFERENCES services (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS marketplace_purchases (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  investor_id BIGINT UNSIGNED NOT NULL,
  listing_type ENUM('product', 'service') NOT NULL,
  listing_id BIGINT UNSIGNED NOT NULL,
  listing_title VARCHAR(150) NOT NULL,
  gateway_reference VARCHAR(40) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'ZAR',
  payment_status ENUM('pending', 'paid', 'failed') NOT NULL DEFAULT 'pending',
  checkout_token_hash CHAR(64) NULL,
  checkout_expires_at DATETIME NULL,
  payfast_payment_id VARCHAR(100) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_marketplace_purchase_reference (gateway_reference),
  UNIQUE KEY uq_marketplace_purchase_checkout_token (checkout_token_hash),
  UNIQUE KEY uq_marketplace_purchase_payfast_id (payfast_payment_id),
  KEY idx_marketplace_purchases_investor (investor_id, created_at),
  KEY idx_marketplace_purchases_listing (listing_type, listing_id),
  KEY idx_marketplace_purchases_status (payment_status, created_at),
  CONSTRAINT fk_marketplace_purchase_investor
    FOREIGN KEY (investor_id) REFERENCES investors (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS communities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL,
  description VARCHAR(500) NOT NULL,
  created_by_role ENUM('student', 'lecturer', 'admin', 'investor') NULL,
  created_by_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_communities_name (name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS community_chat_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  community_id BIGINT UNSIGNED NOT NULL,
  sender_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
  sender_id BIGINT UNSIGNED NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_community_chat_messages_community (community_id, id),
  CONSTRAINT fk_community_chat_message_community
    FOREIGN KEY (community_id) REFERENCES communities (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS community_memberships (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  community_id BIGINT UNSIGNED NOT NULL,
  account_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
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
  industry VARCHAR(100) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_business_ideas_created_at (created_at),
  KEY idx_business_ideas_owner (owner_role, owner_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS marketplace_chats (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_type ENUM('product', 'service') NOT NULL,
  listing_id BIGINT UNSIGNED NOT NULL,
  seller_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
  seller_id BIGINT UNSIGNED NOT NULL,
  buyer_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
  buyer_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_marketplace_chat_listing_buyer
    (listing_type, listing_id, buyer_role, buyer_id),
  KEY idx_marketplace_chats_seller (seller_role, seller_id, updated_at),
  KEY idx_marketplace_chats_buyer (buyer_role, buyer_id, updated_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS marketplace_chat_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chat_id BIGINT UNSIGNED NOT NULL,
  sender_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL,
  sender_id BIGINT UNSIGNED NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_marketplace_chat_messages_chat (chat_id, id),
  CONSTRAINT fk_marketplace_chat_message_chat
    FOREIGN KEY (chat_id) REFERENCES marketplace_chats (id) ON DELETE CASCADE
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

CREATE TABLE IF NOT EXISTS entrepreneurial_posts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  author_role ENUM('lecturer', 'admin', 'investor') NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_entrepreneurial_posts_created (created_at, id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS entrepreneurial_post_comments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  post_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  body VARCHAR(3000) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_entrepreneurial_comments_post (post_id, created_at, id),
  CONSTRAINT fk_entrepreneurial_comment_post
    FOREIGN KEY (post_id) REFERENCES entrepreneurial_posts (id) ON DELETE CASCADE,
  CONSTRAINT fk_entrepreneurial_comment_student
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS entrepreneurial_post_reactions (
  post_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, student_id),
  CONSTRAINT fk_entrepreneurial_reaction_post
    FOREIGN KEY (post_id) REFERENCES entrepreneurial_posts (id) ON DELETE CASCADE,
  CONSTRAINT fk_entrepreneurial_reaction_student
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS investor_chats (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idea_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  investor_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_investor_chat_idea_investor (idea_id, investor_id),
  KEY idx_investor_chats_student (student_id, updated_at),
  KEY idx_investor_chats_investor (investor_id, updated_at),
  CONSTRAINT fk_investor_chat_idea
    FOREIGN KEY (idea_id) REFERENCES business_ideas (id) ON DELETE CASCADE,
  CONSTRAINT fk_investor_chat_student
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
  CONSTRAINT fk_investor_chat_investor
    FOREIGN KEY (investor_id) REFERENCES investors (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS investor_chat_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chat_id BIGINT UNSIGNED NOT NULL,
  sender_role ENUM('student', 'investor') NOT NULL,
  sender_id BIGINT UNSIGNED NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_investor_chat_messages_chat (chat_id, id),
  CONSTRAINT fk_investor_chat_message_chat
    FOREIGN KEY (chat_id) REFERENCES investor_chats (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS idea_interests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idea_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  investor_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_idea_interest_idea_investor (idea_id, investor_id),
  KEY idx_idea_interests_student (student_id, created_at),
  CONSTRAINT fk_idea_interest_idea
    FOREIGN KEY (idea_id) REFERENCES business_ideas (id) ON DELETE CASCADE,
  CONSTRAINT fk_idea_interest_student
    FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
  CONSTRAINT fk_idea_interest_investor
    FOREIGN KEY (investor_id) REFERENCES investors (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS idea_interest_payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  interest_id BIGINT UNSIGNED NOT NULL,
  gateway_reference VARCHAR(40) NOT NULL,
  amount DECIMAL(8, 2) NOT NULL DEFAULT 200.00,
  currency CHAR(3) NOT NULL DEFAULT 'ZAR',
  payment_status ENUM('pending', 'paid', 'failed') NOT NULL DEFAULT 'pending',
  checkout_token_hash CHAR(64) NULL,
  checkout_expires_at DATETIME NULL,
  payfast_payment_id VARCHAR(100) NULL,
  verification_source ENUM('payfast', 'admin') NULL,
  verified_by_admin_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_idea_interest_payment_interest (interest_id),
  UNIQUE KEY uq_idea_interest_payment_reference (gateway_reference),
  UNIQUE KEY uq_idea_interest_payment_checkout_token (checkout_token_hash),
  UNIQUE KEY uq_idea_interest_payment_payfast_id (payfast_payment_id),
  KEY idx_idea_interest_payments_status (payment_status, created_at),
  CONSTRAINT fk_idea_interest_payment_interest
    FOREIGN KEY (interest_id) REFERENCES idea_interests (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auction_offers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idea_id BIGINT UNSIGNED NOT NULL,
  investor_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  message VARCHAR(2000) NOT NULL DEFAULT '',
  offer_status ENUM('pending', 'accepted', 'rejected') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  accepted_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_auction_offer_idea_investor (idea_id, investor_id),
  KEY idx_auction_offers_idea_status (idea_id, offer_status, created_at),
  CONSTRAINT fk_auction_offer_idea
    FOREIGN KEY (idea_id) REFERENCES business_ideas (id) ON DELETE CASCADE,
  CONSTRAINT fk_auction_offer_investor
    FOREIGN KEY (investor_id) REFERENCES investors (id) ON DELETE CASCADE
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
