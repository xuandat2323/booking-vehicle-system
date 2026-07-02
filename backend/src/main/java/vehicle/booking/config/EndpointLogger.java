package vehicle.booking.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
public class EndpointLogger implements CommandLineRunner {

    @Override
    public void run(String... args) throws Exception {
        log.info("================================================================================");
        log.info("APPLICATION STARTED SUCCESSFULLY");
        log.info("================================================================================");
        log.info("Application URL: http://localhost:5173/");

        if (isSwaggerEnabled()) {
            log.info("Swagger UI: http://localhost:8080/swagger-ui.html");
            log.info("API Docs: http://localhost:8080/v3/api-docs");
        }

        log.info("================================================================================");
    }

    private boolean isSwaggerEnabled() {
        try {
            Class.forName("org.springdoc.core.models.GroupedOpenApi");
            return true;
        } catch (ClassNotFoundException e) {
            try {
                Class.forName("springfox.documentation.spring.web.plugins.Docket");
                return true;
            } catch (ClassNotFoundException ex) {
                return false;
            }
        }
    }
}