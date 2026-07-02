package vehicle.booking;

import vehicle.booking.config.TwilioProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(TwilioProperties.class)
public class VehicleBookingSystemApplication {

	public static void main(String[] args) {
		SpringApplication.run(VehicleBookingSystemApplication.class, args);
	}

}
