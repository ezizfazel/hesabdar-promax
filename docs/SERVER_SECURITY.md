# امن‌سازی سرور (`api.php`)

اپ از این نسخه به بعد برای ورود امن آماده است، اما **امنیت واقعی فقط روی سرور تأمین می‌شود.**
هر کسی آدرس `https://promaxmobile.ir/api.php` را از داخل APK پیدا کند، می‌تواند مستقیم به آن درخواست بفرستد.
پس سرور نباید به هیچ چیزی که اپ درباره‌ی هویت یا نقش کاربر می‌گوید اعتماد کند.

## اپ چه چیزی از سرور انتظار دارد

| مورد | رفتار مورد انتظار |
|---|---|
| `action=login` | اگر نام کاربری و رمز درست بود: `{"status":"success","admin":{...},"token":"<توکن تصادفی>"}` |
| همه‌ی درخواست‌های دیگر | اپ هدر `Authorization: Bearer <token>` را می‌فرستد. اگر توکن نبود، نامعتبر یا منقضی بود، سرور باید **کد HTTP 401** برگرداند. اپ در این حالت کاربر را خودکار به صفحه‌ی ورود می‌برد. |
| `action=logout` | توکن فعلی را باطل کند. |

> تا وقتی سرور `token` برنگرداند، اپ همچنان کار می‌کند، اما ورود با اثر انگشت غیرفعال می‌ماند و یک هشدار نمایش می‌دهد.

## مشکلات فعلی که باید در سرور برطرف شوند

1. **هیچ درخواستی احراز هویت ندارد.** مثلاً `get_logs`، `get_admins`، `delete_admin`، `pay_debt` و `sell_phone` را هر کسی می‌تواند بدون ورود صدا بزند.
2. **نقش کاربر از طرف اپ فرستاده می‌شود.** فیلد `requester_role` (در `create_admin`، `delete_admin` و `update_admin_permissions`) قابل جعل است. سرور باید نقش را **از روی توکن و از دیتابیس** بخواند و این فیلد را نادیده بگیرد.
3. **`update_profile` شناسه‌ی ادمین را از اپ می‌گیرد** (`admin_id`). با این روش هر کسی می‌تواند نام کاربری و رمز **هر ادمینی** را عوض کند. شناسه باید از توکن خوانده شود.
4. رمزها باید با `password_hash` ذخیره شوند، نه به‌صورت متن ساده یا MD5.
5. رمز پیش‌فرض `admin1 / 123456` قبلاً داخل اپ نوشته شده بود و در نسخه‌های قدیمی APK هنوز هست. **همین الان رمز این حساب را عوض کنید.**

## پیاده‌سازی نمونه (PHP + PDO)

ساختار دیتابیس شما را ندیده‌ام. فرض این نمونه این است که جدولی به اسم `admins` با ستون‌های `id`، `username`، `password_hash`، `role` و `permissions` دارید. نام‌ها را با دیتابیس خودتان تطبیق دهید.

### ۱. جدول توکن‌ها

```sql
CREATE TABLE admin_tokens (
  token_hash CHAR(64)     NOT NULL PRIMARY KEY,   -- SHA-256 توکن؛ خود توکن ذخیره نمی‌شود
  admin_id   INT          NOT NULL,
  expires_at DATETIME     NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX (admin_id),
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);
```

### ۲. توابع کمکی

```php
<?php
const TOKEN_TTL_DAYS = 30;

function json_out(array $data, int $code = 200): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function bearer_token(): ?string {
    $h = $_SERVER['HTTP_AUTHORIZATION']
      ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
      ?? (function_exists('apache_request_headers') ? (apache_request_headers()['Authorization'] ?? '') : '');
    return preg_match('/^Bearer\s+([A-Za-z0-9_\-]{20,})$/', trim($h), $m) ? $m[1] : null;
}

/** ادمین واردشده را برمی‌گرداند یا با 401 خاتمه می‌دهد. */
function require_auth(PDO $db): array {
    $token = bearer_token();
    if (!$token) json_out(['status' => 'error', 'message' => 'ابتدا وارد شوید'], 401);

    $st = $db->prepare(
        'SELECT a.* FROM admin_tokens t JOIN admins a ON a.id = t.admin_id
         WHERE t.token_hash = ? AND t.expires_at > NOW()'
    );
    $st->execute([hash('sha256', $token)]);
    $admin = $st->fetch(PDO::FETCH_ASSOC);
    if (!$admin) json_out(['status' => 'error', 'message' => 'نشست منقضی شده است'], 401);
    return $admin;
}

/** فقط نقش‌های مجاز؛ نقش از دیتابیس خوانده می‌شود، نه از درخواست. */
function require_role(array $admin, array $roles): void {
    if (!in_array($admin['role'], $roles, true)) {
        json_out(['status' => 'error', 'message' => 'دسترسی ندارید'], 403);
    }
}
```

