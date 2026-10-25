<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();

    foreach (['products', 'services', 'business_ideas', 'investor_chats', 'investor_chat_messages'] as $table) {
        $statement = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $statement->execute(['table_name' => $table]);
        if ((int) $statement->fetchColumn() === 0) {
            throw new RuntimeException('Required table "' . $table . '" is missing. Import schema.sql first.');
        }
    }

    $connection->exec(
        'CREATE TABLE IF NOT EXISTS service_images (
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
        ) ENGINE=InnoDB'
    );

    $columns = [];
    $columnStatement = $connection->prepare(
        'SELECT column_name FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = \'business_ideas\''
    );
    $columnStatement->execute();
    foreach ($columnStatement->fetchAll(PDO::FETCH_COLUMN) as $column) {
        $columns[$column] = true;
    }

    if (!isset($columns['industry'])) {
        $connection->exec(
            'ALTER TABLE business_ideas
             ADD COLUMN industry VARCHAR(100) NOT NULL DEFAULT \'Other\''
        );
    }
    if (!isset($columns['expires_at'])) {
        $connection->exec(
            'ALTER TABLE business_ideas ADD COLUMN expires_at DATETIME NULL'
        );
    }
    $connection->exec(
        'UPDATE business_ideas
         SET expires_at = DATE_ADD(created_at, INTERVAL 30 DAY)
         WHERE expires_at IS NULL'
    );
    $connection->exec(
        'ALTER TABLE business_ideas
         MODIFY expires_at DATETIME NOT NULL'
    );

    $connection->exec(
        'CREATE TABLE IF NOT EXISTS marketplace_chats (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            listing_type ENUM(\'product\', \'service\') NOT NULL,
            listing_id BIGINT UNSIGNED NOT NULL,
            seller_role ENUM(\'student\', \'lecturer\', \'admin\', \'investor\') NOT NULL,
            seller_id BIGINT UNSIGNED NOT NULL,
            buyer_role ENUM(\'student\', \'lecturer\', \'admin\', \'investor\') NOT NULL,
            buyer_id BIGINT UNSIGNED NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_marketplace_chat_listing_buyer
              (listing_type, listing_id, buyer_role, buyer_id),
            KEY idx_marketplace_chats_seller (seller_role, seller_id, updated_at),
            KEY idx_marketplace_chats_buyer (buyer_role, buyer_id, updated_at)
        ) ENGINE=InnoDB'
    );
    $connection->exec(
        'CREATE TABLE IF NOT EXISTS marketplace_chat_messages (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            chat_id BIGINT UNSIGNED NOT NULL,
            sender_role ENUM(\'student\', \'lecturer\', \'admin\', \'investor\') NOT NULL,
            sender_id BIGINT UNSIGNED NOT NULL,
            body TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_marketplace_chat_messages_chat (chat_id, id),
            CONSTRAINT fk_marketplace_chat_message_chat
              FOREIGN KEY (chat_id) REFERENCES marketplace_chats (id) ON DELETE CASCADE
        ) ENGINE=InnoDB'
    );

    fwrite(STDOUT, "Marketplace service images, idea deadlines, and marketplace chats are ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Marketplace/idea migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
