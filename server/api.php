<?php
/**
 * API حسابدار پرومکس — نسخه‌ی امن‌شده
 *
 * تغییرات امنیتی نسبت به نسخه‌ی قبل:
 *  - اطلاعات دیتابیس به config.php منتقل شد (داخل گیت نیست)
 *  - ورود توکن صادر می‌کند؛ همه‌ی action ها به جز login توکن معتبر می‌خواهند (وگرنه 401)
 *  - نقش و دسترسی کاربر از دیتابیس خوانده می‌شود، نه از requester_role ارسالی اپ
 *  - نام ثبت‌کننده در لاگ‌ها از توکن خوانده می‌شود، نه از admin_name ارسالی اپ
 *  - رمزها با password_hash ذخیره می‌شوند (رمزهای قدیمی موقع ورود خودکار تبدیل می‌شوند)
 *  - محدودیت تلاش ناموفق برای ورود
 *  - رفع SQL Injection در update_registry_status
 *  - پیام‌های خطای داخلی دیتابیس دیگر به کاربر نمایش داده نمی‌شوند
 *  - action های جدید: logout و update_profile
 */
error_reporting(0);
ini_set('display_errors', 0);

header('Content-Type: application/json; charset=utf-8');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Auth-Token");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ------------------- تنظیمات -------------------
$configFile = __DIR__ . '/config.php';
if (!is_file($configFile)) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "پیکربندی سرور انجام نشده است"], JSON_UNESCAPED_UNICODE);
    exit;
}
$config = require $configFile;

const TOKEN_TTL_DAYS = 30;
const LOGIN_MAX_FAILS = 5;          // حداکثر تلاش ناموفق ...
const LOGIN_WINDOW_MINUTES = 15;    // ... در این بازه‌ی زمانی

// کد این فایل نتیجه‌ی کوئری‌ها را خودش چک می‌کند؛ از PHP 8.1 به بعد mysqli به‌طور پیش‌فرض
// به جای برگرداندن false استثنا پرتاب می‌کند (و مثلاً IMEI تکراری خطای 500 می‌دهد).
mysqli_report(MYSQLI_REPORT_OFF);
$conn = @new mysqli($config['db_host'], $config['db_user'], $config['db_pass'], $config['db_name']);
if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "اتصال دیتابیس برقرار نشد"], JSON_UNESCAPED_UNICODE);
    exit;
}
$conn->set_charset("utf8mb4");

// ------------------- توابع کمکی -------------------
function json_out(array $payload, int $code = 200): void {
    http_response_code($code);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

/** خطای داخلی را در لاگ سرور ثبت می‌کند و پیام عمومی به کاربر می‌دهد. */
function server_error(string $publicMessage, string $detail = ''): void {
    if ($detail !== '') error_log("[promax-api] $detail");
    json_out(["status" => "error", "message" => $publicMessage]);
}

function columnExists($conn, $table, $column) {
    $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    return ($res && $res->num_rows > 0);
}

function addLog($conn, $adminName, $actionType, $desc) {
    if (columnExists($conn, 'activity_logs', 'id')) {
        @$conn->query("INSERT INTO activity_logs (admin_name, action_type, description) VALUES ('" . $conn->real_escape_string($adminName) . "', '" . $conn->real_escape_string($actionType) . "', '" . $conn->real_escape_string($desc) . "')");
    }
}

function ensureSecurityTables($conn): void {
    $conn->query("CREATE TABLE IF NOT EXISTS admin_tokens (
        token_hash CHAR(64) NOT NULL PRIMARY KEY,
        admin_id INT NOT NULL,
        expires_at DATETIME NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_admin (admin_id),
        INDEX idx_expires (expires_at)
    ) DEFAULT CHARSET=utf8mb4");
    $conn->query("CREATE TABLE IF NOT EXISTS login_attempts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ip VARCHAR(45) NOT NULL,
        username VARCHAR(191) NOT NULL,
        attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_lookup (ip, username, attempted_at)
    ) DEFAULT CHARSET=utf8mb4");
}

function bearerToken(): ?string {
    $candidates = [
        $_SERVER['HTTP_AUTHORIZATION'] ?? '',
        $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '',
    ];
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $k => $v) {
            if (strcasecmp($k, 'Authorization') === 0) $candidates[] = $v;
        }
    }
    foreach ($candidates as $h) {
        if (preg_match('/^Bearer\s+([A-Za-z0-9_\-]{20,128})$/', trim($h), $m)) return $m[1];
    }
    // برخی هاست‌ها هدر Authorization را حذف می‌کنند؛ اپ این هدر را هم می‌فرستد.
    $alt = trim($_SERVER['HTTP_X_AUTH_TOKEN'] ?? '');
    if (preg_match('/^[A-Za-z0-9_\-]{20,128}$/', $alt)) return $alt;
    return null;
}

