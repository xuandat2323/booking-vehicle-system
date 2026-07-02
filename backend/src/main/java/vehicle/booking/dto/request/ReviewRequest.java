package vehicle.booking.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ReviewRequest(
        @NotNull(message = "Rating không được để trống")
        @Min(value = 1, message = "Đánh giá thấp nhất là 1 sao")
        @Max(value = 5, message = "Đánh giá cao nhất là 5 sao")
        Integer rating,

        @Size(max = 1000, message = "Bình luận không được vượt quá 1000 ký tự")
        String comment
) {}
