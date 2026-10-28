<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();
    foreach (['business_ideas', 'investors', 'entrepreneurial_posts'] as $table) {
        $statement = $connection->prepare(
            'SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = :table_name'
        );
        $statement->execute(['table_name' => $table]);
        if ((int) $statement->fetchColumn() === 0) {
            throw new RuntimeException(
                'Required table "' . $table . '" is missing. Run the existing feature migrations first.'
            );
        }
    }

    $connection->exec(
        "ALTER TABLE entrepreneurial_posts
         MODIFY author_role ENUM('lecturer', 'admin', 'investor') NOT NULL"
    );
    $connection->exec(
        'CREATE TABLE IF NOT EXISTS auction_offers (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            idea_id BIGINT UNSIGNED NOT NULL,
            investor_id BIGINT UNSIGNED NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            message VARCHAR(2000) NOT NULL DEFAULT \'\',
            offer_status ENUM(\'pending\', \'accepted\', \'rejected\') NOT NULL DEFAULT \'pending\',
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
        ) ENGINE=InnoDB'
    );

    fwrite(STDOUT, "Auction offers and investor advice publishing are ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Auction/investor advice migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
