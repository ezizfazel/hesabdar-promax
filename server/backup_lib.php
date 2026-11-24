<?php
/**
 * تهیه‌ی نسخه‌ی پشتیبان کامل دیتابیس به‌صورت SQL فشرده (gzip)
 *
 * هم api.php (دکمه‌ی پشتیبان در اپ) و هم backup_cron.php (پشتیبان خودکار روزانه)
 * از این فایل استفاده می‌کنند. فایل خروجی را می‌توان مستقیم در phpMyAdmin → Import
 * بازگرداند.
 */

// جدول‌هایی که فقط ساختارشان ذخیره می‌شود (داده‌ی موقت و حساس نشست‌ها)
const BACKUP_STRUCTURE_ONLY = ['admin_tokens', 'login_attempts'];

/**
 * کل دیتابیس را به متن SQL تبدیل می‌کند.
 * @throws RuntimeException در صورت خطای دیتابیس
 */
function promax_backup_sql(mysqli $conn, string $dbName): string {
    $out = [];
    $out[] = "-- نسخه‌ی پشتیبان حسابدار پرومکس";
    $out[] = "-- دیتابیس: $dbName";
    $out[] = "-- زمان تهیه: " . date('Y-m-d H:i:s');
    $out[] = "-- بازگردانی: phpMyAdmin → Import → انتخاب همین فایل";
    $out[] = "";
    $out[] = "SET NAMES utf8mb4;";
    $out[] = "SET FOREIGN_KEY_CHECKS = 0;";
    $out[] = "SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';";
    $out[] = "";

    $tablesRes = $conn->query("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'");
    if (!$tablesRes) throw new RuntimeException("SHOW TABLES failed: " . $conn->error);

    $tables = [];
    while ($row = $tablesRes->fetch_row()) $tables[] = $row[0];

    foreach ($tables as $table) {
        $qt = '`' . str_replace('`', '``', $table) . '`';

        $createRes = $conn->query("SHOW CREATE TABLE $qt");
        if (!$createRes) throw new RuntimeException("SHOW CREATE TABLE $table failed: " . $conn->error);
        $create = $createRes->fetch_row()[1];

        $out[] = "-- ----------------------------------------";
        $out[] = "-- جدول $table";
        $out[] = "-- ----------------------------------------";
        $out[] = "DROP TABLE IF EXISTS $qt;";
        $out[] = $create . ";";
        $out[] = "";

        if (in_array($table, BACKUP_STRUCTURE_ONLY, true)) continue;

        // ستون‌های محاسباتی (GENERATED) قابل INSERT نیستند و کنار گذاشته می‌شوند
        $cols = [];
        $colRes = $conn->query("SHOW COLUMNS FROM $qt");
        if (!$colRes) throw new RuntimeException("SHOW COLUMNS $table failed: " . $conn->error);
        while ($c = $colRes->fetch_assoc()) {
            if (stripos($c['Extra'] ?? '', 'GENERATED') !== false) continue;
            $cols[] = $c['Field'];
        }
        if (!$cols) continue;

        $colList = implode(', ', array_map(fn($c) => '`' . str_replace('`', '``', $c) . '`', $cols));
        $dataRes = $conn->query("SELECT $colList FROM $qt", MYSQLI_USE_RESULT);
        if (!$dataRes) throw new RuntimeException("SELECT $table failed: " . $conn->error);

        $batch = [];
        while ($r = $dataRes->fetch_row()) {
            $vals = [];
            foreach ($r as $v) {
                $vals[] = $v === null ? 'NULL' : "'" . $conn->real_escape_string($v) . "'";
            }
            $batch[] = '(' . implode(', ', $vals) . ')';
            if (count($batch) >= 200) {
                $out[] = "INSERT INTO $qt ($colList) VALUES\n" . implode(",\n", $batch) . ";";
                $batch = [];
            }
        }
        $dataRes->free();
        if ($batch) $out[] = "INSERT INTO $qt ($colList) VALUES\n" . implode(",\n", $batch) . ";";
        $out[] = "";
    }

    $out[] = "SET FOREIGN_KEY_CHECKS = 1;";
    $out[] = "-- پایان نسخه‌ی پشتیبان";
    return implode("\n", $out) . "\n";
}

/** نام فایل پشتیبان با تاریخ و ساعت، مثلاً promax-backup-2026-11-24_2315.sql.gz */
function promax_backup_filename(): string {
    return 'promax-backup-' . date('Y-m-d_Hi') . '.sql.gz';
}

/** نسخه‌ی پشتیبان فشرده (gzip) */
function promax_backup_gz(mysqli $conn, string $dbName): string {
    $gz = gzencode(promax_backup_sql($conn, $dbName), 9);
    if ($gz === false) throw new RuntimeException("gzencode failed");
    return $gz;
}
