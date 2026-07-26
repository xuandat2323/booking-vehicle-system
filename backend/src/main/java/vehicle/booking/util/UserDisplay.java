package vehicle.booking.util;

import vehicle.booking.entity.User;

/**
 * Tên hiển thị an toàn khi user.name null/blank (đăng ký cũ chỉ có SĐT).
 */
public final class UserDisplay {

    private UserDisplay() {
    }

    public static String name(User user) {
        if (user == null) {
            return "Khách";
        }
        if (user.getName() != null && !user.getName().isBlank()) {
            return user.getName().trim();
        }
        if (user.getPhone() != null && !user.getPhone().isBlank()) {
            return user.getPhone().trim();
        }
        return "Khách";
    }
}
