package com.example.eduvos_app;

import androidx.annotation.NonNull;

import org.json.JSONException;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String AUTH_CHANNEL = "eduvos/auth_api";
    private static final String FEATURE_CHANNEL = "eduvos/features";
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                AUTH_CHANNEL
        ).setMethodCallHandler(this::handleAuthCall);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                FEATURE_CHANNEL
        ).setMethodCallHandler(this::handleFeatureCall);
    }

    private void handleAuthCall(MethodCall call, MethodChannel.Result result) {
        if (!"request".equals(call.method) || !(call.arguments instanceof Map)) {
            result.notImplemented();
            return;
        }

        Map<?, ?> arguments = (Map<?, ?>) call.arguments;
        Object urlValue = arguments.get("url");
        Object methodValue = arguments.get("method");
        Object headersValue = arguments.get("headers");
        Object bodyValue = arguments.get("body");
        if (!(urlValue instanceof String) || !(methodValue instanceof String)) {
            result.error("INVALID_REQUEST", "A URL and HTTP method are required.", null);
            return;
        }

        String url = (String) urlValue;
        String method = (String) methodValue;
        if (!"GET".equals(method) && !"POST".equals(method)) {
            result.error("INVALID_REQUEST", "Only GET and POST are supported.", null);
            return;
        }

        Map<String, String> headers = new HashMap<>();
        if (headersValue instanceof Map) {
            Map<?, ?> providedHeaders = (Map<?, ?>) headersValue;
            for (Map.Entry<?, ?> entry : providedHeaders.entrySet()) {
                if (entry.getKey() instanceof String && entry.getValue() instanceof String) {
                    headers.put((String) entry.getKey(), (String) entry.getValue());
                }
            }
        }
        String body = bodyValue instanceof String ? (String) bodyValue : null;
        executor.execute(() -> {
            try {
                Map<String, Object> response = AuthApiClient.request(url, method, headers, body);
                runOnUiThread(() -> result.success(response));
            } catch (IOException exception) {
                runOnUiThread(() -> result.error(
                        "NETWORK_ERROR",
                        "Could not reach the PHP API. Check that XAMPP Apache is running and the API URL is correct.",
                        null
                ));
            }
        });
    }

    private void handleFeatureCall(MethodCall call, MethodChannel.Result result) {
        if (!(call.arguments instanceof Map)) {
            result.error("INVALID_REQUEST", "Feature request details are required.", null);
            return;
        }

        Map<?, ?> arguments = (Map<?, ?>) call.arguments;
        Object endpointValue = arguments.get("endpoint");
        Object tokenValue = arguments.get("token");
        Object dataValue = arguments.get("data");
        if (!(endpointValue instanceof String) || !(tokenValue instanceof String)) {
            result.error("INVALID_REQUEST", "The feature API endpoint and session token are required.", null);
            return;
        }

        String endpoint = (String) endpointValue;
        String token = (String) tokenValue;
        Map<?, ?> data = dataValue instanceof Map ? (Map<?, ?>) dataValue : new HashMap<>();
        String operation = call.method;
        executor.execute(() -> {
            try {
                Map<String, Object> response;
                if (operation.startsWith("marketplace.")) {
                    response = Marketplace.handle(
                            operation.substring("marketplace.".length()), endpoint, token, data
                    );
                } else if (operation.startsWith("community.")) {
                    response = Community.handle(
                            operation.substring("community.".length()), endpoint, token, data
                    );
                } else if (operation.startsWith("tank.")) {
                    response = Tank.handle(
                            operation.substring("tank.".length()), endpoint, token, data
                    );
                } else if (operation.startsWith("bursaries.")) {
                    response = Bursaries.handle(
                            operation.substring("bursaries.".length()), endpoint, token, data
                    );
                } else {
                    runOnUiThread(result::notImplemented);
                    return;
                }
                runOnUiThread(() -> result.success(response));
            } catch (IOException exception) {
                runOnUiThread(() -> result.error(
                        "NETWORK_ERROR",
                        "Could not reach the PHP feature API. Check that XAMPP Apache is running.",
                        null
                ));
            } catch (JSONException exception) {
                runOnUiThread(() -> result.error(
                        "INVALID_FEATURE_DATA",
                        "The feature request could not be encoded.",
                        null
                ));
            }
        });
    }

    @Override
    protected void onDestroy() {
        executor.shutdownNow();
        super.onDestroy();
    }
}
