<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

function idea_chat_participant(PDO $connection, array $account, int $chatId): bool
{
    $column = match ($account['account_role']) {
        'student' => 'student_id',
        'investor' => 'investor_id',
        default => null,
    };
    if ($column === null) {
        return false;
    }

    $statement = $connection->prepare(
        'SELECT id FROM investor_chats
         WHERE id = :chat_id AND ' . $column . ' = :account_id'
    );
    $statement->execute([
        'chat_id' => $chatId,
        'account_id' => $account['account_id'],
    ]);
    return (bool) $statement->fetchColumn();
}

function marketplace_chat_participant(PDO $connection, array $account, int $chatId): bool
{
    $statement = $connection->prepare(
        'SELECT id FROM marketplace_chats
         WHERE id = :chat_id
           AND ((seller_role = :seller_role AND seller_id = :seller_id)
             OR (buyer_role = :buyer_role AND buyer_id = :buyer_id))'
    );
    $statement->execute([
        'chat_id' => $chatId,
        'seller_role' => $account['account_role'],
        'seller_id' => $account['account_id'],
        'buyer_role' => $account['account_role'],
        'buyer_id' => $account['account_id'],
    ]);
    return (bool) $statement->fetchColumn();
}

function community_chat_member(PDO $connection, array $account, int $communityId): bool
{
    if ($account['account_role'] === 'investor') {
        return false;
    }

    $statement = $connection->prepare(
        'SELECT id FROM community_memberships
         WHERE community_id = :community_id
           AND account_role = :account_role
           AND account_id = :account_id'
    );
    $statement->execute([
        'community_id' => $communityId,
        'account_role' => $account['account_role'],
        'account_id' => $account['account_id'],
    ]);
    return (bool) $statement->fetchColumn();
}

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $chats = [];
        if (in_array($account['account_role'], ['student', 'investor'], true)) {
            $isStudent = $account['account_role'] === 'student';
            $whereColumn = $isStudent ? 'c.student_id' : 'c.investor_id';
            $nameColumn = $isStudent ? 'i.first_name' : 's.first_name';
            $surnameColumn = $isStudent ? 'i.surname' : 's.surname';
            $sql = 'SELECT c.id, c.idea_id, c.student_id, c.investor_id,
                           bi.title AS idea_title,
                           ii.id AS interest_id,
                           COALESCE(iip.payment_status, \'not_started\') AS fee_status,
                           CONCAT(' . $nameColumn . ', \' \', ' . $surnameColumn . ') AS other_name,
                           (SELECT m.body FROM investor_chat_messages m
                            WHERE m.chat_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message,
                           (SELECT m.created_at FROM investor_chat_messages m
                            WHERE m.chat_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message_at,
                           COALESCE(c.updated_at, c.created_at) AS sort_at
                    FROM investor_chats c
                    INNER JOIN business_ideas bi ON bi.id = c.idea_id
                    INNER JOIN students s ON s.id = c.student_id
                    INNER JOIN investors i ON i.id = c.investor_id
                    LEFT JOIN idea_interests ii
                      ON ii.idea_id = c.idea_id AND ii.investor_id = c.investor_id
                    LEFT JOIN idea_interest_payments iip ON iip.interest_id = ii.id
                    WHERE ' . $whereColumn . ' = :account_id';
            $statement = $connection->prepare($sql);
            $statement->execute(['account_id' => $account['account_id']]);
            foreach ($statement->fetchAll(PDO::FETCH_ASSOC) as $chat) {
                $chat['id'] = (int) $chat['id'];
                $chat['idea_id'] = (int) $chat['idea_id'];
                $chat['student_id'] = (int) $chat['student_id'];
                $chat['investor_id'] = (int) $chat['investor_id'];
                $chat['chat_type'] = 'idea';
                $chat['context_title'] = $chat['idea_title'];
                $chat['interest_id'] = $chat['interest_id'] === null
                    ? null
                    : (int) $chat['interest_id'];
                $chats[] = $chat;
            }
        }

        $marketplaceStatement = $connection->prepare(
            'SELECT c.id, c.listing_type, c.listing_id, c.seller_role, c.seller_id,
                    c.buyer_role, c.buyer_id, c.updated_at, c.created_at,
                    (SELECT m.body FROM marketplace_chat_messages m
                     WHERE m.chat_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message,
                    (SELECT m.created_at FROM marketplace_chat_messages m
                     WHERE m.chat_id = c.id ORDER BY m.id DESC LIMIT 1) AS last_message_at
             FROM marketplace_chats c
             WHERE (c.seller_role = :seller_role AND c.seller_id = :seller_id)
                OR (c.buyer_role = :buyer_role AND c.buyer_id = :buyer_id)'
        );
        $marketplaceStatement->execute([
            'seller_role' => $account['account_role'],
            'seller_id' => $account['account_id'],
            'buyer_role' => $account['account_role'],
            'buyer_id' => $account['account_id'],
        ]);
        foreach ($marketplaceStatement->fetchAll(PDO::FETCH_ASSOC) as $chat) {
            $listingTable = $chat['listing_type'] === 'product' ? 'products' : 'services';
            $listingStatement = $connection->prepare(
                'SELECT title FROM ' . $listingTable . ' WHERE id = :id'
            );
            $listingStatement->execute(['id' => $chat['listing_id']]);
            $listingTitle = $listingStatement->fetchColumn();
            $isSeller = $chat['seller_role'] === $account['account_role']
                && (int) $chat['seller_id'] === $account['account_id'];
            $otherRole = $isSeller ? $chat['buyer_role'] : $chat['seller_role'];
            $otherId = (int) ($isSeller ? $chat['buyer_id'] : $chat['seller_id']);
            $chats[] = [
                'id' => (int) $chat['id'],
                'chat_type' => 'marketplace',
                'listing_type' => $chat['listing_type'],
                'listing_id' => (int) $chat['listing_id'],
                'context_title' => is_string($listingTitle)
                    ? $listingTitle
                    : 'Marketplace listing',
                'other_name' => api_owner_name($connection, $otherRole, $otherId),
                'last_message' => $chat['last_message'],
                'last_message_at' => $chat['last_message_at'],
                'sort_at' => $chat['updated_at'] ?? $chat['created_at'],
            ];
        }
        $communityStatement = $connection->prepare(
            'SELECT c.id, c.name,
                    (SELECT COUNT(*) FROM community_memberships cm
                     WHERE cm.community_id = c.id) AS member_count,
                    (SELECT m.body FROM community_chat_messages m
                     WHERE m.community_id = c.id
                     ORDER BY m.id DESC LIMIT 1) AS last_message,
                    (SELECT m.created_at FROM community_chat_messages m
                     WHERE m.community_id = c.id
                     ORDER BY m.id DESC LIMIT 1) AS last_message_at,
                    c.created_at
             FROM communities c
             INNER JOIN community_memberships mine ON mine.community_id = c.id
             WHERE mine.account_role = :account_role
               AND mine.account_id = :account_id
               AND mine.account_role != \'investor\''
        );
        $communityStatement->execute([
            'account_role' => $account['account_role'],
            'account_id' => $account['account_id'],
        ]);
        foreach ($communityStatement->fetchAll(PDO::FETCH_ASSOC) as $chat) {
            $chats[] = [
                'id' => (int) $chat['id'],
                'chat_type' => 'community',
                'other_name' => $chat['name'],
                'community_name' => $chat['name'],
                'context_title' => (int) $chat['member_count'] . ' members · Community chat',
                'last_message' => $chat['last_message'],
                'last_message_at' => $chat['last_message_at'],
                'sort_at' => $chat['last_message_at'] ?? $chat['created_at'],
            ];
        }
        usort($chats, static fn (array $left, array $right): int =>
            strcmp((string) $right['sort_at'], (string) $left['sort_at'])
        );
        foreach ($chats as &$chat) {
            unset($chat['sort_at']);
        }
        unset($chat);
        api_respond(200, ['success' => true, 'data' => $chats]);
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        header('Allow: GET, POST, OPTIONS');
        api_respond(405, ['success' => false, 'message' => 'Use GET or POST.']);
    }

    $data = api_read_json();
    $action = $data['action'] ?? '';

    if ($action === 'open') {
        if ($account['account_role'] !== 'investor') {
            api_respond(403, ['success' => false, 'message' => 'Only investors can start a chat from a business idea.']);
        }
        $ideaId = filter_var($data['idea_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$ideaId || $ideaId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid student idea.']);
        }
        $ideaStatement = $connection->prepare(
            'SELECT owner_id FROM business_ideas
             WHERE id = :id AND owner_role = \'student\'
               AND expires_at > CURRENT_TIMESTAMP'
        );
        $ideaStatement->execute(['id' => $ideaId]);
        $studentId = $ideaStatement->fetchColumn();
        if (!$studentId) {
            api_respond(404, ['success' => false, 'message' => 'Student idea not found.']);
        }
        $interestStatement = $connection->prepare(
            'SELECT id FROM idea_interests
             WHERE idea_id = :idea_id AND investor_id = :investor_id'
        );
        $interestStatement->execute([
            'idea_id' => $ideaId,
            'investor_id' => $account['account_id'],
        ]);
        if (!$interestStatement->fetchColumn()) {
            api_respond(403, ['success' => false, 'message' => 'Tap Interested on the idea before opening its chat.']);
        }

        $insert = $connection->prepare(
            'INSERT INTO investor_chats (idea_id, student_id, investor_id)
             VALUES (:idea_id, :student_id, :investor_id)
             ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)'
        );
        $insert->execute([
            'idea_id' => $ideaId,
            'student_id' => (int) $studentId,
            'investor_id' => $account['account_id'],
        ]);
        api_respond(200, [
            'success' => true,
            'chat_id' => (int) $connection->lastInsertId(),
        ]);
    }

    if ($action === 'open_marketplace') {
        $listingType = $data['listing_type'] ?? null;
        $listingId = filter_var($data['listing_id'] ?? null, FILTER_VALIDATE_INT);
        if (!is_string($listingType) ||
            !in_array($listingType, ['product', 'service'], true) ||
            !$listingId || $listingId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid marketplace listing.']);
        }
        $listingTable = $listingType === 'product' ? 'products' : 'services';
        $listingStatement = $connection->prepare(
            'SELECT owner_role, owner_id FROM ' . $listingTable . ' WHERE id = :id'
        );
        $listingStatement->execute(['id' => $listingId]);
        $listing = $listingStatement->fetch(PDO::FETCH_ASSOC);
        if (!$listing) {
            api_respond(404, ['success' => false, 'message' => 'Marketplace listing not found.']);
        }
        if ($listing['owner_role'] === $account['account_role']
            && (int) $listing['owner_id'] === $account['account_id']) {
            api_respond(422, ['success' => false, 'message' => 'You cannot start a chat about your own listing.']);
        }
        $insert = $connection->prepare(
            'INSERT INTO marketplace_chats
                (listing_type, listing_id, seller_role, seller_id, buyer_role, buyer_id)
             VALUES
                (:listing_type, :listing_id, :seller_role, :seller_id, :buyer_role, :buyer_id)
             ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)'
        );
        $insert->execute([
            'listing_type' => $listingType,
            'listing_id' => $listingId,
            'seller_role' => $listing['owner_role'],
            'seller_id' => (int) $listing['owner_id'],
            'buyer_role' => $account['account_role'],
            'buyer_id' => $account['account_id'],
        ]);
        api_respond(200, [
            'success' => true,
            'chat_id' => (int) $connection->lastInsertId(),
            'chat_type' => 'marketplace',
        ]);
    }

    $chatType = $data['chat_type'] ?? 'idea';
    if (!is_string($chatType) ||
        !in_array($chatType, ['idea', 'marketplace', 'community'], true)) {
        api_respond(422, ['success' => false, 'message' => 'Choose a supported chat type.']);
    }
    $chatId = filter_var($data['chat_id'] ?? null, FILTER_VALIDATE_INT);
    $isParticipant = $chatId && $chatId > 0 && (
        $chatType === 'idea'
            ? idea_chat_participant($connection, $account, $chatId)
            : ($chatType === 'marketplace'
                ? marketplace_chat_participant($connection, $account, $chatId)
                : community_chat_member($connection, $account, $chatId))
    );
    if (!$isParticipant) {
        api_respond(404, ['success' => false, 'message' => 'Chat not found.']);
    }

    if ($action === 'messages') {
        $messageTable = match ($chatType) {
            'idea' => 'investor_chat_messages',
            'marketplace' => 'marketplace_chat_messages',
            'community' => 'community_chat_messages',
        };
        $chatColumn = $chatType === 'community' ? 'community_id' : 'chat_id';
        $statement = $connection->prepare(
            'SELECT id, sender_role, sender_id, body, created_at
             FROM ' . $messageTable . '
             WHERE ' . $chatColumn . ' = :chat_id
             ORDER BY id'
        );
        $statement->execute(['chat_id' => $chatId]);
        $messages = $statement->fetchAll(PDO::FETCH_ASSOC);
        foreach ($messages as &$message) {
            $message['id'] = (int) $message['id'];
            $message['sender_id'] = (int) $message['sender_id'];
            $message['sender'] = api_owner_name(
                $connection,
                $message['sender_role'],
                $message['sender_id']
            );
            $message['is_mine'] = $message['sender_role'] === $account['account_role']
                && $message['sender_id'] === $account['account_id'];
        }
        unset($message);
        api_respond(200, ['success' => true, 'data' => $messages]);
    }

    if ($action === 'send') {
        $body = api_required_string($data, 'body', 5000);
        $messageTable = match ($chatType) {
            'idea' => 'investor_chat_messages',
            'marketplace' => 'marketplace_chat_messages',
            'community' => 'community_chat_messages',
        };
        $chatColumn = $chatType === 'community' ? 'community_id' : 'chat_id';
        $statement = $connection->prepare(
            'INSERT INTO ' . $messageTable . ' (' . $chatColumn . ', sender_role, sender_id, body)
             VALUES (:chat_id, :sender_role, :sender_id, :body)'
        );
        $statement->execute([
            'chat_id' => $chatId,
            'sender_role' => $account['account_role'],
            'sender_id' => $account['account_id'],
            'body' => $body,
        ]);
        if ($chatType !== 'community') {
            $chatTable = $chatType === 'idea' ? 'investor_chats' : 'marketplace_chats';
            $connection->prepare(
                'UPDATE ' . $chatTable . ' SET updated_at = CURRENT_TIMESTAMP WHERE id = :id'
            )->execute(['id' => $chatId]);
        }
        api_respond(201, ['success' => true, 'message' => 'Message sent.']);
    }

    api_respond(422, ['success' => false, 'message' => 'Choose a supported chat action.']);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
