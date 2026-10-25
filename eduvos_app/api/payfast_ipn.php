<?php

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/payfast_common.php';

header('Content-Type: text/plain; charset=utf-8');

function ipn_reject(int $status, string $message): void
{
    http_response_code($status);
    error_log('Eduvos PayFast IPN rejected: ' . $message);
    echo $message;
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    ipn_reject(405, 'POST required');
}

$configuration = payfast_local_configuration();
if (!payfast_configuration_is_ready($configuration)) {
    ipn_reject(503, 'PayFast is not configured');
}

$fields = $_POST;
foreach ($fields as $value) {
    if (!is_string($value)) {
        ipn_reject(400, 'Payment fields must be scalar values');
    }
}
$signature = $fields['signature'] ?? null;
if (!is_string($signature) || !hash_equals(
    payfast_signature($fields, $configuration['passphrase']),
    strtolower($signature)
)) {
    ipn_reject(400, 'Invalid signature');
}
if (!isset($fields['merchant_id'], $fields['m_payment_id'], $fields['payment_status'])) {
    ipn_reject(400, 'Required payment fields are missing');
}
if (!hash_equals((string) $configuration['merchant_id'], (string) $fields['merchant_id'])) {
    ipn_reject(400, 'Unexpected merchant');
}
if (!function_exists('curl_init')) {
    ipn_reject(500, 'The PHP cURL extension is required for PayFast validation');
}

$curl = curl_init(payfast_validation_url($configuration));
if ($curl === false) {
    ipn_reject(500, 'Could not initialize PayFast validation');
}
curl_setopt_array($curl, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query($fields),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_TIMEOUT => 20,
    CURLOPT_SSL_VERIFYPEER => true,
    CURLOPT_SSL_VERIFYHOST => 2,
    CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
]);
$validationResponse = curl_exec($curl);
$curlError = curl_error($curl);
$httpStatus = (int) curl_getinfo($curl, CURLINFO_HTTP_CODE);
curl_close($curl);
if (!is_string($validationResponse) || $curlError !== '' || $httpStatus !== 200
    || trim($validationResponse) !== 'VALID') {
    ipn_reject(502, 'PayFast server validation failed');
}

if ($fields['payment_status'] !== 'COMPLETE') {
    http_response_code(200);
    echo 'Payment not complete';
    exit;
}
if (!isset($fields['amount_gross'], $fields['pf_payment_id'])
    || !is_numeric($fields['amount_gross'])
    || !preg_match('/^\d+(?:\.\d{1,2})?$/', (string) $fields['amount_gross'])) {
    ipn_reject(400, 'Payment amount or PayFast transaction ID is invalid');
}

try {
    $connection = get_database_connection();
    $connection->beginTransaction();
    $paymentStatement = $connection->prepare(
        'SELECT id, amount, payment_status
         FROM idea_interest_payments
         WHERE gateway_reference = :gateway_reference
         FOR UPDATE'
    );
    $paymentStatement->execute(['gateway_reference' => $fields['m_payment_id']]);
    $payment = $paymentStatement->fetch(PDO::FETCH_ASSOC);
    if (!$payment) {
        $connection->rollBack();
        ipn_reject(404, 'Payment reference was not found');
    }
    $expectedCents = (int) round((float) $payment['amount'] * 100);
    $receivedCents = (int) round((float) $fields['amount_gross'] * 100);
    if ($expectedCents !== $receivedCents) {
        $connection->rollBack();
        ipn_reject(400, 'Payment amount does not match');
    }

    if ($payment['payment_status'] !== 'paid') {
        $update = $connection->prepare(
            'UPDATE idea_interest_payments
             SET payment_status = \'paid\', verification_source = \'payfast\',
                 verified_by_admin_id = NULL, payfast_payment_id = :payfast_payment_id,
                 paid_at = UTC_TIMESTAMP(), checkout_token_hash = NULL,
                 checkout_expires_at = NULL
             WHERE id = :id AND payment_status != \'paid\''
        );
        $update->execute([
            'payfast_payment_id' => (string) $fields['pf_payment_id'],
            'id' => $payment['id'],
        ]);
    }
    $connection->commit();
    http_response_code(200);
    echo 'OK';
} catch (Throwable $exception) {
    if (isset($connection) && $connection instanceof PDO && $connection->inTransaction()) {
        $connection->rollBack();
    }
    error_log('Eduvos PayFast IPN processing error: ' . $exception->getMessage());
    http_response_code(500);
    echo 'Could not process payment';
}
