<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

try {
    $connection = get_database_connection();
    $tableStatement = $connection->prepare(
        'SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name = :table_name'
    );
    $tableStatement->execute(['table_name' => 'bursaries']);
    if ((int) $tableStatement->fetchColumn() === 0) {
        throw new RuntimeException('The bursaries table does not exist. Import schema.sql first.');
    }

    $columnStatement = $connection->prepare(
        'SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE()
           AND table_name = :table_name
           AND column_name = :column_name'
    );
    $columnStatement->execute([
        'table_name' => 'bursaries',
        'column_name' => 'company_name',
    ]);
    if ((int) $columnStatement->fetchColumn() === 0) {
        $connection->exec(
            "ALTER TABLE bursaries
             ADD COLUMN company_name VARCHAR(200) NOT NULL DEFAULT '' AFTER id"
        );
    }

    fwrite(STDOUT, "Bursaries company_name column is ready.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Bursaries migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
