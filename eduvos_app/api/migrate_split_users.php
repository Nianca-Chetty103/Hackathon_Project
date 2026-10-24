<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db.php';

function migration_table_exists(PDO $connection, string $table): bool
{
    $statement = $connection->prepare(
        'SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name = :table_name'
    );
    $statement->execute(['table_name' => $table]);
    return (int) $statement->fetchColumn() > 0;
}

try {
    $connection = get_database_connection();
    foreach (['users', 'api_tokens', 'students', 'lecturers', 'admins', 'auth_tokens'] as $table) {
        if (!migration_table_exists($connection, $table)) {
            throw new RuntimeException(
                'Required table "' . $table . '" is missing. Keep the legacy users and api_tokens tables, and import the new role-table schema before migrating.'
            );
        }
    }

    $connection->beginTransaction();

    $students = $connection->exec(
        'INSERT IGNORE INTO students
            (id, first_name, surname, email, password_hash, student_number, phone_number, created_at)
         SELECT id, first_name, surname, email, password_hash, student_number, phone_number, created_at
         FROM users
         WHERE role = \'student\''
    );
    $lecturers = $connection->exec(
        'INSERT IGNORE INTO lecturers
            (id, first_name, surname, email, password_hash, lecturer_number, phone_number, created_at)
         SELECT id, first_name, surname, email, password_hash, lecturer_number, phone_number, created_at
         FROM users
         WHERE role = \'lecturer\''
    );
    $admins = $connection->exec(
        "INSERT IGNORE INTO admins (id, name, email, password_hash, created_at)
         SELECT id, CONCAT_WS(' ', first_name, surname), email, password_hash, created_at
         FROM users
         WHERE role = 'admin'"
    );
    $tokens = $connection->exec(
        'INSERT IGNORE INTO auth_tokens
            (account_role, account_id, token_hash, expires_at, created_at)
         SELECT users.role, users.id, api_tokens.token_hash, api_tokens.expires_at, api_tokens.created_at
         FROM api_tokens
         INNER JOIN users ON users.id = api_tokens.user_id'
    );

    $connection->commit();
    fwrite(
        STDOUT,
        sprintf(
            "Migration completed. Copied %d students, %d lecturers, %d admins, and %d tokens.\n",
            $students,
            $lecturers,
            $admins,
            $tokens
        )
    );
} catch (Throwable $exception) {
    if (isset($connection) && $connection->inTransaction()) {
        $connection->rollBack();
    }
    fwrite(STDERR, 'Split-users migration failed: ' . $exception->getMessage() . "\n");
    exit(1);
}
