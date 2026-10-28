<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        if (!in_array($account['account_role'], ['student', 'investor'], true)) {
            api_respond(403, ['success' => false, 'message' => 'The auction is available to students and investors.']);
        }

        if ($account['account_role'] === 'investor') {
            $statement = $connection->prepare(
                'SELECT bi.id, bi.title, bi.description, bi.industry,
                        DATE_FORMAT(
                            DATE_SUB(bi.expires_at, INTERVAL 1 DAY),
                            \'%Y-%m-%d\'
                        ) AS deadline,
                        (bi.expires_at <= CURRENT_TIMESTAMP) AS is_expired,
                        bi.created_at,
                        CONCAT(s.first_name, \' \', s.surname) AS student_name,
                        ii.id AS interest_id,
                        COALESCE(p.payment_status, \'not_started\') AS fee_status,
                        c.id AS chat_id,
                        o.id AS offer_id, o.amount, o.message, o.offer_status,
                        o.created_at AS offer_created_at,
                        (
                            SELECT COUNT(*)
                            FROM auction_offers all_offers
                            WHERE all_offers.idea_id = bi.id
                        ) AS offer_count,
                        EXISTS (
                            SELECT 1
                            FROM auction_offers accepted_offer
                            WHERE accepted_offer.idea_id = bi.id
                              AND accepted_offer.offer_status = \'accepted\'
                        ) AS auction_closed
                 FROM business_ideas bi
                 INNER JOIN students s ON s.id = bi.owner_id
                 INNER JOIN idea_interests ii
                   ON ii.idea_id = bi.id AND ii.investor_id = :interest_investor_id
                 LEFT JOIN idea_interest_payments p ON p.interest_id = ii.id
                 LEFT JOIN investor_chats c
                   ON c.idea_id = bi.id AND c.investor_id = :chat_investor_id
                 LEFT JOIN auction_offers o
                   ON o.idea_id = bi.id AND o.investor_id = :offer_investor_id
                 WHERE bi.owner_role = \'student\'
                 ORDER BY bi.created_at DESC, bi.id DESC'
            );
            $statement->execute([
                'interest_investor_id' => $account['account_id'],
                'chat_investor_id' => $account['account_id'],
                'offer_investor_id' => $account['account_id'],
            ]);
            $ideas = $statement->fetchAll(PDO::FETCH_ASSOC);
            foreach ($ideas as &$idea) {
                $idea['id'] = (int) $idea['id'];
                $idea['is_expired'] = (bool) $idea['is_expired'];
                $idea['interest_id'] = $idea['interest_id'] === null
                    ? null
                    : (int) $idea['interest_id'];
                $idea['chat_id'] = $idea['chat_id'] === null
                    ? null
                    : (int) $idea['chat_id'];
                $idea['offer_count'] = (int) $idea['offer_count'];
                $idea['auction_closed'] = (bool) $idea['auction_closed'];
                $idea['my_offer'] = $idea['offer_id'] === null
                    ? null
                    : [
                        'id' => (int) $idea['offer_id'],
                        'amount' => number_format((float) $idea['amount'], 2, '.', ''),
                        'message' => $idea['message'],
                        'status' => $idea['offer_status'],
                        'created_at' => $idea['offer_created_at'],
                    ];
                unset(
                    $idea['offer_id'],
                    $idea['amount'],
                    $idea['message'],
                    $idea['offer_status'],
                    $idea['offer_created_at']
                );
            }
            unset($idea);
        } else {
            $statement = $connection->prepare(
                'SELECT bi.id, bi.title, bi.description, bi.industry,
                        DATE_FORMAT(
                            DATE_SUB(bi.expires_at, INTERVAL 1 DAY),
                            \'%Y-%m-%d\'
                        ) AS deadline,
                        (bi.expires_at <= CURRENT_TIMESTAMP) AS is_expired,
                        bi.created_at,
                        CONCAT(s.first_name, \' \', s.surname) AS student_name
                 FROM business_ideas bi
                 INNER JOIN students s ON s.id = bi.owner_id
                 WHERE bi.owner_role = \'student\' AND bi.owner_id = :student_id
                 ORDER BY bi.created_at DESC, bi.id DESC'
            );
            $statement->execute(['student_id' => $account['account_id']]);
            $ideas = $statement->fetchAll(PDO::FETCH_ASSOC);
            $offersStatement = $connection->prepare(
                'SELECT o.id, o.amount, o.message, o.offer_status,
                        o.created_at, CONCAT(i.first_name, \' \', i.surname) AS investor_name
                 FROM auction_offers o
                 INNER JOIN investors i ON i.id = o.investor_id
                 WHERE o.idea_id = :idea_id
                 ORDER BY o.created_at, o.id'
            );
            foreach ($ideas as &$idea) {
                $idea['id'] = (int) $idea['id'];
                $idea['is_expired'] = (bool) $idea['is_expired'];
                $offersStatement->execute(['idea_id' => $idea['id']]);
                $idea['offers'] = $offersStatement->fetchAll(PDO::FETCH_ASSOC);
                foreach ($idea['offers'] as &$offer) {
                    $offer['id'] = (int) $offer['id'];
                    $offer['amount'] = number_format((float) $offer['amount'], 2, '.', '');
                    $offer['status'] = $offer['offer_status'];
                    unset($offer['offer_status']);
                }
                unset($offer);
            }
            unset($idea);
        }

        api_respond(200, ['success' => true, 'data' => $ideas]);
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        header('Allow: GET, POST, OPTIONS');
        api_respond(405, ['success' => false, 'message' => 'Use GET or POST.']);
    }

    $data = api_read_json();
    $action = $data['action'] ?? '';

    if ($action === 'offer') {
        if ($account['account_role'] !== 'investor') {
            api_respond(403, ['success' => false, 'message' => 'Only investors can make auction offers.']);
        }
        $ideaId = filter_var($data['idea_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$ideaId || $ideaId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid student idea.']);
        }
        $amount = $data['amount'] ?? null;
        if (!is_numeric($amount) || (float) $amount <= 0 || (float) $amount > 99999999.99) {
            api_respond(422, ['success' => false, 'message' => 'Enter a valid offer amount greater than zero.']);
        }
        $message = $data['message'] ?? '';
        if (!is_string($message) || strlen($message) > 2000) {
            api_respond(422, ['success' => false, 'message' => 'Keep your offer message under 2000 characters.']);
        }

        $connection->beginTransaction();
        $ideaStatement = $connection->prepare(
            'SELECT id FROM business_ideas
             WHERE id = :id AND owner_role = \'student\'
               AND expires_at > CURRENT_TIMESTAMP
             FOR UPDATE'
        );
        $ideaStatement->execute(['id' => $ideaId]);
        if (!$ideaStatement->fetchColumn()) {
            $connection->rollBack();
            api_respond(404, ['success' => false, 'message' => 'Student idea not found or its auction has ended.']);
        }
        $paymentStatement = $connection->prepare(
            'SELECT p.payment_status
             FROM idea_interests ii
             INNER JOIN idea_interest_payments p ON p.interest_id = ii.id
             WHERE ii.idea_id = :idea_id AND ii.investor_id = :investor_id'
        );
        $paymentStatement->execute([
            'idea_id' => $ideaId,
            'investor_id' => $account['account_id'],
        ]);
        if ($paymentStatement->fetchColumn() !== 'paid') {
            $connection->rollBack();
            api_respond(403, ['success' => false, 'message' => 'Pay the R200 admin fee for this idea before submitting an offer.']);
        }
        $acceptedStatement = $connection->prepare(
            'SELECT 1 FROM auction_offers
             WHERE idea_id = :idea_id AND offer_status = \'accepted\''
        );
        $acceptedStatement->execute(['idea_id' => $ideaId]);
        if ($acceptedStatement->fetchColumn()) {
            $connection->rollBack();
            api_respond(409, ['success' => false, 'message' => 'This auction already has an accepted offer.']);
        }
        $existingStatement = $connection->prepare(
            'SELECT offer_status FROM auction_offers
             WHERE idea_id = :idea_id AND investor_id = :investor_id
             FOR UPDATE'
        );
        $existingStatement->execute([
            'idea_id' => $ideaId,
            'investor_id' => $account['account_id'],
        ]);
        $existingStatus = $existingStatement->fetchColumn();
        if ($existingStatus === 'rejected' || $existingStatus === 'accepted') {
            $connection->rollBack();
            api_respond(409, ['success' => false, 'message' => 'This offer can no longer be changed.']);
        }
        $offerStatement = $connection->prepare(
            'INSERT INTO auction_offers (idea_id, investor_id, amount, message)
             VALUES (:idea_id, :investor_id, :amount, :message)
             ON DUPLICATE KEY UPDATE
               amount = VALUES(amount),
               message = VALUES(message),
               updated_at = CURRENT_TIMESTAMP'
        );
        $offerStatement->execute([
            'idea_id' => $ideaId,
            'investor_id' => $account['account_id'],
            'amount' => number_format((float) $amount, 2, '.', ''),
            'message' => trim($message),
        ]);
        $connection->commit();
        api_respond(200, ['success' => true, 'message' => 'Your offer was submitted.']);
    }

    if ($action === 'accept') {
        if ($account['account_role'] !== 'student') {
            api_respond(403, ['success' => false, 'message' => 'Only the student who posted the idea can accept an offer.']);
        }
        $offerId = filter_var($data['offer_id'] ?? null, FILTER_VALIDATE_INT);
        if (!$offerId || $offerId < 1) {
            api_respond(422, ['success' => false, 'message' => 'Choose a valid offer.']);
        }

        $connection->beginTransaction();
        $ideaLookup = $connection->prepare(
            'SELECT idea_id FROM auction_offers WHERE id = :offer_id'
        );
        $ideaLookup->execute(['offer_id' => $offerId]);
        $ideaId = $ideaLookup->fetchColumn();
        if (!$ideaId) {
            $connection->rollBack();
            api_respond(404, ['success' => false, 'message' => 'Offer not found.']);
        }
        $ideaLock = $connection->prepare(
            'SELECT id FROM business_ideas
             WHERE id = :idea_id AND owner_role = \'student\' AND owner_id = :student_id
             FOR UPDATE'
        );
        $ideaLock->execute([
            'idea_id' => $ideaId,
            'student_id' => $account['account_id'],
        ]);
        if (!$ideaLock->fetchColumn()) {
            $connection->rollBack();
            api_respond(404, ['success' => false, 'message' => 'Offer not found for one of your ideas.']);
        }
        $offerStatement = $connection->prepare(
            'SELECT o.id, o.idea_id, o.investor_id, o.amount, o.offer_status,
                    bi.title
             FROM auction_offers o
             INNER JOIN business_ideas bi ON bi.id = o.idea_id
             WHERE o.id = :offer_id AND bi.owner_role = \'student\'
               AND bi.owner_id = :student_id
             FOR UPDATE'
        );
        $offerStatement->execute([
            'offer_id' => $offerId,
            'student_id' => $account['account_id'],
        ]);
        $offer = $offerStatement->fetch(PDO::FETCH_ASSOC);
        if (!$offer) {
            $connection->rollBack();
            api_respond(404, ['success' => false, 'message' => 'Offer not found for one of your ideas.']);
        }
        if ($offer['offer_status'] !== 'pending') {
            $connection->rollBack();
            api_respond(409, ['success' => false, 'message' => 'This offer is no longer available to accept.']);
        }
        $acceptedStatement = $connection->prepare(
            'SELECT 1 FROM auction_offers
             WHERE idea_id = :idea_id AND offer_status = \'accepted\'
             FOR UPDATE'
        );
        $acceptedStatement->execute(['idea_id' => $offer['idea_id']]);
        if ($acceptedStatement->fetchColumn()) {
            $connection->rollBack();
            api_respond(409, ['success' => false, 'message' => 'Another offer has already been accepted for this idea.']);
        }

        $connection->prepare(
            'UPDATE auction_offers
             SET offer_status = \'accepted\', accepted_at = UTC_TIMESTAMP()
             WHERE id = :offer_id'
        )->execute(['offer_id' => $offerId]);
        $connection->prepare(
            'UPDATE auction_offers
             SET offer_status = \'rejected\'
             WHERE idea_id = :idea_id AND id != :offer_id
               AND offer_status = \'pending\''
        )->execute(['idea_id' => $offer['idea_id'], 'offer_id' => $offerId]);
        $chatStatement = $connection->prepare(
            'INSERT INTO investor_chats (idea_id, student_id, investor_id)
             VALUES (:idea_id, :student_id, :investor_id)
             ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)'
        );
        $chatStatement->execute([
            'idea_id' => $offer['idea_id'],
            'student_id' => $account['account_id'],
            'investor_id' => $offer['investor_id'],
        ]);
        $chatId = (int) $connection->lastInsertId();
        $connection->prepare(
            'INSERT INTO investor_chat_messages (chat_id, sender_role, sender_id, body)
             VALUES (:chat_id, \'student\', :student_id, :body)'
        )->execute([
            'chat_id' => $chatId,
            'student_id' => $account['account_id'],
            'body' => 'Your offer of R'
                . number_format((float) $offer['amount'], 2, '.', '')
                . ' was accepted for "' . $offer['title'] . '".',
        ]);
        $connection->prepare(
            'UPDATE investor_chats SET updated_at = CURRENT_TIMESTAMP WHERE id = :id'
        )->execute(['id' => $chatId]);
        $connection->commit();
        api_respond(200, [
            'success' => true,
            'message' => 'Offer accepted. Continue the conversation in your private chat.',
            'chat_id' => $chatId,
        ]);
    }

    api_respond(422, ['success' => false, 'message' => 'Choose a supported auction action.']);
} catch (PDOException $exception) {
    if (isset($connection) && $connection->inTransaction()) {
        $connection->rollBack();
    }
    api_handle_database_error($exception);
}
