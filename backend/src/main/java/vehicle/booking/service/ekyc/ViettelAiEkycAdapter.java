package vehicle.booking.service.ekyc;

import lombok.RequiredArgsConstructor;
import vehicle.booking.service.ViettelAiService;
import org.springframework.web.multipart.MultipartFile;
import java.util.Map;

@RequiredArgsConstructor
public class ViettelAiEkycAdapter implements EkycProvider {

    private final ViettelAiService viettelAiService;

    @Override
    public Map<String, Object> ocrIdCard(MultipartFile file) {
        return viettelAiService.ocrIdCard(file);
    }

    @Override
    public Map<String, Object> spoofCheck(MultipartFile file) {
        return viettelAiService.spoofCheck(file);
    }

    @Override
    public Map<String, Object> faceMatch(MultipartFile face, MultipartFile idCard) {
        return viettelAiService.faceMatch(face, idCard);
    }

    @Override
    public Map<String, Object> livenessCheck(MultipartFile face) {
        return viettelAiService.livenessCheck(face);
    }
}
