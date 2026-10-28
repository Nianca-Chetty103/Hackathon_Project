<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);
    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        if ($account['account_role'] === 'investor') {
            api_respond(403, ['success' => false, 'message' => 'Investors cannot view bursaries.']);
        }
        $bursaries = $connection->query(
            'SELECT id, company_name, name, details, application_url, created_at
             FROM bursaries ORDER BY created_at DESC, id DESC'
        )->fetchAll(PDO::FETCH_ASSOC);
        foreach ($bursaries as &$bursary) {
            $bursary['id'] = (int) $bursary['id'];
        }
        unset($bursary);

        api_respond(200, ['success' => true, 'data' => $bursaries]);
    }

    if ($method === 'POST') {
        if ($account['account_role'] !== 'admin') {
            api_respond(403, ['success' => false, 'message' => 'Only administrators can post bursaries.']);
        }

        $data = api_read_json();
        if (($data['action'] ?? '') !== 'create') {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid bursary action.']);
        }

        $companyName = api_required_string($data, 'company_name', 200);
        $name = api_required_string($data, 'name', 200);
        $details = api_required_string($data, 'details', 5000);
        $applicationUrl = api_required_string($data, 'application_url', 2048);
        $urlParts = parse_url($applicationUrl);
        if (
            filter_var($applicationUrl, FILTER_VALIDATE_URL) === false
            || !is_array($urlParts)
            || !isset($urlParts['scheme'], $urlParts['host'])
            || !in_array(strtolower($urlParts['scheme']), ['http', 'https'], true)
        ) {
            api_respond(422, ['success' => false, 'message' => 'Enter a valid bursary website link starting with http:// or https://.']);
        }

        $statement = $connection->prepare(
            'INSERT INTO bursaries (company_name, name, details, application_url)
             VALUES (:company_name, :name, :details, :application_url)'
        );
        $statement->execute([
            'company_name' => $companyName,
            'name' => $name,
            'details' => $details,
            'application_url' => $applicationUrl,
        ]);

        api_respond(201, [
            'success' => true,
            'message' => 'Bursary posted.',
            'id' => (int) $connection->lastInsertId(),
        ]);
    }

    header('Allow: GET, POST, OPTIONS');
    api_respond(405, ['success' => false, 'message' => 'Use GET or a supported POST action.']);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
