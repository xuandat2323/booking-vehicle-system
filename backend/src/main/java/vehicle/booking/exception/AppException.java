package vehicle.booking.exception;

public class AppException extends RuntimeException {
    private final ErrorCode errorCode;
    private final String resolvedMessage;
    public AppException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
        this.resolvedMessage = errorCode.getMessage();
    }
    public AppException(ErrorCode errorCode, Object... args) {
        super(errorCode.getMessage(args));
        this.errorCode = errorCode;
        this.resolvedMessage = errorCode.getMessage(args);
    }
    public ErrorCode getErrorCode() {
        return errorCode;
    }

    public String getResolvedMessage() {
        return resolvedMessage;
    }
}
