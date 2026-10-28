<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();

    $requiredTables = ['students', 'business_ideas', 'auth_tokens', 'account_settings', 'community_memberships'];
    foreach ($requiredTables as $table) {
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
        'CREATE TABLE IF NOT EXISTS investors (
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
        ) ENGINE=InnoDB'
    );
    $connection->exec(
        "ALTER TABLE auth_tokens
         MODIFY account_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL"
    );
    $connection->exec(
        "ALTER TABLE account_settings
         MODIFY account_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL"
    );
    $connection->exec(
        "ALTER TABLE community_memberships
         MODIFY account_role ENUM('student', 'lecturer', 'admin', 'investor') NOT NULL"
    );
    $connection->exec(
        "CREATE TABLE IF NOT EXISTS entrepreneurial_posts (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            author_role ENUM('lecturer', 'admin', 'investor') NOT NULL,
            author_id BIGINT UNSIGNED NOT NULL,
            title VARCHAR(200) NOT NULL,
            body TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_entrepreneurial_posts_created (created_at, id)
        ) ENGINE=InnoDB"
    );
    $connection->exec(
        'CREATE TABLE IF NOT EXISTS entrepreneurial_post_comments (
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
        ) ENGINE=InnoDB'
    );
    $connection->exec(
        'CREATE TABLE IF NOT EXISTS entrepreneurial_post_reactions (
            post_id BIGINT UNSIGNED NOT NULL,
            student_id BIGINT UNSIGNED NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (post_id, student_id),
            CONSTRAINT fk_entrepreneurial_reaction_post
              FOREIGN KEY (post_id) REFERENCES entrepreneurial_posts (id) ON DELETE CASCADE,
            CONSTRAINT fk_entrepreneurial_reaction_student
              FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        ) ENGINE=InnoDB'
    );
    $connection->exec(
        'CREATE TABLE IF NOT EXISTS investor_chats (
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
        ) ENGINE=InnoDB'
    );
    $connection->exec(
        "CREATE TABLE IF NOT EXISTS investor_chat_messages (
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
        ) ENGINE=InnoDB"
    );

    fwrite(STDOUT, "Investor, entrepreneurial blog, and private chat tables are ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Investor/blog/chat migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
