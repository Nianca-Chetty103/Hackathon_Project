<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);
    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $ideas = $connection->query(
            'SELECT id, owner_role, owner_id, title, description, created_at
             FROM business_ideas ORDER BY created_at DESC, id DESC'
        )->fetchAll(PDO::FETCH_ASSOC);

        foreach ($ideas as &$idea) {
            $idea['id'] = (int) $idea['id'];
            $idea['owner_id'] = (int) $idea['owner_id'];
            $idea['author'] = api_owner_name($connection, $idea['owner_role'], $idea['owner_id']);
            $idea['is_mine'] = $idea['owner_role'] === $account['account_role']
                && $idea['owner_id'] === $account['account_id'];
            $idea['can_delete'] = $idea['is_mine'] || $account['account_role'] === 'admin';
        }
        unset($idea);

        api_respond(200, ['success' => true, 'data' => $ideas]);
    }

    if ($method === 'POST') {
        $data = api_read_json();
        $action = $data['action'] ?? '';

        if ($action === 'create') {
            api_require_student($account);
            $title = api_required_string($data, 'title', 150);
            $description = api_required_string($data, 'description', 5000);
            $statement = $connection->prepare(
                'INSERT INTO business_ideas (owner_role, owner_id, title, description)
                 VALUES (:owner_role, :owner_id, :title, :description)'
            );
            $statement->execute([
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
                'title' => $title,
                'description' => $description,
            ]);
            api_respond(201, ['success' => true, 'message' => 'Business idea created.']);
        }

        if ($action === 'delete') {
            $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT);
            if (!$id || $id < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid idea to delete.']);
            }

            $statement = $connection->prepare(
                'DELETE FROM business_ideas
                 WHERE id = :id
                   AND ((owner_role = :owner_role AND owner_id = :owner_id) OR :is_admin = 1)'
            );
            $statement->execute([
                'id' => $id,
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
                'is_admin' => $account['account_role'] === 'admin' ? 1 : 0,
            ]);
            if ($statement->rowCount() === 0) {
                api_respond(404, ['success' => false, 'message' => 'Idea not found or you cannot delete it.']);
            }
            api_respond(200, ['success' => true, 'message' => 'Business idea deleted.']);
        }
    }

    header('Allow: GET, POST, OPTIONS');
    api_respond(405, ['success' => false, 'message' => 'Use GET or a supported POST action.']);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
