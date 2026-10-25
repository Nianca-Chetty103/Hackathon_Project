<?php

function payfast_local_configuration(): ?array
{
    $path = __DIR__ . '/payfast_config.local.php';
    if (!is_file($path)) {
        return null;
    }

    $configuration = require $path;
    return is_array($configuration) ? $configuration : null;
}

function payfast_configuration_is_ready(?array $configuration): bool
{
    if ($configuration === null) {
        return false;
    }

    foreach (['merchant_id', 'merchant_key', 'return_url', 'cancel_url', 'notify_url', 'checkout_url'] as $key) {
        if (!isset($configuration[$key]) || !is_string($configuration[$key]) || trim($configuration[$key]) === '') {
            return false;
        }
    }

    if (!array_key_exists('passphrase', $configuration) || !is_string($configuration['passphrase'])) {
        return false;
    }
    if (!array_key_exists('sandbox', $configuration) || !is_bool($configuration['sandbox'])) {
        return false;
    }

    foreach (['return_url', 'cancel_url', 'notify_url', 'checkout_url'] as $key) {
        $url = filter_var($configuration[$key], FILTER_VALIDATE_URL);
        $scheme = is_string($url) ? strtolower((string) parse_url($url, PHP_URL_SCHEME)) : '';
        if (!in_array($scheme, ['http', 'https'], true)) {
            return false;
        }
    }

    return true;
}

function payfast_signature(array $fields, string $passphrase): string
{
    unset($fields['signature']);
    ksort($fields);
    $parts = [];
    foreach ($fields as $key => $value) {
        if (!is_scalar($value)) {
            throw new InvalidArgumentException('PayFast fields must be scalar values.');
        }
        $value = trim((string) $value);
        if ($value !== '') {
            $parts[] = $key . '=' . urlencode($value);
        }
    }
    if ($passphrase !== '') {
        $parts[] = 'passphrase=' . urlencode(trim($passphrase));
    }

    return md5(implode('&', $parts));
}

function payfast_process_url(array $configuration): string
{
    return $configuration['sandbox']
        ? 'https://sandbox.payfast.co.za/eng/process'
        : 'https://www.payfast.co.za/eng/process';
}

function payfast_validation_url(array $configuration): string
{
    return $configuration['sandbox']
        ? 'https://sandbox.payfast.co.za/eng/query/validate'
        : 'https://www.payfast.co.za/eng/query/validate';
}
