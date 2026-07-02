package vehicle.booking.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;

import javax.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.Base64;

@Configuration
@Slf4j
public class FirebaseConfig {

    /** Base64-encoded content of the service account JSON (preferred for env-based config). */
    @Value("${firebase.service-account-json:}")
    private String serviceAccountJson;

    /** Fallback: path to the JSON file (classpath or file:). */
    @Value("${firebase.service-account-path:classpath:firebase-service-account.json}")
    private String serviceAccountPath;

    private final ResourceLoader resourceLoader;

    public FirebaseConfig(ResourceLoader resourceLoader) {
        this.resourceLoader = resourceLoader;
    }

    @PostConstruct
    public void initialize() {
        if (!FirebaseApp.getApps().isEmpty()) return;
        try {
            InputStream stream = resolveCredentialStream();
            if (stream == null) {
                log.warn("Firebase service account not configured — FCM and Firebase OTP will be disabled.");
                return;
            }
            try (stream) {
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(stream))
                        .build();
                FirebaseApp.initializeApp(options);
                log.info("Firebase initialized successfully.");
            }
        } catch (Exception e) {
            log.error("Failed to initialize Firebase: {}", e.getMessage());
        }
    }

    private InputStream resolveCredentialStream() throws Exception {
        // 1. Env var FIREBASE_SERVICE_ACCOUNT_JSON (base64 JSON content)
        if (serviceAccountJson != null && !serviceAccountJson.isBlank()) {
            log.info("Firebase: loading credentials from env var (base64).");
            byte[] decoded = Base64.getDecoder().decode(serviceAccountJson.strip());
            return new ByteArrayInputStream(decoded);
        }
        // 2. File path (classpath or file:)
        Resource resource = resourceLoader.getResource(serviceAccountPath);
        if (resource.exists()) {
            log.info("Firebase: loading credentials from file: {}", serviceAccountPath);
            return resource.getInputStream();
        }
        return null;
    }
}
