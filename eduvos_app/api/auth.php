<?php

require_once __DIR__ . '/db.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

function respond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_SLASHES);
    exit;
}

function get_request_data(): array
{
    try {
        $data = json_decode(file_get_contents('php://input'), true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        respond(400, ['success' => false, 'message' => 'Request body must be valid JSON.']);
    }

    if (!is_array($data)) {
        respond(400, ['success' => false, 'message' => 'Request body must be a JSON object.']);
    }

    return $data;
}

function required_string(array $data, string $field, int $maxLength): string
{
    $value = $data[$field] ?? null;
    if (!is_string($value) || trim($value) === '' || strlen(trim($value)) > $maxLength) {
        respond(422, ['success' => false, 'message' => 'Please provide a valid ' . str_replace('_', ' ', $field) . '.']);
    }

    return trim($value);
}

function role_tables(): array
{
    return [
        'student' => 'students',
        'lecturer' => 'lecturers',
        'admin' => 'admins',
    ];
}

function public_profile(PDO $connection, string $role, int $accountId): ?array
{
    $queries = [
        'student' => 'SELECT id, first_name, surname, email, student_number,
                             NULL AS lecturer_number, phone_number
                      FROM students WHERE id = :id',
        'lecturer' => 'SELECT id, first_name, surname, email,
                              NULL AS student_number, lecturer_number, phone_number
                       FROM lecturers WHERE id = :id',
        'admin' => 'SELECT id, name AS first_name, \'\' AS surname, email,
                           NULL AS student_number, NULL AS lecturer_number,
                           NULL AS phone_number
                    FROM admins WHERE id = :id',
    ];
    if (!isset($queries[$role])) {
        return null;
    }

    $statement = $connection->prepare($queries[$role]);
    $statement->execute(['id' => $accountId]);
    $profile = $statement->fetch();
    if (!$profile) {
        return null;
    }

    $profile['id'] = (int) $profile['id'];
    $profile['role'] = $role;
    return $profile;
}

function create_api_token(PDO $connection, string $role, int $accountId): string
{
    $token = bin2hex(random_bytes(32));
    $statement = $connection->prepare(
        'INSERT INTO auth_tokens (account_role, account_id, token_hash, expires_at)
         VALUES (:role, :account_id, :token_hash, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))'
    );
    $statement->execute([
        'role' => $role,
        'account_id' => $accountId,
        'token_hash' => hash('sha256', $token),
    ]);

    return $token;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    $connection = get_database_connection();

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if ($authorization === '' && function_exists('getallheaders')) {
            foreach (getallheaders() as $name => $value) {
                if (strcasecmp($name, 'Authorization') === 0 && is_string($value)) {
                    $authorization = $value;
                    break;
                }
            }
        }
        if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $authorization, $matches)) {
            respond(401, ['success' => false, 'message' => 'A valid bearer token is required.']);
        }

        $statement = $connection->prepare(
            'SELECT account_role, account_id
             FROM auth_tokens
             WHERE token_hash = :token_hash AND expires_at > UTC_TIMESTAMP()
             LIMIT 1'
        );
        $statement->execute(['token_hash' => hash('sha256', $matches[1])]);
        $token = $statement->fetch();

        if (!$token) {
            respond(401, ['success' => false, 'message' => 'Your session is invalid or has expired.']);
        }

        $profile = public_profile($connection, $token['account_role'], (int) $token['account_id']);
        if (!$profile) {
            respond(401, ['success' => false, 'message' => 'Your account no longer exists.']);
        }

        respond(200, ['success' => true, 'data' => $profile]);
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        header('Allow: GET, POST, OPTIONS');
        respond(405, ['success' => false, 'message' => 'Method not allowed.']);
    }

    $data = get_request_data();
    $action = $_GET['action'] ?? ($data['action'] ?? '');
    $tables = role_tables();

    if ($action === 'signup') {
        $role = $data['role'] ?? null;
        if (!is_string($role) || !in_array($role, ['student', 'lecturer'], true)) {
            respond(422, ['success' => false, 'message' => 'Choose student or lecturer to create an account.']);
        }

        $firstName = required_string($data, 'first_name', 100);
        $surname = required_string($data, 'surname', 100);
        $email = strtolower(required_string($data, 'email', 254));
        $password = $data['password'] ?? null;
        $phoneNumber = required_string($data, 'phone_number', 25);

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            respond(422, ['success' => false, 'message' => 'Enter a valid email address.']);
        }
        if (!is_string($password) || strlen($password) < 8) {
            respond(422, ['success' => false, 'message' => 'Password must be at least 8 characters.']);
        }
        if (!preg_match('/^[0-9+().\-\s]{7,25}$/', $phoneNumber) ||
            strlen(preg_replace('/\D/', '', $phoneNumber)) < 7) {
            respond(422, ['success' => false, 'message' => 'Enter a valid phone number.']);
        }

        $numberColumn = null;
        $institutionNumber = null;
        if ($role === 'student') {
            $numberColumn = 'student_number';
            $institutionNumber = required_string($data, $numberColumn, 100);
        } else {
            $numberColumn = 'lecturer_number';
            $institutionNumber = required_string($data, $numberColumn, 100);
        }

        $columns = 'first_name, surname, email, password_hash, phone_number';
        $values = ':first_name, :surname, :email, :password_hash, :phone_number';
        if ($numberColumn !== null) {
            $columns .= ', ' . $numberColumn;
            $values .= ', :institution_number';
        }

        $connection->beginTransaction();
        $statement = $connection->prepare(
            'INSERT INTO ' . $tables[$role] . ' (' . $columns . ') VALUES (' . $values . ')'
        );
        $parameters = [
            'first_name' => $firstName,
            'surname' => $surname,
            'email' => $email,
            'password_hash' => password_hash($password, PASSWORD_DEFAULT),
            'phone_number' => $phoneNumber,
        ];
        if ($numberColumn !== null) {
            $parameters['institution_number'] = $institutionNumber;
        }
        $statement->execute($parameters);

        $accountId = (int) $connection->lastInsertId();
        $token = create_api_token($connection, $role, $accountId);
        $connection->commit();
        $profile = public_profile($connection, $role, $accountId);

        respond(201, [
            'success' => true,
            'message' => 'Account created successfully.',
            'data' => ['token' => $token, 'profile' => $profile],
        ]);
    }

    if ($action === 'login') {
        $role = $data['role'] ?? null;
        if (!is_string($role) || !isset($tables[$role])) {
            respond(422, ['success' => false, 'message' => 'Choose the role for your account.']);
        }

        $email = strtolower(required_string($data, 'email', 254));
        $password = $data['password'] ?? null;
        if (!is_string($password) || $password === '') {
            respond(422, ['success' => false, 'message' => 'Enter your password.']);
        }

        $statement = $connection->prepare(
            'SELECT id, password_hash FROM ' . $tables[$role] . ' WHERE email = :email LIMIT 1'
        );
        $statement->execute(['email' => $email]);
        $account = $statement->fetch();

        if (!$account || !password_verify($password, $account['password_hash'])) {
            respond(401, ['success' => false, 'message' => 'Email or password is incorrect.']);
        }

        $token = create_api_token($connection, $role, (int) $account['id']);
        $profile = public_profile($connection, $role, (int) $account['id']);
        respond(200, [
            'success' => true,
            'message' => 'Signed in successfully.',
            'data' => ['token' => $token, 'profile' => $profile],
        ]);
    }

    respond(400, ['success' => false, 'message' => 'Use action=signup or action=login.']);
} catch (PDOException $exception) {
    if (isset($connection) && $connection->inTransaction()) {
        $connection->rollBack();
    }
    error_log('Eduvos API database error: ' . $exception->getMessage());
    if ($exception->getCode() === '23000') {
        respond(409, ['success' => false, 'message' => 'An account already exists with that email or number in this role.']);
    }
    respond(500, [
        'success' => false,
        'message' => 'MySQL could not complete the request. Check that XAMPP MySQL is running, the eduvos_db tables are imported, and api/db_config.php has the correct credentials.',
    ]);
}
