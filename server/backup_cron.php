<?php
/**
 * پشتیبان خودکار روزانه — برای Cron Job هاست
 *
 * روش ۱ (ترجیحی، از طریق خط فرمان):
 *   php /home/USERNAME/public_html/backup_cron.php
 *
 * روش ۲ (اگر هاست فقط Cron با آدرس اینترنتی را پشتیبانی می‌کند):
 *   wget -q -O /dev/null "https://promaxmobile.ir/backup_cron.php?key=کلید_مخفی"
 *   کلید در config.php با نام backup_cron_key تعریف می‌شود.
 *
 * فایل‌ها در پوشه‌ی backup_dir (پیش‌فرض: پوشه‌ی backups کنار همین فایل) ذخیره می‌شوند
 * و فقط backup_keep نسخه‌ی آخر (پیش‌فرض ۱۴) نگه داشته می‌شود.
 */
error_reporting(0);
ini_set('display_errors', 0);
@set_time_limit(300);

$isCli = (PHP_SAPI === 'cli');
if (!$isCli) header('Content-Type: text/plain; charset=utf-8');

function cron_exit(string $msg, int $code = 0, bool $isCli = true): void {
    if (!$isCli && $code !== 0) http_response_code($code === 2 ? 403 : 500);
    echo $msg . "\n";
    if ($code !== 0) error_log("[promax-backup] $msg");
    exit($isCli ? $code : 0);
}

$configFile = __DIR__ . '/config.php';
if (!is_file($configFile)) cron_exit("config.php not found", 1, $isCli);
$config = require $configFile;

// اجرای اینترنتی فقط با کلید مخفی مجاز است
if (!$isCli) {
    $key = (string)($config['backup_cron_key'] ?? '');
    $given = (string)($_GET['key'] ?? '');
    if (strlen($key) < 16 || !hash_equals($key, $given)) cron_exit("forbidden", 2, $isCli);
}

require __DIR__ . '/backup_lib.php';

$backupDir = rtrim($config['backup_dir'] ?? (__DIR__ . '/backups'), '/');
$keep = max(1, (int)($config['backup_keep'] ?? 14));

if (!is_dir($backupDir) && !@mkdir($backupDir, 0750, true)) {
    cron_exit("cannot create backup dir: $backupDir", 1, $isCli);
}
// اگر پوشه داخل public_html باشد، دسترسی مستقیم از اینترنت مسدود می‌شود
if (!is_file("$backupDir/.htaccess")) {
    @file_put_contents("$backupDir/.htaccess", "Require all denied\nDeny from all\n");
}
if (!is_file("$backupDir/index.html")) {
    @file_put_contents("$backupDir/index.html", "");
}

mysqli_report(MYSQLI_REPORT_OFF);
$conn = @new mysqli($config['db_host'], $config['db_user'], $config['db_pass'], $config['db_name']);
if ($conn->connect_error) cron_exit("database connection failed", 1, $isCli);
$conn->set_charset("utf8mb4");

try {
    $gz = promax_backup_gz($conn, $config['db_name']);
} catch (Throwable $e) {
    cron_exit("backup failed: " . $e->getMessage(), 1, $isCli);
}

$file = "$backupDir/" . promax_backup_filename();
if (@file_put_contents($file, $gz, LOCK_EX) === false) cron_exit("cannot write $file", 1, $isCli);
@chmod($file, 0640);

// حذف نسخه‌های قدیمی‌تر از backup_keep
$files = glob("$backupDir/promax-backup-*.sql.gz") ?: [];
rsort($files); // نام فایل شامل تاریخ است؛ جدیدترین اول
foreach (array_slice($files, $keep) as $old) @unlink($old);

cron_exit("ok: " . basename($file) . " (" . round(strlen($gz) / 1024, 1) . " KB), kept " . min(count($files), $keep) . " backups", 0, $isCli);
