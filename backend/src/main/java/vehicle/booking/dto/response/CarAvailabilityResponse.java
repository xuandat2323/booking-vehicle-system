package vehicle.booking.dto.response;

import java.time.LocalDate;
import java.util.List;

public record CarAvailabilityResponse(
        Long carId,
        String carName,
        String licensePlate,
        List<LocalDate> bookedDates
) {
}
