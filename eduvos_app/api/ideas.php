<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);
    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $statement = $connection->prepare(
            'SELECT bi.id, bi.owner_role, bi.owner_id, bi.title, bi.description, bi.industry,
                    DATE_FORMAT(
                        DATE_SUB(bi.expires_at, INTERVAL 1 DAY),
                        \'%Y-%m-%d\'
                    ) AS deadline,
                    bi.expires_at, (bi.expires_at <= CURRENT_TIMESTAMP) AS is_expired,
                    bi.created_at, ii.id AS interest_id,
                    COALESCE(iip.payment_status, \'not_started\') AS fee_status
             FROM business_ideas bi
             LEFT JOIN idea_interests ii
               ON :account_role = \'investor\'
              AND ii.idea_id = bi.id
              AND ii.investor_id = :investor_id
             LEFT JOIN idea_interest_payments iip ON iip.interest_id = ii.id
             WHERE bi.expires_at > CURRENT_TIMESTAMP
                OR (bi.owner_role = :owner_role AND bi.owner_id = :owner_id)
             ORDER BY bi.created_at DESC, bi.id DESC'
        );
        $statement->execute([
            'account_role' => $account['account_role'],
            'investor_id' => $account['account_id'],
            'owner_role' => $account['account_role'],
            'owner_id' => $account['account_id'],
        ]);
        $ideas = $statement->fetchAll(PDO::FETCH_ASSOC);

        foreach ($ideas as &$idea) {
            $idea['id'] = (int) $idea['id'];
            $idea['owner_id'] = (int) $idea['owner_id'];
            $idea['is_expired'] = (bool) $idea['is_expired'];
            $idea['author'] = api_owner_name($connection, $idea['owner_role'], $idea['owner_id']);
            $idea['is_mine'] = $idea['owner_role'] === $account['account_role']
                && $idea['owner_id'] === $account['account_id'];
            $idea['can_delete'] = $idea['is_mine'] || $account['account_role'] === 'admin';
            $idea['interest_id'] = $idea['interest_id'] === null
                ? null
                : (int) $idea['interest_id'];
            $idea['interested'] = $idea['interest_id'] !== null;
            $idea['can_chat'] = $account['account_role'] === 'investor'
                && $idea['owner_role'] === 'student'
                && !$idea['is_expired'];
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
            $industry = api_required_string($data, 'industry', 100);
            $industries = [
                'Agriculture',
                'Arts & Entertainment',
                'Construction',
                'Education',
                'Energy & Environment',
                'Finance & Fintech',
                'Food & Hospitality',
                'Healthcare',
                'Manufacturing',
                'Retail & E-commerce',
                'Technology',
                'Tourism',
                'Transport & Logistics',
                'Social Impact & Community',
                'Other',
            ];
            if (!in_array($industry, $industries, true)) {
                api_respond(422, ['success' => false, 'message' => 'Choose an industry from the list.']);
            }
            $deadline = $data['deadline'] ?? null;
            if (!is_string($deadline) ||
                !preg_match('/^\d{4}-\d{2}-\d{2}$/', $deadline) ||
                !checkdate(
                    (int) substr($deadline, 5, 2),
                    (int) substr($deadline, 8, 2),
                    (int) substr($deadline, 0, 4)
                )) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid idea deadline.']);
            }
            $deadlineStatement = $connection->prepare(
                'SELECT :deadline >= CURRENT_DATE'
            );
            $deadlineStatement->execute(['deadline' => $deadline]);
            if (!(bool) $deadlineStatement->fetchColumn()) {
                api_respond(422, ['success' => false, 'message' => 'The idea deadline must be today or later.']);
            }
            $statement = $connection->prepare(
                'INSERT INTO business_ideas
                    (owner_role, owner_id, title, description, industry, expires_at)
                 VALUES (
                    :owner_role, :owner_id, :title, :description, :industry,
                    DATE_ADD(STR_TO_DATE(:deadline, \'%Y-%m-%d\'), INTERVAL 1 DAY)
                 )'
            );
            $statement->execute([
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
                'title' => $title,
                'description' => $description,
                'industry' => $industry,
                'deadline' => $deadline,
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

        if ($action === 'interested') {
            if ($account['account_role'] !== 'investor') {
                api_respond(403, ['success' => false, 'message' => 'Only investors can express interest in a student idea.']);
            }
            $ideaId = filter_var($data['idea_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$ideaId || $ideaId < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid student idea.']);
            }

            $ideaStatement = $connection->prepare(
                'SELECT id, owner_id, title FROM business_ideas
                 WHERE id = :id AND owner_role = \'student\'
                   AND expires_at > CURRENT_TIMESTAMP'
            );
            $ideaStatement->execute(['id' => $ideaId]);
            $idea = $ideaStatement->fetch(PDO::FETCH_ASSOC);
            if (!$idea) {
                api_respond(404, ['success' => false, 'message' => 'Student idea not found or its investor deadline has passed.']);
            }

            $connection->beginTransaction();
            $insertInterest = $connection->prepare(
                'INSERT IGNORE INTO idea_interests (idea_id, student_id, investor_id)
                 VALUES (:idea_id, :student_id, :investor_id)'
            );
            $insertInterest->execute([
                'idea_id' => $ideaId,
                'student_id' => (int) $idea['owner_id'],
                'investor_id' => $account['account_id'],
            ]);
            $isNewInterest = $insertInterest->rowCount() === 1;

            $interestStatement = $connection->prepare(
                'SELECT id FROM idea_interests
                 WHERE idea_id = :idea_id AND investor_id = :investor_id'
            );
            $interestStatement->execute([
                'idea_id' => $ideaId,
                'investor_id' => $account['account_id'],
            ]);
            $interestId = (int) $interestStatement->fetchColumn();

            $chatInsert = $connection->prepare(
                'INSERT INTO investor_chats (idea_id, student_id, investor_id)
                 VALUES (:idea_id, :student_id, :investor_id)
                 ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)'
            );
            $chatInsert->execute([
                'idea_id' => $ideaId,
                'student_id' => (int) $idea['owner_id'],
                'investor_id' => $account['account_id'],
            ]);
            $chatId = (int) $connection->lastInsertId();

            $paymentInsert = $connection->prepare(
                'INSERT IGNORE INTO idea_interest_payments (interest_id, gateway_reference)
                 VALUES (:interest_id, :gateway_reference)'
            );
            $paymentInsert->execute([
                'interest_id' => $interestId,
                'gateway_reference' => 'EDU-' . strtoupper(bin2hex(random_bytes(8))),
            ]);
            $paymentStatusStatement = $connection->prepare(
                'SELECT payment_status FROM idea_interest_payments
                 WHERE interest_id = :interest_id'
            );
            $paymentStatusStatement->execute(['interest_id' => $interestId]);
            $feeStatus = $paymentStatusStatement->fetchColumn();

            if ($isNewInterest) {
                $investorName = api_owner_name(
                    $connection,
                    $account['account_role'],
                    $account['account_id']
                );
                $message = $connection->prepare(
                    'INSERT INTO investor_chat_messages (chat_id, sender_role, sender_id, body)
                     VALUES (:chat_id, \'investor\', :sender_id, :body)'
                );
                $message->execute([
                    'chat_id' => $chatId,
                    'sender_id' => $account['account_id'],
                    'body' => $investorName . ' is interested in "' . $idea['title']
                        . '". The R200 admin fee is pending; you can chat now.',
                ]);
            }
            $connection->prepare(
                'UPDATE investor_chats SET updated_at = CURRENT_TIMESTAMP WHERE id = :id'
            )->execute(['id' => $chatId]);
            $connection->commit();

            api_respond(200, [
                'success' => true,
                'message' => 'Your interest was sent to the student in chat.',
                'chat_id' => $chatId,
                'interest_id' => $interestId,
                'fee_status' => $feeStatus,
                'fee_amount' => '200.00',
                'currency' => 'ZAR',
            ]);
        }

        if ($action === 'fee_checkout') {
            if ($account['account_role'] !== 'investor') {
                api_respond(403, ['success' => false, 'message' => 'Only investors can pay this fee.']);
            }
            $interestId = filter_var($data['interest_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$interestId || $interestId < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid idea interest.']);
            }
            $paymentStatement = $connection->prepare(
                'SELECT p.id, p.gateway_reference, p.amount, p.payment_status, i.idea_id
                 FROM idea_interest_payments p
                 INNER JOIN idea_interests i ON i.id = p.interest_id
                 WHERE i.id = :interest_id AND i.investor_id = :investor_id'
            );
            $paymentStatement->execute([
                'interest_id' => $interestId,
                'investor_id' => $account['account_id'],
            ]);
            $payment = $paymentStatement->fetch(PDO::FETCH_ASSOC);
            if (!$payment) {
                api_respond(404, ['success' => false, 'message' => 'Idea interest not found.']);
            }
            if ($payment['payment_status'] === 'paid') {
                api_respond(200, [
                    'success' => true,
                    'payment_status' => 'paid',
                    'message' => 'The R200 admin fee is already paid.',
                ]);
            }

            require_once __DIR__ . '/payfast_common.php';
            $configuration = payfast_local_configuration();
            if (!payfast_configuration_is_ready($configuration)) {
                api_respond(503, [
                    'success' => false,
                    'message' => 'PayFast is not configured. Copy api/payfast_config.example.php to api/payfast_config.local.php and add your merchant settings.',
                ]);
            }

            $checkoutToken = bin2hex(random_bytes(32));
            $checkoutUpdate = $connection->prepare(
                'UPDATE idea_interest_payments
                 SET checkout_token_hash = :token_hash,
                     checkout_expires_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 20 MINUTE),
                     payment_status = \'pending\',
                     verification_source = NULL,
                     verified_by_admin_id = NULL
                 WHERE id = :id AND payment_status != \'paid\''
            );
            $checkoutUpdate->execute([
                'token_hash' => hash('sha256', $checkoutToken),
                'id' => $payment['id'],
            ]);
            $checkoutUrl = rtrim($configuration['checkout_url'], '?')
                . '?token=' . rawurlencode($checkoutToken);
            api_respond(200, [
                'success' => true,
                'payment_status' => 'pending',
                'checkout_url' => $checkoutUrl,
                'fee_amount' => number_format((float) $payment['amount'], 2, '.', ''),
                'currency' => 'ZAR',
            ]);
        }

        if ($action === 'fee_list') {
            if ($account['account_role'] !== 'admin') {
                api_respond(403, ['success' => false, 'message' => 'Only administrators can review fee payments.']);
            }
            $payments = $connection->query(
                'SELECT p.id AS payment_id, p.gateway_reference, p.amount, p.currency,
                        p.payment_status, p.created_at, i.idea_id,
                        bi.title AS idea_title, i.investor_id,
                        CONCAT(inv.first_name, \' \', inv.surname) AS investor_name,
                        inv.email AS investor_email
                 FROM idea_interest_payments p
                 INNER JOIN idea_interests i ON i.id = p.interest_id
                 INNER JOIN business_ideas bi ON bi.id = i.idea_id
                 INNER JOIN investors inv ON inv.id = i.investor_id
                 WHERE p.payment_status != \'paid\'
                 ORDER BY p.created_at DESC, p.id DESC'
            )->fetchAll(PDO::FETCH_ASSOC);
            foreach ($payments as &$payment) {
                $payment['payment_id'] = (int) $payment['payment_id'];
                $payment['idea_id'] = (int) $payment['idea_id'];
                $payment['amount'] = number_format((float) $payment['amount'], 2, '.', '');
            }
            unset($payment);
            api_respond(200, ['success' => true, 'data' => $payments]);
        }

        if ($action === 'fee_verify') {
            if ($account['account_role'] !== 'admin') {
                api_respond(403, ['success' => false, 'message' => 'Only administrators can verify fee payments.']);
            }
            $paymentId = filter_var($data['payment_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$paymentId || $paymentId < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid fee payment.']);
            }
            $verify = $connection->prepare(
                'UPDATE idea_interest_payments
                 SET payment_status = \'paid\', verification_source = \'admin\',
                     verified_by_admin_id = :admin_id, paid_at = UTC_TIMESTAMP(),
                     checkout_token_hash = NULL, checkout_expires_at = NULL
                 WHERE id = :id AND payment_status != \'paid\''
            );
            $verify->execute([
                'admin_id' => $account['account_id'],
                'id' => $paymentId,
            ]);
            if ($verify->rowCount() === 0) {
                $exists = $connection->prepare(
                    'SELECT payment_status FROM idea_interest_payments WHERE id = :id'
                );
                $exists->execute(['id' => $paymentId]);
                if ($exists->fetchColumn() === false) {
                    api_respond(404, ['success' => false, 'message' => 'Fee payment not found.']);
                }
            }
            api_respond(200, ['success' => true, 'message' => 'Fee payment marked as verified.']);
        }
    }

    header('Allow: GET, POST, OPTIONS');
    api_respond(405, ['success' => false, 'message' => 'Use GET or a supported POST action.']);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
