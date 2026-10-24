<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);
    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $statement = $connection->prepare(
            'SELECT c.id, c.name, c.description,
                    (SELECT COUNT(*) FROM community_memberships cm WHERE cm.community_id = c.id) AS member_count,
                    EXISTS(
                        SELECT 1 FROM community_memberships mine
                        WHERE mine.community_id = c.id
                          AND mine.account_role = :account_role
                          AND mine.account_id = :account_id
                    ) AS is_joined
             FROM communities c ORDER BY c.name'
        );
        $statement->execute([
            'account_role' => $account['account_role'],
            'account_id' => $account['account_id'],
        ]);
        $communities = $statement->fetchAll(PDO::FETCH_ASSOC);

        $updatesStatement = $connection->prepare(
            'SELECT id, message, created_at
             FROM community_updates WHERE community_id = :community_id
             ORDER BY created_at DESC, id DESC'
        );
        foreach ($communities as &$community) {
            $community['id'] = (int) $community['id'];
            $community['member_count'] = (int) $community['member_count'];
            $community['is_joined'] = (bool) $community['is_joined'];
            $community['updates'] = [];
            if ($community['is_joined'] || $account['account_role'] === 'admin') {
                $updatesStatement->execute(['community_id' => $community['id']]);
                $community['updates'] = $updatesStatement->fetchAll(PDO::FETCH_ASSOC);
            }
        }
        unset($community);

        api_respond(200, ['success' => true, 'data' => $communities]);
    }

    if ($method === 'POST') {
        $data = api_read_json();
        $action = $data['action'] ?? '';
        $communityId = filter_var($data['community_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$communityId || $communityId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid community.']);
        }

        $exists = $connection->prepare('SELECT id FROM communities WHERE id = :id');
        $exists->execute(['id' => $communityId]);
        if (!$exists->fetchColumn()) {
            api_respond(404, ['success' => false, 'message' => 'Community not found.']);
        }

        if ($action === 'join') {
            $statement = $connection->prepare(
                'INSERT IGNORE INTO community_memberships (community_id, account_role, account_id)
                 VALUES (:community_id, :account_role, :account_id)'
            );
            $statement->execute([
                'community_id' => $communityId,
                'account_role' => $account['account_role'],
                'account_id' => $account['account_id'],
            ]);
            api_respond(200, ['success' => true, 'message' => 'You joined the community.']);
        }

        if ($action === 'leave') {
            $statement = $connection->prepare(
                'DELETE FROM community_memberships
                 WHERE community_id = :community_id
                   AND account_role = :account_role
                   AND account_id = :account_id'
            );
            $statement->execute([
                'community_id' => $communityId,
                'account_role' => $account['account_role'],
                'account_id' => $account['account_id'],
            ]);
            api_respond(200, ['success' => true, 'message' => 'You left the community.']);
        }
    }

    header('Allow: GET, POST, OPTIONS');
    api_respond(405, ['success' => false, 'message' => 'Use GET or a supported POST action.']);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
