-- Tên/địa chỉ chi nhánh và khu vực xe đang bị mã hoá sai kép (UTF-8 bị đọc như codepage
-- console rồi encode lại), nên UI hiện "GoRento Ho├án Kiß║┐m" và bộ lọc theo chi nhánh
-- không khớp được (chatbot luôn phải bỏ tiêu chí chi nhánh).
--
-- Dùng UNHEX với chuỗi UTF-8 đúng để migration này không phụ thuộc charset lúc đọc file.
--   GoRento Hoàn Kiếm  = 476F52656E746F20486FC3A06E204B69E1BABF6D
--   GoRento Cầu Giấy   = 476F52656E746F2043E1BAA775204769E1BAA579
--   GoRento Thanh Xuân = 476F52656E746F205468616E68205875C3A26E

-- 1) Chuẩn hoá tên 3 chi nhánh, khớp theo phần ASCII để không phụ thuộc text đang lỗi.
UPDATE `branch`
SET `name`    = UNHEX('476F52656E746F20486FC3A06E204B69E1BABF6D'),
    `address` = UNHEX('53E1BB912031205472C3A06E67205469E1BB816E2C20486FC3A06E204B69E1BABF6D2C2048C3A0204EE1BB9969')
WHERE `phone` = '0901111222';

UPDATE `branch`
SET `name`    = UNHEX('476F52656E746F2043E1BAA775204769E1BAA579'),
    `address` = UNHEX('53E1BB91203135204475792054C3A26E2C2043E1BAA775204769E1BAA5792C2048C3A0204EE1BB9969')
WHERE `phone` = '0901111333';

UPDATE `branch`
SET `name`    = UNHEX('476F52656E746F205468616E68205875C3A26E'),
    `address` = UNHEX('53E1BB9120323031204E677579E1BB856E205472C3A3692C205468616E68205875C3A26E2C2048C3A0204EE1BB9969')
WHERE `phone` = '0901111444';

-- 2) car.location phải đồng bộ với địa chỉ chi nhánh, nếu không bộ lọc khu vực vẫn trượt.
UPDATE `car` c
INNER JOIN `branch` b ON b.`branch_id` = c.`branch_id`
SET c.`location` = b.`address`
WHERE c.`branch_id` IS NOT NULL;
