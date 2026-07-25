package vehicle.booking.controller;

import vehicle.booking.dto.response.ApiResponse;
import vehicle.booking.entity.User;
import vehicle.booking.entity.UserVerification;
import vehicle.booking.entity.enums.VerificationStatus;
import vehicle.booking.exception.AppException;
import vehicle.booking.exception.ErrorCode;
import vehicle.booking.repository.UserRepository;
import vehicle.booking.repository.UserVerificationRepository;
import vehicle.booking.service.ekyc.EkycService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/verification")
@RequiredArgsConstructor
public class VerificationController {

    /** Face cosine similarity tối thiểu để coi là khớp (0..1). */
    private static final float FACE_MATCH_THRESHOLD = 0.65f;
    /** Liveness score tối thiểu. */
    private static final float LIVENESS_THRESHOLD = 0.55f;

    private final UserRepository userRepository;
    private final UserVerificationRepository verificationRepository;
    private final EkycService ekycService;

    @GetMapping("/status")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStatus(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElse(null);
        if (v == null) {
            return ResponseEntity.ok(new ApiResponse<>(true, "Chưa xác minh",
                    Map.of("status", "UNVERIFIED",
                            "cccdVerified", false,
                            "licenseVerified", false,
                            "cccdBackVerified", false,
                            "licenseBackVerified", false,
                            "faceMatchVerified", false,
                            "faceMatchScore", 0.0,
                            "livenessVerified", false,
                            "livenessScore", 0.0)));
        }
        Map<String, Object> result = new HashMap<>();
        result.put("status", v.getStatus());
        result.put("cccdVerified", Boolean.TRUE.equals(v.getCccdVerified()));
        result.put("cccdSpoofed", Boolean.TRUE.equals(v.getCccdSpoofed()));
        result.put("licenseVerified", Boolean.TRUE.equals(v.getLicenseVerified()));
        result.put("licenseSpoofed", Boolean.TRUE.equals(v.getLicenseSpoofed()));
        result.put("cccdBackVerified", Boolean.TRUE.equals(v.getCccdBackVerified()));
        result.put("cccdBackSpoofed", Boolean.TRUE.equals(v.getCccdBackSpoofed()));
        result.put("licenseBackVerified", Boolean.TRUE.equals(v.getLicenseBackVerified()));
        result.put("licenseBackSpoofed", Boolean.TRUE.equals(v.getLicenseBackSpoofed()));
        result.put("faceMatchVerified", Boolean.TRUE.equals(v.getFaceMatchVerified()));
        result.put("faceMatchScore", v.getFaceMatchScore() != null ? v.getFaceMatchScore() : 0.0);
        result.put("livenessVerified", Boolean.TRUE.equals(v.getLivenessVerified()));
        result.put("livenessScore", v.getLivenessScore() != null ? v.getLivenessScore() : 0.0);
        result.put("fullName", v.getFullName() != null ? v.getFullName() : "");
        result.put("cccdNumber", v.getCccdNumber() != null ? v.getCccdNumber() : "");
        result.put("birthDay", v.getBirthDay() != null ? v.getBirthDay() : "");
        result.put("licenseClass", v.getLicenseClass() != null ? v.getLicenseClass() : "");
        return ResponseEntity.ok(new ApiResponse<>(true, "Lấy trạng thái thành công", result));
    }

