<?php

return [
    'merchant_id' => 'YOUR_PAYFAST_MERCHANT_ID',
    'merchant_key' => 'YOUR_PAYFAST_MERCHANT_KEY',
    'passphrase' => 'YOUR_PAYFAST_PASSPHRASE',
    'sandbox' => true,
    'return_url' => 'https://your-public-domain.example/api/payfast_return.php',
    'cancel_url' => 'https://your-public-domain.example/api/payfast_cancel.php',
    'notify_url' => 'https://your-public-domain.example/api/payfast_ipn.php',
    'checkout_url' => 'https://your-public-domain.example/api/payfast_checkout.php',
];
