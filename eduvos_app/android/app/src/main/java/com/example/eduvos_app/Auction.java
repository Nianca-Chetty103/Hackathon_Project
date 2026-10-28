package com.example.eduvos_app;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

final class Auction {
    private Auction() {}

    static Map<String, Object> handle(
            String operation,
            String endpoint,
            String token,
            Map<?, ?> data
    ) throws IOException, JSONException {
        Map<String, String> headers = new HashMap<>();
        headers.put("Authorization", "Bearer " + token);
        if ("list".equals(operation)) {
            return AuthApiClient.request(endpoint, "GET", headers, null);
        }
        if (!"offer".equals(operation) && !"accept".equals(operation)) {
            throw new IllegalArgumentException("Unknown auction operation.");
        }

        JSONObject body = new JSONObject();
        body.put("action", operation);
        copyValue(data, body, "idea_id");
        copyValue(data, body, "offer_id");
        copyValue(data, body, "amount");
        copyValue(data, body, "message");
        return AuthApiClient.request(endpoint, "POST", headers, body.toString());
    }

    private static void copyValue(Map<?, ?> source, JSONObject destination, String key)
            throws JSONException {
        Object value = source.get(key);
        if (value instanceof String || value instanceof Number) destination.put(key, value);
    }
}
