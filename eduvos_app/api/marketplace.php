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
        foreach ($products as &$product) {
            $product['images'] = $imagesByProduct[(int) $product['id']] ?? [];
        }
        unset($product);

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
                api_respond(403, ['success' => false, 'message' => 'Only student listing owners can upload product photos.']);
            }
            $productId = filter_var($data['product_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$productId || $productId < 1) {
                api_respond(422, ['success' => false, 'message' => 'Choose a valid product listing.']);
            }
            $ownerStatement = $connection->prepare(
                'SELECT 1 FROM products
                 WHERE id = :id AND owner_role = :owner_role AND owner_id = :owner_id'
            );
            $ownerStatement->execute([
                'id' => $productId,
                'owner_role' => $account['account_role'],
                'owner_id' => $account['account_id'],
            ]);
            if (!$ownerStatement->fetchColumn()) {
                api_respond(404, ['success' => false, 'message' => 'Product not found or you cannot add photos to it.']);
            }

            $uploadedFiles = $_FILES['images'] ?? null;
            if (!is_array($uploadedFiles) || !isset($uploadedFiles['name']) ||
                !is_array($uploadedFiles['name'])) {
                api_respond(422, ['success' => false, 'message' => 'Select at least one product photo.']);
            }
            $fileCount = count($uploadedFiles['name']);
            if ($fileCount < 1 || $fileCount > 5) {
                api_respond(422, ['success' => false, 'message' => 'Upload between 1 and 5 photos at a time.']);
            }
            $countStatement = $connection->prepare(
                'SELECT COUNT(*) FROM product_images WHERE product_id = :product_id'
            );
            $countStatement->execute(['product_id' => $productId]);
            if ((int) $countStatement->fetchColumn() + $fileCount > 5) {
                api_respond(422, ['success' => false, 'message' => 'A product can have up to 5 photos.']);
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
                    api_respond(422, ['success' => false, 'message' => 'Each photo must be a valid image smaller than 5 MB.']);
                }
                $mimeType = $finfo->file($temporaryPath);
                if (!is_string($mimeType) || !isset($allowedMimeTypes[$mimeType])) {
                    api_respond(422, ['success' => false, 'message' => 'Photos must be JPEG, PNG, or WebP images.']);
                }
                $validFiles[] = [
                    'temporary_path' => $temporaryPath,
                    'size' => (int) $size,
                    'mime_type' => $mimeType,
                    'extension' => $allowedMimeTypes[$mimeType],
                ];
            }

            $uploadDirectory = __DIR__ . '/uploads/product_images';
            if (!is_dir($uploadDirectory) &&
                !mkdir($uploadDirectory, 0750, true) && !is_dir($uploadDirectory)) {
                error_log('Eduvos Marketplace could not create product image directory.');
                api_respond(500, ['success' => false, 'message' => 'Product photo storage is unavailable.']);
            }

            $savedPaths = [];
            try {
                $connection->beginTransaction();
                $insert = $connection->prepare(
                    'INSERT INTO product_images (product_id, image_path, mime_type, file_size)
                     VALUES (:product_id, :image_path, :mime_type, :file_size)'
                );
                foreach ($validFiles as $file) {
                    $fileName = bin2hex(random_bytes(24)) . '.' . $file['extension'];
                    $destination = $uploadDirectory . '/' . $fileName;
                    if (!move_uploaded_file($file['temporary_path'], $destination)) {
                        throw new RuntimeException('A product photo could not be saved.');
                    }
                    $savedPaths[] = $destination;
                    $insert->execute([
                        'product_id' => $productId,
                        'image_path' => 'uploads/product_images/' . $fileName,
                        'mime_type' => $file['mime_type'],
                        'file_size' => $file['size'],
                    ]);
                }
                $connection->commit();
            } catch (Throwable $exception) {
                if ($connection->inTransaction()) {
                    $connection->rollBack();
                }
                foreach ($savedPaths as $savedPath) {
                    if (is_file($savedPath) && !unlink($savedPath)) {
                        error_log('Eduvos Marketplace could not remove an incomplete product photo: ' . $savedPath);
                    }
                }
                if ($exception instanceof PDOException) {
                    throw $exception;
                }
                error_log('Eduvos Marketplace product photo upload failed: ' . $exception->getMessage());
                api_respond(500, ['success' => false, 'message' => 'A product photo could not be saved.']);
            }

            api_respond(201, ['success' => true, 'message' => 'Product photos uploaded.']);
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
            $imagePaths = [];
            if ($type === 'product') {
                $images = $connection->prepare(
                    'SELECT image_path FROM product_images WHERE product_id = :id'
                );
                $images->execute(['id' => $id]);
                $imagePaths = $images->fetchAll(PDO::FETCH_COLUMN);
            }
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
                    error_log('Eduvos Marketplace could not remove product photo: ' . $absolutePath);
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
