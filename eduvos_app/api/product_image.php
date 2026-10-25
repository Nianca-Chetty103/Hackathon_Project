<?php

require_once __DIR__ . '/api_common.php';

header('Access-Control-Allow-Methods: GET, OPTIONS');
api_handle_options();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    header('Allow: GET, OPTIONS');
    api_respond(405, ['success' => false, 'message' => 'Method not allowed.']);
}

try {
    $connection = get_database_connection();
    api_authenticated_account($connection);
    $imageId = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
    if (!$imageId || $imageId < 1) {
        api_respond(404, ['success' => false, 'message' => 'Product photo not found.']);
    }

    $listingType = $_GET['type'] ?? 'product';
    if (!is_string($listingType) || !in_array($listingType, ['product', 'service'], true)) {
        api_respond(404, ['success' => false, 'message' => 'Listing image not found.']);
    }
    $imageTable = $listingType === 'product' ? 'product_images' : 'service_images';
    $statement = $connection->prepare(
        'SELECT image_path, mime_type, file_size
         FROM ' . $imageTable . ' WHERE id = :id LIMIT 1'
    );
    $statement->execute(['id' => $imageId]);
    $image = $statement->fetch(PDO::FETCH_ASSOC);
    $allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!$image || !in_array($image['mime_type'], $allowedMimeTypes, true)) {
        api_respond(404, ['success' => false, 'message' => 'Listing image not found.']);
    }

    $fileName = basename($image['image_path']);
    $imagePath = __DIR__ . '/uploads/' . $listingType . '_images/' . $fileName;
    if (!is_file($imagePath)) {
        api_respond(404, ['success' => false, 'message' => 'Listing image is unavailable.']);
    }

    header_remove('Content-Type');
    header('Content-Type: ' . $image['mime_type']);
    header('Content-Length: ' . (string) filesize($imagePath));
    header('Cache-Control: private, max-age=86400');
    readfile($imagePath);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
