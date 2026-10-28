<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();
    foreach (['investors', 'products', 'services'] as $table) {
        $statement = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $statement->execute(['table_name' => $table]);
        if ((int) $statement->fetchColumn() === 0) {
            throw new RuntimeException(
                'Required table "' . $table . '" is missing. Run the earlier migrations first.'
            );
        }
    }

    $connection->exec(
        'CREATE TABLE IF NOT EXISTS marketplace_purchases (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            investor_id BIGINT UNSIGNED NOT NULL,
            listing_type ENUM(\'product\', \'service\') NOT NULL,
            listing_id BIGINT UNSIGNED NOT NULL,
            listing_title VARCHAR(150) NOT NULL,
            gateway_reference VARCHAR(40) NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            currency CHAR(3) NOT NULL DEFAULT \'ZAR\',
            payment_status ENUM(\'pending\', \'paid\', \'failed\') NOT NULL DEFAULT \'pending\',
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
        ) ENGINE=InnoDB'
    );

    fwrite(STDOUT, "Marketplace purchase payments are ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Marketplace purchase migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
