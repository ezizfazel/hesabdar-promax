-- یک بار در phpMyAdmin اجرا شود (قبل از آپلود api.php جدید).

-- ۱. جا برای رمزهای هش‌شده (bcrypt حداقل ۶۰ کاراکتر لازم دارد).
--    تا این اجرا نشود، رمزهای قدیمی موقع ورود به هش تبدیل نمی‌شوند.
ALTER TABLE admins MODIFY password VARCHAR(255) NOT NULL;

-- ۲. جدول‌های نشست و محدودیت ورود (api.php اگر نباشند خودش می‌سازد).
CREATE TABLE IF NOT EXISTS admin_tokens (
    token_hash CHAR(64) NOT NULL PRIMARY KEY,
    admin_id INT NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admin (admin_id),
    INDEX idx_expires (expires_at)
) DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip VARCHAR(45) NOT NULL,
    username VARCHAR(191) NOT NULL,
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_lookup (ip, username, attempted_at)
) DEFAULT CHARSET=utf8mb4;
