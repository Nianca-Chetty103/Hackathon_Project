package com.example.eduvos_app;

import org.json.JSONObject;
import org.json.JSONException;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

final class Marketplace {
    private Marketplace() {}

    static Map<String, Object> handle(
            String operation,
            String endpoint,
            String token,
            Map<?, ?> data
    ) throws IOException, JSONException {
        if ("uploadImages".equals(operation)) {
            Object productId = data.get("product_id");
            Object filePaths = data.get("files");
            if (!(productId instanceof Number) || !(filePaths instanceof List)) {
                throw new IllegalArgumentException("A product ID and image files are required.");
            }
            return uploadImages(
                    endpoint,
                    token,
                    ((Number) productId).intValue(),
                    (List<?>) filePaths
            );
        }

        Map<String, String> headers = new HashMap<>();
        headers.put("Authorization", "Bearer " + token);
        String method = "GET";
        JSONObject body = null;

        if ("createProduct".equals(operation) || "createService".equals(operation)) {
            method = "POST";
            body = new JSONObject();
            body.put("action", "create");
            body.put("type", "createProduct".equals(operation) ? "product" : "service");
            copyString(data, body, "title");
            copyString(data, body, "description");
            copyString(data, body, "price");
        } else if ("update".equals(operation)) {
            method = "POST";
            body = new JSONObject();
            body.put("action", "update");
            copyString(data, body, "type");
            copyString(data, body, "id");
            copyString(data, body, "title");
            copyString(data, body, "description");
            copyString(data, body, "price");
        } else if ("delete".equals(operation)) {
            method = "POST";
            body = new JSONObject();
            body.put("action", "delete");
            copyString(data, body, "type");
            copyString(data, body, "id");
        } else if (!"list".equals(operation)) {
            throw new IllegalArgumentException("Unknown Marketplace operation.");
        }

        return AuthApiClient.request(endpoint, method, headers, body == null ? null : body.toString());
    }

    private static Map<String, Object> uploadImages(
            String endpoint,
            String token,
            int productId,
            List<?> paths
    ) throws IOException {
        String boundary = "Eduvos" + UUID.randomUUID().toString().replace("-", "");
        HttpURLConnection connection = (HttpURLConnection) new URL(endpoint).openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(60000);
        connection.setDoOutput(true);
        connection.setChunkedStreamingMode(8192);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("Authorization", "Bearer " + token);
        connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);

        try {
            try (OutputStream rawOutput = connection.getOutputStream();
                 BufferedOutputStream output = new BufferedOutputStream(rawOutput)) {
                writeField(output, boundary, "action", "upload_images");
                writeField(output, boundary, "product_id", String.valueOf(productId));
                for (int index = 0; index < paths.size(); index++) {
                    Object pathValue = paths.get(index);
                    if (!(pathValue instanceof String)) {
                        throw new IOException("A selected product photo has an invalid path.");
                    }
                    File file = new File((String) pathValue);
                    if (!file.isFile() || !file.canRead()) {
                        throw new IOException("A selected product photo is no longer available.");
                    }
                    writeAscii(output, "--" + boundary + "\r\n");
                    writeAscii(
                            output,
                            "Content-Disposition: form-data; name=\"images[]\"; filename=\"photo-"
                                    + index + ".jpg\"\r\n"
                    );
                    writeAscii(output, "Content-Type: image/jpeg\r\n\r\n");
                    try (InputStream input = new BufferedInputStream(new FileInputStream(file))) {
                        byte[] buffer = new byte[8192];
                        int bytesRead;
                        while ((bytesRead = input.read(buffer)) != -1) {
                            output.write(buffer, 0, bytesRead);
                        }
                    }
                    writeAscii(output, "\r\n");
                }
                writeAscii(output, "--" + boundary + "--\r\n");
                output.flush();
            }

            int statusCode = connection.getResponseCode();
            InputStream responseStream = statusCode >= HttpURLConnection.HTTP_BAD_REQUEST
                    ? connection.getErrorStream()
                    : connection.getInputStream();
            String responseBody = responseStream == null
                    ? ""
                    : readResponse(responseStream);
            Map<String, Object> response = new HashMap<>();
            response.put("statusCode", statusCode);
            response.put("body", responseBody);
            return response;
        } finally {
            connection.disconnect();
        }
    }

    private static void writeField(
            OutputStream output,
            String boundary,
            String name,
            String value
    ) throws IOException {
        writeAscii(output, "--" + boundary + "\r\n");
        writeAscii(output, "Content-Disposition: form-data; name=\"" + name + "\"\r\n\r\n");
        writeAscii(output, value + "\r\n");
    }

    private static void writeAscii(OutputStream output, String value) throws IOException {
        output.write(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String readResponse(InputStream input) throws IOException {
        try (InputStream response = input;
             java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096];
            int bytesRead;
            while ((bytesRead = response.read(buffer)) != -1) {
                output.write(buffer, 0, bytesRead);
            }
            return output.toString(StandardCharsets.UTF_8.name());
        }
    }

    private static void copyString(Map<?, ?> source, JSONObject destination, String key)
            throws JSONException {
        Object value = source.get(key);
        if (value instanceof String) destination.put(key, value);
        else if (value instanceof Number) destination.put(key, value);
    }
}
