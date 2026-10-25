<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();
    foreach (['communities', 'community_memberships'] as $table) {
        $statement = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $statement->execute(['table_name' => $table]);
        if ((int) $statement->fetchColumn() === 0) {
            throw new RuntimeException(
                'Required table "' . $table . '" is missing. Import schema.sql first.'
            );
        }
    }

    $columns = [
        'created_by_role' => "ENUM('student', 'lecturer', 'admin', 'investor') NULL",
        'created_by_id' => 'BIGINT UNSIGNED NULL',
    ];
    foreach ($columns as $column => $definition) {
        $statement = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE()
               AND table_name = \'communities\'
               AND column_name = :column_name'
        );
        $statement->execute(['column_name' => $column]);
        if ((int) $statement->fetchColumn() === 0) {
            $connection->exec(
                'ALTER TABLE communities ADD COLUMN ' . $column . ' ' . $definition
            );
        }
    }

    $connection->exec(
        "CREATE TABLE IF NOT EXISTS community_chat_messages (
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
        ) ENGINE=InnoDB"
    );

    fwrite(STDOUT, "Community creation and group chat tables are ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Community chat migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
