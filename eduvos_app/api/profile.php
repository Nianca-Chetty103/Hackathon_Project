<?php

require_once __DIR__ . '/api_common.php';

header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);
    $role = $account['account_role'];
    $accountId = $account['account_id'];
    $profileQueries = [
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
    $profileStatement = $connection->prepare($profileQueries[$role]);
    $profileStatement->execute(['id' => $accountId]);
    $profile = $profileStatement->fetch(PDO::FETCH_ASSOC);
    if (!$profile) {
        api_respond(401, ['success' => false, 'message' => 'Your account no longer exists.']);
    }

    $profile['id'] = (int) $profile['id'];
    $profile['role'] = $role;
    $settingsStatement = $connection->prepare(
        'SELECT dark_mode, notifications_enabled
         FROM account_settings
         WHERE account_role = :role AND account_id = :account_id'
    );
    $settingsStatement->execute(['role' => $role, 'account_id' => $accountId]);
    $settings = $settingsStatement->fetch(PDO::FETCH_ASSOC) ?: [
        'dark_mode' => 0,
        'notifications_enabled' => 1,
    ];
    $settings = [
        'dark_mode' => (bool) $settings['dark_mode'],
        'notifications_enabled' => (bool) $settings['notifications_enabled'],
    ];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        api_respond(200, ['success' => true, 'data' => [
            'profile' => $profile,
            'settings' => $settings,
        ]]);
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        header('Allow: GET, POST, OPTIONS');
        api_respond(405, ['success' => false, 'message' => 'Method not allowed.']);
    }

    $data = api_read_json();
    $action = $data['action'] ?? '';
    if ($action === 'logout') {
        $token = api_bearer_token();
        $statement = $connection->prepare('DELETE FROM auth_tokens WHERE token_hash = :token_hash');
        $statement->execute(['token_hash' => hash('sha256', $token)]);
        api_respond(200, ['success' => true, 'message' => 'Signed out successfully.']);
    }

    if ($action === 'update_settings') {
        if (!is_bool($data['dark_mode'] ?? null) ||
            !is_bool($data['notifications_enabled'] ?? null)) {
            api_respond(422, ['success' => false, 'message' => 'Choose valid settings values.']);
        }
        $statement = $connection->prepare(
            'INSERT INTO account_settings
                (account_role, account_id, dark_mode, notifications_enabled)
             VALUES (:role, :account_id, :dark_mode, :notifications_enabled)
             ON DUPLICATE KEY UPDATE
                dark_mode = VALUES(dark_mode),
                notifications_enabled = VALUES(notifications_enabled)'
        );
        $statement->execute([
            'role' => $role,
            'account_id' => $accountId,
            'dark_mode' => (int) $data['dark_mode'],
            'notifications_enabled' => (int) $data['notifications_enabled'],
        ]);
        api_respond(200, ['success' => true, 'settings' => [
            'dark_mode' => $data['dark_mode'],
            'notifications_enabled' => $data['notifications_enabled'],
        ]]);
    }

    if ($action !== 'update_profile') {
        api_respond(400, ['success' => false, 'message' => 'Choose a valid profile action.']);
    }

    $email = strtolower(api_required_string($data, 'email', 254));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        api_respond(422, ['success' => false, 'message' => 'Enter a valid email address.']);
    }

    if ($role === 'admin') {
        $name = api_required_string($data, 'first_name', 201);
        $statement = $connection->prepare(
            'UPDATE admins SET name = :name, email = :email WHERE id = :id'
        );
        $statement->execute(['name' => $name, 'email' => $email, 'id' => $accountId]);
    } else {
        $firstName = api_required_string($data, 'first_name', 100);
        $surname = api_required_string($data, 'surname', 100);
        $phoneNumber = api_required_string($data, 'phone_number', 25);
        if (!preg_match('/^[0-9+().\-\s]{7,25}$/', $phoneNumber) ||
            strlen(preg_replace('/\D/', '', $phoneNumber)) < 7) {
            api_respond(422, ['success' => false, 'message' => 'Enter a valid phone number.']);
        }
        if ($role === 'student') {
            $number = api_required_string($data, 'student_number', 100);
            $statement = $connection->prepare(
                'UPDATE students
                 SET first_name = :first_name, surname = :surname, email = :email,
                     phone_number = :phone_number, student_number = :number
                 WHERE id = :id'
            );
        } else {
            $number = api_required_string($data, 'lecturer_number', 100);
            $statement = $connection->prepare(
                'UPDATE lecturers
                 SET first_name = :first_name, surname = :surname, email = :email,
                     phone_number = :phone_number, lecturer_number = :number
                 WHERE id = :id'
            );
        }
        $statement->execute([
            'first_name' => $firstName,
            'surname' => $surname,
            'email' => $email,
            'phone_number' => $phoneNumber,
            'number' => $number,
            'id' => $accountId,
        ]);
    }

    $profileStatement->execute(['id' => $accountId]);
    $profile = $profileStatement->fetch(PDO::FETCH_ASSOC);
    $profile['id'] = (int) $profile['id'];
    $profile['role'] = $role;
    api_respond(200, ['success' => true, 'profile' => $profile]);
} catch (PDOException $exception) {
    if ($exception->getCode() === '23000') {
        api_respond(409, [
            'success' => false,
            'message' => 'That email or institution number is already used by another account.',
        ]);
    }
    api_handle_database_error($exception);
}
