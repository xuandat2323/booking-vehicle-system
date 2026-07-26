package vehicle.booking.service.ekyc;

import org.springframework.web.multipart.MultipartFile;
import java.util.Map;

public interface EkycProvider {
    Map<String, Object> ocrIdCard(MultipartFile file);

    /** OCR theo đúng bước upload: cccd, cccd_back, license, license_back. */
    default Map<String, Object> ocrDocument(MultipartFile file, String expectedDocType) {
        return ocrIdCard(file);
    }

    Map<String, Object> spoofCheck(MultipartFile file);
    Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard);
    Map<String, Object> livenessCheck(MultipartFile face);
}
