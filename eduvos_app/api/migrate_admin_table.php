<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

function has_table(PDO $connection, string $table): bool
{
    $statement = $connection->prepare(
        'SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name = :table_name'
    );
    $statement->execute(['table_name' => $table]);
    return (int) $statement->fetchColumn() > 0;
}

function has_column(PDO $connection, string $table, string $column): bool
{
    $statement = $connection->prepare(
        'SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = DATABASE()
           AND table_name = :table_name
           AND column_name = :column_name'
    );
    $statement->execute([
        'table_name' => $table,
        'column_name' => $column,
    ]);
    return (int) $statement->fetchColumn() > 0;
}

try {
    $connection = get_database_connection();
    if (!has_table($connection, 'admins')) {
        throw new RuntimeException('The admins table does not exist. Import schema.sql first.');
    }

    $hasFirstName = has_column($connection, 'admins', 'first_name');
    $hasSurname = has_column($connection, 'admins', 'surname');
    $hasName = has_column($connection, 'admins', 'name');

    if (!$hasName) {
        if (!$hasFirstName || !$hasSurname) {
            throw new RuntimeException(
                'Cannot build admins.name: expected either name or both first_name and surname columns.'
            );
        }
        $connection->exec('ALTER TABLE admins ADD COLUMN name VARCHAR(201) NULL AFTER id');
        $hasName = true;
    }

    if ($hasName && $hasFirstName && $hasSurname) {
        $connection->exec(
            "UPDATE admins
             SET name = TRIM(CONCAT_WS(' ', first_name, surname))
             WHERE name IS NULL OR name = ''"
        );
    }

    $connection->exec('ALTER TABLE admins MODIFY name VARCHAR(201) NOT NULL');

    $columnsToDrop = [];
    foreach (['first_name', 'surname', 'phone_number'] as $column) {
        if (has_column($connection, 'admins', $column)) {
            $columnsToDrop[] = 'DROP COLUMN ' . $column;
        }
    }
    if ($columnsToDrop !== []) {
        $connection->exec('ALTER TABLE admins ' . implode(', ', $columnsToDrop));
    }

    fwrite(STDOUT, "Admin table migration completed successfully.\n");
} catch (Throwable $exception) {
    fwrite(STDERR, 'Admin table migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
