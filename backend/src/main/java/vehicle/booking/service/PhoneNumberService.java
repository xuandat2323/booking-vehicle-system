package vehicle.booking.service;

import org.springframework.stereotype.Service;

import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;

@Service
public class PhoneNumberService {
    private static final String VIETNAM_COUNTRY_CODE = "+84";
    public String normalizeToE164(String rawPhone) {
        if(rawPhone == null || rawPhone.isBlank()){
            throw new AppException(ErrorCode.PHONE_INVALID);
        }
        String phone = rawPhone.trim()
        .replace(" ", "")
        .replace("-", "")
        .replace(".", "");
        if(phone.startsWith("+84")){
            return normalizeVietnamInternationPhone(phone);
        }
        if(phone.startsWith("84")){
            return normalizeVietnamInternationPhone("+" + phone);
        }
        if(phone.startsWith("0")){
            return normalizeVietnamLocalPhone(phone);
        }
        throw new AppException(ErrorCode.PHONE_INVALID);
    }

    private String normalizeVietnamLocalPhone(String phone){
        if (!phone.matches("^0\\d{9}$")) {
            throw new AppException(ErrorCode.PHONE_INVALID);
        }
        return VIETNAM_COUNTRY_CODE + phone.substring(1);
    }

    private String normalizeVietnamInternationPhone(String phone){
        if (!phone.matches("^\\+84\\d{9}$")) {
            throw new AppException(ErrorCode.PHONE_INVALID);
        }
        return phone;
    }
    public String maskPhone(String phone){
        if(phone == null || phone.length() < 7){
            return "****";
        }

        return phone.substring(0, 4) + "****" + phone.substring(phone.length() - 3);
    }
}