### ۳. ورود و خروج

```php
$action = $_GET['action'] ?? '';
$input  = json_decode(file_get_contents('php://input'), true) ?: [];

if ($action === 'login') {
    // TODO: محدودیت تعداد تلاش (مثلاً ۵ بار در ۱۵ دقیقه برای هر IP/نام کاربری)
    $st = $db->prepare('SELECT * FROM admins WHERE username = ?');
    $st->execute([trim($input['username'] ?? '')]);
    $admin = $st->fetch(PDO::FETCH_ASSOC);

    if (!$admin || !password_verify($input['password'] ?? '', $admin['password_hash'])) {
        json_out(['status' => 'error', 'message' => 'نام کاربری یا رمز عبور اشتباه است']);
    }

    $token = rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    $db->prepare('INSERT INTO admin_tokens (token_hash, admin_id, expires_at)
                  VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ' . TOKEN_TTL_DAYS . ' DAY))')
       ->execute([hash('sha256', $token), $admin['id']]);

    unset($admin['password_hash']);                    // هرگز هش رمز را برنگردانید
    json_out(['status' => 'success', 'admin' => $admin, 'token' => $token]);
}

// از اینجا به بعد همه‌ی action ها نیاز به ورود دارند
$me = require_auth($db);

if ($action === 'logout') {
    $db->prepare('DELETE FROM admin_tokens WHERE token_hash = ?')
       ->execute([hash('sha256', bearer_token())]);
    json_out(['status' => 'success']);
}
```

### ۴. اصلاح action های حساس

```php
if ($action === 'delete_admin') {
    require_role($me, ['super_admin']);                 // نه $input['requester_role']
    if ((int)$input['admin_id'] === (int)$me['id']) {
        json_out(['status' => 'error', 'message' => 'نمی‌توانید خودتان را حذف کنید']);
    }
    // ... حذف
}

if ($action === 'update_profile') {
    $adminId = (int)$me['id'];                          // نه $input['admin_id']
    // اگر رمز جدید داده شد:
    //   password_hash($input['new_password'], PASSWORD_DEFAULT)
    //   و همه‌ی توکن‌های دیگر این ادمین را باطل کنید
}
```

نام نقش‌ها (`super_admin` و غیره) را با مقادیری که در دیتابیس دارید جایگزین کنید.
اگر دسترسی‌ها به‌صورت جزئی در ستون `permissions` ذخیره شده‌اند، برای هر action همان دسترسی را از `$me['permissions']` چک کنید.

### ۵. مهاجرت رمزهای موجود

اگر رمزها الان به‌صورت متن ساده ذخیره شده‌اند، یک بار این اسکریپت را اجرا کنید و بعد ستون قدیمی را حذف کنید:

```php
foreach ($db->query('SELECT id, password FROM admins') as $row) {
    $db->prepare('UPDATE admins SET password_hash = ? WHERE id = ?')
       ->execute([password_hash($row['password'], PASSWORD_DEFAULT), $row['id']]);
}
```

## چک‌لیست

- [ ] جدول `admin_tokens` ساخته شد
- [ ] `login` توکن برمی‌گرداند و `password_hash` را در پاسخ نمی‌فرستد
- [ ] `require_auth` قبل از همه‌ی action ها (به جز `login`) اجرا می‌شود و در صورت خطا **401** برمی‌گرداند
- [ ] `requester_role` و `admin_id` ارسالی از اپ نادیده گرفته می‌شوند و نقش و شناسه از `$me` خوانده می‌شوند
- [ ] رمزها با `password_hash` ذخیره شده‌اند
- [ ] رمز حساب `admin1` عوض شده است
- [ ] همه‌ی کوئری‌ها با `prepare` و پارامتر نوشته شده‌اند (جلوگیری از SQL Injection)
- [ ] برای `login` محدودیت تعداد تلاش گذاشته شده است
- [ ] خطاهای PHP روی سرور اصلی نمایش داده نمی‌شوند (`display_errors = Off`)
