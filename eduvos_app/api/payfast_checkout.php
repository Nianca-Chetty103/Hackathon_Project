<?php

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/payfast_common.php';

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

function checkout_error(int $status, string $message): void
{
    http_response_code($status);
    echo '<!doctype html><html lang="en"><meta charset="utf-8"><title>Eduvos payment</title>'
        . '<p>' . htmlspecialchars($message, ENT_QUOTES, 'UTF-8') . '</p></html>';
    exit;
}

$token = $_GET['token'] ?? '';
if (!is_string($token) || !preg_match('/^[a-f0-9]{64}$/', $token)) {
    checkout_error(400, 'This payment link is invalid. Return to Eduvos and try again.');
}

$configuration = payfast_local_configuration();
if (!payfast_configuration_is_ready($configuration)) {
    checkout_error(503, 'PayFast is not configured for this installation.');
}

try {
    $connection = get_database_connection();
    $connection->beginTransaction();
    $statement = $connection->prepare(
        'SELECT p.gateway_reference, p.amount, p.payment_status,
                i.idea_id, inv.first_name, inv.email
         FROM idea_interest_payments p
         INNER JOIN idea_interests i ON i.id = p.interest_id
         INNER JOIN investors inv ON inv.id = i.investor_id
         WHERE p.checkout_token_hash = :token_hash
           AND p.checkout_expires_at > UTC_TIMESTAMP()
         LIMIT 1
         FOR UPDATE'
    );
    $statement->execute(['token_hash' => hash('sha256', $token)]);
    $payment = $statement->fetch(PDO::FETCH_ASSOC);
    if (!$payment || $payment['payment_status'] !== 'pending') {
        $connection->rollBack();
        checkout_error(410, 'This payment link has expired or has already been used. Return to Eduvos to refresh it.');
    }
    $consumeToken = $connection->prepare(
        'UPDATE idea_interest_payments
         SET checkout_token_hash = NULL, checkout_expires_at = NULL
         WHERE gateway_reference = :gateway_reference
           AND checkout_token_hash = :token_hash'
    );
    $consumeToken->execute([
        'gateway_reference' => $payment['gateway_reference'],
        'token_hash' => hash('sha256', $token),
    ]);
    if ($consumeToken->rowCount() !== 1) {
        $connection->rollBack();
        checkout_error(410, 'This payment link has already been used. Return to Eduvos to refresh it.');
    }
    $connection->commit();

    $fields = [
        'merchant_id' => $configuration['merchant_id'],
        'merchant_key' => $configuration['merchant_key'],
        'return_url' => $configuration['return_url'],
        'cancel_url' => $configuration['cancel_url'],
        'notify_url' => $configuration['notify_url'],
        'name_first' => $payment['first_name'],
        'email_address' => $payment['email'],
        'm_payment_id' => $payment['gateway_reference'],
        'amount' => number_format((float) $payment['amount'], 2, '.', ''),
        'item_name' => 'Eduvos investor idea admin fee',
        'item_description' => 'Admin fee for expressing interest in business idea ' . $payment['idea_id'],
    ];
    $fields['signature'] = payfast_signature($fields, $configuration['passphrase']);
    $processUrl = payfast_process_url($configuration);
    $allowedFormAction = htmlspecialchars($processUrl, ENT_QUOTES, 'UTF-8');

    header(
        "Content-Security-Policy: default-src 'none'; form-action "
        . ($configuration['sandbox'] ? 'https://sandbox.payfast.co.za' : 'https://www.payfast.co.za')
        . "; script-src 'unsafe-inline'; style-src 'unsafe-inline'"
    );
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        . '<meta name="viewport" content="width=device-width, initial-scale=1">'
        . '<title>Continue to PayFast</title>'
        . '<style>body{font:16px sans-serif;max-width:36rem;margin:4rem auto;padding:0 1rem}button{padding:.8rem 1.2rem}</style>'
        . '</head><body><h1>Continue to PayFast</h1><p>You are paying R200.00 (ZAR) to Eduvos.</p>'
        . '<form id="payfast" method="post" action="' . $allowedFormAction . '">';
    foreach ($fields as $name => $value) {
        echo '<input type="hidden" name="' . htmlspecialchars($name, ENT_QUOTES, 'UTF-8')
            . '" value="' . htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8') . '">';
    }
    echo '<button type="submit">Continue securely</button></form>'
        . '<script>document.getElementById("payfast").submit();</script></body></html>';
} catch (Throwable $exception) {
    if (isset($connection) && $connection instanceof PDO && $connection->inTransaction()) {
        $connection->rollBack();
    }
    error_log('Eduvos PayFast checkout error: ' . $exception->getMessage());
    checkout_error(500, 'The payment page could not be prepared. Return to Eduvos and try again.');
}
