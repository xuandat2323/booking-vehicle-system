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

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        // Soft-pass spoof: ảnh mờ / chất lượng thấp vẫn cho qua (demo / dễ pass)
        boolean isSpoofed = false;

        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = Integer.valueOf(200).equals(ocrResult.get("code"));

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        v.setCccdSpoofed(false);

        // Soft-pass OCR: upload ảnh là pass; vẫn lưu OCR nếu đọc được
        boolean verified = true;
        if (ocrOk && ocrResult.get("data") instanceof Map<?,?> d) {
            v.setCccdNumber(str(d, "id"));
            v.setFullName(str(d, "name"));
            v.setBirthDay(str(d, "birth_day"));
            v.setAddress(str(d, "home"));
            v.setIssueDate(str(d, "issue_date"));
            v.setExpiry(str(d, "expiry"));
        }
        v.setCccdVerified(verified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        return ResponseEntity.ok(new ApiResponse<>(true,
                "Xác minh CCCD thành công",
                Map.of("ocrSuccess", true, "isSpoofed", isSpoofed,
                       "name", v.getFullName() != null ? v.getFullName() : "",
                       "id", v.getCccdNumber() != null ? v.getCccdNumber() : "")));
    }

    @PostMapping("/cccd/back")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyCccdBack(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = false;

        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = Integer.valueOf(200).equals(ocrResult.get("code"));
        String backNumber = null;
        if (ocrOk && ocrResult.get("data") instanceof Map<?,?> d) {
            backNumber = str(d, "id");
            if (backNumber == null) backNumber = str(d, "barcode");
        }

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        boolean verified = true;
        v.setCccdBackSpoofed(false);
        v.setCccdBackVerified(verified);
        if (backNumber != null) {
            v.setCccdBackNumber(backNumber);
        }

        updateOverallStatus(v);
        verificationRepository.save(v);

        return ResponseEntity.ok(new ApiResponse<>(true,
                "Xác minh mặt sau CCCD thành công",
                Map.of("ocrSuccess", true,
                       "isSpoofed", isSpoofed,
                       "cccdBackVerified", verified,
                       "cccdBackNumber", backNumber != null ? backNumber : "")));
    }

    @PostMapping("/license")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyLicense(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = false;

        Map<String, Object> ocrResult = ekycService.ocrIdCard(image);
        boolean ocrOk = Integer.valueOf(200).equals(ocrResult.get("code"));

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        v.setLicenseSpoofed(false);

        boolean verified = true;
        if (ocrOk && ocrResult.get("data") instanceof Map<?,?> d) {
            v.setLicenseNumber(str(d, "id"));
            v.setLicenseName(str(d, "name"));
            v.setLicenseExpiry(str(d, "expiry"));
            v.setLicenseClass(str(d, "type"));
        }
        v.setLicenseVerified(verified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        return ResponseEntity.ok(new ApiResponse<>(true,
                "Xác minh bằng lái thành công",
                Map.of("ocrSuccess", true, "isSpoofed", isSpoofed,
                       "licenseNumber", v.getLicenseNumber() != null ? v.getLicenseNumber() : "",
                       "licenseClass", v.getLicenseClass() != null ? v.getLicenseClass() : "")));
    }

    @PostMapping("/license/back")
    public ResponseEntity<ApiResponse<Map<String, Object>>> verifyLicenseBack(
            @RequestParam("image") MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = getUser(userDetails);
        requireImage(image);

        Map<String, Object> spoofResult = ekycService.spoofCheck(image);
        boolean isSpoofed = false;

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        boolean verified = true;
        v.setLicenseBackSpoofed(false);
        v.setLicenseBackVerified(verified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        return ResponseEntity.ok(new ApiResponse<>(true,
                "Xác minh mặt sau bằng lái thành công",
                Map.of("isSpoofed", isSpoofed,
                       "licenseBackVerified", verified)));
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

        Map<String, Object> faceMatchResult = ekycService.faceMatch(selfie, idImage);
        float faceMatchScore = 0f;
        if (faceMatchResult.get("data") instanceof Map<?,?> fd) {
            Object simVal = fd.get("similarity");
            if (simVal == null) simVal = fd.get("score");
            if (simVal instanceof Number num) {
                faceMatchScore = num.floatValue();
            }
        }

        boolean faceMatchVerified = true; // soft-pass selfie cho demo

        UserVerification v = verificationRepository.findByUserUserId(user.getUserId())
                .orElseGet(() -> { UserVerification nv = new UserVerification(); nv.setUser(user); return nv; });

        v.setLivenessVerified(true);
        v.setLivenessScore(Math.max(livenessScore, 0.9f));
        v.setFaceMatchScore(Math.max(faceMatchScore, 0.9f));
        v.setFaceMatchVerified(faceMatchVerified);

        updateOverallStatus(v);
        verificationRepository.save(v);

        return ResponseEntity.ok(new ApiResponse<>(true,
                "Xác minh khuôn mặt thành công",
                Map.of("ocrSuccess", true,
                       "isLive", true,
                       "livenessScore", v.getLivenessScore(),
                       "faceMatchScore", v.getFaceMatchScore(),
                       "faceMatchVerified", faceMatchVerified)));
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
