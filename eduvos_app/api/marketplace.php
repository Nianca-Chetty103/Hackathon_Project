<?php

require_once __DIR__ . '/api_common.php';

api_handle_options();

try {
    $connection = get_database_connection();
    $account = api_authenticated_account($connection);
    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $products = $connection->query(
            'SELECT id, owner_role, owner_id, title, description, price, created_at
             FROM products ORDER BY created_at DESC, id DESC'
        )->fetchAll(PDO::FETCH_ASSOC);
        $services = $connection->query(
            'SELECT id, owner_role, owner_id, title, description, price, created_at
             FROM services ORDER BY created_at DESC, id DESC'
        )->fetchAll(PDO::FETCH_ASSOC);
        $imagesByProduct = [];
        $imageStatement = $connection->query(
            'SELECT id, product_id FROM product_images ORDER BY id'
        );
        foreach ($imageStatement->fetchAll(PDO::FETCH_ASSOC) as $image) {
            $productId = (int) $image['product_id'];
            $imagesByProduct[$productId][] = ['id' => (int) $image['id']];
        }
        $imagesByService = [];
        $serviceImageStatement = $connection->query(
            'SELECT id, service_id FROM service_images ORDER BY id'
        );
        foreach ($serviceImageStatement->fetchAll(PDO::FETCH_ASSOC) as $image) {
            $serviceId = (int) $image['service_id'];
            $imagesByService[$serviceId][] = ['id' => (int) $image['id']];
        }
        foreach ($products as &$product) {
            $product['images'] = $imagesByProduct[(int) $product['id']] ?? [];
        }
        unset($product);
        foreach ($services as &$service) {
            $service['images'] = $imagesByService[(int) $service['id']] ?? [];
        }
        unset($service);

        foreach (['products' => &$products, 'services' => &$services] as &$items) {
            foreach ($items as &$item) {
                $item['id'] = (int) $item['id'];
                $item['owner_id'] = (int) $item['owner_id'];
                $item['price'] = $item['price'] === null ? null : (float) $item['price'];
                $item['seller'] = api_owner_name($connection, $item['owner_role'], $item['owner_id']);
                $item['is_mine'] = $item['owner_role'] === $account['account_role']
                    && $item['owner_id'] === $account['account_id'];
                $item['can_edit'] = $item['is_mine'];
                $item['can_delete'] = $item['is_mine'] || $account['account_role'] === 'admin';
                $item['can_chat'] = !$item['is_mine'];
            }
            unset($item);
        }
        unset($items);

        api_respond(200, [
            'success' => true,
            'data' => ['products' => $products, 'services' => $services],
        ]);
    }

    if ($method === 'POST') {
        $data = isset($_POST['action']) ? $_POST : api_read_json();
        $action = $data['action'] ?? '';

        if ($action === 'create') {
            api_require_student($account);
            $type = $data['type'] ?? null;
            if (!is_string($type) || !in_array($type, ['product', 'service'], true)) {
                api_respond(422, ['success' => false, 'message' => 'Choose a product or service listing.']);
            }

            $title = api_required_string($data, 'title', 150);
            $description = api_required_string($data, 'description', 5000);
            $price = $data['price'] ?? null;
            if ($price !== null && (!is_numeric($price) || (float) $price < 0 || (float) $price > 99999999.99)) {
                api_respond(422, ['success' => false, 'message' => 'Enter a valid non-negative price, or leave it blank.']);
            }

            $table = $type === 'product' ? 'products' : 'services';
            $statement = $connection->prepare(
                'INSERT INTO ' . $table . ' (owner_role, owner_id, title, description, price)
                 VALUES (:owner_role, :owner_id, :title, :description, :price)'
            );
            $statement->execute([
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
                'title' => $title,
                'description' => $description,
                'price' => $price === null || $price === '' ? null : (float) $price,
            ]);

            api_respond(201, [
                'success' => true,
                'message' => 'Listing created.',
                'id' => (int) $connection->lastInsertId(),
            ]);
        }

        if ($action === 'upload_images') {
            if ($account['account_role'] !== 'student') {
                api_respond(403, ['success' => false, 'message' => 'Only student listing owners can upload listing images.']);
            }
            $listingType = $data['type'] ?? 'product';
            if (!is_string($listingType) || !in_array($listingType, ['product', 'service'], true)) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid listing type.']);
            }
            $listingId = filter_var(
                $data['listing_id'] ?? $data[$listingType . '_id'] ?? $data['product_id'] ?? null,
                FILTER_VALIDATE_INT
            );
            if (!$listingId || $listingId < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid listing.']);
            }
            $listingTable = $listingType === 'product' ? 'products' : 'services';
            $imageTable = $listingType === 'product' ? 'product_images' : 'service_images';
            $listingIdColumn = $listingType === 'product' ? 'product_id' : 'service_id';
            $ownerStatement = $connection->prepare(
                'SELECT 1 FROM ' . $listingTable . '
                 WHERE id = :id AND owner_role = :owner_role AND owner_id = :owner_id'
            );
            $ownerStatement->execute([
                'id' => $listingId,
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
            ]);
            if (!$ownerStatement->fetchColumn()) {
                api_respond(404, ['success' => false, 'message' => 'Listing not found or you cannot add images to it.']);
            }

            $uploadedFiles = $_FILES['images'] ?? null;
            if (!is_array($uploadedFiles) || !isset($uploadedFiles['name']) ||
                !is_array($uploadedFiles['name'])) {
                api_respond(422, ['success' => false, 'message' => 'Select an image for your listing.']);
            }
            $fileCount = count($uploadedFiles['name']);
            $maximumImages = $listingType === 'product' ? 5 : 1;
            if ($fileCount < 1 || $fileCount > $maximumImages) {
                api_respond(422, ['success' => false, 'message' => 'A service can have one price-list image; products can have up to five photos.']);
            }
            $previousImagePaths = [];
            if ($listingType === 'service') {
                $existingImages = $connection->prepare(
                    'SELECT image_path FROM service_images WHERE service_id = :listing_id'
                );
                $existingImages->execute(['listing_id' => $listingId]);
                $previousImagePaths = $existingImages->fetchAll(PDO::FETCH_COLUMN);
            } else {
                $countStatement = $connection->prepare(
                    'SELECT COUNT(*) FROM product_images WHERE product_id = :listing_id'
                );
                $countStatement->execute(['listing_id' => $listingId]);
                if ((int) $countStatement->fetchColumn() + $fileCount > $maximumImages) {
                    api_respond(422, ['success' => false, 'message' => 'A product can have up to five photos.']);
                }
            }

            $finfo = new finfo(FILEINFO_MIME_TYPE);
            $allowedMimeTypes = [
                'image/jpeg' => 'jpg',
                'image/png' => 'png',
                'image/webp' => 'webp',
            ];
            $validFiles = [];
            for ($index = 0; $index < $fileCount; $index++) {
                $error = $uploadedFiles['error'][$index] ?? UPLOAD_ERR_NO_FILE;
                $temporaryPath = $uploadedFiles['tmp_name'][$index] ?? '';
                $size = $uploadedFiles['size'][$index] ?? 0;
                if ($error !== UPLOAD_ERR_OK || !is_uploaded_file($temporaryPath) ||
                    $size < 1 || $size > 5 * 1024 * 1024) {
                    api_respond(422, ['success' => false, 'message' => 'Each image must be a valid image smaller than 5 MB.']);
                }
                $mimeType = $finfo->file($temporaryPath);
                if (!is_string($mimeType) || !isset($allowedMimeTypes[$mimeType])) {
                    api_respond(422, ['success' => false, 'message' => 'Images must be JPEG, PNG, or WebP files.']);
                }
                $validFiles[] = [
                    'temporary_path' => $temporaryPath,
                    'size' => (int) $size,
                    'mime_type' => $mimeType,
                    'extension' => $allowedMimeTypes[$mimeType],
                ];
            }

            $uploadDirectory = __DIR__ . '/uploads/' . $listingType . '_images';
            if (!is_dir($uploadDirectory) &&
                !mkdir($uploadDirectory, 0750, true) && !is_dir($uploadDirectory)) {
                error_log('Eduvos Marketplace could not create ' . $listingType . ' image directory.');
                api_respond(500, ['success' => false, 'message' => 'Listing image storage is unavailable.']);
            }

            $savedPaths = [];
            try {
                $connection->beginTransaction();
                if ($listingType === 'service' && $previousImagePaths !== []) {
                    $connection->prepare(
                        'DELETE FROM service_images WHERE service_id = :listing_id'
                    )->execute(['listing_id' => $listingId]);
                }
                $insert = $connection->prepare(
                    'INSERT INTO ' . $imageTable . '
                        (' . $listingIdColumn . ', image_path, mime_type, file_size)
                     VALUES (:listing_id, :image_path, :mime_type, :file_size)'
                );
                foreach ($validFiles as $file) {
                    $fileName = bin2hex(random_bytes(24)) . '.' . $file['extension'];
                    $destination = $uploadDirectory . '/' . $fileName;
                    if (!move_uploaded_file($file['temporary_path'], $destination)) {
                        throw new RuntimeException('A product photo could not be saved.');
                    }
                    $savedPaths[] = $destination;
                    $insert->execute([
                        'listing_id' => $listingId,
                        'image_path' => 'uploads/' . $listingType . '_images/' . $fileName,
                        'mime_type' => $file['mime_type'],
                        'file_size' => $file['size'],
                    ]);
                }
                $connection->commit();
                foreach ($previousImagePaths as $previousImagePath) {
                    $absolutePath = __DIR__ . '/' . $previousImagePath;
                    if (is_file($absolutePath) && !unlink($absolutePath)) {
                        error_log('Eduvos Marketplace could not remove replaced service image: ' . $absolutePath);
                    }
                }
            } catch (Throwable $exception) {
                if ($connection->inTransaction()) {
                    $connection->rollBack();
                }
                foreach ($savedPaths as $savedPath) {
                    if (is_file($savedPath) && !unlink($savedPath)) {
                        error_log('Eduvos Marketplace could not remove an incomplete listing image: ' . $savedPath);
                    }
                }
                if ($exception instanceof PDOException) {
                    throw $exception;
                }
                error_log('Eduvos Marketplace listing image upload failed: ' . $exception->getMessage());
                api_respond(500, ['success' => false, 'message' => 'A listing image could not be saved.']);
            }

            api_respond(201, ['success' => true, 'message' => 'Listing images uploaded.']);
        }

        if ($action === 'update') {
            $type = $data['type'] ?? null;
            $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT);
            if (!is_string($type) || !in_array($type, ['product', 'service'], true) || !$id || $id < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid listing to update.']);
            }

            $title = api_required_string($data, 'title', 150);
            $description = api_required_string($data, 'description', 5000);
            $price = $data['price'] ?? null;
            if ($price !== null && $price !== '' &&
                (!is_numeric($price) || (float) $price < 0 || (float) $price > 99999999.99)) {
                api_respond(422, ['success' => false, 'message' => 'Enter a valid non-negative price, or leave it blank.']);
            }

            $table = $type === 'product' ? 'products' : 'services';
            $statement = $connection->prepare(
                'UPDATE ' . $table . '
                 SET title = :title, description = :description, price = :price
                 WHERE id = :id AND owner_role = :owner_role AND owner_id = :owner_id'
            );
            $statement->execute([
                'title' => $title,
                'description' => $description,
                'price' => $price === null || $price === '' ? null : (float) $price,
                'id' => $id,
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
            ]);
            if ($statement->rowCount() === 0) {
                $exists = $connection->prepare('SELECT 1 FROM ' . $table . ' WHERE id = :id');
                $exists->execute(['id' => $id]);
                if (!$exists->fetchColumn()) {
                    api_respond(404, ['success' => false, 'message' => 'Listing not found.']);
                }
                $owner = $connection->prepare(
                    'SELECT 1 FROM ' . $table . '
                     WHERE id = :id AND owner_role = :owner_role AND owner_id = :owner_id'
                );
                $owner->execute([
                    'id' => $id,
                    'owner_role' => $account['account_role'],
                    'owner_id' => $account['account_id'],
                ]);
                if (!$owner->fetchColumn()) {
                    api_respond(404, ['success' => false, 'message' => 'Listing not found or you cannot edit it.']);
                }
            }
            api_respond(200, ['success' => true, 'message' => 'Listing updated.']);
        }

        if ($action === 'delete') {
            $type = $data['type'] ?? null;
            $id = filter_var($data['id'] ?? null, FILTER_VALIDATE_INT);
            if (!is_string($type) || !in_array($type, ['product', 'service'], true) || !$id || $id < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid listing to delete.']);
            }

            $table = $type === 'product' ? 'products' : 'services';
            $imageTable = $type === 'product' ? 'product_images' : 'service_images';
            $listingIdColumn = $type === 'product' ? 'product_id' : 'service_id';
            $images = $connection->prepare(
                'SELECT image_path FROM ' . $imageTable . '
                 WHERE ' . $listingIdColumn . ' = :id'
            );
            $images->execute(['id' => $id]);
            $imagePaths = $images->fetchAll(PDO::FETCH_COLUMN);
            $statement = $connection->prepare(
                'DELETE FROM ' . $table . '
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
                api_respond(404, ['success' => false, 'message' => 'Listing not found or you cannot delete it.']);
            }
            foreach ($imagePaths as $imagePath) {
                $absolutePath = __DIR__ . '/' . $imagePath;
                if (is_file($absolutePath) && !unlink($absolutePath)) {
                    error_log('Eduvos Marketplace could not remove listing image: ' . $absolutePath);
                }
            }
            api_respond(200, ['success' => true, 'message' => 'Listing deleted.']);
        }
    }

    header('Allow: GET, POST, OPTIONS');
    api_respond(405, ['success' => false, 'message' => 'Use GET or a supported POST action.']);
} catch (PDOException $exception) {
    api_handle_database_error($exception);
}
