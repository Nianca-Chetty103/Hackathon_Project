package com.example.eduvos_app;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

final class AuthApiClient {
    private AuthApiClient() {}

    static Map<String, Object> request(
            String url,
            String method,
            Map<String, String> headers,
            String body
    ) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
        connection.setRequestMethod(method);
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(15000);
        connection.setRequestProperty("Accept", "application/json");

        for (Map.Entry<String, String> header : headers.entrySet()) {
            connection.setRequestProperty(header.getKey(), header.getValue());
        }

        if (("POST".equals(method) || "DELETE".equals(method)) && body != null) {
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            byte[] requestBody = body.getBytes(StandardCharsets.UTF_8);
            try (OutputStream output = connection.getOutputStream()) {
                output.write(requestBody);
            }
        }

        try {
            int statusCode = connection.getResponseCode();
            InputStream responseStream = statusCode >= HttpURLConnection.HTTP_BAD_REQUEST
                    ? connection.getErrorStream()
                    : connection.getInputStream();
            String responseBody = responseStream == null ? "" : readResponse(responseStream);

            Map<String, Object> response = new HashMap<>();
            response.put("statusCode", statusCode);
            response.put("body", responseBody);
            return response;
        } finally {
            connection.disconnect();
        }
    }

    private static String readResponse(InputStream input) throws IOException {
        try (InputStream response = input;
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096];
            int bytesRead;
            while ((bytesRead = response.read(buffer)) != -1) {
                output.write(buffer, 0, bytesRead);
            }
            return output.toString(StandardCharsets.UTF_8.name());
        }
    }
}