    @PostMapping("/cccd")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyCccd(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        // Spoof vẫn soft: chỉ log, không chặn vì ảnh mờ (đòi hỏi trước đây của khách).
        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = extractSpoofed(spoofResult);

        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = isOcrOk(ocrResult);
        String ocrMsg = messageOf(ocrResult, "Không nhận dạng được CCCD — vui lòng chụp lại rõ hơn");

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        v.setCccdSpoofed(isSpoofed);

        String id = null;
        String name = null;
        String docType = null;
        if (ocrOk && ocrResult.get("data") instanceof Map<?,?> d) {
            id = str(d, "id");
            name = str(d, "name");
            docType = str(d, "doc_type");
            v.setCccdNumber(id);
            v.setFullName(name);
            v.setBirthDay(str(d, "birth_day"));
            v.setAddress(str(d, "home"));
            v.setIssueDate(str(d, "issue_date"));
            v.setExpiry(str(d, "expiry"));
        }

        // Mặt trước CCCD: bắt buộc đọc được số 12 số, và không phải ảnh GPLX.
        boolean looksLikeLicense = "license".equalsIgnoreCase(docType);
        boolean verified = ocrOk && !looksLikeLicense && isCccdNumber(id);
        if (looksLikeLicense) {
            ocrMsg = "Ảnh giống bằng lái xe — vui lòng upload mặt trước CCCD";
        } else if (ocrOk && !isCccdNumber(id)) {
            ocrMsg = "Không đọc được số CCCD 12 số — chụp rõ phần số căn cước";
        }
        v.setCccdVerified(verified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        Map<String, Object> payload = new HashMap<>();
        payload.put("ocrSuccess", verified);
        payload.put("isSpoofed", isSpoofed);
        payload.put("name", name != null ? name : "");
        payload.put("id", id != null ? id : "");
        payload.put("message", verified ? "Xác minh CCCD thành công" : ocrMsg);

        return ResponseEntity.ok(new ApiResponse<>(
                verified,
                verified ? "Xác minh CCCD thành công" : ocrMsg,
                payload));
    }

    @PostMapping("/cccd/back")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyCccdBack(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = extractSpoofed(spoofResult);

        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = isOcrOk(ocrResult);
        String ocrMsg = messageOf(ocrResult, "Không nhận dạng được mặt sau CCCD");

        String backNumber = null;
        String docType = null;
        if (ocrOk && ocrResult.get("data") instanceof Map<?,?> d) {
            backNumber = str(d, "id");
            if (backNumber == null) backNumber = str(d, "barcode");
            docType = str(d, "doc_type");
        }

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        // Mặt sau: OCR phải đọc được giấy tờ (code 200), không chấp nhận ảnh trống/random.
        boolean verified = ocrOk && !"license".equalsIgnoreCase(docType);
        if ("license".equalsIgnoreCase(docType)) {
            ocrMsg = "Ảnh giống bằng lái — vui lòng upload mặt sau CCCD";
            verified = false;
        }
        v.setCccdBackSpoofed(isSpoofed);
        v.setCccdBackVerified(verified);
        if (backNumber != null) {
            v.setCccdBackNumber(backNumber);
        }

        updateOverallStatus(v);
        verificationRepository.save(v);

        Map<String, Object> payload = new HashMap<>();
        payload.put("ocrSuccess", verified);
        payload.put("isSpoofed", isSpoofed);
        payload.put("cccdBackVerified", verified);
        payload.put("cccdBackNumber", backNumber != null ? backNumber : "");
        payload.put("message", verified ? "Xác minh mặt sau CCCD thành công" : ocrMsg);

        return ResponseEntity.ok(new ApiResponse<>(
                verified,
                verified ? "Xác minh mặt sau CCCD thành công" : ocrMsg,
                payload));
    }

    @PostMapping("/license")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyLicense(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = extractSpoofed(spoofResult);

        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = isOcrOk(ocrResult);
        String ocrMsg = messageOf(ocrResult, "Không nhận dạng được bằng lái — vui lòng chụp lại rõ hơn");

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        v.setLicenseSpoofed(isSpoofed);

        String licId = null;
        String licName = null;
        String licClass = null;
        String docType = null;
        if (ocrOk && ocrResult.get("data") instanceof Map<?,?> d) {
            licId = str(d, "id");
            licName = str(d, "name");
            licClass = str(d, "type");
            docType = str(d, "doc_type");
            v.setLicenseNumber(licId);
            v.setLicenseName(licName);
            v.setLicenseExpiry(str(d, "expiry"));
            v.setLicenseClass(licClass);
        }

        boolean looksLikeCccd = "cccd".equalsIgnoreCase(docType) && (licClass == null || licClass.isBlank());
        boolean hasClass = licClass != null && !licClass.isBlank();
        boolean hasIdOrName = isCccdNumber(licId) || (licName != null && licName.length() >= 3);
        boolean verified = ocrOk && !looksLikeCccd && (hasClass || hasIdOrName);
        if (looksLikeCccd) {
            ocrMsg = "Ảnh giống CCCD — vui lòng upload mặt trước bằng lái xe";
            verified = false;
        } else if (ocrOk && !verified) {
            ocrMsg = "Không đọc được hạng bằng / số GPLX — chụp rõ phần hạng (A1, B1, B2…)";
        }
        v.setLicenseVerified(verified);

        // Đồng bộ số GPLX sang hồ sơ user để màn Tài khoản không còn "Chưa cập nhật".
        if (verified && licId != null && !licId.isBlank()) {
            user.setDriveLicense(licId);
            userRepository.save(user);
        }

        updateOverallStatus(v);
        verificationRepository.save(v);

        Map<String, Object> payload = new HashMap<>();
        payload.put("ocrSuccess", verified);
        payload.put("isSpoofed", isSpoofed);
        payload.put("licenseNumber", licId != null ? licId : "");
        payload.put("licenseClass", licClass != null ? licClass : "");
        payload.put("message", verified ? "Xác minh bằng lái thành công" : ocrMsg);

        return ResponseEntity.ok(new ApiResponse<>(
                verified,
                verified ? "Xác minh bằng lái thành công" : ocrMsg,
                payload));
    }

    @PostMapping("/license/back")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyLicenseBack(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = extractSpoofed(spoofResult);

        // Mặt sau bằng: vẫn OCR để từ chối ảnh trống / không có chữ.
        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = isOcrOk(ocrResult);
        String ocrMsg = messageOf(ocrResult, "Không nhận dạng được mặt sau bằng lái");

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        boolean verified = ocrOk;
        v.setLicenseBackSpoofed(isSpoofed);
        v.setLicenseBackVerified(verified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        Map<String, Object> payload = new HashMap<>();
        payload.put("ocrSuccess", verified);
        payload.put("isSpoofed", isSpoofed);
        payload.put("licenseBackVerified", verified);
        payload.put("message", verified ? "Xác minh mặt sau bằng lái thành công" : ocrMsg);

        return ResponseEntity.ok(new ApiResponse<>(
                verified,
                verified ? "Xác minh mặt sau bằng lái thành công" : ocrMsg,
                payload));
    }

    @PostMapping("/face")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyFace(
            @RequestParam("selfie") MultipartFile selfie,
            @RequestParam("idImage") MultipartFile idImage,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(selfie);
        requireImage(idImage);

        Map<String, Object> livenessResult = ekycService.livenessCheck(selfie);
        boolean isLive = false;
        float livenessScore = 0f;
        if (livenessResult.get("data") instanceof Map<?,?> ld) {
            Object liveVal = ld.get("is_live");
            isLive = Boolean.TRUE.equals(liveVal);
            Object scoreVal = ld.get("liveness_score");
            if (scoreVal instanceof Number num) {
                livenessScore = num.floatValue();
            }
        }
        boolean livenessOk = isLive && livenessScore >= LIVENESS_THRESHOLD;

        Map<String, Object> faceMatchResult = ekycService.faceMatch(selfie, idImage);
        float faceMatchScore = 0f;
        boolean providerVerified = false;
        if (faceMatchResult.get("data") instanceof Map<?,?> fd) {
            Object simVal = fd.get("similarity");
            if (simVal == null) simVal = fd.get("score");
            if (simVal instanceof Number num) {
                faceMatchScore = num.floatValue();
            }
            providerVerified = Boolean.TRUE.equals(fd.get("verified"));
        }
        boolean faceMatchVerified = providerVerified || faceMatchScore >= FACE_MATCH_THRESHOLD;
        // Cần sống + khớp — không soft-pass.
        boolean verified = livenessOk && faceMatchVerified;

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        v.setLivenessVerified(livenessOk);
        v.setLivenessScore(livenessScore);
        v.setFaceMatchScore(faceMatchScore);
        v.setFaceMatchVerified(verified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        String msg;
        if (!livenessOk) {
            msg = "Không phát hiện khuôn mặt sống — vui lòng chụp selfie rõ, nhìn thẳng camera";
        } else if (!faceMatchVerified) {
            msg = String.format("Khuôn mặt không khớp giấy tờ (%.0f%%) — thử lại với ảnh CCCD rõ mặt", faceMatchScore * 100);
        } else {
            msg = "Xác minh khuôn mặt thành công";
        }

        Map<String, Object> payload = new HashMap<>();
        payload.put("ocrSuccess", verified);
        payload.put("isLive", livenessOk);
        payload.put("livenessScore", livenessScore);
        payload.put("faceMatchScore", faceMatchScore);
        payload.put("faceMatchVerified", verified);
        payload.put("message", msg);

        return ResponseEntity.ok(new ApiResponse<>(verified, msg, payload));
    }

    private User getUser(UserDetails ud) {
        return userRepository.findByPhone(ud.getUsername())
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
    }

    private void requireImage(MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new AppException(ErrorCode.COMMON_BAD_REQUEST);
        }
    }

    private boolean isOcrOk(Map<String, Object> ocrResult) {
        return Integer.valueOf(200).equals(ocrResult.get("code"));
    }

    private String messageOf(Map<String, Object> result, String fallback) {
        Object msg = result.get("message");
        if (msg != null && !msg.toString().isBlank() && !"ok".equalsIgnoreCase(msg.toString())) {
            return msg.toString();
        }
        return fallback;
    }

    private boolean isCccdNumber(String id) {
        return id != null && id.matches("\\d{12}");
    }

    private boolean extractSpoofed(Map<String, Object> spoofResult) {
        if (spoofResult.get("data") instanceof Map<?,?> sd) {
            Object spoofVal = sd.get("is_fake");
            if (spoofVal == null) spoofVal = sd.get("is_spoof");
            return Boolean.TRUE.equals(spoofVal);
        }
        return false;
    }

    private String str(Map<?,?> map, String key) {
        Object val = map.get(key);
        return val != null ? val.toString() : null;
    }

    private void updateOverallStatus(UserVerification v) {
        boolean cccdOk = Boolean.TRUE.equals(v.getCccdVerified()) && !Boolean.TRUE.equals(v.getCccdSpoofed());
        boolean cccdBackOk = Boolean.TRUE.equals(v.getCccdBackVerified()) && !Boolean.TRUE.equals(v.getCccdBackSpoofed());
        boolean licOk = Boolean.TRUE.equals(v.getLicenseVerified()) && !Boolean.TRUE.equals(v.getLicenseSpoofed());
        boolean licBackOk = Boolean.TRUE.equals(v.getLicenseBackVerified()) && !Boolean.TRUE.equals(v.getLicenseBackSpoofed());
        boolean faceOk = Boolean.TRUE.equals(v.getFaceMatchVerified());

        if (Boolean.TRUE.equals(v.getCccdSpoofed()) || Boolean.TRUE.equals(v.getLicenseSpoofed())
                || Boolean.TRUE.equals(v.getCccdBackSpoofed()) || Boolean.TRUE.equals(v.getLicenseBackSpoofed())) {
            v.setStatus(VerificationStatus.REJECTED);
            return;
        }

        if (cccdOk && cccdBackOk && licOk && licBackOk && faceOk) {
            v.setStatus(VerificationStatus.VERIFIED);
        } else if (cccdOk || cccdBackOk || licOk || licBackOk || faceOk
                || Boolean.TRUE.equals(v.getLivenessVerified())) {
            v.setStatus(VerificationStatus.PENDING);
        } else {
            v.setStatus(VerificationStatus.UNVERIFIED);
        }
    }
}
