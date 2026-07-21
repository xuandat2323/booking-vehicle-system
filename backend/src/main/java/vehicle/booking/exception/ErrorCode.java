package vehicle.booking.exception;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    COMMON_INTERNAL_ERROR(
            "COMMON_INTERNAL_ERROR",
            "Lỗi hệ thống. Vui lòng thử lại sau",
            HttpStatus.INTERNAL_SERVER_ERROR
    ),
    COMMON_BAD_REQUEST(
            "COMMON_BAD_REQUEST",
            "Yêu cầu không hợp lệ.",
            HttpStatus.BAD_REQUEST
    ),
    VALIDATION_ERROR(
            "VALIDATION_ERROR",
            "Dữ liệu đầu vào không hợp lệ: %s",
            HttpStatus.BAD_REQUEST
    ),
    AUTH_INVALID_CREDENTIALS(
            "AUTH_INVALID_CREDENTIALS",
            "Số điện thoại hoặc mật khẩu không đúng.",
            HttpStatus.UNAUTHORIZED
    ),
    AUTH_UNAUTHORIZED(
            "AUTH_UNAUTHORIZED",
            "Bạn chưa đăng nhập hoặc token không hợp lệ.",
            HttpStatus.UNAUTHORIZED
    ),
    AUTH_FORBIDDEN(
            "AUTH_FORBIDDEN",
            "Bạn không có quyền thực hiện hành động này.",
            HttpStatus.FORBIDDEN
    ),
    AUTH_PHONE_ALREADY_EXISTS(
            "AUTH_PHONE_ALREADY_EXISTS",
            "Số điện thoại '%s' đã được sử dụng.",
            HttpStatus.CONFLICT
    ),
    PHONE_INVALID(
            "PHONE_INVALID",
            "Số điện thoại không hợp lệ.",
            HttpStatus.BAD_REQUEST
    ),
    PHONE_OTP_REQUIRED(
            "PHONE_OTP_REQUIRED",
            "Vui lòng nhập mã OTP.",
            HttpStatus.BAD_REQUEST
    ),
    PHONE_OTP_INVALID(
            "PHONE_OTP_INVALID",
            "Mã OTP không hợp lệ hoặc đã hết hạn.",
            HttpStatus.BAD_REQUEST
    ),
    PHONE_OTP_SEND_FAILED(
            "PHONE_OTP_SEND_FAILED",
            "Không thể gửi mã OTP. Vui lòng thử lại sau.",
            HttpStatus.BAD_REQUEST
    ),
    TWILIO_CONFIG_INVALID(
            "TWILIO_CONFIG_INVALID",
            "Cấu hình Twilio chưa hợp lệ.",
            HttpStatus.INTERNAL_SERVER_ERROR
    ),
    AUTH_REFRESH_TOKEN_INVALID(
            "AUTH_REFRESH_TOKEN_INVALID",
            "Refresh token không hợp lệ.",
            HttpStatus.UNAUTHORIZED
    ),
    AUTH_REFRESH_TOKEN_EXPIRED(
            "AUTH_REFRESH_TOKEN_EXPIRED",
            "Refresh token đã hết hạn. Vui lòng đăng nhập lại.",
            HttpStatus.UNAUTHORIZED
    ),
    AUTH_PASSWORD_MISMATCH(
            "AUTH_PASSWORD_MISMATCH",
            "Mật khẩu mới và xác nhận không khớp.",
            HttpStatus.BAD_REQUEST
    ),
    AUTH_OLD_PASSWORD_INCORRECT(
            "AUTH_OLD_PASSWORD_INCORRECT",
            "Mật khẩu cũ không đúng.",
            HttpStatus.BAD_REQUEST
    ),
    USER_NOT_FOUND(
            "USER_NOT_FOUND",
            "Không tìm thấy người dùng.",
            HttpStatus.NOT_FOUND
    ),
    PASSWORD_MISMATCH(
            "PASSWORD_MISMATCH",
            "Mật khẩu mới và xác nhận không khớp.",
            HttpStatus.BAD_REQUEST
    ),
    PASSWORD_WRONG_OLD(
            "PASSWORD_WRONG_OLD",
            "Mật khẩu cũ không đúng.",
            HttpStatus.BAD_REQUEST
    ),
    PASSWORD_RESET_OTP_INVALID(
            "PASSWORD_RESET_OTP_INVALID",
            "Mã OTP không hợp lệ.",
            HttpStatus.BAD_REQUEST
    ),
    PASSWORD_RESET_OTP_EXPIRED(
            "PASSWORD_RESET_OTP_EXPIRED",
            "Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.",
            HttpStatus.BAD_REQUEST
    ),
    PASSWORD_RESET_OTP_USED(
            "PASSWORD_RESET_OTP_USED",
            "Mã OTP đã được sử dụng.",
            HttpStatus.BAD_REQUEST
    ),
    CAR_NOT_FOUND(
            "CAR_NOT_FOUND",
            "Không tìm thấy xe với ID: %s",
            HttpStatus.NOT_FOUND
    ),
    CAR_LICENSE_PLATE_EXISTS(
            "CAR_LICENSE_PLATE_EXISTS",
            "Biển số xe '%s' đã tồn tại.",
            HttpStatus.CONFLICT
    ),
    CAR_FILTER_INVALID_PRICE_RANGE(
            "CAR_FILTER_INVALID_PRICE_RANGE",
            "Khoảng giá không hợp lệ. minPrice phải <= maxPrice và không âm.",
            HttpStatus.BAD_REQUEST
    ),
        CAR_FILTER_INVALID_SEATS(
            "CAR_FILTER_INVALID_SEATS",
            "Số chỗ không hợp lệ. Chỉ hỗ trợ: 4, 5, 7, 8, 9 chỗ.",
            HttpStatus.BAD_REQUEST
    ),
        CAR_IMAGE_LIMIT_EXCEEDED(
            "CAR_IMAGE_LIMIT_EXCEEDED",
            "Mỗi xe chỉ được tối đa 5 ảnh.",
            HttpStatus.BAD_REQUEST
    ),
    CAR_IMAGE_INVALID_FILE_TYPE(
            "CAR_IMAGE_INVALID_FILE_TYPE",
            "Định dạng ảnh không hợp lệ. Chỉ hỗ trợ JPG, JPEG, PNG.",
            HttpStatus.BAD_REQUEST
    ),
    CAR_IMAGE_UPLOAD_FAILED(
            "CAR_IMAGE_UPLOAD_FAILED",
            "Tải ảnh lên thất bại. Vui lòng thử lại.",
            HttpStatus.INTERNAL_SERVER_ERROR
    ),
    CAR_NOT_OWNER(
            "CAR_NOT_OWNER",
            "Bạn không có quyền thao tác xe này.",
            HttpStatus.FORBIDDEN
    ),
    BOOKING_OWNER_FORBIDDEN(
            "BOOKING_OWNER_FORBIDDEN",
            "Bạn không có quyền quản lý booking này.",
            HttpStatus.FORBIDDEN
    ),
    CAR_IMAGE_NOT_FOUND(
            "CAR_IMAGE_NOT_FOUND",
            "Không tìm thấy ảnh xe với ID: %s.",
            HttpStatus.NOT_FOUND
    ),
    BOOKING_NOT_FOUND(
            "BOOKING_NOT_FOUND",
            "Không tìm thấy booking với ID: %s",
            HttpStatus.NOT_FOUND
    ),
    BOOKING_DATE_CONFLICT(
            "BOOKING_DATE_CONFLICT",
            "Xe đã được đặt từ %s đến %s. Vui lòng chọn khoảng thời gian khác.",
            HttpStatus.CONFLICT
    ),
    BOOKING_INVALID_DATE_RANGE(
            "BOOKING_INVALID_DATE_RANGE",
            "Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.",
            HttpStatus.BAD_REQUEST
    ),
    BOOKING_INVALID_STATUS_TRANSITION(
            "BOOKING_INVALID_STATUS_TRANSITION",
            "Không thể chuyển trạng thái booking từ %s sang %s.",
            HttpStatus.BAD_REQUEST
    ),
    BOOKING_CANCEL_NOT_ALLOWED(
            "BOOKING_CANCEL_NOT_ALLOWED",
            "USER chỉ có thể hủy booking khi trạng thái là PENDING. Trạng thái hiện tại: %s",
            HttpStatus.BAD_REQUEST
    ),
    BOOKING_ACCESS_DENIED(
            "BOOKING_ACCESS_DENIED",
            "Bạn không có quyền truy cập booking này.",
            HttpStatus.FORBIDDEN
    ),
    INVOICE_NOT_FOUND(
            "INVOICE_NOT_FOUND",
            "Không tìm thấy hóa đơn với ID: %s",
            HttpStatus.NOT_FOUND
    ),
    INVOICE_ALREADY_EXISTS(
            "INVOICE_ALREADY_EXISTS",
            "Booking ID %s đã có hóa đơn. Không thể tạo thêm.",
            HttpStatus.CONFLICT
    ),
    INVOICE_INVALID_STATUS(
            "INVOICE_INVALID_STATUS",
            "Hóa đơn phải ở trạng thái UNPAID mới có thể xác nhận. Trạng thái hiện tại: %s",
            HttpStatus.BAD_REQUEST
    ),
    INVOICE_ACCESS_DENIED(
            "INVOICE_ACCESS_DENIED",
            "Bạn không có quyền xem hóa đơn này.",
            HttpStatus.FORBIDDEN
    ),
    PAYMENT_NOT_FOUND(
            "PAYMENT_NOT_FOUND",
            "Không tìm thấy payment với ID: %s",
            HttpStatus.NOT_FOUND
    ),
    PAYMENT_ALREADY_EXISTS(
            "PAYMENT_ALREADY_EXISTS",
            "Hóa đơn ID %s đã có payment. Không thể tạo thêm.",
            HttpStatus.CONFLICT
    ),
    PAYMENT_INVALID_RESULT(
            "PAYMENT_INVALID_RESULT",
            "Kết quả xác nhận chỉ được là SUCCESS hoặc FAILED.",
            HttpStatus.BAD_REQUEST
    ),
    PAYMENT_ACCESS_DENIED(
            "PAYMENT_ACCESS_DENIED",
            "Bạn không có quyền xem payment này.",
            HttpStatus.FORBIDDEN
    ),
    REVIEW_ALREADY_EXISTS(
            "REVIEW_ALREADY_EXISTS",
            "Bạn đã đánh giá cho chuyến đi này rồi.",
            HttpStatus.CONFLICT
    ),
    REVIEW_BOOKING_NOT_COMPLETED(
            "REVIEW_BOOKING_NOT_COMPLETED",
            "Chỉ có thể đánh giá sau khi chuyến đi đã hoàn thành.",
            HttpStatus.BAD_REQUEST
    ),
    REVIEW_NOT_FOUND(
            "REVIEW_NOT_FOUND",
            "Không tìm thấy đánh giá.",
            HttpStatus.NOT_FOUND
    ),
    RESOURCE_NOT_FOUND(
            "RESOURCE_NOT_FOUND",
            "Không tìm thấy %s với ID: %s",
            HttpStatus.NOT_FOUND
    ),
    BRANCH_NOT_FOUND(
            "BRANCH_NOT_FOUND",
            "Không tìm thấy chi nhánh với ID: %s",
            HttpStatus.NOT_FOUND
    );
    private final String code;
    private final String message;
    private final HttpStatus httpStatus;

    ErrorCode(String code, String message, HttpStatus httpStatus) {
        this.code = code;
        this.message = message;
        this.httpStatus = httpStatus;
    }

    public String getCode() {
        return code;
    }

    public HttpStatus getHttpStatus() {
        return httpStatus;
    }

    public String getMessage() {
        return message;
    }
    public String getMessage(Object... args) {
        if (args == null || args.length == 0) {
            return message;
        }
        return String.format(message, args);
    }
}




