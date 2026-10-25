<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();
    foreach (['business_ideas', 'students', 'investors', 'investor_chats', 'investor_chat_messages'] as $table) {
        $statement = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $statement->execute(['table_name' => $table]);
        if ((int) $statement->fetchColumn() === 0) {
            throw new RuntimeException('Required table "' . $table . '" is missing. Run the earlier migrations first.');
        }
    }

    $connection->exec(
        'CREATE TABLE IF NOT EXISTS idea_interests (
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
        ) ENGINE=InnoDB'
    );
    $connection->exec(
        'CREATE TABLE IF NOT EXISTS idea_interest_payments (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            interest_id BIGINT UNSIGNED NOT NULL,
            gateway_reference VARCHAR(40) NOT NULL,
            amount DECIMAL(8, 2) NOT NULL DEFAULT 200.00,
            currency CHAR(3) NOT NULL DEFAULT \'ZAR\',
            payment_status ENUM(\'pending\', \'paid\', \'failed\') NOT NULL DEFAULT \'pending\',
            checkout_token_hash CHAR(64) NULL,
            checkout_expires_at DATETIME NULL,
            payfast_payment_id VARCHAR(100) NULL,
            verification_source ENUM(\'payfast\', \'admin\') NULL,
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
        ) ENGINE=InnoDB'
    );

    fwrite(STDOUT, "Idea interest notifications and fee payments are ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Idea interest/payment migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
