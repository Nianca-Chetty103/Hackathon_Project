package com.example.eduvos_app;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

final class Bursaries {
    private Bursaries() {}

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

        if ("create".equals(operation)) {
            method = "POST";
            body = new JSONObject();
            body.put("action", operation);
            copyValue(data, body, "company_name");
            copyValue(data, body, "name");
            copyValue(data, body, "details");
            copyValue(data, body, "application_url");
        } else if (!"list".equals(operation)) {
            throw new IllegalArgumentException("Unknown bursaries operation.");
        }

        return AuthApiClient.request(endpoint, method, headers, body == null ? null : body.toString());
    }

    private static void copyValue(Map<?, ?> source, JSONObject destination, String key)
            throws JSONException {
        Object value = source.get(key);
        if (value instanceof String || value instanceof Number) destination.put(key, value);
    }
}