/** ادمین واردشده را از روی توکن برمی‌گرداند؛ در غیر این صورت 401. */
function requireAuth($conn): array {
    $token = bearerToken();
    if ($token === null) json_out(["status" => "error", "message" => "ابتدا وارد شوید"], 401);

    $hash = hash('sha256', $token);
    $stmt = $conn->prepare("SELECT a.id, a.username, a.full_name, a.role, a.permissions
                            FROM admin_tokens t JOIN admins a ON a.id = t.admin_id
                            WHERE t.token_hash = ? AND t.expires_at > NOW()");
    if (!$stmt) {
        // جدول توکن‌ها هنوز ساخته نشده (هنوز کسی با نسخه‌ی جدید وارد نشده است)
        ensureSecurityTables($conn);
        json_out(["status" => "error", "message" => "ابتدا وارد شوید"], 401);
    }
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    $me = $stmt->get_result()->fetch_assoc();
    if (!$me) json_out(["status" => "error", "message" => "نشست منقضی شده است. دوباره وارد شوید"], 401);
    return $me;
}

function isSuperAdmin(array $me): bool {
    return ($me['role'] ?? '') === 'super_admin';
}

function requireSuperAdmin(array $me): void {
    if (!isSuperAdmin($me)) json_out(["status" => "error", "message" => "دسترسی غیرمجاز"], 403);
}

/** دسترسی‌های بخش‌ها: analytics, buy, sell, inventory, accessories */
function requirePermission(array $me, string $perm): void {
    if (isSuperAdmin($me)) return;
    $perms = array_map('trim', explode(',', (string)($me['permissions'] ?? '')));
    if (!in_array($perm, $perms, true)) {
        json_out(["status" => "error", "message" => "شما به این بخش دسترسی ندارید"], 403);
    }
}

function isPasswordHash(string $stored): bool {
    return password_get_info($stored)['algo'] !== null && password_get_info($stored)['algo'] !== 0;
}

/** آیا ستون password جای هش (حداقل ۶۰ کاراکتر) را دارد؟ */
function passwordColumnFitsHash($conn): bool {
    $res = $conn->query("SHOW COLUMNS FROM admins LIKE 'password'");
    if (!$res || !($col = $res->fetch_assoc())) return false;
    $type = strtolower($col['Type']);
    if (strpos($type, 'text') !== false) return true;
    return preg_match('/char\((\d+)\)/', $type, $m) && (int)$m[1] >= 60;
}

function clientIp(): string {
    return substr($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0', 0, 45);
}

// ------------------- ورودی -------------------
$action = $_GET['action'] ?? '';
$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true);
if (!is_array($data)) $data = [];

// ------------------- ورود -------------------
if ($action === 'login') {
    ensureSecurityTables($conn);

    $u = trim((string)($data['username'] ?? ''));
    $p = (string)($data['password'] ?? '');
    $ip = clientIp();

    // محدودیت تلاش ناموفق
    $stmt = $conn->prepare("SELECT COUNT(*) AS c FROM login_attempts WHERE ip = ? AND username = ? AND attempted_at > DATE_SUB(NOW(), INTERVAL " . LOGIN_WINDOW_MINUTES . " MINUTE)");
    $stmt->bind_param("ss", $ip, $u);
    $stmt->execute();
    if ((int)$stmt->get_result()->fetch_assoc()['c'] >= LOGIN_MAX_FAILS) {
        json_out(["status" => "error", "message" => "تعداد تلاش‌های ناموفق زیاد است. " . LOGIN_WINDOW_MINUTES . " دقیقه‌ی دیگر دوباره امتحان کنید"], 429);
    }

    $stmt = $conn->prepare("SELECT id, username, full_name, role, permissions, password FROM admins WHERE username = ?");
    $stmt->bind_param("s", $u);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();

    $ok = false;
    if ($row && $p !== '') {
        $stored = (string)$row['password'];
        if (isPasswordHash($stored)) {
            $ok = password_verify($p, $stored);
        } else {
            // رمز قدیمی به‌صورت متن ساده؛ پس از ورود موفق به هش تبدیل می‌شود
            $ok = hash_equals($stored, $p);
            if ($ok && passwordColumnFitsHash($conn)) {
                $newHash = password_hash($p, PASSWORD_DEFAULT);
                $up = $conn->prepare("UPDATE admins SET password = ? WHERE id = ?");
                $up->bind_param("si", $newHash, $row['id']);
                $up->execute();
            }
        }
    }

    if (!$ok) {
        $stmt = $conn->prepare("INSERT INTO login_attempts (ip, username) VALUES (?, ?)");
        $stmt->bind_param("ss", $ip, $u);
        $stmt->execute();
        json_out(["status" => "error", "message" => "نام کاربری یا رمز عبور اشتباه است"]);
    }

    // ورود موفق: پاک کردن تلاش‌های ناموفق و توکن‌های منقضی
    $stmt = $conn->prepare("DELETE FROM login_attempts WHERE ip = ? AND username = ?");
    $stmt->bind_param("ss", $ip, $u);
    $stmt->execute();
    $conn->query("DELETE FROM admin_tokens WHERE expires_at < NOW()");
    $conn->query("DELETE FROM login_attempts WHERE attempted_at < DATE_SUB(NOW(), INTERVAL 1 DAY)");

    $token = rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    $tokenHash = hash('sha256', $token);
    $adminId = (int)$row['id'];
    $stmt = $conn->prepare("INSERT INTO admin_tokens (token_hash, admin_id, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL " . TOKEN_TTL_DAYS . " DAY))");
    $stmt->bind_param("si", $tokenHash, $adminId);
    if (!$stmt->execute()) server_error("خطا در ایجاد نشست", "token insert: " . $conn->error);

    unset($row['password']);
    addLog($conn, $row['full_name'], 'ورود', 'ورود به سامانه');
    json_out(["status" => "success", "admin" => $row, "token" => $token]);
}

// =====================================================================
// از اینجا به بعد همه‌ی درخواست‌ها نیاز به توکن معتبر دارند
// =====================================================================
$me = requireAuth($conn);

// نام ثبت‌کننده همیشه از نشست خوانده می‌شود، نه از چیزی که اپ می‌فرستد
$data['admin_name'] = $me['full_name'];

// ------------------- خروج -------------------
if ($action === 'logout') {
    $hash = hash('sha256', bearerToken());
    $stmt = $conn->prepare("DELETE FROM admin_tokens WHERE token_hash = ?");
    $stmt->bind_param("s", $hash);
    $stmt->execute();
    json_out(["status" => "success", "message" => "خارج شدید"]);
}

// ------------------- ویرایش پروفایل خود کاربر -------------------
if ($action === 'update_profile') {
    $adminId = (int)$me['id'];   // فقط پروفایل خودِ کاربر؛ admin_id ارسالی نادیده گرفته می‌شود
    $fullName = trim((string)($data['full_name'] ?? ''));
    $username = trim((string)($data['username'] ?? ''));
    $newPass = (string)($data['new_password'] ?? '');

    if ($fullName === '' || $username === '') {
        json_out(["status" => "error", "message" => "نام و نام کاربری نمی‌توانند خالی باشند"]);
    }

    $stmt = $conn->prepare("SELECT id FROM admins WHERE username = ? AND id <> ?");
    $stmt->bind_param("si", $username, $adminId);
    $stmt->execute();
    if ($stmt->get_result()->fetch_assoc()) {
        json_out(["status" => "error", "message" => "این نام کاربری قبلاً استفاده شده است"]);
    }

    if ($newPass !== '') {
        if (mb_strlen($newPass) < 8) {
            json_out(["status" => "error", "message" => "رمز عبور جدید باید حداقل ۸ کاراکتر باشد"]);
        }
        if (!passwordColumnFitsHash($conn)) {
            server_error("ستون رمز عبور در دیتابیس برای رمز امن کوتاه است. ابتدا migration را اجرا کنید", "admins.password too short for hash");
        }
        $hash = password_hash($newPass, PASSWORD_DEFAULT);
        $stmt = $conn->prepare("UPDATE admins SET full_name = ?, username = ?, password = ? WHERE id = ?");
        $stmt->bind_param("sssi", $fullName, $username, $hash, $adminId);
    } else {
        $stmt = $conn->prepare("UPDATE admins SET full_name = ?, username = ? WHERE id = ?");
        $stmt->bind_param("ssi", $fullName, $username, $adminId);
    }
    if (!$stmt->execute()) server_error("خطا در ذخیره‌ی پروفایل", "update_profile: " . $conn->error);

    if ($newPass !== '') {
        // با تغییر رمز، همه‌ی نشست‌های دیگر این کاربر باطل می‌شوند
        $current = hash('sha256', bearerToken());
        $stmt = $conn->prepare("DELETE FROM admin_tokens WHERE admin_id = ? AND token_hash <> ?");
        $stmt->bind_param("is", $adminId, $current);
        $stmt->execute();
    }
    addLog($conn, $fullName, 'ویرایش پروفایل', $newPass !== '' ? 'تغییر مشخصات و رمز عبور' : 'تغییر مشخصات');
    json_out(["status" => "success", "message" => "پروفایل بروزرسانی شد"]);
}

// ------------------- اعلان‌ها (همه‌ی کاربران واردشده) -------------------
if ($action === 'get_notifications') {
    $notifications = [];
    $regQuery = "SELECT id, brand, model, buyer_name, buyer_phone, sale_date FROM phones WHERE status = 'SOLD' AND registry_status != 'بدون ریجستر' AND registry_status != 'انجام شد (سفید)' AND (DATEDIFF(CURDATE(), sale_date) % 6 = 0 OR DATEDIFF(CURDATE(), sale_date) >= 6)";
    $resReg = @$conn->query($regQuery);
    if ($resReg) {
        while ($r = $resReg->fetch_assoc()) {
            $notifications[] = [
                "type" => "registry",
                "title" => "یادآوری انتقال رجیستری",
                "message" => "دستگاه {$r['brand']} {$r['model']} خریده شده توسط {$r['buyer_name']} نیاز به انتقال دارد.",
                "buyer_phone" => $r['buyer_phone'] ?? '',
            ];
        }
    }

    $debtQuery = "SELECT id, brand, model, buyer_name, buyer_phone, remaining_amount FROM phones WHERE status = 'SOLD' AND remaining_amount > 0";
    $resDebt = @$conn->query($debtQuery);
    if ($resDebt) {
        while ($d = $resDebt->fetch_assoc()) {
            $notifications[] = [
                "type" => "debt",
                "title" => "سررسید موعد تسویه",
                "message" => "مشتری {$d['buyer_name']} مبلغ " . number_format($d['remaining_amount']) . " ت بدهکار است.",
                "buyer_phone" => $d['buyer_phone'] ?? '',
            ];
        }
    }
    echo json_encode(["status" => "success", "data" => $notifications], JSON_UNESCAPED_UNICODE);
    exit;
}

// =====================================================================
// بخش آمار و صندوق — دسترسی analytics
// =====================================================================

// ------------------- تسویه و دریافت وجه بدهی بدهکاران -------------------
if ($action === 'pay_debt') {
    requirePermission($me, 'analytics');
    $phoneId = (int)($data['phone_id'] ?? 0);
    $payAmount = (int)($data['amount'] ?? 0);
    $adminName = $data['admin_name'];

    if ($phoneId <= 0 || $payAmount <= 0) {
        echo json_encode(["status" => "error", "message" => "اطلاعات پرداخت نامعتبر است"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $chk = $conn->query("SELECT id, brand, model, buyer_name, paid_amount, remaining_amount FROM phones WHERE id = $phoneId AND status = 'SOLD'");
    if (!$chk || $chk->num_rows === 0) {
        echo json_encode(["status" => "error", "message" => "سفارش پیدا نشد"], JSON_UNESCAPED_UNICODE);
        exit;
    }
    $phone = $chk->fetch_assoc();
    $currentRemaining = (int)$phone['remaining_amount'];

    if ($payAmount > $currentRemaining) {
        $payAmount = $currentRemaining;
    }

    $newPaid = (int)$phone['paid_amount'] + $payAmount;
    $newRemaining = $currentRemaining - $payAmount;

    $conn->query("UPDATE phones SET paid_amount = $newPaid, remaining_amount = $newRemaining WHERE id = $phoneId");
    if (columnExists($conn, 'store_treasury', 'bank_balance')) {
        $conn->query("UPDATE store_treasury SET bank_balance = bank_balance + $payAmount WHERE id = 1");
    }
    addLog($conn, $adminName, 'تسویه بدهی', "دریافت مبلغ $payAmount ت بدهی از {$phone['buyer_name']} بابت {$phone['brand']} {$phone['model']}");
    echo json_encode(["status" => "success", "message" => "دریافت وجه ثبت شد و از مانده بدهی کسر گردید", "new_remaining" => $newRemaining], JSON_UNESCAPED_UNICODE);
    exit;
}

// ------------------- آمار مالی و نقدینگی بخش موبایل -------------------
if ($action === 'get_summary') {
    requirePermission($me, 'analytics');
    try {
        $period = $_GET['period'] ?? 'this_month';
        $dateConditionPhone = "1=1";
        $dateConditionExp = "1=1";

        if ($period === 'today' || $period === 'امروز') {
            $dateConditionPhone = "DATE(sale_date) = CURDATE()";
            $dateConditionExp = "DATE(expense_date) = CURDATE()";
        } elseif ($period === 'yesterday' || $period === 'دیروز') {
            $dateConditionPhone = "DATE(sale_date) = SUBDATE(CURDATE(), 1)";
            $dateConditionExp = "DATE(expense_date) = SUBDATE(CURDATE(), 1)";
        } elseif ($period === '7days' || $period === '۷ روز اخیر') {
            $dateConditionPhone = "sale_date >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
            $dateConditionExp = "expense_date >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
        } elseif ($period === '30days' || $period === '۳۰ روز اخیر') {
            $dateConditionPhone = "sale_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
            $dateConditionExp = "expense_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
        } elseif ($period === 'this_month' || $period === 'این ماه') {
            $dateConditionPhone = "MONTH(sale_date) = MONTH(CURDATE()) AND YEAR(sale_date) = YEAR(CURDATE())";
            $dateConditionExp = "MONTH(expense_date) = MONTH(CURDATE()) AND YEAR(expense_date) = YEAR(CURDATE())";
        } elseif ($period === 'last_month' || $period === 'ماه قبل') {
            $dateConditionPhone = "MONTH(sale_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)) AND YEAR(sale_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))";
            $dateConditionExp = "MONTH(expense_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)) AND YEAR(expense_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))";
        }

        $phoneStats = @$conn->query("SELECT COUNT(id) as count, COALESCE(SUM(sale_price), 0) as total_sales, COALESCE(SUM(purchase_price), 0) as total_buys, COALESCE(SUM(profit), 0) as profit FROM phones WHERE status = 'SOLD' AND $dateConditionPhone")->fetch_assoc();
        $invPhone = @$conn->query("SELECT COUNT(id) as count, COALESCE(SUM(purchase_price), 0) as cost FROM phones WHERE status = 'IN_STOCK'")->fetch_assoc();

        $bankBal = 0;
        if (columnExists($conn, 'store_treasury', 'bank_balance')) {
            $treasury = @$conn->query("SELECT bank_balance FROM store_treasury WHERE id = 1")->fetch_assoc();
            $bankBal = (int)($treasury['bank_balance'] ?? 0);
        }

        $debts = @$conn->query("SELECT COALESCE(SUM(remaining_amount), 0) as total_debt FROM phones WHERE remaining_amount > 0 AND status = 'SOLD'")->fetch_assoc();

        $expensesList = [];
        $totalExpensesAmount = 0;
        if (columnExists($conn, 'store_expenses', 'id')) {
            $expensesRes = @$conn->query("SELECT * FROM store_expenses WHERE $dateConditionExp ORDER BY id DESC");
            if ($expensesRes) {
                while ($ex = $expensesRes->fetch_assoc()) {
                    $totalExpensesAmount += (int)$ex['amount'];
                    $expensesList[] = [
                        "id" => (int)$ex['id'],
                        "title" => $ex['title'] ?? 'هزینه',
                        "amount" => (int)$ex['amount'],
                        "category" => $ex['category'] ?? 'هزینه جاری',
                        "description" => $ex['description'] ?? '',
                        "recorded_by" => $ex['recorded_by'] ?? 'مدیر',
                        "expense_date" => $ex['expense_date'] ?? '',
                    ];
                }
            }
        }

        $debtorsList = [];
        $debtorsRes = @$conn->query("SELECT id, brand, model, buyer_name, buyer_phone, remaining_amount, credit_due_shamsi FROM phones WHERE status = 'SOLD' AND remaining_amount > 0 ORDER BY remaining_amount DESC");
        if ($debtorsRes) {
            while ($d = $debtorsRes->fetch_assoc()) {
                $debtorsList[] = [
                    "id" => (int)$d['id'],
                    "brand" => $d['brand'] ?? '',
                    "model" => $d['model'] ?? '',
                    "buyer_name" => !empty($d['buyer_name']) ? $d['buyer_name'] : 'مشتری متفرقه',
                    "buyer_phone" => $d['buyer_phone'] ?? '',
                    "remaining_amount" => (int)($d['remaining_amount'] ?? 0),
                    "credit_due_shamsi" => $d['credit_due_shamsi'] ?? '-',
                ];
            }
        }

        $ordersRes = @$conn->query("SELECT id, brand, model, sale_price, paid_amount, remaining_amount, payment_method, buyer_name, buyer_phone, sale_time, sale_date, credit_due_shamsi FROM phones WHERE status = 'SOLD' AND $dateConditionPhone ORDER BY id DESC LIMIT 50");
        $salesOrders = [];
        if ($ordersRes) {
            while ($o = $ordersRes->fetch_assoc()) {
                $salesOrders[] = [
                    "id" => (int)$o['id'],
                    "brand" => $o['brand'] ?? '',
                    "model" => $o['model'] ?? '',
                    "sale_price" => (int)($o['sale_price'] ?? 0),
                    "paid_amount" => (int)($o['paid_amount'] ?? 0),
                    "remaining_amount" => (int)($o['remaining_amount'] ?? 0),
                    "payment_method" => $o['payment_method'] ?? 'نقدی',
                    "buyer_name" => !empty($o['buyer_name']) ? $o['buyer_name'] : 'مشتری متفرقه',
                    "buyer_phone" => $o['buyer_phone'] ?? '-',
                    "sale_time" => $o['sale_time'] ?? '',
                    "sale_date" => $o['sale_date'] ?? '',
                    "credit_due_shamsi" => $o['credit_due_shamsi'] ?? null,
                ];
            }
        }

        // آمار روزانه برای نمودار روند فروش و سود (تجمیع کامل، بدون محدودیت تعداد)
        $daily = [];
        $dailyRes = @$conn->query("SELECT DATE(sale_date) AS d, COALESCE(SUM(sale_price), 0) AS sales, COALESCE(SUM(profit), 0) AS profit, COUNT(id) AS cnt FROM phones WHERE status = 'SOLD' AND $dateConditionPhone GROUP BY DATE(sale_date) ORDER BY d ASC");
        if ($dailyRes) {
            while ($r = $dailyRes->fetch_assoc()) {
                $daily[] = ["date" => $r['d'], "sales" => (int)$r['sales'], "profit" => (int)$r['profit'], "count" => (int)$r['cnt']];
            }
        }

        // سهم هر برند از فروش دوره
        $brands = [];
        $brandRes = @$conn->query("SELECT brand, COALESCE(SUM(sale_price), 0) AS sales, COUNT(id) AS cnt FROM phones WHERE status = 'SOLD' AND $dateConditionPhone GROUP BY brand ORDER BY sales DESC");
        if ($brandRes) {
            while ($r = $brandRes->fetch_assoc()) {
                $brands[] = ["brand" => $r['brand'] ?? '', "sales" => (int)$r['sales'], "count" => (int)$r['cnt']];
            }
        }

        $mobileLiquidity = $bankBal + (int)($invPhone['cost'] ?? 0);

        echo json_encode([
            "status" => "success",
            "data" => [
                "period" => $period,
                "bank_balance" => $bankBal,
                "total_liquidity" => $mobileLiquidity,
                "phone_buys" => (int)($phoneStats['total_buys'] ?? 0),
                "phone_sales" => (int)($phoneStats['total_sales'] ?? 0),
                "phone_profit" => (int)($phoneStats['profit'] ?? 0),
                "phone_stock_count" => (int)($invPhone['count'] ?? 0),
                "phone_stock_value" => (int)($invPhone['cost'] ?? 0),
                "total_debt" => (int)($debts['total_debt'] ?? 0),
                "total_expenses" => $totalExpensesAmount,
                "expenses" => $expensesList,
                "debtors" => $debtorsList,
                "sales_orders" => $salesOrders,
                "daily" => $daily,
                "brands" => $brands
            ]
        ], JSON_UNESCAPED_UNICODE);
    } catch (Throwable $e) {
        server_error("خطا در دریافت آمار", "get_summary: " . $e->getMessage());
    }
    exit;
}

// ------------------- ثبت برداشت سود یا هزینه -------------------
if ($action === 'add_expense') {
    requirePermission($me, 'analytics');
    $title = $data['title'] ?? 'هزینه متفرقه';
    $amount = (int)($data['amount'] ?? 0);
    $cat = $data['category'] ?? 'هزینه جاری';
    $desc = $data['description'] ?? '';
    $admin = $data['admin_name'];

    if ($amount <= 0) {
        json_out(["status" => "error", "message" => "مبلغ نامعتبر است"]);
    }

    $stmt = $conn->prepare("INSERT INTO store_expenses (title, amount, category, description, recorded_by) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("sisss", $title, $amount, $cat, $desc, $admin);
    if ($stmt->execute()) {
        if (columnExists($conn, 'store_treasury', 'bank_balance')) {
            $conn->query("UPDATE store_treasury SET bank_balance = bank_balance - $amount WHERE id = 1");
        }
        addLog($conn, $admin, 'ثبت هزینه/برداشت', "برداشت یا هزینه $title به مبلغ $amount ت");
        echo json_encode(["status" => "success", "message" => "هزینه ثبت و از نقدینگی کسر گردید"], JSON_UNESCAPED_UNICODE);
    } else {
        server_error("خطا در ثبت هزینه", "add_expense: " . $conn->error);
    }
    exit;
}

// ------------------- صندوق -------------------
if ($action === 'update_bank_balance') {
    requirePermission($me, 'analytics');
    $bal = (int)($data['bank_balance'] ?? 0);
    if (columnExists($conn, 'store_treasury', 'bank_balance')) {
        $conn->query("UPDATE store_treasury SET bank_balance = $bal WHERE id = 1");
    }
    addLog($conn, $data['admin_name'], 'تغییر موجودی', "تنظیم موجودی کارت‌ها روی $bal ت");
    echo json_encode(["status" => "success", "message" => "موجودی کارت‌ها بروز شد"], JSON_UNESCAPED_UNICODE);
    exit;
}

// =====================================================================
// فروش گوشی — دسترسی sell
// =====================================================================
if ($action === 'sell_phone') {
    requirePermission($me, 'sell');
    try {
        $imei = trim($data['imei'] ?? '');
        $salePrice = (int)($data['sale_price'] ?? 0);
        $paidAmount = isset($data['paid_amount']) ? (int)$data['paid_amount'] : $salePrice;
        $paidAmount = max(0, min($paidAmount, $salePrice));
        $remaining = $salePrice - $paidAmount;
        $method = $conn->real_escape_string($data['payment_method'] ?? 'نقدی');
        $payDetails = $conn->real_escape_string($data['payment_details'] ?? '');
        $buyerName = $conn->real_escape_string(!empty($data['buyer_name']) ? $data['buyer_name'] : 'مشتری متفرقه');
        $buyerPhone = $conn->real_escape_string($data['buyer_phone'] ?? '');
        $adminName = $conn->real_escape_string($data['admin_name']);
        $saleTime = $conn->real_escape_string($data['sale_time'] ?? date('H:i'));
        $desc = $conn->real_escape_string($data['description'] ?? '');
        $regStatus = $conn->real_escape_string($data['registry_status'] ?? 'شرکتی با گارانتی');
        $hamta = !empty($data['hamta_verified']) ? 1 : 0;
        $creditDueShamsi = $conn->real_escape_string($data['credit_due_shamsi'] ?? '');

        if (empty($imei)) {
            echo json_encode(["status" => "error", "message" => "شناسه IMEI دستگاه الزامی است"], JSON_UNESCAPED_UNICODE);
            exit;
        }

        if ($salePrice <= 0) {
            echo json_encode(["status" => "error", "message" => "مبلغ فروش نامعتبر است"], JSON_UNESCAPED_UNICODE);
            exit;
        }

        $imeiSafe = $conn->real_escape_string($imei);
        $chk = $conn->query("SELECT * FROM phones WHERE (imei = '$imeiSafe' OR imei2 = '$imeiSafe') AND status = 'IN_STOCK' LIMIT 1");
        if (!$chk || $chk->num_rows === 0) {
            echo json_encode(["status" => "error", "message" => "دستگاه با این IMEI در انبار موجود نیست یا قبلاً فروخته شده است"], JSON_UNESCAPED_UNICODE);
            exit;
        }
        $phoneRow = $chk->fetch_assoc();
        $phoneId = (int)$phoneRow['id'];

        $purchasePrice = isset($phoneRow['purchase_price']) ? (int)$phoneRow['purchase_price'] : 0;
        $extraCost = isset($phoneRow['extra_cost']) ? (int)$phoneRow['extra_cost'] : 0;
        $calculatedProfit = $salePrice - $purchasePrice - $extraCost;

        $updateFields = [
            "sale_price = $salePrice",
            "sale_date = NOW(),
            sale_time = '$saleTime'",
            "payment_method = '$method'",
            "payment_details = '$payDetails'",
            "paid_amount = $paidAmount",
            "remaining_amount = $remaining",
            "buyer_name = '$buyerName'",
            "buyer_phone = '$buyerPhone'",
            "sold_by_admin = '$adminName'",
            "description = '$desc'",
            "registry_status = '$regStatus'",
            "hamta_verified = $hamta",
            "status = 'SOLD'"
        ];

        if (columnExists($conn, 'phones', 'credit_due_shamsi')) {
            $updateFields[] = "credit_due_shamsi = '$creditDueShamsi'";
        }

        // شرط status از فروش هم‌زمان یک دستگاه توسط دو نفر جلوگیری می‌کند
        $sql = "UPDATE phones SET " . implode(", ", $updateFields) . " WHERE id = $phoneId AND status = 'IN_STOCK'";

        if ($conn->query($sql) && $conn->affected_rows === 1) {
            if ($paidAmount > 0 && columnExists($conn, 'store_treasury', 'bank_balance')) {
                @$conn->query("UPDATE store_treasury SET bank_balance = bank_balance + $paidAmount WHERE id = 1");
            }
            $buyerLabel = !empty($data['buyer_name']) ? $data['buyer_name'] : 'مشتری متفرقه';
            addLog($conn, $data['admin_name'], 'فروش کالا', "فروش {$phoneRow['brand']} {$phoneRow['model']} به $buyerLabel به مبلغ $salePrice ت");
            echo json_encode([
                "status" => "success",
                "profit" => $calculatedProfit,
                "remaining" => $remaining,
                "message" => "فروش دستگاه با موفقیت ثبت شد"
            ], JSON_UNESCAPED_UNICODE);
        } else {
            server_error("خطا در ثبت فروش. دوباره تلاش کنید", "sell_phone: " . $conn->error);
        }
    } catch (Throwable $e) {
        server_error("خطای سرور در ثبت فروش", "sell_phone: " . $e->getMessage());
    }
    exit;
}

// =====================================================================
// خرید گوشی — دسترسی buy
// =====================================================================
if ($action === 'buy_phone') {
    requirePermission($me, 'buy');
    $custName = !empty($data['customer_name']) ? $data['customer_name'] : 'مشتری متفرقه';
    $custPhone = $data['phone_number'] ?? '';
    $custNId = preg_replace('/[^0-9]/', '', $data['national_id'] ?? '');

    $stmtCust = $conn->prepare("INSERT INTO customers (full_name, phone, national_id) VALUES (?, ?, ?)");
    $stmtCust->bind_param("sss", $custName, $custPhone, $custNId);
    $stmtCust->execute();
    $customerId = $conn->insert_id;

    $adminName = $data['admin_name'];
    $desc = $data['description'] ?? '';
    $regStatus = $data['registry_status'] ?? 'شرکتی با گارانتی';
    $hamta = !empty($data['hamta_verified']) ? 1 : 0;
    $imei = $data['imei'] ?? '';
    $imei2 = $data['imei2'] ?? '';
    $brand = $data['brand'] ?? '';
    $model = $data['model'] ?? '';
    $entryTime = $data['entry_time'] ?? date('H:i');
    $purchasePrice = (int)($data['purchase_price'] ?? 0);

    $stmtPhone = $conn->prepare("INSERT INTO phones (imei, imei2, brand, model, customer_id, purchase_price, description, registry_status, hamta_verified, entry_time, created_by_admin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmtPhone->bind_param("sssssississ", $imei, $imei2, $brand, $model, $customerId, $purchasePrice, $desc, $regStatus, $hamta, $entryTime, $adminName);

    if ($stmtPhone->execute()) {
        if (columnExists($conn, 'store_treasury', 'bank_balance')) {
            $conn->query("UPDATE store_treasury SET bank_balance = bank_balance - $purchasePrice WHERE id = 1");
        }
        addLog($conn, $adminName, 'خرید کالا', "ثبت دستگاه $brand $model به مبلغ $purchasePrice ت");
        echo json_encode(["status" => "success", "message" => "دستگاه در انبار ثبت شد"], JSON_UNESCAPED_UNICODE);
    } else {
        echo json_encode(["status" => "error", "message" => "شناسه IMEI تکراری است"], JSON_UNESCAPED_UNICODE);
    }
    exit;
}

// =====================================================================
// انبار و سفارش‌ها — دسترسی inventory
// =====================================================================
if ($action === 'get_all_phones') {
    requirePermission($me, 'inventory');
    $sql = "SELECT p.*, c.full_name AS seller_name, c.phone AS seller_phone, c.national_id AS seller_nid FROM phones p LEFT JOIN customers c ON p.customer_id = c.id ORDER BY p.id DESC";
    $res = $conn->query($sql);
    $items = [];
    if ($res) while ($row = $res->fetch_assoc()) $items[] = $row;
    echo json_encode(["status" => "success", "data" => $items], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'update_registry_status') {
    requirePermission($me, 'inventory');
    $phoneId = (int)($data['phone_id'] ?? 0);
    $status = (string)($data['registry_status'] ?? 'انجام شد (سفید)');
    $hamta = !empty($data['hamta_verified']) ? 1 : 0;
    $adminName = $data['admin_name'];
    // قبلاً registry_status مستقیم داخل SQL قرار می‌گرفت (SQL Injection)
    $stmt = $conn->prepare("UPDATE phones SET registry_status = ?, hamta_verified = ? WHERE id = ?");
    $stmt->bind_param("sii", $status, $hamta, $phoneId);
    $stmt->execute();
    addLog($conn, $adminName, 'تغییر رجیستری', "تغییر رجیستری دستگاه $phoneId به $status");
    echo json_encode(["status" => "success", "message" => "وضعیت رجیستری بروزرسانی شد"], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'delete_phone') {
    requirePermission($me, 'inventory');
    $phoneId = (int)($data['phone_id'] ?? 0);
    $adminName = $data['admin_name'];
    $conn->query("DELETE FROM phones WHERE id = $phoneId");
    addLog($conn, $adminName, 'حذف سفارش', "حذف قطعی سفارش شناسه $phoneId");
    echo json_encode(["status" => "success", "message" => "سفارش با موفقیت حذف شد"], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'update_order') {
    requirePermission($me, 'inventory');
    $phoneId = (int)($data['phone_id'] ?? 0);
    $brand = $data['brand'] ?? '';
    $model = $data['model'] ?? '';
    $imei = $data['imei'] ?? '';
    $imei2 = $data['imei2'] ?? '';
    $price = (int)($data['price'] ?? 0);
    $adminName = $data['admin_name'];

    $stmt = $conn->prepare("UPDATE phones SET brand = ?, model = ?, imei = ?, imei2 = ?, purchase_price = ? WHERE id = ?");
    $stmt->bind_param("ssssii", $brand, $model, $imei, $imei2, $price, $phoneId);
    $stmt->execute();
    addLog($conn, $adminName, 'ویرایش سفارش', "ویرایش مشخصات دستگاه $brand $model");
    echo json_encode(["status" => "success", "message" => "کالا ویرایش شد"], JSON_UNESCAPED_UNICODE);
    exit;
}

// =====================================================================
// اکسسوری — دسترسی accessories
// =====================================================================
if ($action === 'get_acc_summary') {
    requirePermission($me, 'accessories');
    $period = $_GET['period'] ?? 'this_month';
    $dateConditionAcc = "1=1";

    if ($period === 'today' || $period === 'امروز') {
        $dateConditionAcc = "DATE(sale_date) = CURDATE()";
    } elseif ($period === 'yesterday' || $period === 'دیروز') {
        $dateConditionAcc = "DATE(sale_date) = SUBDATE(CURDATE(), 1)";
    } elseif ($period === '7days' || $period === '۷ روز اخیر') {
        $dateConditionAcc = "sale_date >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
    } elseif ($period === '30days' || $period === '۳۰ روز اخیر') {
        $dateConditionAcc = "sale_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
    } elseif ($period === 'this_month' || $period === 'این ماه') {
        $dateConditionAcc = "MONTH(sale_date) = MONTH(CURDATE()) AND YEAR(sale_date) = YEAR(CURDATE())";
    } elseif ($period === 'last_month' || $period === 'ماه قبل') {
        $dateConditionAcc = "MONTH(sale_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)) AND YEAR(sale_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))";
    }

    $accSalesRow = @$conn->query("SELECT COALESCE(SUM(total_price), 0) as total_sales, COALESCE(SUM(profit), 0) as total_profit, COUNT(id) as total_count FROM accessory_sales WHERE $dateConditionAcc")->fetch_assoc();
    $invAcc = @$conn->query("SELECT COALESCE(SUM(stock), 0) as count, COALESCE(SUM(stock * buy_price), 0) as cost FROM accessories WHERE stock > 0")->fetch_assoc();

    echo json_encode([
        "status" => "success",
        "data" => [
            "period" => $period,
            "acc_sales" => (int)($accSalesRow['total_sales'] ?? 0),
            "acc_profit" => (int)($accSalesRow['total_profit'] ?? 0),
            "acc_orders_count" => (int)($accSalesRow['total_count'] ?? 0),
            "acc_stock_count" => (int)($invAcc['count'] ?? 0),
            "acc_stock_value" => (int)($invAcc['cost'] ?? 0),
        ]
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'get_accessories') {
    requirePermission($me, 'accessories');
    $res = $conn->query("SELECT * FROM accessories ORDER BY id DESC");
    $items = [];
    if ($res) while ($row = $res->fetch_assoc()) $items[] = $row;
    echo json_encode(["status" => "success", "data" => $items], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'add_accessory') {
    requirePermission($me, 'accessories');
    $name = $data['name'] ?? '';
    $barcode = $data['barcode'] ?? null;
    $cat = $data['category'] ?? 'عمومی';
    $stock = (int)($data['stock'] ?? 0);
    $buy = (int)($data['buy_price'] ?? 0);
    $sale = (int)($data['sale_price'] ?? 0);
    $admin = $data['admin_name'];

    $stmt = $conn->prepare("INSERT INTO accessories (name, barcode, category, stock, buy_price, sale_price) VALUES (?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("sssiii", $name, $barcode, $cat, $stock, $buy, $sale);
    if ($stmt->execute()) {
        addLog($conn, $admin, 'خرید اکسسوری', "افزودن $stock عدد $name");
        echo json_encode(["status" => "success", "message" => "کالا در انبار ثبت شد"], JSON_UNESCAPED_UNICODE);
    } else {
        echo json_encode(["status" => "error", "message" => "خطا در ثبت"], JSON_UNESCAPED_UNICODE);
    }
    exit;
}

if ($action === 'update_accessory') {
    requirePermission($me, 'accessories');
    $id = (int)($data['id'] ?? 0);
    $name = $data['name'] ?? '';
    $barcode = $data['barcode'] ?? null;
    $stock = (int)($data['stock'] ?? 0);
    $buy = (int)($data['buy_price'] ?? 0);
    $sale = (int)($data['sale_price'] ?? 0);
    $admin = $data['admin_name'];

    $stmt = $conn->prepare("UPDATE accessories SET name = ?, barcode = ?, stock = ?, buy_price = ?, sale_price = ? WHERE id = ?");
    $stmt->bind_param("ssiiii", $name, $barcode, $stock, $buy, $sale, $id);
    if ($stmt->execute()) {
        addLog($conn, $admin, 'ویرایش اکسسوری', "ویرایش کالا شناسه $id ($name)");
        echo json_encode(["status" => "success", "message" => "بروزرسانی شد"], JSON_UNESCAPED_UNICODE);
    } else {
        echo json_encode(["status" => "error", "message" => "خطا در ویرایش"], JSON_UNESCAPED_UNICODE);
    }
    exit;
}

if ($action === 'sell_accessory') {
    requirePermission($me, 'accessories');
    $accId = (int)($data['accessory_id'] ?? 0);
    $qty = (int)($data['quantity'] ?? 1);
    $customPrice = isset($data['custom_sale_price']) ? (int)$data['custom_sale_price'] : 0;
    $buyer = $data['buyer_name'] ?? 'مشتری متفرقه';
    $admin = $data['admin_name'];

    if ($qty <= 0) {
        json_out(["status" => "error", "message" => "تعداد نامعتبر است"]);
    }

    $item = $conn->query("SELECT * FROM accessories WHERE id = $accId")->fetch_assoc();
    if (!$item || $item['stock'] < $qty) {
        echo json_encode(["status" => "error", "message" => "موجودی کافی نیست"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    // کسر موجودی فقط اگر هنوز کافی باشد (جلوگیری از منفی شدن در فروش هم‌زمان)
    $conn->query("UPDATE accessories SET stock = stock - $qty WHERE id = $accId AND stock >= $qty");
    if ($conn->affected_rows !== 1) {
        json_out(["status" => "error", "message" => "موجودی کافی نیست"]);
    }

    $unitPrice = ($customPrice > 0) ? $customPrice : (int)$item['sale_price'];
    $totalPrice = $unitPrice * $qty;
    $profit = ($unitPrice - (int)$item['buy_price']) * $qty;

    $stmt = $conn->prepare("INSERT INTO accessory_sales (accessory_id, quantity, unit_price, total_price, profit, buyer_name, admin_name) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("iiiiiss", $accId, $qty, $unitPrice, $totalPrice, $profit, $buyer, $admin);
    $stmt->execute();

    addLog($conn, $admin, 'فروش اکسسوری', "فروش $qty عدد {$item['name']} به مبلغ هر عدد $unitPrice ت");
    echo json_encode(["status" => "success", "message" => "فروش با موفقیت ثبت شد", "profit" => $profit], JSON_UNESCAPED_UNICODE);
    exit;
}

// =====================================================================
// مدیریت ادمین‌ها و لاگ‌ها — فقط مدیر ارشد
// =====================================================================
if ($action === 'get_admins') {
    requireSuperAdmin($me);
    $res = $conn->query("SELECT id, username, full_name, role, permissions FROM admins ORDER BY id ASC");
    $admins = [];
    while ($r = $res->fetch_assoc()) $admins[] = $r;
    echo json_encode(["status" => "success", "data" => $admins], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'create_admin') {
    requireSuperAdmin($me);   // requester_role ارسالی اپ دیگر استفاده نمی‌شود
    $u = trim((string)($data['username'] ?? ''));
    $p = (string)($data['password'] ?? '');
    $name = trim((string)($data['full_name'] ?? ''));
    $perms = $data['permissions'] ?? 'accessories';

    if ($u === '' || $name === '') {
        json_out(["status" => "error", "message" => "نام و نام کاربری الزامی است"]);
    }
    if (mb_strlen($p) < 8) {
        json_out(["status" => "error", "message" => "رمز عبور باید حداقل ۸ کاراکتر باشد"]);
    }
    if (!passwordColumnFitsHash($conn)) {
        server_error("ستون رمز عبور در دیتابیس برای رمز امن کوتاه است. ابتدا migration را اجرا کنید", "admins.password too short for hash");
    }
    $hash = password_hash($p, PASSWORD_DEFAULT);

    $stmt = $conn->prepare("INSERT INTO admins (username, password, full_name, role, permissions) VALUES (?, ?, ?, 'admin', ?)");
    $stmt->bind_param("ssss", $u, $hash, $name, $perms);
    if ($stmt->execute()) {
        addLog($conn, $me['full_name'], 'افزودن همکار', "ایجاد ادمین جدید: $name با دسترسی $perms");
        echo json_encode(["status" => "success", "message" => "همکار جدید ثبت شد"], JSON_UNESCAPED_UNICODE);
    } else {
        echo json_encode(["status" => "error", "message" => "نام کاربری تکراری است"], JSON_UNESCAPED_UNICODE);
    }
    exit;
}

if ($action === 'delete_admin') {
    requireSuperAdmin($me);
    $targetId = (int)($data['admin_id'] ?? 0);

    $chk = $conn->query("SELECT role, full_name FROM admins WHERE id = $targetId")->fetch_assoc();
    if (!$chk) {
        json_out(["status" => "error", "message" => "همکار پیدا نشد"]);
    }
    if ($chk['role'] === 'super_admin') {
        echo json_encode(["status" => "error", "message" => "امکان حذف مدیر ارشد وجود ندارد"], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $conn->query("DELETE FROM admin_tokens WHERE admin_id = $targetId");
    $conn->query("DELETE FROM admins WHERE id = $targetId");
    addLog($conn, $me['full_name'], 'حذف همکار', "حذف ادمین: {$chk['full_name']}");
    echo json_encode(["status" => "success", "message" => "همکار حذف شد"], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'update_admin_permissions') {
    requireSuperAdmin($me);
    $adminId = (int)($data['admin_id'] ?? 0);
    $perms = $data['permissions'] ?? '';
    $stmt = $conn->prepare("UPDATE admins SET permissions = ? WHERE id = ? AND role <> 'super_admin'");
    $stmt->bind_param("si", $perms, $adminId);
    $stmt->execute();
    addLog($conn, $me['full_name'], 'تغییر دسترسی', "تغییر دسترسی ادمین شناسه $adminId به $perms");
    echo json_encode(["status" => "success", "message" => "سطح دسترسی بروز شد"], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($action === 'get_logs') {
    requireSuperAdmin($me);
    $res = $conn->query("SELECT * FROM activity_logs ORDER BY id DESC LIMIT 100");
    $logs = [];
    while ($r = $res->fetch_assoc()) $logs[] = $r;
    echo json_encode(["status" => "success", "data" => $logs], JSON_UNESCAPED_UNICODE);
    exit;
}

json_out(["status" => "error", "message" => "درخواست نامعتبر"], 400);
