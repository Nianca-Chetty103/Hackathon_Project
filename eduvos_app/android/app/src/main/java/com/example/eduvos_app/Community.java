package com.example.eduvos_app;

import org.json.JSONObject;
import org.json.JSONException;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

final class Community {
    private Community() {}

    static Map<String, Object> handle(
            String operation,
            String endpoint,
            String token,
            Map<?, ?> data
    ) throws IOException, JSONException {
        Map<String, String> headers = new HashMap<>();
        headers.put("Authorization", "Bearer " + token);
        String method = "GET";
        JSONObject body = null;

        if ("join".equals(operation) || "leave".equals(operation)) {
            method = "POST";
            body = new JSONObject();
            body.put("action", operation);
            copyValue(data, body, "community_id");
        } else if (!"list".equals(operation)) {
            throw new IllegalArgumentException("Unknown community operation.");
        }

        return AuthApiClient.request(endpoint, method, headers, body == null ? null : body.toString());
    }

    private static void copyValue(Map<?, ?> source, JSONObject destination, String key)
            throws JSONException {
        Object value = source.get(key);
        if (value instanceof String || value instanceof Number) destination.put(key, value);
    }
}
