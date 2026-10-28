<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $posts = $connection->query(
            'SELECT id, author_role, author_id, title, body, created_at
             FROM entrepreneurial_posts
             ORDER BY created_at DESC, id DESC'
        )->fetchAll(PDO::FETCH_ASSOC);
        $commentStatement = $connection->prepare(
            'SELECT c.id, c.body, c.created_at, c.student_id,
                    CONCAT(s.first_name, \' \', s.surname) AS author
             FROM entrepreneurial_post_comments c
             INNER JOIN students s ON s.id = c.student_id
             WHERE c.post_id = :post_id
             ORDER BY c.created_at, c.id'
        );
        $reactionCountStatement = $connection->prepare(
            'SELECT COUNT(*) FROM entrepreneurial_post_reactions WHERE post_id = :post_id'
        );
        $reactionMineStatement = $connection->prepare(
            'SELECT 1 FROM entrepreneurial_post_reactions
             WHERE post_id = :post_id AND student_id = :student_id'
        );

        foreach ($posts as &$post) {
            $post['id'] = (int) $post['id'];
            $post['author_id'] = (int) $post['author_id'];
            $post['author'] = api_owner_name(
                $connection,
                $post['author_role'],
                $post['author_id']
            );
            $post['can_edit'] = $post['author_role'] === $account['account_role']
                && $post['author_id'] === $account['account_id'];
            $post['can_delete'] = in_array($account['account_role'], ['admin', 'investor'], true)
                && $post['can_edit'];
            $commentStatement->execute(['post_id' => $post['id']]);
            $post['comments'] = $commentStatement->fetchAll(PDO::FETCH_ASSOC);
            foreach ($post['comments'] as &$comment) {
                $comment['id'] = (int) $comment['id'];
                $comment['student_id'] = (int) $comment['student_id'];
            }
            unset($comment);
            $reactionCountStatement->execute(['post_id' => $post['id']]);
            $post['reaction_count'] = (int) $reactionCountStatement->fetchColumn();
            $post['liked_by_me'] = false;
            if ($account['account_role'] === 'student') {
                $reactionMineStatement->execute([
                    'post_id' => $post['id'],
                    'student_id' => $account['account_id'],
                ]);
                $post['liked_by_me'] = (bool) $reactionMineStatement->fetchColumn();
            }
        }
        unset($post);

        api_respond(200, ['success' => true, 'data' => $posts]);
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        header('Allow: GET, POST, OPTIONS');
        api_respond(405, ['success' => false, 'message' => 'Use GET or POST.']);
    }

    $data = api_read_json();
    $action = $data['action'] ?? '';

    if ($action === 'create') {
        if (!in_array($account['account_role'], ['lecturer', 'admin', 'investor'], true)) {
            api_respond(403, ['success' => false, 'message' => 'Only lecturers, administrators, and investors can publish advice posts.']);
        }
        $title = api_required_string($data, 'title', 200);
        $body = api_required_string($data, 'body', 8000);
        $statement = $connection->prepare(
            'INSERT INTO entrepreneurial_posts (author_role, author_id, title, body)
             VALUES (:author_role, :author_id, :title, :body)'
        );
        $statement->execute([
            'author_role' => $account['account_role'],
            'author_id' => $account['account_id'],
            'title' => $title,
            'body' => $body,
        ]);
        api_respond(201, [
            'success' => true,
            'id' => (int) $connection->lastInsertId(),
            'message' => 'Advice post published.',
        ]);
    }

    if ($action === 'update') {
        $postId = filter_var($data['post_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$postId || $postId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid advice post.']);
        }
        $title = api_required_string($data, 'title', 200);
        $body = api_required_string($data, 'body', 8000);
        $statement = $connection->prepare(
            'UPDATE entrepreneurial_posts
             SET title = :title, body = :body
             WHERE id = :id AND author_role = :author_role AND author_id = :author_id'
        );
        $statement->execute([
            'title' => $title,
            'body' => $body,
            'id' => $postId,
            'author_role' => $account['account_role'],
            'author_id' => $account['account_id'],
        ]);
        if ($statement->rowCount() === 0) {
            $exists = $connection->prepare(
                'SELECT 1 FROM entrepreneurial_posts
                 WHERE id = :id AND author_role = :author_role AND author_id = :author_id'
            );
            $exists->execute([
                'id' => $postId,
                'author_role' => $account['account_role'],
                'author_id' => $account['account_id'],
            ]);
            if (!$exists->fetchColumn()) {
                api_respond(404, ['success' => false, 'message' => 'Advice post not found or you cannot edit it.']);
            }
        }
        api_respond(200, ['success' => true, 'message' => 'Advice post updated.']);
    }

    if ($action === 'delete') {
        if (!in_array($account['account_role'], ['admin', 'investor'], true)) {
            api_respond(403, ['success' => false, 'message' => 'Only administrators and investors can delete their own advice posts.']);
        }
        $postId = filter_var($data['post_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$postId || $postId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid advice post.']);
        }
        $statement = $connection->prepare(
            'DELETE FROM entrepreneurial_posts
             WHERE id = :id AND author_role = :author_role AND author_id = :author_id'
        );
        $statement->execute([
            'id' => $postId,
            'author_role' => $account['account_role'],
            'author_id' => $account['account_id'],
        ]);
        if ($statement->rowCount() === 0) {
            api_respond(404, ['success' => false, 'message' => 'Advice post not found or you cannot delete it.']);
        }
        api_respond(200, ['success' => true, 'message' => 'Advice post deleted.']);
    }

    if ($action === 'comment') {
        api_require_student($account);
        $postId = filter_var($data['post_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$postId || $postId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid advice post.']);
        }
        $body = api_required_string($data, 'body', 3000);
        $statement = $connection->prepare(
            'INSERT INTO entrepreneurial_post_comments (post_id, student_id, body)
             SELECT id, :student_id, :body FROM entrepreneurial_posts WHERE id = :post_id'
        );
        $statement->execute([
            'student_id' => $account['account_id'],
            'body' => $body,
            'post_id' => $postId,
        ]);
        if ($statement->rowCount() === 0) {
            api_respond(404, ['success' => false, 'message' => 'Advice post not found.']);
        }
        api_respond(201, ['success' => true, 'message' => 'Question posted.']);
    }

    if ($action === 'react') {
        api_require_student($account);
        $postId = filter_var($data['post_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$postId || $postId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid advice post.']);
        }
        $connection->beginTransaction();
        $postStatement = $connection->prepare(
            'SELECT id FROM entrepreneurial_posts WHERE id = :id FOR UPDATE'
        );
        $postStatement->execute(['id' => $postId]);
        if (!$postStatement->fetchColumn()) {
            $connection->rollBack();
            api_respond(404, ['success' => false, 'message' => 'Advice post not found.']);
        }
        $reactionStatement = $connection->prepare(
            'SELECT post_id FROM entrepreneurial_post_reactions
             WHERE post_id = :post_id AND student_id = :student_id'
        );
        $reactionStatement->execute([
            'post_id' => $postId,
            'student_id' => $account['account_id'],
        ]);
        if ($reactionStatement->fetchColumn()) {
            $statement = $connection->prepare(
                'DELETE FROM entrepreneurial_post_reactions
                 WHERE post_id = :post_id AND student_id = :student_id'
            );
            $liked = false;
        } else {
            $statement = $connection->prepare(
                'INSERT INTO entrepreneurial_post_reactions (post_id, student_id)
                 VALUES (:post_id, :student_id)'
            );
            $liked = true;
        }
        $statement->execute([
            'post_id' => $postId,
            'student_id' => $account['account_id'],
        ]);
        $connection->commit();
        api_respond(200, ['success' => true, 'liked' => $liked]);
    }

    api_respond(422, ['success' => false, 'message' => 'Choose a supported blog action.']);
} catch (PDOException $exception) {
    if (isset($connection) && $connection->inTransaction()) {
        $connection->rollBack();
    }
    api_handle_database_error($exception);
}
