<?php

require_once __DIR__ . '/db.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

function api_respond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_SLASHES);
    exit;
}

function api_read_json(): array
{
    try {
        $data = json_decode(file_get_contents('php://input'), true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        api_respond(400, ['success' => false, 'message' => 'Request body must be valid JSON.']);
    }

    if (!is_array($data)) {
        api_respond(400, ['success' => false, 'message' => 'Request body must be a JSON object.']);
    }

    return $data;
}

function api_required_string(array $data, string $field, int $maxLength): string
{
    $value = $data[$field] ?? null;
    if (!is_string($value) || trim($value) === '' || strlen(trim($value)) > $maxLength) {
        api_respond(422, ['success' => false, 'message' => 'Please provide a valid ' . str_replace('_', ' ', $field) . '.']);
    }

    return trim($value);
}

function api_authenticated_account(PDO $connection): array
{
    $token = api_bearer_token();
    if ($token === null) {
        api_respond(401, ['success' => false, 'message' => 'A valid bearer token is required.']);
    }

    $statement = $connection->prepare(
        'SELECT account_role, account_id
         FROM auth_tokens
         WHERE token_hash = :token_hash AND expires_at > UTC_TIMESTAMP()
         LIMIT 1'
    );
    $statement->execute(['token_hash' => hash('sha256', $token)]);
    $account = $statement->fetch(PDO::FETCH_ASSOC);
    if (!$account) {
        api_respond(401, ['success' => false, 'message' => 'Your session is invalid or has expired.']);
    }

    $account['account_id'] = (int) $account['account_id'];
    return $account;
}

function api_bearer_token(): ?string
{
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($authorization === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0 && is_string($value)) {
                $authorization = $value;
                break;
            }
        }
    }

    return preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $authorization, $matches)
        ? $matches[1]
        : null;
}

function api_require_student(array $account): void
{
    if ($account['account_role'] !== 'student') {
        api_respond(403, ['success' => false, 'message' => 'Only student accounts can create this content.']);
    }
}

function api_owner_name(PDO $connection, string $role, int $accountId): string
{
    $queries = [
        'student' => 'SELECT CONCAT(first_name, \' \', surname) FROM students WHERE id = :id',
        'lecturer' => 'SELECT CONCAT(first_name, \' \', surname) FROM lecturers WHERE id = :id',
        'investor' => 'SELECT CONCAT(first_name, \' \', surname) FROM investors WHERE id = :id',
        'admin' => 'SELECT name FROM admins WHERE id = :id',
    ];
    if (!isset($queries[$role])) {
        return 'Eduvos member';
    }

    $statement = $connection->prepare($queries[$role]);
    $statement->execute(['id' => $accountId]);
    $name = $statement->fetchColumn();
    return is_string($name) && $name !== '' ? $name : 'Eduvos member';
}

function api_handle_options(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function api_handle_database_error(PDOException $exception): void
{
    error_log('Eduvos feature API database error: ' . $exception->getMessage());
    api_respond(500, [
        'success' => false,
        'message' => 'MySQL could not complete the request. Check that the feature tables have been created from api/schema.sql.',
    ]);
}
