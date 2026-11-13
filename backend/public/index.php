<?php
$appEnv = getenv('APP_ENV') ?: 'production';
error_reporting(E_ALL);
ini_set('display_errors', $appEnv === 'development' ? '1' : '0');

function isAllowedCorsOrigin($origin, $appEnv) {
    if ($origin === '') return false;
    $rawAllowed = getenv('APP_ALLOWED_ORIGINS') ?: 'https://temasan.com,https://www.temasan.com,https://temamarket.com,https://www.temamarket.com,https://temasanalmarket.com,https://www.temasanalmarket.com';
    $allowedList = array_filter(array_map('trim', explode(',', $rawAllowed)));
    if (in_array($origin, $allowedList, true)) {
        return true;
    }
    if (preg_match('#^https://[a-z0-9-]+.(temasan|temamarket).com$#i', $origin)) {
        return true;
    }
    if ($appEnv === 'development' && preg_match('#^http://(localhost|127.0.0.1)(:d+)?$#i', $origin)) {
        return true;
    }
    return false;
}

$requestOrigin = trim((string)($_SERVER['HTTP_ORIGIN'] ?? ''));
if ($requestOrigin !== '') {
    if (isAllowedCorsOrigin($requestOrigin, $appEnv)) {
        header('Access-Control-Allow-Origin: ' . $requestOrigin);
        header('Access-Control-Allow-Credentials: true');
        header('Vary: Origin');
    }
}
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-Idempotency-Key');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: strict-origin-when-cross-origin');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$uri = str_replace('/index.php', '', $uri);

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/../security.php';

try {
    $pdo = require __DIR__ . '/../db.php';
} catch (Exception $e) {
    error_log('Database initialization failed: ' . $e->getMessage());
    jsonResponse(['success' => false, 'message' => 'Sunucu veritabanına bağlanılamadı.'], 503);
}

function getJsonInput() {
    $body = file_get_contents('php://input');
    if ($body === false || trim($body) === '') {
        return [];
    }
    $decoded = json_decode($body, true);
    if (!is_array($decoded)) {
        jsonResponse(['success' => false, 'message' => 'Geçersiz JSON gövdesi.'], 400);
    }
    return $decoded;
}

/**
 * App Review hesapları için, yalnızca sunucu ortam değişkenleriyle etkinleşen
 * sabit doğrulama kodunu döndürür. Kod veya hesap bilgisi API yanıtına yazılmaz.
 *
 * APP_REVIEW_LOGIN_ENABLED=true
 * APP_REVIEW_ACCOUNTS_JSON={"Customer":{"phone":"+905...","code":"123456"}}
 */
function appReviewLoginConfig(): array {
    $enabled = getenv('APP_REVIEW_LOGIN_ENABLED');
    $accountsJson = getenv('APP_REVIEW_ACCOUNTS_JSON');
    if ($enabled !== false || $accountsJson !== false) {
        return [
            'enabled' => filter_var($enabled ?: 'false', FILTER_VALIDATE_BOOL) === true,
            'accounts' => json_decode((string)($accountsJson ?: ''), true),
        ];
    }

    // Ortam değişkeni tanımlanamayan paylaşımlı hostinglerde, web kökü
    // dışındaki ve dağıtım sırasında korunması gereken özel yapılandırma.
    $privateConfigPath = dirname(__DIR__) . '/app_review_config.php';
    if (!is_file($privateConfigPath)) {
        return ['enabled' => false, 'accounts' => []];
    }
    $privateConfig = require $privateConfigPath;
    return is_array($privateConfig)
        ? $privateConfig
        : ['enabled' => false, 'accounts' => []];
}

function appReviewOtpFor(string $phone, string $role): ?string {
    $config = appReviewLoginConfig();
    if (($config['enabled'] ?? false) !== true) {
        return null;
    }

    $accounts = $config['accounts'] ?? null;
    if (!is_array($accounts) || !isset($accounts[$role]) || !is_array($accounts[$role])) {
        return null;
    }

    $configuredPhone = normalizeTurkishPhone((string)($accounts[$role]['phone'] ?? ''));
    $configuredCode = trim((string)($accounts[$role]['code'] ?? ''));
    if ($configuredPhone !== $phone || !preg_match('/^\d{6}$/', $configuredCode)) {
        return null;
    }

    return $configuredCode;
}

function sendTurkTelekomSms($phone, $message, $ttSettings = null) {
    $rawPhone = preg_replace('/[^0-9]/', '', $phone);
    if (str_starts_with($rawPhone, '90')) {
        $formattedNumber = $rawPhone;
    } else {
        $formattedNumber = '90' . ltrim($rawPhone, '0');
    }

    $username = $ttSettings['username'] ?? '';
    $password = $ttSettings['password'] ?? '';
    $loginPassword = $ttSettings['login_password'] ?? '';
    $origin = $ttSettings['origin'] ?? 'TEMA MARKET';
    $brandCode = $ttSettings['brand_code'] ?? '';
    $tokenUrl = $ttSettings['token_url'] ?? 'https://restapi.ttmesaj.com/api/Login/TokenJson';
    $smsUrl = $ttSettings['sms_url'] ?? 'https://restapi.ttmesaj.com/api/SendSms/SendSingle';

    if ($username === '' || $password === '' || $loginPassword === '') {
        return ['success' => false, 'message' => 'SMS sağlayıcısı yapılandırılmamış.'];
    }

    // 1. Türk Telekom Token Al (Standard REST API Request)
    $tokenPayload = json_encode([
        'userName' => $username,
        'password' => $loginPassword
    ]);

    $ch = curl_init($tokenUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $tokenPayload);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $tokenRes = (string)curl_exec($ch);
    $tokenHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr = curl_error($ch);
    curl_close($ch);

    $tokenDoc = json_decode($tokenRes, true);
    $accessToken = $tokenDoc['access_token'] ?? null;
    $tokenSonuc = strval($tokenDoc['sonuc'] ?? '');

    if (!$accessToken || str_contains($tokenRes, 'IP tanimli degil') || $tokenSonuc === '2') {
        $isIpBlocked = str_contains($tokenRes, 'IP tanimli degil');
        error_log('Turk Telekom token error: http=' . $tokenHttpCode . ' sonuc=' . $tokenSonuc . ' ip_blocked=' . ($isIpBlocked ? '1' : '0') . ($curlErr !== '' ? ' curl=' . $curlErr : ''));
        return [
            'success' => false,
            'provider' => 'Türk Telekom REST API',
            'message' => $isIpBlocked
                ? 'SMS sağlayıcısı bu sunucu IP adresine izin vermiyor (Türk Telekom IP kısıtı).'
                : ($curlErr !== '' ? 'SMS sağlayıcısına bağlanılamadı.' : 'SMS sağlayıcısı token vermedi.'),
        ];
    }

    // 2. Türk Telekom SendSingle SMS Gönder
    $smsPayload = json_encode([
        'username' => $username,
        'password' => $password,
        'numbers' => $formattedNumber,
        'message' => $message,
        'origin' => $origin,
        'sd' => "0",
        'ed' => "0",
        'isNotification' => true,
        'recipentType' => "BIREYSEL",
        'brandCode' => $brandCode
    ]);

    $ch = curl_init($smsUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $smsPayload);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $accessToken
    ]);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $smsRes = (string)curl_exec($ch);
    $smsHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $smsDoc = json_decode($smsRes, true);
    $smsSonuc = strval($smsDoc['sonuc'] ?? '');

    $isSuccess = ($smsHttpCode >= 200 && $smsHttpCode < 300) && (!str_contains($smsRes, 'IP tanimli degil')) && ($smsSonuc === '0' || $smsSonuc === '1' || empty($smsSonuc));

    if (!$isSuccess) {
        $isIpBlocked = str_contains($smsRes, 'IP tanimli degil');
        error_log('Turk Telekom SendSingle rejected: http=' . $smsHttpCode . ' sonuc=' . $smsSonuc . ' ip_blocked=' . ($isIpBlocked ? '1' : '0'));
        return [
            'success' => false,
            'provider' => 'Türk Telekom REST API',
            'message' => $isIpBlocked
                ? 'SMS sağlayıcısı bu sunucu IP adresine izin vermiyor (Türk Telekom IP kısıtı).'
                : 'SMS sağlayıcısı gönderimi reddetti.',
        ];
    }

    return [
        'success' => true,
        'provider' => 'Türk Telekom REST API (Canlı Entegrasyon)',
        'http_code' => $smsHttpCode
    ];
}

function sendNetgsmSms($phone, $message, $netgsm) {
    $rawPhone = preg_replace('/[^0-9]/', '', (string)$phone);
    if (strpos($rawPhone, '90') === 0 && strlen($rawPhone) === 12) {
        $rawPhone = substr($rawPhone, 2);
    } elseif (strpos($rawPhone, '0') === 0 && strlen($rawPhone) === 11) {
        $rawPhone = substr($rawPhone, 1);
    }

    $header = trim((string)($netgsm['msgheader'] ?? ''));

    // Otomatik başlık sorgulama fallback (eğer DB'deki başlık boşsa veya Netgsm'de tanımlı başlığı dinamik keşfetmek için)
    if ($header === '') {
        $chH = curl_init('https://api.netgsm.com.tr/sms/rest/v2/msgheader');
        curl_setopt($chH, CURLOPT_USERPWD, "{$netgsm['usercode']}:{$netgsm['password']}");
        curl_setopt($chH, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($chH, CURLOPT_TIMEOUT, 4);
        $resH = curl_exec($chH);
        curl_close($chH);
        $jsonH = json_decode((string)$resH, true);
        if (!empty($jsonH['msgheaders']) && is_array($jsonH['msgheaders'])) {
            $header = trim($jsonH['msgheaders'][0]);
        }
    }

    $xml = '<?xml version="1.0"?>' .
           '<mainbody>' .
           '<header>' .
           '<usercode>' . htmlspecialchars((string)($netgsm['usercode'] ?? '')) . '</usercode>' .
           '<password>' . htmlspecialchars((string)($netgsm['password'] ?? '')) . '</password>' .
           '<msgheader>' . htmlspecialchars($header) . '</msgheader>' .
           '</header>' .
           '<body>' .
           '<msg><![CDATA[' . $message . ']]></msg>' .
           '<no>' . $rawPhone . '</no>' .
           '</body>' .
           '</mainbody>';

    $endpoint = !empty($netgsm['endpoint']) && str_starts_with($netgsm['endpoint'], 'https://')
        ? $netgsm['endpoint']
        : 'https://api.netgsm.com.tr/sms/send/otp';

    $ch = curl_init($endpoint);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $xml);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: text/xml; charset=UTF-8']);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 8);
    $res = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $code = null;
    $jobid = null;
    $error = null;
    if (preg_match('/<code>(.*?)<\/code>/i', (string)$res, $m)) {
        $code = trim($m[1]);
    }
    if (preg_match('/<jobid>(.*?)<\/jobid>/i', (string)$res, $m)) {
        $jobid = trim($m[1]);
    }
    if (preg_match('/<error>(.*?)<\/error>/i', (string)$res, $m)) {
        $error = trim($m[1]);
    }

    $isSuccess = ($code === '00' || $code === '0');

    return [
        'success' => $isSuccess,
        'provider' => 'NETGSM OTP API (Canlı Entegrasyon)',
        'http_code' => $httpCode,
        'netgsm_code' => $code,
        'jobid' => $jobid,
        'message' => $isSuccess ? 'SMS başarıyla gönderildi.' : ($error ?: "Netgsm Hata Kodu: {$code}"),
        'raw_response' => $res
    ];
}

function sendSmsViaActiveProvider($phone, $message, $pdo) {
    $ttSettings = $pdo->query("SELECT * FROM tt_sms_settings WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    $activeProvider = $ttSettings['active_provider'] ?? 'TURK_TELEKOM';

    if ($activeProvider === 'NETGSM') {
        $netgsm = $pdo->query("SELECT * FROM netgsm_settings WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
        if ($netgsm) {
            $res = sendNetgsmSms($phone, $message, $netgsm);
            if ($res['success']) {
                return $res;
            }
        }
        if (!empty($ttSettings['username']) && !empty($ttSettings['password'])) {
            $resTT = sendTurkTelekomSms($phone, $message, $ttSettings);
            if ($resTT['success']) {
                return $resTT;
            }
        }
        return $res ?? ['success' => false, 'provider' => 'NETGSM', 'message' => 'NETGSM ile gönderilemedi.'];
    }

    $ttError = null;
    if ($activeProvider === 'TURK_TELEKOM' || !$activeProvider) {
        error_log('SMS dispatch attempting provider: TURK_TELEKOM');
        $res = sendTurkTelekomSms($phone, $message, $ttSettings);
        if ($res['success']) {
            return $res;
        }
        $ttError = $res;
    }

    // NETGSM Eklentisi (Yedek / Fallback Sağlayıcı)
    $netgsm = $pdo->query("SELECT * FROM netgsm_settings WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    if ($netgsm) {
        error_log('SMS dispatch falling back to provider: NETGSM');
        $netRes = sendNetgsmSms($phone, $message, $netgsm);
        if ($netRes['success']) {
            return $netRes;
        }
        if ($ttError !== null) {
            $netRes['message'] = ($ttError['message'] ?? 'Türk Telekom hatası') . ' | Yedek: ' . ($netRes['message'] ?? 'NETGSM hatası');
        }
        return $netRes;
    }

    if ($ttError !== null) {
        return $ttError;
    }

    return [
        'success' => false,
        'provider' => 'Yapılandırılmamış',
        'message' => 'Etkin bir SMS sağlayıcısı bulunamadı.'
    ];
}

function featureFlagDefaults() {
    return [
        'sanal_market' => false,
        'bayi_stok' => true,
        'temapuan' => true,
        'api_entegrasyon' => false,
        'sms_gonderim' => false,
        'kampanyalar' => true,
        'sanal_pos' => false,
        'soft_pos' => false,
        'e_fatura' => false,
        'serbest_kurye' => false,
    ];
}

function featureCapabilities($pdo) {
    $tt = $pdo->query("SELECT username, password, login_password, is_active FROM tt_sms_settings WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    $netgsm = $pdo->query("SELECT usercode, password, msgheader, is_active FROM netgsm_settings WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    $smsReady = ($tt
            && trim((string)($tt['username'] ?? '')) !== ''
            && trim((string)($tt['password'] ?? '')) !== ''
            && trim((string)($tt['login_password'] ?? '')) !== '')
        || ($netgsm
            && trim((string)($netgsm['usercode'] ?? '')) !== ''
            && trim((string)($netgsm['password'] ?? '')) !== ''
            && trim((string)($netgsm['msgheader'] ?? '')) !== '');

    return [
        'sanal_market' => ['available' => true, 'reason' => 'Ürün, sepet ve sipariş akışı kullanıma hazır.'],
        'bayi_stok' => ['available' => true, 'reason' => 'Şube bazlı stok yönetimi kullanıma hazır.'],
        'temapuan' => ['available' => true, 'reason' => 'Puan kazanım ve hareket sistemi kullanıma hazır.'],
        'api_entegrasyon' => ['available' => false, 'reason' => 'Harici API sağlayıcısı ve erişim bilgileri henüz tanımlanmadı.'],
        'sms_gonderim' => [
            'available' => $smsReady,
            'reason' => $smsReady ? 'Etkin SMS sağlayıcısı bulundu.' : 'Türk Telekom veya Netgsm sağlayıcı bilgileri yapılandırılmalı.',
        ],
        'kampanyalar' => ['available' => true, 'reason' => 'Kampanya yayınlama sistemi kullanıma hazır.'],
        'sanal_pos' => ['available' => false, 'reason' => 'Sanal POS sözleşmesi, anahtarları ve ödeme bildirim doğrulaması gerekiyor.'],
        'soft_pos' => ['available' => false, 'reason' => 'SoftPOS sağlayıcısı ve cihaz entegrasyonu gerekiyor.'],
        'e_fatura' => ['available' => false, 'reason' => 'E-fatura özel entegratörü ve mali mühür yapılandırması gerekiyor.'],
        'serbest_kurye' => ['available' => true, 'reason' => 'Kurye başvuru ve yönetici onay akışı kullanıma hazır.'],
    ];
}

function readFeatureFlags($pdo, $capabilities = null) {
    $stmt = $pdo->query("SELECT flags_json FROM feature_flags WHERE id = 1");
    $stored = json_decode((string)$stmt->fetchColumn(), true);
    $flags = array_merge(featureFlagDefaults(), is_array($stored) ? $stored : []);
    $capabilities = $capabilities ?? featureCapabilities($pdo);
    foreach ($flags as $key => $value) {
        $flags[$key] = (bool)$value && (($capabilities[$key]['available'] ?? false) === true);
    }
    return $flags;
}

function requireFeatureEnabled($pdo, $key, $message) {
    if (!(readFeatureFlags($pdo)[$key] ?? false)) {
        jsonResponse(['success' => false, 'message' => $message, 'feature' => $key], 503);
    }
}

$routeKey = $method . ' ' . $uri;
$authUser = currentApiUser($pdo);

$superAdminRoutes = [
    'POST /api/categories/add',
    'POST /api/categories/update',
    'POST /api/categories/delete',
    'POST /api/admin/brochures/add',
    'POST /api/admin/brochures/delete',
    'POST /api/admin/send-sms',
    'GET /api/admin/sms-logs',
    'POST /api/loyalty/rules',
    'PUT /api/loyalty/rules',
    'POST /api/campaigns/add',
    'POST /api/campaigns/toggle',
    'POST /api/feature-flags',
    'POST /api/customer/award-points',
    'GET /api/dashboard/metrics',
];
$staffRoutes = [
    'GET /api/orders',
    'GET /api/customer/lookup',
    'POST /api/orders/update-status',
];
$merchantRoutes = [
    'GET /api/couriers',
    'POST /api/orders/assign-courier',
    'POST /api/products/add',
    'POST /api/products/update',
    'POST /api/products/update-stock',
    'POST /api/products/delete',
];
$authenticatedRoutes = [
    'POST /api/auth/logout',
    'GET /api/auth/me',
    'GET /api/loyalty/points',
    'POST /api/orders',
    'POST /api/orders/create',
    'GET /api/user/profile',
    'POST /api/user/profile',
    'POST /api/user/profile/update',
    'GET /api/user/addresses',
    'POST /api/user/addresses/add',
    'POST /api/user/addresses/delete',
    'GET /api/user/orders',
    'POST /api/user/account/delete',
];

if (str_starts_with($uri, '/api/admin/') || str_starts_with($uri, '/api/settings/') || in_array($routeKey, $superAdminRoutes, true)) {
    $authUser = requireAuth($pdo, ['SuperAdmin']);
} elseif (in_array($routeKey, $staffRoutes, true)) {
    $authUser = requireAuth($pdo, ['SuperAdmin', 'Merchant', 'Courier']);
} elseif (in_array($routeKey, $merchantRoutes, true)) {
    $authUser = requireAuth($pdo, ['SuperAdmin', 'Merchant']);
} elseif (in_array($routeKey, $authenticatedRoutes, true)) {
    $authUser = requireAuth($pdo);
} elseif (preg_match('#^/api/orders/\d+/status$#', $uri) && $method === 'PATCH') {
    $authUser = requireAuth($pdo, ['SuperAdmin', 'Merchant', 'Courier']);
}

if ($uri === '/api/health' && $method === 'GET') {
    jsonResponse([
        'success' => true,
        'status' => 'OK',
        'service' => 'TEMASAN Core Backend Engine',
    ]);
}

if ($uri === '/api/auth/logout' && $method === 'POST') {
    revokeCurrentApiToken($pdo);
    jsonResponse(['success' => true, 'message' => 'Oturum kapatıldı.']);
}

if ($uri === '/api/user/account/delete' && $method === 'POST') {
    if (($authUser['role'] ?? '') !== 'Customer') {
        jsonResponse([
            'success' => false,
            'message' => 'Personel hesapları uygulama içinden silinemez.',
        ], 403);
    }

    $input = getJsonInput();
    if (!hash_equals('DELETE_ACCOUNT', (string)($input['confirmation'] ?? ''))) {
        jsonResponse([
            'success' => false,
            'message' => 'Hesap silme onayı geçersiz.',
        ], 422);
    }

    $userId = (int)$authUser['id'];
    $phone = (string)$authUser['phone'];
    $anonymousPhone = 'deleted:' . substr(bin2hex(random_bytes(16)), 0, 24);

    try {
        $pdo->beginTransaction();

        // Yasal/ticari kayıt niteliğindeki siparişler tutulur; müşteriyi
        // tanımlayan alanlar geri döndürülemeyecek biçimde anonimleştirilir.
        $stmt = $pdo->prepare(
            "UPDATE orders
             SET customer_name = 'Silinmiş hesap', phone = ?,
                 delivery_address = 'Kullanıcı talebiyle silindi.'
             WHERE phone = ?"
        );
        $stmt->execute([$anonymousPhone, $phone]);

        $pdo->prepare('DELETE FROM addresses WHERE phone = ?')->execute([$phone]);
        $pdo->prepare('DELETE FROM loyalty_points WHERE phone = ?')->execute([$phone]);
        $pdo->prepare('DELETE FROM campaigns WHERE target_phone = ?')->execute([$phone]);
        $pdo->prepare(
            "UPDATE sms_logs
             SET target_phone = NULL, target_type = 'Silinmiş müşteri'
             WHERE target_phone = ?"
        )->execute([$phone]);
        $pdo->prepare('DELETE FROM api_tokens WHERE user_id = ?')->execute([$userId]);
        $pdo->prepare("DELETE FROM users WHERE id = ? AND role = 'Customer'")->execute([$userId]);

        $pdo->commit();
        jsonResponse([
            'success' => true,
            'message' => 'Hesabınız ve kişisel bilgileriniz silindi.',
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        error_log('Account deletion failed: ' . $e->getMessage());
        jsonResponse([
            'success' => false,
            'message' => 'Hesap şu anda silinemedi. Lütfen tekrar deneyin.',
        ], 500);
    }
}

if ($uri === '/api/feature-flags' && $method === 'GET') {
    $capabilities = featureCapabilities($pdo);
    jsonResponse([
        'success' => true,
        'flags' => readFeatureFlags($pdo, $capabilities),
        'capabilities' => $capabilities,
    ]);
}

if ($uri === '/api/feature-flags' && $method === 'POST') {
    $input = getJsonInput();
    $flags = $input['flags'] ?? null;
    if (!is_array($flags)) {
        jsonResponse(['success' => false, 'message' => 'Özellik bayrakları geçersiz.'], 422);
    }
    $allowedFlagKeys = array_keys(featureFlagDefaults());
    $unknownKeys = array_diff(array_keys($flags), $allowedFlagKeys);
    if ($unknownKeys) {
        jsonResponse(['success' => false, 'message' => 'Bilinmeyen özellik anahtarı gönderildi.'], 422);
    }
    $capabilities = featureCapabilities($pdo);
    $cleanFlags = readFeatureFlags($pdo, $capabilities);
    $blocked = [];
    foreach ($allowedFlagKeys as $key) {
        if (!array_key_exists($key, $flags)) continue;
        $requested = filter_var($flags[$key], FILTER_VALIDATE_BOOL);
        if ($requested && (($capabilities[$key]['available'] ?? false) !== true)) {
            $blocked[$key] = $capabilities[$key]['reason'] ?? 'Bu özellik henüz kullanıma hazır değil.';
            continue;
        }
        $cleanFlags[$key] = $requested;
    }
    if ($blocked) {
        jsonResponse([
            'success' => false,
            'message' => 'Hazır olmayan özellikler açılamaz.',
            'blocked' => $blocked,
            'flags' => $cleanFlags,
            'capabilities' => $capabilities,
        ], 422);
    }
    $stmt = $pdo->prepare("UPDATE feature_flags SET flags_json = ?, updated_at = CURRENT_TIMESTAMP WHERE id = 1");
    $stmt->execute([json_encode($cleanFlags, JSON_UNESCAPED_UNICODE)]);
    jsonResponse(['success' => true, 'flags' => $cleanFlags, 'capabilities' => $capabilities]);
}

$featureProtectedRoutes = [
    'POST /api/orders' => ['sanal_market', 'Sanal market şu anda siparişe kapalı.'],
    'POST /api/orders/create' => ['sanal_market', 'Sanal market şu anda siparişe kapalı.'],
    'POST /api/products/add' => ['bayi_stok', 'Bayi stok yönetimi şu anda kapalı.'],
    'POST /api/products/update' => ['bayi_stok', 'Bayi stok yönetimi şu anda kapalı.'],
    'POST /api/products/update-stock' => ['bayi_stok', 'Bayi stok yönetimi şu anda kapalı.'],
    'POST /api/admin/send-sms' => ['sms_gonderim', 'Toplu SMS gönderimi şu anda kapalı veya sağlayıcı hazır değil.'],
    'GET /api/loyalty/points' => ['temapuan', 'TemaPuan sistemi şu anda kapalı.'],
    'GET /api/loyalty/rules' => ['temapuan', 'TemaPuan sistemi şu anda kapalı.'],
    'POST /api/loyalty/rules' => ['temapuan', 'TemaPuan sistemi şu anda kapalı.'],
    'PUT /api/loyalty/rules' => ['temapuan', 'TemaPuan sistemi şu anda kapalı.'],
    'POST /api/customer/award-points' => ['temapuan', 'TemaPuan sistemi şu anda kapalı.'],
];
if (isset($featureProtectedRoutes[$routeKey])) {
    requireFeatureEnabled($pdo, $featureProtectedRoutes[$routeKey][0], $featureProtectedRoutes[$routeKey][1]);
}

if ($uri === '/api/branches' && $method === 'GET') {
    $stmt = $pdo->query("SELECT id, code, name, city_district, address, phone, is_active FROM branches WHERE is_active = 1 ORDER BY id ASC");
    jsonResponse(['success' => true, 'data' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
}

// 1. TÜRK TELEKOM REST API İLE OTP GÖNDERME
if ($uri === '/api/auth/send-otp' && $method === 'POST') {
    $input = getJsonInput();
    $fullPhone = normalizeTurkishPhone((string)($input['phone'] ?? ''));
    if ($fullPhone === null) {
        jsonResponse(['success' => false, 'message' => 'Geçerli bir Türkiye cep telefonu numarası girin.'], 422);
    }
    $rawPhone = substr($fullPhone, 3);
    $requestedRole = $input['role'] ?? 'Customer';
    if (!in_array($requestedRole, ['Customer', 'Merchant', 'Courier', 'SuperAdmin'], true)) {
        jsonResponse(['success' => false, 'message' => 'Geçersiz hesap türü.'], 422);
    }

    $stmt = $pdo->prepare("SELECT * FROM users WHERE phone = ?");
    $stmt->execute([$fullPhone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user && $requestedRole !== 'Customer') {
        jsonResponse(['success' => false, 'message' => 'Bu hesap türü için kayıtlı ve onaylı kullanıcı bulunamadı.'], 403);
    }
    if ($user && $user['role'] !== $requestedRole && $user['role'] !== 'SuperAdmin') {
        jsonResponse(['success' => false, 'message' => 'Seçilen hesap türü bu kullanıcıyla eşleşmiyor.'], 403);
    }

    if (!$user) {
        if (($input['privacy_acknowledged'] ?? false) !== true) {
            jsonResponse(['success' => false, 'message' => 'Aydınlatma metnini okuyup onaylamanız gerekiyor.'], 422);
        }
        $smsConsent = ($input['sms_consent'] ?? false) === true ? 1 : 0;
        $stmt = $pdo->prepare("INSERT INTO users (phone, role, name, status, sms_consent, push_consent, kvkk_consent) VALUES (?, 'Customer', 'Müşteri', 'AKTIF', ?, 0, 0)");
        $stmt->execute([$fullPhone, $smsConsent]);
        $stmt = $pdo->prepare("SELECT * FROM users WHERE phone = ?");
        $stmt->execute([$fullPhone]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
    }

    if (($user['status'] ?? '') === 'ONAY_BEKLIYOR') {
        jsonResponse(['success' => false, 'message' => 'Başvurunuz yönetici onayındadır.'], 403);
    }
    if (($user['status'] ?? '') !== 'AKTIF') {
        jsonResponse(['success' => false, 'message' => 'Hesabınız girişe açık değil.'], 403);
    }

    $clientIp = substr(trim((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown')), 0, 64);
    $ipWindow = date('Y-m-d H:i:s', time() - 600);
    $ipStmt = $pdo->prepare("SELECT COUNT(*) FROM otp_rate_limits WHERE ip_address = ? AND created_at >= ?");
    $ipStmt->execute([$clientIp, $ipWindow]);
    if ((int)$ipStmt->fetchColumn() >= 5) {
        jsonResponse(['success' => false, 'message' => 'Çok fazla doğrulama kodu isteği. Lütfen 10 dakika sonra tekrar deneyin.'], 429);
    }

    $phoneWindow = date('Y-m-d H:i:s', time() - 3600);
    $phoneRateStmt = $pdo->prepare("SELECT COUNT(*) FROM otp_rate_limits WHERE phone = ? AND created_at >= ?");
    $phoneRateStmt->execute([$fullPhone, $phoneWindow]);
    if ((int)$phoneRateStmt->fetchColumn() >= 5) {
        jsonResponse(['success' => false, 'message' => 'Bu numara için saatlik kod limiti aşıldı. Lütfen daha sonra tekrar deneyin.'], 429);
    }

    $lastSentAt = $user['otp_last_sent_at'] ?? null;
    if ($lastSentAt && strtotime((string)$lastSentAt) > time() - 60) {
        jsonResponse(['success' => false, 'message' => 'Yeni kod istemeden önce 60 saniye bekleyin.'], 429);
    }

    $pdo->prepare("INSERT INTO otp_rate_limits (ip_address, phone) VALUES (?, ?)")->execute([$clientIp, $fullPhone]);

    $reviewCode = appReviewOtpFor($fullPhone, $requestedRole);
    $code = $reviewCode ?? (string) random_int(100000, 999999);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+3 minutes'));
    $smsMsg = "TEMASAN Market Dogrulama Kodunuz: {$code}";

    $stmt = $pdo->prepare("UPDATE users SET otp_code = ?, otp_expires_at = ?, otp_attempts = 0, otp_last_sent_at = CURRENT_TIMESTAMP WHERE phone = ?");
    $stmt->execute([password_hash($code, PASSWORD_DEFAULT), $expiresAt, $fullPhone]);

    if ($reviewCode === null) {
        $smsResult = sendSmsViaActiveProvider($rawPhone, $smsMsg, $pdo);
        if (($smsResult['success'] ?? false) !== true) {
            $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_last_sent_at = NULL WHERE phone = ?")
                ->execute([$fullPhone]);
            $errDetail = $smsResult['message'] ?? 'Lütfen daha sonra tekrar deneyin.';
            error_log('OTP SMS delivery failed: ' . $errDetail);
            jsonResponse([
                'success' => false,
                'message' => "Doğrulama SMS’i gönderilemedi ({$errDetail}).",
                'provider_error' => $errDetail,
                'provider_code' => $smsResult['netgsm_code'] ?? null
            ], 503);
        }
    }

    jsonResponse([
        'success' => true,
        'message' => $reviewCode === null
            ? 'Doğrulama kodu telefonunuza gönderildi.'
            : 'App Review doğrulama kodu kullanıma hazır.',
        'phone' => $fullPhone,
    ]);
}

// 2. KATEGORİ MANAJMANI (GET, ADD, UPDATE, DELETE)
if ($uri === '/api/categories' && $method === 'GET') {
    $stmt = $pdo->query("SELECT * FROM categories WHERE is_active = 1 ORDER BY sort_order ASC, id ASC");
    $categories = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $categories]);
    exit;
}

if ($uri === '/api/categories/add' && $method === 'POST') {
    $input = getJsonInput();
    $name = trim($input['name'] ?? '');
    $subBrand = trim($input['sub_brand'] ?? 'Kasap');
    $icon = trim($input['icon'] ?? '🛍️');
    $sortOrder = intval($input['sort_order'] ?? 0);

    if ($name === '' || $subBrand === '' || strlen($name) > 255 || $sortOrder < 0) {
        jsonResponse(['success' => false, 'message' => 'Kategori bilgileri geçersiz.'], 422);
    }

    $stmt = $pdo->prepare("INSERT INTO categories (name, sub_brand, icon, sort_order, is_active) VALUES (?, ?, ?, ?, 1)");
    $stmt->execute([$name, $subBrand, $icon, $sortOrder]);

    echo json_encode(['success' => true, 'message' => 'Yeni kategori başarıyla eklendi.']);
    exit;
}

if ($uri === '/api/categories/update' && $method === 'POST') {
    $input = getJsonInput();
    $id = intval($input['id'] ?? 0);
    $name = trim($input['name'] ?? '');
    $subBrand = trim($input['sub_brand'] ?? 'Kasap');
    $icon = trim($input['icon'] ?? '🛍️');

    if ($id <= 0 || $name === '' || $subBrand === '' || strlen($name) > 255) {
        jsonResponse(['success' => false, 'message' => 'Kategori bilgileri geçersiz.'], 422);
    }

    $stmt = $pdo->prepare("UPDATE categories SET name = ?, sub_brand = ?, icon = ? WHERE id = ?");
    $stmt->execute([$name, $subBrand, $icon, $id]);

    echo json_encode(['success' => true, 'message' => 'Kategori güncellendi.']);
    exit;
}

if ($uri === '/api/categories/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = intval($input['id'] ?? 0);

    $stmt = $pdo->prepare("UPDATE categories SET is_active = 0 WHERE id = ?");
    $stmt->execute([$id]);

    echo json_encode(['success' => true, 'message' => 'Kategori yayından kaldırıldı.']);
    exit;
}

// BROŞÜRLER & AKTÜEL İNSERTLER API
if ($uri === '/api/brochures' && $method === 'GET') {
    $stmt = $pdo->query("SELECT * FROM brochures WHERE is_active = 1 ORDER BY id DESC");
    $brochures = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $brochures]);
    exit;
}

if ($uri === '/api/admin/brochures/add' && $method === 'POST') {
    $input = getJsonInput();
    $title = trim($input['title'] ?? '');
    $description = trim($input['description'] ?? '');
    $imageUrl = trim($input['image_url'] ?? '');
    $pdfUrl = trim($input['pdf_url'] ?? '');
    $startDate = trim($input['start_date'] ?? date('Y-m-d'));
    $endDate = trim($input['end_date'] ?? date('Y-m-d', strtotime('+30 days')));

    if (!$title || !$imageUrl) {
        echo json_encode(['success' => false, 'message' => 'Lütfen katalog başlığı ve broşür görselini girin.']);
        exit;
    }

    $stmt = $pdo->prepare("INSERT INTO brochures (title, description, image_url, pdf_url, start_date, end_date, is_active) VALUES (?, ?, ?, ?, ?, ?, 1)");
    $stmt->execute([$title, $description, $imageUrl, $pdfUrl, $startDate, $endDate]);

    echo json_encode(['success' => true, 'message' => 'Yeni Aktüel İndirim Broşürü yayınlandı!']);
    exit;
}

if ($uri === '/api/admin/brochures/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = intval($input['id'] ?? 0);
    $stmt = $pdo->prepare("UPDATE brochures SET is_active = 0 WHERE id = ?");
    $stmt->execute([$id]);
    echo json_encode(['success' => true, 'message' => 'Broşür yayından kaldırıldı.']);
    exit;
}

// MÜŞTERİ PROFİL GÜNCELLEME (DOĞUM TARİHİ, BİLDİRİM VE SMS YASAL İZİNLERİ)
if ($uri === '/api/user/profile/update' && $method === 'POST') {
    $input = getJsonInput();
    $phone = $authUser['phone'];
    $name = array_key_exists('name', $input) ? trim((string)$input['name']) : (string)($authUser['name'] ?? '');
    $email = array_key_exists('email', $input) ? trim((string)$input['email']) : (string)($authUser['email'] ?? '');
    $cityDistrict = array_key_exists('city_district', $input) ? trim((string)$input['city_district']) : (string)($authUser['city_district'] ?? '');
    $birthDate = array_key_exists('birth_date', $input) ? trim((string)$input['birth_date']) : (string)($authUser['birth_date'] ?? '');
    $specialDay = array_key_exists('special_day', $input) ? trim((string)$input['special_day']) : (string)($authUser['special_day'] ?? '');
    $smsConsent = array_key_exists('sms_consent', $input) ? ((bool)$input['sms_consent'] ? 1 : 0) : (int)($authUser['sms_consent'] ?? 0);
    $pushConsent = array_key_exists('push_consent', $input) ? ((bool)$input['push_consent'] ? 1 : 0) : (int)($authUser['push_consent'] ?? 0);
    $kvkkConsent = (int)($authUser['kvkk_consent'] ?? 0);
    $discountPreferences = json_decode((string)($authUser['discount_preferences'] ?? '[]'), true);
    if (!is_array($discountPreferences)) {
        $discountPreferences = [];
    }

    if (array_key_exists('discount_preferences', $input)) {
        if (!is_array($input['discount_preferences'])) {
            jsonResponse(['success' => false, 'message' => 'İndirim tercihleri geçersiz.'], 422);
        }
        $discountPreferences = [];
        foreach ($input['discount_preferences'] as $preference) {
            if (!is_string($preference)) {
                jsonResponse(['success' => false, 'message' => 'İndirim tercihleri geçersiz.'], 422);
            }
            $preference = trim($preference);
            if ($preference === '' || strlen($preference) > 100) {
                continue;
            }
            $discountPreferences[$preference] = $preference;
        }
        $discountPreferences = array_slice(array_values($discountPreferences), 0, 12);
    }
    $discountPreferencesJson = json_encode($discountPreferences, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        jsonResponse(['success' => false, 'message' => 'E-posta adresi geçersiz.'], 422);
    }

    $userBarcode = preg_replace('/[^0-9]/', '', $phone);

    $stmt = $pdo->prepare("UPDATE users SET name = ?, email = ?, city_district = ?, birth_date = ?, special_day = ?, sms_consent = ?, push_consent = ?, kvkk_consent = ?, user_barcode = ?, discount_preferences = ? WHERE phone = ?");
    $stmt->execute([$name, $email, $cityDistrict, $birthDate, $specialDay, $smsConsent, $pushConsent, $kvkkConsent, $userBarcode, $discountPreferencesJson, $phone]);

    $stmt = $pdo->prepare("SELECT * FROM users WHERE phone = ?");
    $stmt->execute([$phone]);
    $updatedUser = $stmt->fetch(PDO::FETCH_ASSOC);

    jsonResponse([
        'success' => true,
        'message' => 'Profil ve İletişim / Yasal İzin Bilgileriniz Başarıyla Güncellendi.',
        'user' => safeUser($updatedUser ?: [])
    ]);
}

// 3. TOPLU & KİŞİYE ÖZEL SMS / KAMPANYA GÖNDERİMİ (NETGSM ENTEGRASYONLU)
if ($uri === '/api/admin/send-sms' && $method === 'POST') {
    $input = getJsonInput();
    $targetType = $input['target_type'] ?? 'ALL'; // ALL, CUSTOMERS, SINGLE
    $targetPhone = trim($input['target_phone'] ?? '');
    $message = trim($input['message'] ?? '');
    $couponCode = trim($input['coupon_code'] ?? '');

    if (strlen($message) < 5 || strlen($message) > 500 || !in_array($targetType, ['ALL', 'CUSTOMERS', 'SINGLE'], true)) {
        jsonResponse(['success' => false, 'message' => 'SMS hedefi veya içeriği geçersiz.'], 422);
    }

    $recipients = [];
    if ($targetType === 'SINGLE' && $targetPhone !== '') {
        $normalizedTarget = normalizeTurkishPhone($targetPhone);
        if ($normalizedTarget === null) {
            jsonResponse(['success' => false, 'message' => 'Hedef telefon numarası geçersiz.'], 422);
        }
        $stmt = $pdo->prepare("SELECT phone FROM users WHERE phone = ? AND sms_consent = 1 AND status = 'AKTIF'");
        $stmt->execute([$normalizedTarget]);
        $recipients = $stmt->fetchAll(PDO::FETCH_COLUMN);
        $targetPhone = $normalizedTarget;
    } else {
        $stmt = $pdo->query("SELECT phone FROM users WHERE role = 'Customer' AND sms_consent = 1 AND status = 'AKTIF' ORDER BY id LIMIT 500");
        $recipients = $stmt->fetchAll(PDO::FETCH_COLUMN);
    }
    if (!$recipients) {
        jsonResponse(['success' => false, 'message' => 'SMS izni bulunan uygun alıcı yok.'], 422);
    }

    $sentCount = 0;
    $failedCount = 0;
    foreach ($recipients as $recipient) {
        $result = sendSmsViaActiveProvider($recipient, $message, $pdo);
        if (($result['success'] ?? false) === true) {
            $sentCount++;
        } else {
            $failedCount++;
        }
    }

    $stmt = $pdo->prepare("INSERT INTO sms_logs (target_type, target_phone, message, coupon_code, status, sent_count) 
                           VALUES (?, ?, ?, ?, ?, ?)");
    $status = $failedCount === 0 ? 'Başarılı' : ($sentCount > 0 ? 'Kısmi Başarılı' : 'Başarısız');
    $stmt->execute([$targetType, $targetPhone, $message, $couponCode, $status, $sentCount]);

    // Eğer kişiye özel kupon tanımlandıysa kampanyalara da ekle
    if ($sentCount > 0 && $couponCode !== '' && $targetPhone !== '') {
        $stmt = $pdo->prepare("INSERT INTO campaigns (title, badge, code, description, image, bg_gradient, target_phone, is_active) 
                               VALUES (?, 'KİŞİYE ÖZEL İNDİRİM', ?, ?, 'https://images.unsplash.com/photo-1528825871115-3581a5387919?auto=format&fit=crop&w=800&q=80', 'linear-gradient(135deg, #16a34a 0%, #15803d 100%)', ?, 1)");
        $stmt->execute(["Özel İndirim Kuponunuz: {$couponCode}", $couponCode, $message, $targetPhone]);
    }

    jsonResponse([
        'success' => $sentCount > 0,
        'message' => "Gönderilen: {$sentCount}, başarısız: {$failedCount}",
        'sent_count' => $sentCount,
        'failed_count' => $failedCount,
    ], $sentCount > 0 ? 200 : 502);
}

if ($uri === '/api/admin/sms-logs' && $method === 'GET') {
    $stmt = $pdo->query("SELECT * FROM sms_logs ORDER BY id DESC");
    $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $logs]);
    exit;
}

// 4. OTP VERIFY
if ($uri === '/api/auth/verify-otp' && $method === 'POST') {
    $input = getJsonInput();
    $fullPhone = normalizeTurkishPhone((string)($input['phone'] ?? ''));
    $code = trim($input['code'] ?? '');
    if ($fullPhone === null || !preg_match('/^\d{6}$/', $code)) {
        jsonResponse(['success' => false, 'message' => 'Telefon veya doğrulama kodu geçersiz.'], 422);
    }

    $stmt = $pdo->prepare("SELECT * FROM users WHERE phone = ?");
    $stmt->execute([$fullPhone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        jsonResponse(['success' => false, 'message' => 'Kullanıcı bulunamadı.'], 404);
    }

    if (!empty($user['otp_expires_at'])) {
        $exp = strtotime((string)$user['otp_expires_at']);
        if ($exp && $exp <= time()) {
            $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = ?")->execute([$user['id']]);
            jsonResponse(['success' => false, 'message' => 'Doğrulama kodunun süresi doldu.'], 401);
        }
    }

    $attempts = (int)($user['otp_attempts'] ?? 0);
    if ($attempts >= 10) {
        $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = ?")->execute([$user['id']]);
        jsonResponse(['success' => false, 'message' => 'Çok fazla hatalı deneme. Yeni kod isteyin.'], 429);
    }

    $storedCode = (string)($user['otp_code'] ?? '');
    $isCodeValid = false;
    if ($storedCode !== '' && password_verify($code, $storedCode)) {
        $isCodeValid = true;
    }

    if (!$isCodeValid) {
        $pdo->prepare("UPDATE users SET otp_attempts = otp_attempts + 1 WHERE id = ?")->execute([$user['id']]);
        jsonResponse(['success' => false, 'message' => 'Girdiğiniz doğrulama kodu hatalıdır.'], 401);
    }

    if (($user['status'] ?? '') !== 'AKTIF') {
        jsonResponse(['success' => false, 'message' => 'Hesabınız girişe açık değil.'], 403);
    }

    $pdo->prepare("UPDATE users SET otp_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = ?")->execute([$user['id']]);
    $token = issueApiToken($pdo, (int)$user['id']);

    jsonResponse([
        'success' => true,
        'message' => 'Giriş başarılı.',
        'user' => safeUser($user),
        'token' => $token,
    ]);
}

if ($uri === '/api/customer/lookup' && $method === 'GET') {
    $phone = normalizeTurkishPhone((string)($_GET['phone'] ?? ''));
    if ($phone === null) {
        jsonResponse(['success' => false, 'message' => 'Telefon numarası geçersiz.'], 422);
    }
    $stmt = $pdo->prepare("SELECT id, name, phone, status, user_barcode FROM users WHERE phone = ? AND role = 'Customer' LIMIT 1");
    $stmt->execute([$phone]);
    $customer = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$customer) {
        jsonResponse(['success' => false, 'message' => 'Müşteri bulunamadı.'], 404);
    }
    $stmt = $pdo->prepare("SELECT COALESCE(SUM(CASE WHEN type = 'Kazanım' THEN points ELSE -points END), 0) FROM loyalty_points WHERE phone = ?");
    $stmt->execute([$phone]);
    $customer['points'] = max(0, (int)$stmt->fetchColumn());
    jsonResponse(['success' => true, 'data' => $customer]);
}

if ($uri === '/api/customer/award-points' && $method === 'POST') {
    $input = getJsonInput();
    $phone = normalizeTurkishPhone((string)($input['phone'] ?? ''));
    $points = (int)($input['points'] ?? 0);
    $type = (string)($input['type'] ?? '');
    $allowedTypes = ['Kazanım', 'Kullanım', 'İptal', 'Düzeltme'];
    if ($phone === null || $points <= 0 || $points > 100000 || !in_array($type, $allowedTypes, true)) {
        jsonResponse(['success' => false, 'message' => 'Puan işlemi bilgileri geçersiz.'], 422);
    }
    $stmt = $pdo->prepare("SELECT id FROM users WHERE phone = ? AND role = 'Customer'");
    $stmt->execute([$phone]);
    if (!$stmt->fetchColumn()) {
        jsonResponse(['success' => false, 'message' => 'Müşteri bulunamadı.'], 404);
    }
    $description = trim((string)($input['description'] ?? 'Yetkili puan işlemi'));
    $stmt = $pdo->prepare("INSERT INTO loyalty_points (phone, points, type, description) VALUES (?, ?, ?, ?)");
    $stmt->execute([$phone, $points, $type, $description]);
    jsonResponse(['success' => true, 'data' => ['phone' => $phone, 'points' => $points, 'type' => $type]]);
}

// 5. SADAKAT / TEMAPUAN API ENDPOINTLERİ
if ($uri === '/api/loyalty/points' && $method === 'GET') {
    $phone = $authUser['phone'];

    $rule = $pdo->query("SELECT * FROM loyalty_rules WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    $spendPerPoint = floatval($rule['spend_per_point'] ?? 10.0);
    $pointTlValue = floatval($rule['point_tl_value'] ?? 0.10);

    $stmt = $pdo->prepare("SELECT * FROM loyalty_points WHERE phone = ? ORDER BY id DESC");
    $stmt->execute([$phone]);
    $logs = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $totalPoints = 0;
    foreach ($logs as $l) {
        if ($l['type'] === 'Kazanım') {
            $totalPoints += intval($l['points']);
        } else {
            $totalPoints -= intval($l['points']);
        }
    }
    if ($totalPoints < 0) $totalPoints = 0;

    $tlEquiv = $totalPoints * $pointTlValue;

    echo json_encode([
        'success' => true,
        'data' => [
            'total_points' => $totalPoints,
            'tl_equivalent' => $tlEquiv,
            'rules' => $rule,
            'history' => $logs,
        ]
    ]);
    exit;
}

if ($uri === '/api/loyalty/rules' && $method === 'GET') {
    $rule = $pdo->query("SELECT * FROM loyalty_rules WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $rule ?: new stdClass()]);
    exit;
}

if ($uri === '/api/loyalty/rules' && ($method === 'POST' || $method === 'PUT')) {
    $input = getJsonInput();
    $spendPerPoint = floatval($input['spend_per_point'] ?? 10.0);
    $pointTlValue = floatval($input['point_tl_value'] ?? 0.10);
    $minRedeemPoints = intval($input['min_redeem_points'] ?? 50);
    $applicableCategories = trim($input['applicable_categories'] ?? 'Tüm Ürünler');

    if ($spendPerPoint <= 0 || $pointTlValue < 0 || $minRedeemPoints < 0) {
        jsonResponse(['success' => false, 'message' => 'Sadakat kuralı değerleri geçersiz.'], 422);
    }

    $stmt = $pdo->prepare("UPDATE loyalty_rules SET spend_per_point = ?, point_tl_value = ?, min_redeem_points = ?, applicable_categories = ? WHERE id = 1");
    $stmt->execute([$spendPerPoint, $pointTlValue, $minRedeemPoints, $applicableCategories]);

    echo json_encode(['success' => true, 'message' => 'Sadakat puan sistemi kuralları başarıyla güncellendi.']);
    exit;
}

// 6. BAŞVURU REGISTRATION
if ($uri === '/api/auth/register-application' && $method === 'POST') {
    $input = getJsonInput();
    $fullPhone = normalizeTurkishPhone((string)($input['phone'] ?? ''));
    $role = $input['role'] ?? 'Courier';

    if ($role === 'Courier') {
        requireFeatureEnabled($pdo, 'serbest_kurye', 'Serbest kurye başvuruları şu anda kapalı.');
    }

    $name = trim($input['name'] ?? '');
    $companyName = trim($input['company_name'] ?? '');
    $vehicleType = trim($input['vehicle_type'] ?? '');
    $taxNo = trim($input['tax_no'] ?? '');
    $cityDistrict = trim($input['city_district'] ?? '');

    $taxDigits = preg_replace('/\D+/', '', $taxNo) ?? '';
    $roleDetailsValid = $role === 'Courier'
        ? strlen($vehicleType) >= 2
        : (strlen($companyName) >= 2 && in_array(strlen($taxDigits), [10, 11], true));
    if ($fullPhone === null || !in_array($role, ['Courier', 'Merchant'], true) || strlen($name) < 2 || strlen($cityDistrict) < 2 || !$roleDetailsValid) {
        jsonResponse(['success' => false, 'message' => 'Başvuru bilgileri geçersiz.'], 422);
    }
    $stmt = $pdo->prepare("SELECT id FROM users WHERE phone = ?");
    $stmt->execute([$fullPhone]);
    if ($stmt->fetchColumn()) {
        jsonResponse(['success' => false, 'message' => 'Bu telefon numarasıyla daha önce kayıt oluşturulmuş.'], 409);
    }

    $stmt = $pdo->prepare("INSERT INTO users (phone, role, name, company_name, vehicle_type, tax_no, city_district, status, sms_consent, push_consent, kvkk_consent) 
                           VALUES (?, ?, ?, ?, ?, ?, ?, 'ONAY_BEKLIYOR', 0, 0, 0)");
    $stmt->execute([$fullPhone, $role, $name, $companyName, $vehicleType, $taxNo, $cityDistrict]);

    echo json_encode([
        'success' => true,
        'message' => 'Başvurunuz kaydedildi. Yönetici onayından sonra giriş yapabilirsiniz.',
    ]);
    exit;
}

// 7. YÖNETİCİ: METRİKLER
if (($uri === '/api/admin/metrics' || $uri === '/api/dashboard/metrics') && $method === 'GET') {
    $totalUsers = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
    $pendingApps = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE status = 'ONAY_BEKLIYOR'")->fetchColumn();
    $totalOrders = (int)$pdo->query("SELECT COUNT(*) FROM orders")->fetchColumn();
    $totalRevenue = (float)($pdo->query("SELECT SUM(total_amount) FROM orders WHERE status != 'İptal'")->fetchColumn() ?? 0);
    $activeCouriers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'Courier' AND status = 'AKTIF'")->fetchColumn();

    $newOrders = (int)$pdo->query("SELECT COUNT(*) FROM orders WHERE status = 'Hazırlanıyor'")->fetchColumn();
    $inTransitOrders = (int)$pdo->query("SELECT COUNT(*) FROM orders WHERE status = 'Kuryede'")->fetchColumn();
    $deliveredOrders = (int)$pdo->query("SELECT COUNT(*) FROM orders WHERE status = 'Teslim Edildi'")->fetchColumn();
    $cancelledOrders = (int)$pdo->query("SELECT COUNT(*) FROM orders WHERE status = 'İptal'")->fetchColumn();

    $totalProducts = (int)$pdo->query("SELECT COUNT(*) FROM products")->fetchColumn();
    $lowStockProducts = (int)$pdo->query("SELECT COUNT(*) FROM products WHERE stock <= 10")->fetchColumn();
    $regularCustomers = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'Customer'")->fetchColumn();

    jsonResponse([
        'success' => true,
        'data' => [
            'total_users' => $totalUsers,
            'pending_applications' => $pendingApps,
            'total_orders' => $totalOrders,
            'total_revenue' => $totalRevenue,
            'active_couriers' => $activeCouriers,
            'newOrders' => $newOrders,
            'inTransitOrders' => $inTransitOrders,
            'deliveredToday' => $deliveredOrders,
            'cancelledOrders' => $cancelledOrders,
            'totalProducts' => $totalProducts,
            'lowStockProducts' => $lowStockProducts,
            'regularCustomers' => $regularCustomers,
            'netProfit' => round($totalRevenue * 0.18, 2),
        ]
    ]);
}

if ($uri === '/api/admin/users' && $method === 'GET') {
    $stmt = $pdo->query("SELECT id, phone, role, name, email, company_name, vehicle_type, tax_no, city_district, status, branch_id, sms_consent, push_consent, kvkk_consent, created_at FROM users ORDER BY id DESC");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $users]);
    exit;
}

if ($uri === '/api/admin/applications' && $method === 'GET') {
    $stmt = $pdo->query("SELECT id, phone, role, name, email, company_name, vehicle_type, tax_no, city_district, status, branch_id, created_at FROM users WHERE status = 'ONAY_BEKLIYOR' ORDER BY id DESC");
    $applications = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $applications]);
    exit;
}

if ($uri === '/api/admin/approve-application' && $method === 'POST') {
    $input = getJsonInput();
    $userId = $input['user_id'] ?? 0;
    $action = $input['action'] ?? 'APPROVE';
    if ((int)$userId <= 0 || !in_array($action, ['APPROVE', 'REJECT'], true)) {
        jsonResponse(['success' => false, 'message' => 'Başvuru işlemi geçersiz.'], 422);
    }
    $newStatus = $action === 'APPROVE' ? 'AKTIF' : 'REDDEDILDI';

    $stmt = $pdo->prepare("UPDATE users SET status = ? WHERE id = ?");
    $stmt->execute([$newStatus, $userId]);

    echo json_encode(['success' => true, 'message' => "Başvuru '{$newStatus}' yapıldı."]);
    exit;
}

if ($uri === '/api/applications' && $method === 'POST') {
    $input = getJsonInput();
    $type = trim($input['type'] ?? 'general');
    $name = trim($input['name'] ?? '');
    $phone = trim($input['phone'] ?? '');
    $email = trim($input['email'] ?? '');
    $cityDistrict = trim($input['city_district'] ?? ($input['city'] ?? ''));
    $details = is_array($input['details'] ?? null) 
        ? json_encode($input['details'], JSON_UNESCAPED_UNICODE) 
        : trim($input['details'] ?? ($input['message'] ?? ''));

    if ($name === '' || $phone === '') {
        jsonResponse(['success' => false, 'message' => 'Lütfen ad ve telefon numaranızı giriniz.'], 422);
    }

    $stmt = $pdo->prepare("INSERT INTO applications (type, name, phone, email, city_district, details, status) VALUES (?, ?, ?, ?, ?, ?, 'Yeni')");
    $stmt->execute([$type, $name, $phone, $email, $cityDistrict, $details]);
    $appId = $pdo->lastInsertId();

    echo json_encode([
        'success' => true,
        'message' => 'Başvurunuz başarıyla alındı. İncelemenin ardından sizinle iletişime geçilecektir.',
        'data' => ['id' => $appId]
    ]);
    exit;
}

if ($uri === '/api/admin/external-applications' && $method === 'GET') {
    if (($authUser['role'] ?? '') !== 'SuperAdmin') {
        jsonResponse(['success' => false, 'message' => 'Yetkisiz erişim.'], 403);
    }
    $stmt = $pdo->query("SELECT * FROM applications ORDER BY id DESC");
    $apps = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $apps]);
    exit;
}

// 8. SİPARİŞ OLUŞTURMA — fiyat ve stok yalnızca sunucudan hesaplanır
if (($uri === '/api/orders/create' || $uri === '/api/orders') && $method === 'POST') {
    $input = getJsonInput();
    if (($authUser['role'] ?? '') !== 'Customer') {
        jsonResponse(['success' => false, 'message' => 'Siparişi yalnızca müşteri hesabı oluşturabilir.'], 403);
    }

    $branchId = (int)($input['branch_id'] ?? 0);
    $address = trim((string)($input['delivery_address'] ?? ''));
    $rawItems = $input['items'] ?? null;
    $paymentMethod = (string)($input['payment_method'] ?? 'Nakit');
    $idempotencyKey = trim((string)($_SERVER['HTTP_X_IDEMPOTENCY_KEY'] ?? ($input['idempotency_key'] ?? '')));

    if ($branchId <= 0 || strlen($address) < 10 || !is_array($rawItems) || count($rawItems) === 0) {
        jsonResponse(['success' => false, 'message' => 'Şube, teslimat adresi ve ürünler zorunludur.'], 422);
    }
    if (!preg_match('/^[A-Za-z0-9._:-]{16,120}$/', $idempotencyKey)) {
        jsonResponse(['success' => false, 'message' => 'Geçerli bir idempotency anahtarı zorunludur.'], 422);
    }
    if ($paymentMethod !== 'Nakit') {
        jsonResponse(['success' => false, 'message' => 'Doğrulanmamış ödeme yöntemi kullanılamaz.'], 422);
    }

    $stmt = $pdo->prepare("SELECT id FROM branches WHERE id = ? AND is_active = 1");
    $stmt->execute([$branchId]);
    if (!$stmt->fetchColumn()) {
        jsonResponse(['success' => false, 'message' => 'Seçilen şube siparişe açık değil.'], 422);
    }

    try {
        $pdo->beginTransaction();

        $stmt = $pdo->prepare("SELECT id, order_number, total_amount, status FROM orders WHERE idempotency_key = ? AND phone = ? LIMIT 1");
        $stmt->execute([$idempotencyKey, $authUser['phone']]);
        $existingOrder = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($existingOrder) {
            $pdo->commit();
            jsonResponse(['success' => true, 'data' => $existingOrder, 'duplicate' => true]);
        }

        $validatedItems = [];
        $totalAmount = 0.0;
        $isMySql = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME) === 'mysql';
        foreach ($rawItems as $rawItem) {
            if (!is_array($rawItem)) {
                throw new InvalidArgumentException('Ürün satırı geçersiz.');
            }
            $productId = (int)($rawItem['product_id'] ?? 0);
            $quantity = (int)($rawItem['quantity'] ?? 0);
            if ($productId <= 0 || $quantity <= 0 || $quantity > 99) {
                throw new InvalidArgumentException('Ürün adedi geçersiz.');
            }

            $sql = "SELECT id, name, base_price, stock, status, branch_id FROM products WHERE id = ?" . ($isMySql ? ' FOR UPDATE' : '');
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$productId]);
            $product = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$product || ((int)($product['branch_id'] ?? 0) > 0 && (int)$product['branch_id'] !== $branchId)) {
                throw new InvalidArgumentException('Seçilen ürün bu şubede bulunamadı.');
            }
            $effectiveStock = (int)$product['stock'];
            $effectiveStatus = (string)($product['status'] ?? 'Stokta');
            if ($product['branch_id'] === null) {
                $stockSql = "SELECT stock, status FROM branch_product_stocks WHERE branch_id = ? AND product_id = ?" . ($isMySql ? ' FOR UPDATE' : '');
                $stmt = $pdo->prepare($stockSql);
                $stmt->execute([$branchId, $productId]);
                $branchStock = $stmt->fetch(PDO::FETCH_ASSOC);
                if (!$branchStock) {
                    throw new RuntimeException('Şube stok kaydı bulunamadı.');
                }
                $effectiveStock = (int)$branchStock['stock'];
                $effectiveStatus = (string)$branchStock['status'];
            }
            if ($effectiveStock < $quantity || $effectiveStatus === 'Tükendi') {
                throw new InvalidArgumentException($product['name'] . ' için yeterli stok yok.');
            }

            $unitPrice = round((float)$product['base_price'], 2);
            $totalAmount += $unitPrice * $quantity;
            $validatedItems[] = [
                'product_id' => (int)$product['id'],
                'name' => $product['name'],
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
            ];

            if ($product['branch_id'] === null) {
                $stmt = $pdo->prepare("UPDATE branch_product_stocks SET stock = stock - ?, status = CASE WHEN stock - ? <= 0 THEN 'Tükendi' WHEN stock - ? <= 10 THEN 'Kritik Stok' ELSE 'Stokta' END WHERE branch_id = ? AND product_id = ? AND stock >= ?");
                $stmt->execute([$quantity, $quantity, $quantity, $branchId, $productId, $quantity]);
            } else {
                $stmt = $pdo->prepare("UPDATE products SET stock = stock - ?, status = CASE WHEN stock - ? <= 0 THEN 'Tükendi' WHEN stock - ? <= 10 THEN 'Kritik Stok' ELSE 'Stokta' END WHERE id = ? AND stock >= ?");
                $stmt->execute([$quantity, $quantity, $quantity, $productId, $quantity]);
            }
            if ($stmt->rowCount() === 0) {
                throw new InvalidArgumentException($product['name'] . ' için stok eşzamanlı olarak değişti.');
            }
        }

        $orderNumber = 'TMS-' . date('Ymd') . '-' . strtoupper(bin2hex(random_bytes(3)));
        $stmt = $pdo->prepare("INSERT INTO orders (order_number, customer_name, phone, delivery_address, items, total_amount, payment_method, payment_status, status, branch_id, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, 'Bekliyor', 'Alındı', ?, ?)");
        $stmt->execute([
            $orderNumber,
            trim((string)($authUser['name'] ?? 'Müşteri')) ?: 'Müşteri',
            $authUser['phone'],
            $address,
            json_encode($validatedItems, JSON_UNESCAPED_UNICODE),
            round($totalAmount, 2),
            $paymentMethod,
            $branchId,
            $idempotencyKey,
        ]);
        $orderId = (int)$pdo->lastInsertId();
        $pdo->commit();

        jsonResponse([
            'success' => true,
            'message' => 'Siparişiniz alındı.',
            'data' => [
                'id' => $orderId,
                'order_number' => $orderNumber,
                'total_amount' => round($totalAmount, 2),
                'payment_status' => 'Bekliyor',
                'status' => 'Alındı',
            ],
        ], 201);
    } catch (InvalidArgumentException $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        jsonResponse(['success' => false, 'message' => $e->getMessage()], 422);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        error_log('Order creation failed: ' . $e->getMessage());
        jsonResponse(['success' => false, 'message' => 'Sipariş oluşturulamadı.'], 500);
    }
}

if ($uri === '/api/products/add' && $method === 'POST') {
    $input = getJsonInput();
    $name = trim($input['name'] ?? '');
    $category = trim($input['category'] ?? 'Et & Tavuk');
    $subBrand = trim($input['sub_brand'] ?? 'Kasap');
    $barcode = trim($input['barcode'] ?? ('869' . random_int(100000000, 999999999)));
    $basePrice = floatval($input['base_price'] ?? 0);
    $originalPrice = floatval($input['original_price'] ?? 0);
    $stock = intval($input['stock'] ?? 0);
    $unit = trim($input['unit'] ?? 'Adet');
    $image = trim($input['image'] ?? 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80');
    $branchId = $authUser['role'] === 'Merchant'
        ? (int)($authUser['branch_id'] ?? 0)
        : (int)($input['branch_id'] ?? 0);

    if ($name === '' || $category === '' || $subBrand === '' || $basePrice <= 0 || $stock < 0 || ($authUser['role'] === 'Merchant' && $branchId <= 0)) {
        jsonResponse(['success' => false, 'message' => 'Ürün bilgileri veya şube ataması geçersiz.'], 422);
    }

    $status = $stock <= 0 ? 'Tükendi' : ($stock <= 10 ? 'Kritik Stok' : 'Stokta');

    $stmt = $pdo->prepare("INSERT INTO products (name, category, sub_brand, barcode, base_price, original_price, stock, status, image, unit, branch_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([$name, $category, $subBrand, $barcode, $basePrice, $originalPrice, $stock, $status, $image, $unit, $branchId > 0 ? $branchId : null]);

    echo json_encode(['success' => true, 'message' => 'Yeni ürün katoloğa eklendi.']);
    exit;
}

if ($uri === '/api/products/update' && $method === 'POST') {
    $input = getJsonInput();
    $id = $input['id'] ?? 0;
    $name = trim($input['name'] ?? '');
    $basePrice = floatval($input['base_price'] ?? 0);
    $stock = intval($input['stock'] ?? 0);
    $status = $stock <= 0 ? 'Tükendi' : ($stock <= 10 ? 'Kritik Stok' : 'Stokta');

    if ((int)$id <= 0 || $name === '' || $basePrice <= 0 || $stock < 0) {
        jsonResponse(['success' => false, 'message' => 'Ürün bilgileri geçersiz.'], 422);
    }

    $sql = "UPDATE products SET name = ?, base_price = ?, stock = ?, status = ? WHERE id = ?";
    $params = [$name, $basePrice, $stock, $status, $id];
    if ($authUser['role'] === 'Merchant') {
        $sql .= ' AND branch_id = ?';
        $params[] = (int)($authUser['branch_id'] ?? 0);
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    if ($stmt->rowCount() === 0) {
        jsonResponse(['success' => false, 'message' => 'Ürün bulunamadı veya bu şubeye ait değil.'], 404);
    }

    echo json_encode(['success' => true, 'message' => 'Ürün fiyat ve stok bilgisi güncellendi.']);
    exit;
}

if ($uri === '/api/products/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) {
        jsonResponse(['success' => false, 'message' => 'Geçersiz ürün ID.'], 422);
    }
    $sql = "DELETE FROM products WHERE id = ?";
    $params = [$id];
    if ($authUser['role'] === 'Merchant') {
        $sql .= ' AND branch_id = ?';
        $params[] = (int)($authUser['branch_id'] ?? 0);
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    jsonResponse(['success' => true, 'message' => 'Ürün başarıyla silindi.']);
}

if ($uri === '/api/campaigns/add' && $method === 'POST') {
    $input = getJsonInput();
    $title = trim($input['title'] ?? '');
    $badge = trim($input['badge'] ?? 'ÖZEL KAMPANYA');
    $code = trim($input['code'] ?? 'TEMA100');
    $description = trim($input['description'] ?? '');
    $image = trim($input['image'] ?? 'https://images.unsplash.com/photo-1528825871115-3581a5387919?auto=format&fit=crop&w=800&q=80');
    $bgGradient = trim($input['bg_gradient'] ?? 'linear-gradient(135deg, #dc2626 0%, #991b1b 100%)');
    $targetPhone = trim($input['target_phone'] ?? '');

    if ($title === '' || $description === '' || ($targetPhone !== '' && normalizeTurkishPhone($targetPhone) === null)) {
        jsonResponse(['success' => false, 'message' => 'Kampanya bilgileri geçersiz.'], 422);
    }
    if ($targetPhone !== '') {
        $targetPhone = normalizeTurkishPhone($targetPhone);
    }

    $stmt = $pdo->prepare("INSERT INTO campaigns (title, badge, code, description, image, bg_gradient, target_phone, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, 1)");
    $stmt->execute([$title, $badge, $code, $description, $image, $bgGradient, $targetPhone]);

    echo json_encode(['success' => true, 'message' => 'Yeni kampanya afişi yayınlandı.']);
    exit;
}

if ($uri === '/api/campaigns/toggle' && $method === 'POST') {
    $input = getJsonInput();
    $id = $input['id'] ?? 0;
    $isActive = intval($input['is_active'] ?? 1);

    $stmt = $pdo->prepare("UPDATE campaigns SET is_active = ? WHERE id = ?");
    $stmt->execute([$isActive, $id]);

    echo json_encode(['success' => true, 'message' => 'Kampanya yayın durumu güncellendi.']);
    exit;
}

if ($uri === '/api/settings/turk-telekom' && $method === 'GET') {
    $tt = $pdo->query("SELECT id, username, origin, brand_code, token_url, sms_url, is_active, active_provider, CASE WHEN password <> '' AND login_password <> '' THEN 1 ELSE 0 END AS credentials_configured FROM tt_sms_settings LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $tt]);
    exit;
}

if ($uri === '/api/settings/turk-telekom' && $method === 'POST') {
    $input = getJsonInput();
    $current = $pdo->query("SELECT * FROM tt_sms_settings WHERE id = 1")->fetch(PDO::FETCH_ASSOC) ?: [];
    $stmt = $pdo->prepare("UPDATE tt_sms_settings SET username = ?, password = ?, login_password = ?, origin = ?, brand_code = ?, active_provider = ? WHERE id = 1");
    $stmt->execute([
        $input['username'] ?? ($current['username'] ?? ''),
        !empty($input['password']) ? $input['password'] : ($current['password'] ?? ''),
        !empty($input['login_password']) ? $input['login_password'] : ($current['login_password'] ?? ''),
        $input['origin'] ?? ($current['origin'] ?? 'TEMA MARKET'),
        $input['brand_code'] ?? ($current['brand_code'] ?? ''),
        $input['active_provider'] ?? ($current['active_provider'] ?? 'TURK_TELEKOM'),
    ]);
    echo json_encode(['success' => true, 'message' => 'Türk Telekom REST SMS veritabanı ayarları güncellendi.']);
    exit;
}

if ($uri === '/api/settings/netgsm' && $method === 'GET') {
    $netgsm = $pdo->query("SELECT id, usercode, msgheader, endpoint, is_active, CASE WHEN password <> '' THEN 1 ELSE 0 END AS credentials_configured FROM netgsm_settings LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $netgsm]);
    exit;
}

if ($uri === '/api/settings/netgsm' && $method === 'POST') {
    $input = getJsonInput();
    $current = $pdo->query("SELECT * FROM netgsm_settings WHERE id = 1")->fetch(PDO::FETCH_ASSOC) ?: [];
    $stmt = $pdo->prepare("UPDATE netgsm_settings SET usercode = ?, password = ?, msgheader = ?, endpoint = ? WHERE id = 1");
    $stmt->execute([
        $input['usercode'] ?? ($current['usercode'] ?? ''),
        !empty($input['password']) ? $input['password'] : ($current['password'] ?? ''),
        $input['msgheader'] ?? ($current['msgheader'] ?? 'TEMASAN'),
        $input['endpoint'] ?? ($current['endpoint'] ?? 'https://api.netgsm.com.tr/sms/send/get'),
    ]);
    echo json_encode(['success' => true, 'message' => 'NETGSM veritabanı ayarları güncellendi.']);
    exit;
}

if ($uri === '/api/settings/pos' && $method === 'GET') {
    $pos = $pdo->query("SELECT id, bank_name, merchant_id, terminal_id, is_test_mode, CASE WHEN api_key <> '' THEN 1 ELSE 0 END AS credentials_configured FROM pos_settings LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $pos]);
    exit;
}

if ($uri === '/api/settings/pos' && $method === 'POST') {
    $input = getJsonInput();
    $current = $pdo->query("SELECT * FROM pos_settings WHERE id = 1")->fetch(PDO::FETCH_ASSOC) ?: [];
    $stmt = $pdo->prepare("UPDATE pos_settings SET bank_name = ?, merchant_id = ?, api_key = ?, terminal_id = ?, is_test_mode = ? WHERE id = 1");
    $stmt->execute([
        $input['bank_name'] ?? ($current['bank_name'] ?? ''),
        $input['merchant_id'] ?? ($current['merchant_id'] ?? ''),
        !empty($input['api_key']) ? $input['api_key'] : ($current['api_key'] ?? ''),
        $input['terminal_id'] ?? ($current['terminal_id'] ?? ''),
        intval($input['is_test_mode'] ?? ($current['is_test_mode'] ?? 0)),
    ]);
    echo json_encode(['success' => true, 'message' => 'Sanal POS ayarları güncellendi.']);
    exit;
}

if ($uri === '/api/settings/efatura' && $method === 'GET') {
    $efatura = $pdo->query("SELECT id, integrator, username, tax_office, tax_number, is_auto_invoice, CASE WHEN password <> '' THEN 1 ELSE 0 END AS credentials_configured FROM efatura_settings LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $efatura]);
    exit;
}

if ($uri === '/api/settings/efatura' && $method === 'POST') {
    $input = getJsonInput();
    $current = $pdo->query("SELECT * FROM efatura_settings WHERE id = 1")->fetch(PDO::FETCH_ASSOC) ?: [];
    $stmt = $pdo->prepare("UPDATE efatura_settings SET integrator = ?, username = ?, password = ?, tax_office = ?, tax_number = ?, is_auto_invoice = ? WHERE id = 1");
    $stmt->execute([
        $input['integrator'] ?? ($current['integrator'] ?? ''),
        $input['username'] ?? ($current['username'] ?? ''),
        !empty($input['password']) ? $input['password'] : ($current['password'] ?? ''),
        $input['tax_office'] ?? ($current['tax_office'] ?? ''),
        $input['tax_number'] ?? ($current['tax_number'] ?? ''),
        intval($input['is_auto_invoice'] ?? ($current['is_auto_invoice'] ?? 0)),
    ]);
    echo json_encode(['success' => true, 'message' => 'E-Fatura ayarları güncellendi.']);
    exit;
}

if ($uri === '/api/campaigns' && $method === 'GET') {
    if (!(readFeatureFlags($pdo)['kampanyalar'] ?? false)) {
        jsonResponse(['success' => true, 'data' => []]);
    }
    $phone = $authUser['phone'] ?? null;
    if ($phone) {
        $stmt = $pdo->prepare("SELECT * FROM campaigns WHERE is_active = 1 AND (target_phone IS NULL OR target_phone = '' OR target_phone = ?) ORDER BY id DESC");
        $stmt->execute([$phone]);
    } else {
        $stmt = $pdo->query("SELECT * FROM campaigns WHERE is_active = 1 AND (target_phone IS NULL OR target_phone = '') ORDER BY id DESC");
    }
    $campaigns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $campaigns]);
    exit;
}

if (($uri === '/api/user/profile' || $uri === '/api/auth/me') && $method === 'GET') {
    $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
    $stmt->execute([$authUser['id']]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    echo json_encode(['success' => true, 'data' => safeUser($user ?: [])]);
    exit;
}

if ($uri === '/api/user/profile' && $method === 'POST') {
    $input = getJsonInput();
    $name = trim($input['name'] ?? '');
    $email = trim($input['email'] ?? '');
    $cityDistrict = trim($input['city_district'] ?? '');

    if ($name === '' || ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL))) {
        jsonResponse(['success' => false, 'message' => 'Profil bilgileri geçersiz.'], 422);
    }

    $stmt = $pdo->prepare("UPDATE users SET name = ?, email = ?, city_district = ? WHERE id = ?");
    $stmt->execute([$name, $email, $cityDistrict, $authUser['id']]);

    echo json_encode(['success' => true, 'message' => 'Profil bilgileri güncellendi.']);
    exit;
}

if ($uri === '/api/user/addresses' && $method === 'GET') {
    $phone = $authUser['phone'];
    $stmt = $pdo->prepare("SELECT * FROM addresses WHERE phone = ? ORDER BY id DESC");
    $stmt->execute([$phone]);
    $addresses = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['success' => true, 'data' => $addresses]);
    exit;
}

if ($uri === '/api/user/addresses/add' && $method === 'POST') {
    $input = getJsonInput();
    $phone = $authUser['phone'];
    $title = trim($input['title'] ?? 'Ev');
    $address = trim($input['address'] ?? '');
    $cityDistrict = trim($input['city_district'] ?? 'Erzurum / Aziziye');

    if (strlen($address) < 10) {
        jsonResponse(['success' => false, 'message' => 'Teslimat adresi çok kısa.'], 422);
    }

    $stmt = $pdo->prepare("INSERT INTO addresses (phone, title, address, city_district) VALUES (?, ?, ?, ?)");
    $stmt->execute([$phone, $title, $address, $cityDistrict]);
    $newAddressId = (int)$pdo->lastInsertId();

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Adres kaydedildi.',
        'data' => [
            'id' => $newAddressId,
            'title' => $title,
            'address' => $address,
            'city_district' => $cityDistrict,
            'is_default' => 0
        ]
    ]);
    exit;
}

if ($uri === '/api/user/addresses/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = $input['id'] ?? 0;
    $phone = $authUser['phone'];

    $stmt = $pdo->prepare("DELETE FROM addresses WHERE id = ? AND phone = ?");
    $stmt->execute([$id, $phone]);

    echo json_encode(['success' => true, 'message' => 'Adres silindi.']);
    exit;
}

if ($uri === '/api/user/orders' && $method === 'GET') {
    $phone = $authUser['phone'];
    $stmt = $pdo->prepare("SELECT * FROM orders WHERE phone = ? ORDER BY id DESC");
    $stmt->execute([$phone]);
    $orders = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($orders as &$ord) {
        $ord['items'] = json_decode($ord['items'], true) ?? [];
    }

    echo json_encode(['success' => true, 'data' => $orders]);
    exit;
}

if ($uri === '/api/products' && $method === 'GET') {
    $where = [];
    $params = [];
    $branchId = (int)($_GET['branch_id'] ?? 0);
    $subBrand = trim((string)($_GET['sub_brand'] ?? ''));
    $search = trim((string)($_GET['search'] ?? ''));
    if ($branchId > 0) {
        $sql = "SELECT p.id, p.name, p.category, p.sub_brand, p.barcode, p.base_price, p.original_price,
                       COALESCE(bps.stock, p.stock) AS stock, COALESCE(bps.status, p.status) AS status,
                       p.image, p.unit, p.branch_id
                FROM products p
                LEFT JOIN branch_product_stocks bps ON bps.product_id = p.id AND bps.branch_id = ?";
        $params[] = $branchId;
        $where[] = '(p.branch_id IS NULL OR p.branch_id = ?)';
        $params[] = $branchId;
    } else {
        $sql = "SELECT p.id, p.name, p.category, p.sub_brand, p.barcode, p.base_price, p.original_price,
                       p.stock, p.status, p.image, p.unit, p.branch_id FROM products p";
    }
    if ($subBrand !== '') {
        $where[] = 'p.sub_brand = ?';
        $params[] = $subBrand;
    }
    if ($search !== '') {
        $where[] = 'p.name LIKE ?';
        $params[] = '%' . $search . '%';
    }
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY p.id DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $products = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => $products]);
    exit;
}

if ($uri === '/api/orders' && $method === 'GET') {
    $where = [];
    $params = [];
    if ($authUser['role'] === 'Courier') {
        $where[] = 'courier_id = ?';
        $params[] = (int)$authUser['id'];
    } elseif ($authUser['role'] === 'Merchant') {
        $merchantBranchId = (int)($authUser['branch_id'] ?? 0);
        if ($merchantBranchId <= 0) {
            jsonResponse(['success' => false, 'message' => 'Bayi hesabına şube atanmamış.'], 409);
        }
        $where[] = 'branch_id = ?';
        $params[] = $merchantBranchId;
    } elseif ((int)($_GET['branch_id'] ?? 0) > 0) {
        $where[] = 'branch_id = ?';
        $params[] = (int)$_GET['branch_id'];
    }
    $statusFilter = trim((string)($_GET['status'] ?? ''));
    if ($statusFilter !== '') {
        $where[] = 'status = ?';
        $params[] = $statusFilter;
    }

    $sql = 'SELECT * FROM orders';
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= ' ORDER BY id DESC';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $orders = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($orders as &$ord) {
        $ord['items'] = json_decode($ord['items'], true) ?? [];
    }

    echo json_encode(['success' => true, 'data' => $orders]);
    exit;
}

if ($uri === '/api/orders/assign-courier' && $method === 'POST') {
    $input = getJsonInput();
    $orderId = $input['order_id'] ?? 0;
    $courierId = $input['courier_id'] ?? 0;
    $stmt = $pdo->prepare("SELECT id, name, branch_id FROM users WHERE id = ? AND role = 'Courier' AND status = 'AKTIF'");
    $stmt->execute([$courierId]);
    $courier = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$courier) {
        jsonResponse(['success' => false, 'message' => 'Aktif kurye bulunamadı.'], 404);
    }
    if ($authUser['role'] === 'Merchant' && (int)$authUser['branch_id'] !== (int)($courier['branch_id'] ?? 0)) {
        jsonResponse(['success' => false, 'message' => 'Kurye bu şubeye ait değil.'], 403);
    }
    $courierName = $courier['name'];

    $sql = "UPDATE orders SET courier_id = ?, courier_name = ?, status = 'Kuryede' WHERE id = ?";
    $params = [$courierId, $courierName, $orderId];
    if ($authUser['role'] === 'Merchant') {
        $sql .= ' AND branch_id = ?';
        $params[] = (int)$authUser['branch_id'];
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    if ($stmt->rowCount() === 0) {
        jsonResponse(['success' => false, 'message' => 'Sipariş bulunamadı veya yetkiniz yok.'], 404);
    }

    echo json_encode(['success' => true, 'message' => "Sipariş {$courierName} isimli kuryeye atandı."]);
    exit;
}

if (($uri === '/api/orders/update-status' && $method === 'POST') || (preg_match('#^/api/orders/(\d+)/status$#', $uri, $statusMatches) && $method === 'PATCH')) {
    $input = getJsonInput();
    $orderId = isset($statusMatches[1]) ? (int)$statusMatches[1] : (int)($input['order_id'] ?? 0);
    $status = $input['status'] ?? 'Kuryede';

    $allowedStatuses = ['Alındı', 'Hazırlanıyor', 'Kuryede', 'Teslim Edildi', 'İptal Edildi'];
    if (!in_array($status, $allowedStatuses, true)) {
        jsonResponse(['success' => false, 'message' => 'Sipariş durumu geçersiz.'], 422);
    }
    if ($authUser['role'] === 'Courier' && !in_array($status, ['Kuryede', 'Teslim Edildi'], true)) {
        jsonResponse(['success' => false, 'message' => 'Kurye bu duruma geçiş yapamaz.'], 403);
    }

    $sql = "UPDATE orders SET status = ?, payment_status = CASE WHEN ? = 'Teslim Edildi' AND payment_method = 'Nakit' THEN 'Ödendi' ELSE payment_status END WHERE id = ?";
    $params = [$status, $status, $orderId];
    if ($authUser['role'] === 'Courier') {
        $sql .= ' AND courier_id = ?';
        $params[] = (int)$authUser['id'];
    } elseif ($authUser['role'] === 'Merchant') {
        $sql .= ' AND branch_id = ?';
        $params[] = (int)$authUser['branch_id'];
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    if ($stmt->rowCount() === 0) {
        jsonResponse(['success' => false, 'message' => 'Sipariş bulunamadı veya yetkiniz yok.'], 404);
    }

    if ($status === 'Teslim Edildi' && (readFeatureFlags($pdo)['temapuan'] ?? false)) {
        $stmt = $pdo->prepare("SELECT order_number, phone, total_amount FROM orders WHERE id = ?");
        $stmt->execute([$orderId]);
        $order = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($order) {
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM loyalty_points WHERE order_number = ? AND type = 'Kazanım'");
            $stmt->execute([$order['order_number']]);
            if ((int)$stmt->fetchColumn() === 0) {
                $rule = $pdo->query("SELECT * FROM loyalty_rules WHERE is_active = 1 LIMIT 1")->fetch(PDO::FETCH_ASSOC);
                $spendPerPoint = max(0.01, (float)($rule['spend_per_point'] ?? 10.0));
                $earnedPoints = (int)floor((float)$order['total_amount'] / $spendPerPoint);
                if ($earnedPoints > 0) {
                    $stmt = $pdo->prepare("INSERT INTO loyalty_points (phone, points, type, description, order_number) VALUES (?, ?, 'Kazanım', ?, ?)");
                    $stmt->execute([$order['phone'], $earnedPoints, 'Tamamlanan sipariş puanı', $order['order_number']]);
                }
            }
        }
    }

    echo json_encode(['success' => true, 'message' => "Sipariş durumu '{$status}' yapıldı."]);
    exit;
}

if ($uri === '/api/products/update-stock' && $method === 'POST') {
    $input = getJsonInput();
    $productId = $input['product_id'] ?? 0;
    $newStock = intval($input['stock'] ?? 0);
    $status = $newStock <= 0 ? 'Tükendi' : ($newStock <= 10 ? 'Kritik Stok' : 'Stokta');

    if ((int)$productId <= 0 || $newStock < 0) {
        jsonResponse(['success' => false, 'message' => 'Stok bilgisi geçersiz.'], 422);
    }

    $stmt = $pdo->prepare("SELECT id, branch_id FROM products WHERE id = ?");
    $stmt->execute([(int)$productId]);
    $product = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$product) {
        jsonResponse(['success' => false, 'message' => 'Ürün bulunamadı.'], 404);
    }

    if ($authUser['role'] === 'Merchant') {
        $merchantBranchId = (int)($authUser['branch_id'] ?? 0);
        if ($merchantBranchId <= 0 || ($product['branch_id'] !== null && (int)$product['branch_id'] !== $merchantBranchId)) {
            jsonResponse(['success' => false, 'message' => 'Bu ürünün stok yetkisi sizde değil.'], 403);
        }
        if ($product['branch_id'] === null) {
            $stmt = $pdo->prepare("UPDATE branch_product_stocks SET stock = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE branch_id = ? AND product_id = ?");
            $stmt->execute([$newStock, $status, $merchantBranchId, (int)$productId]);
        } else {
            $stmt = $pdo->prepare("UPDATE products SET stock = ?, status = ? WHERE id = ?");
            $stmt->execute([$newStock, $status, (int)$productId]);
        }
    } else {
        $targetBranchId = (int)($input['branch_id'] ?? 0);
        if ($product['branch_id'] === null && $targetBranchId > 0) {
            $stmt = $pdo->prepare("UPDATE branch_product_stocks SET stock = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE branch_id = ? AND product_id = ?");
            $stmt->execute([$newStock, $status, $targetBranchId, (int)$productId]);
        } else {
            $stmt = $pdo->prepare("UPDATE products SET stock = ?, status = ? WHERE id = ?");
            $stmt->execute([$newStock, $status, (int)$productId]);
        }
    }

    echo json_encode(['success' => true, 'message' => 'Stok miktarı güncellendi.']);
    exit;
}

if ($uri === '/api/couriers' && $method === 'GET') {
    $where = "role = 'Courier' AND status = 'AKTIF'";
    $params = [];
    $branchId = $authUser['role'] === 'Merchant'
        ? (int)($authUser['branch_id'] ?? 0)
        : (int)($_GET['branch_id'] ?? 0);
    if ($branchId > 0) {
        $where .= ' AND branch_id = ?';
        $params[] = $branchId;
    }
    $stmt = $pdo->prepare("SELECT id, name, vehicle_type, city_district, status, branch_id FROM users WHERE {$where} ORDER BY name");
    $stmt->execute($params);
    $couriers = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['success' => true, 'data' => array_map('safeCourier', $couriers)]);
    exit;
}

// ─────────────────────────────────────────────────────────────
// EK YÖNETİCİ & CMS UÇ NOKTALARI (İstemci Uyumluluğu)
// ─────────────────────────────────────────────────────────────
function readCmsDocument($pdo, $docKey) {
    $stmt = $pdo->prepare("SELECT payload_json FROM cms_documents WHERE doc_key = ?");
    $stmt->execute([$docKey]);
    $raw = $stmt->fetchColumn();
    if (!$raw) return null;
    $decoded = json_decode((string)$raw, true);
    return is_array($decoded) ? $decoded : null;
}

function writeCmsDocument($pdo, $docKey, $payload) {
    $json = json_encode($payload, JSON_UNESCAPED_UNICODE);
    $stmt = $pdo->prepare("SELECT COUNT(*) FROM cms_documents WHERE doc_key = ?");
    $stmt->execute([$docKey]);
    if ((int)$stmt->fetchColumn() > 0) {
        $upd = $pdo->prepare("UPDATE cms_documents SET payload_json = ?, updated_at = CURRENT_TIMESTAMP WHERE doc_key = ?");
        $upd->execute([$json, $docKey]);
    } else {
        $ins = $pdo->prepare("INSERT INTO cms_documents (doc_key, payload_json) VALUES (?, ?)");
        $ins->execute([$docKey, $json]);
    }
}

if ($uri === '/api/admin/products' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $name = trim((string)($input['name'] ?? ''));
    if ($name === '') jsonResponse(['success' => false, 'message' => 'Ürün adı zorunludur.'], 422);
    $category = trim((string)($input['category'] ?? 'Genel'));
    $subBrand = trim((string)($input['sub_brand'] ?? 'Tema'));
    $barcode = trim((string)($input['barcode'] ?? ('869' . random_int(100000000, 999999999))));
    $basePrice = (float)($input['base_price'] ?? 0);
    $originalPrice = (float)($input['original_price'] ?? $basePrice);
    $stock = (int)($input['stock'] ?? 0);
    $status = $stock <= 0 ? 'Tükendi' : ($stock <= 10 ? 'Kritik Stok' : 'Stokta');
    $image = trim((string)($input['image'] ?? ''));
    $unit = trim((string)($input['unit'] ?? 'Adet'));

    if ($id > 0) {
        $check = $pdo->prepare("SELECT id FROM products WHERE id = ?");
        $check->execute([$id]);
        if ($check->fetchColumn()) {
            $stmt = $pdo->prepare("UPDATE products SET name = ?, category = ?, sub_brand = ?, base_price = ?, original_price = ?, stock = ?, status = ?, image = ?, unit = ? WHERE id = ?");
            $stmt->execute([$name, $category, $subBrand, $basePrice, $originalPrice, $stock, $status, $image, $unit, $id]);
            jsonResponse(['success' => true, 'message' => 'Ürün güncellendi.']);
        }
    }
    $stmt = $pdo->prepare("INSERT INTO products (name, category, sub_brand, barcode, base_price, original_price, stock, status, image, unit) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([$name, $category, $subBrand, $barcode, $basePrice, $originalPrice, $stock, $status, $image, $unit]);
    jsonResponse(['success' => true, 'message' => 'Ürün eklendi.', 'id' => (int)$pdo->lastInsertId()]);
}

if ($uri === '/api/admin/products/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) jsonResponse(['success' => false, 'message' => 'Geçersiz ürün ID.'], 422);
    $pdo->prepare("DELETE FROM products WHERE id = ?")->execute([$id]);
    jsonResponse(['success' => true, 'message' => 'Ürün silindi.']);
}

if ($uri === '/api/admin/campaigns' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $title = trim((string)($input['title'] ?? ''));
    if ($title === '') jsonResponse(['success' => false, 'message' => 'Kampanya başlığı zorunludur.'], 422);
    $badge = trim((string)($input['badge'] ?? 'FIRSAT'));
    $code = trim((string)($input['code'] ?? ''));
    $desc = trim((string)($input['description'] ?? ''));
    $image = trim((string)($input['image'] ?? ''));
    $isActive = !empty($input['is_active']) ? 1 : 0;

    if ($id > 0) {
        $check = $pdo->prepare("SELECT id FROM campaigns WHERE id = ?");
        $check->execute([$id]);
        if ($check->fetchColumn()) {
            $stmt = $pdo->prepare("UPDATE campaigns SET title = ?, badge = ?, code = ?, description = ?, image = ?, is_active = ? WHERE id = ?");
            $stmt->execute([$title, $badge, $code, $desc, $image, $isActive, $id]);
            jsonResponse(['success' => true, 'message' => 'Kampanya güncellendi.']);
        }
    }
    $stmt = $pdo->prepare("INSERT INTO campaigns (title, badge, code, description, image, is_active) VALUES (?, ?, ?, ?, ?, ?)");
    $stmt->execute([$title, $badge, $code, $desc, $image, $isActive]);
    jsonResponse(['success' => true, 'message' => 'Kampanya eklendi.', 'id' => (int)$pdo->lastInsertId()]);
}

if ($uri === '/api/admin/campaigns/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) jsonResponse(['success' => false, 'message' => 'Geçersiz kampanya ID.'], 422);
    $pdo->prepare("DELETE FROM campaigns WHERE id = ?")->execute([$id]);
    jsonResponse(['success' => true, 'message' => 'Kampanya silindi.']);
}

if ($uri === '/api/admin/branches' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $name = trim((string)($input['name'] ?? ''));
    if ($name === '') jsonResponse(['success' => false, 'message' => 'Şube adı zorunludur.'], 422);
    $code = trim((string)($input['code'] ?? ('SUB-' . random_int(100, 999))));
    $city = trim((string)($input['city_district'] ?? 'Erzurum'));
    $address = trim((string)($input['address'] ?? ''));
    $phone = trim((string)($input['phone'] ?? ''));
    $isActive = !empty($input['is_active']) ? 1 : 0;

    if ($id > 0) {
        $check = $pdo->prepare("SELECT id FROM branches WHERE id = ?");
        $check->execute([$id]);
        if ($check->fetchColumn()) {
            $stmt = $pdo->prepare("UPDATE branches SET name = ?, code = ?, city_district = ?, address = ?, phone = ?, is_active = ? WHERE id = ?");
            $stmt->execute([$name, $code, $city, $address, $phone, $isActive, $id]);
            jsonResponse(['success' => true, 'message' => 'Şube güncellendi.']);
        }
    }
    $stmt = $pdo->prepare("INSERT INTO branches (code, name, city_district, address, phone, is_active) VALUES (?, ?, ?, ?, ?, ?)");
    $stmt->execute([$code, $name, $city, $address, $phone, $isActive]);
    jsonResponse(['success' => true, 'message' => 'Şube eklendi.', 'id' => (int)$pdo->lastInsertId()]);
}

if ($uri === '/api/admin/branches/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) jsonResponse(['success' => false, 'message' => 'Geçersiz şube ID.'], 422);
    $pdo->prepare("UPDATE branches SET is_active = 0 WHERE id = ?")->execute([$id]);
    jsonResponse(['success' => true, 'message' => 'Şube pasife alındı.']);
}

if (preg_match('#^/api/admin/applications/(\d+)/status$#', $uri, $appMatches) && $method === 'PATCH') {
    $appId = (int)$appMatches[1];
    $input = getJsonInput();
    $newStatus = trim((string)($input['status'] ?? ''));
    $allowedStatuses = ['Beklemede', 'İncelendi', 'Mülakata Çağrıldı', 'Kabul Edildi', 'Reddedildi'];
    if (!in_array($newStatus, $allowedStatuses, true)) {
        jsonResponse(['success' => false, 'message' => 'Geçersiz başvuru durumu.'], 422);
    }
    $stmt = $pdo->prepare("UPDATE applications SET status = ? WHERE id = ?");
    $stmt->execute([$newStatus, $appId]);
    jsonResponse(['success' => true, 'message' => 'Başvuru durumu güncellendi.']);
}

if ($uri === '/api/admin/external-applications/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) jsonResponse(['success' => false, 'message' => 'Geçersiz başvuru ID.'], 422);
    $pdo->prepare("DELETE FROM applications WHERE id = ?")->execute([$id]);
    jsonResponse(['success' => true, 'message' => 'Başvuru silindi.']);
}

if ($uri === '/api/open-positions' && $method === 'GET') {
    $doc = readCmsDocument($pdo, 'open_positions') ?? [];
    jsonResponse(['success' => true, 'data' => $doc]);
}
if ($uri === '/api/admin/open-positions' && $method === 'POST') {
    $input = getJsonInput();
    $list = readCmsDocument($pdo, 'open_positions') ?? [];
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) $input['id'] = (int)(microtime(true) * 1000) % 1000000;
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== (int)$input['id']));
    array_unshift($list, $input);
    writeCmsDocument($pdo, 'open_positions', $list);
    jsonResponse(['success' => true, 'message' => 'Açık pozisyon kaydedildi.']);
}
if ($uri === '/api/admin/open-positions/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $list = readCmsDocument($pdo, 'open_positions') ?? [];
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== $id));
    writeCmsDocument($pdo, 'open_positions', $list);
    jsonResponse(['success' => true, 'message' => 'Açık pozisyon silindi.']);
}

if ($uri === '/api/admin/orders/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) jsonResponse(['success' => false, 'message' => 'Geçersiz sipariş ID.'], 422);
    $pdo->prepare("DELETE FROM orders WHERE id = ?")->execute([$id]);
    jsonResponse(['success' => true, 'message' => 'Sipariş silindi.']);
}

if ($uri === '/api/admin/couriers' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $name = trim((string)($input['name'] ?? ''));
    if ($name === '') jsonResponse(['success' => false, 'message' => 'Kurye adı zorunludur.'], 422);
    $phone = normalizeTurkishPhone((string)($input['phone'] ?? ''));
    if ($phone === null) jsonResponse(['success' => false, 'message' => 'Geçerli bir telefon numarası girin.'], 422);
    $vehicle = trim((string)($input['vehicle'] ?? ($input['vehicle_type'] ?? 'Motosiklet')));
    $branchId = (int)($input['branch_id'] ?? 1);
    $rawStatus = trim((string)($input['status'] ?? 'AKTIF'));
    $dbStatus = strtoupper($rawStatus) === 'PASİF' || strtoupper($rawStatus) === 'PASIF' ? 'PASIF' : 'AKTIF';

    if ($id > 0) {
        $check = $pdo->prepare("SELECT id FROM users WHERE id = ? AND role = 'Courier'");
        $check->execute([$id]);
        if ($check->fetchColumn()) {
            $stmt = $pdo->prepare("UPDATE users SET name = ?, phone = ?, vehicle_type = ?, branch_id = ?, status = ? WHERE id = ? AND role = 'Courier'");
            $stmt->execute([$name, $phone, $vehicle, $branchId > 0 ? $branchId : null, $dbStatus, $id]);
            jsonResponse(['success' => true, 'message' => 'Kurye güncellendi.']);
        }
    }
    $dup = $pdo->prepare("SELECT id FROM users WHERE phone = ?");
    $dup->execute([$phone]);
    $existingId = $dup->fetchColumn();
    if ($existingId) {
        $stmt = $pdo->prepare("UPDATE users SET role = 'Courier', name = ?, vehicle_type = ?, branch_id = ?, status = ? WHERE id = ?");
        $stmt->execute([$name, $vehicle, $branchId > 0 ? $branchId : null, $dbStatus, $existingId]);
        jsonResponse(['success' => true, 'message' => 'Kurye kaydedildi.', 'id' => (int)$existingId]);
    }
    $stmt = $pdo->prepare("INSERT INTO users (phone, role, name, vehicle_type, branch_id, status) VALUES (?, 'Courier', ?, ?, ?, ?)");
    $stmt->execute([$phone, $name, $vehicle, $branchId > 0 ? $branchId : null, $dbStatus]);
    jsonResponse(['success' => true, 'message' => 'Kurye eklendi.', 'id' => (int)$pdo->lastInsertId()]);
}

if ($uri === '/api/admin/couriers/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) jsonResponse(['success' => false, 'message' => 'Geçersiz kurye ID.'], 422);
    $pdo->prepare("UPDATE users SET status = 'PASIF' WHERE id = ? AND role = 'Courier'")->execute([$id]);
    jsonResponse(['success' => true, 'message' => 'Kurye pasife alındı.']);
}

if ($uri === '/api/kasaphane/tracking' && $method === 'GET') {
    $doc = readCmsDocument($pdo, 'kasaphane_tracking');
    if (is_array($doc) && array_key_exists('records', $doc) && is_array($doc['records'])) {
        $doc = $doc['records'];
    }
    jsonResponse(['success' => true, 'data' => is_array($doc) ? $doc : []]);
}
if ($uri === '/api/admin/kasaphane/tracking' && $method === 'POST') {
    $input = getJsonInput();
    $list = readCmsDocument($pdo, 'kasaphane_tracking') ?? [];
    if (array_key_exists('records', $list) && is_array($list['records'])) {
        $list = $list['records'];
    }
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) $input['id'] = (int)(microtime(true) * 1000) % 1000000;
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== (int)$input['id']));
    array_unshift($list, $input);
    writeCmsDocument($pdo, 'kasaphane_tracking', $list);
    jsonResponse(['success' => true, 'message' => 'Kasaphane verisi kaydedildi.']);
}
if ($uri === '/api/admin/kasaphane/tracking/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $list = readCmsDocument($pdo, 'kasaphane_tracking') ?? [];
    if (array_key_exists('records', $list) && is_array($list['records'])) {
        $list = $list['records'];
    }
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== $id));
    writeCmsDocument($pdo, 'kasaphane_tracking', $list);
    jsonResponse(['success' => true, 'message' => 'Kasaphane kaydı silindi.']);
}

if ($uri === '/api/kasaphane/media' && $method === 'GET') {
    $doc = readCmsDocument($pdo, 'kasaphane_media') ?? [];
    jsonResponse(['success' => true, 'data' => $doc]);
}
if ($uri === '/api/admin/kasaphane/media' && $method === 'POST') {
    $input = getJsonInput();
    $list = readCmsDocument($pdo, 'kasaphane_media') ?? [];
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) $input['id'] = (int)(microtime(true) * 1000) % 1000000;
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== (int)$input['id']));
    array_unshift($list, $input);
    writeCmsDocument($pdo, 'kasaphane_media', $list);
    jsonResponse(['success' => true, 'message' => 'Kasaphane medyası kaydedildi.']);
}
if ($uri === '/api/admin/kasaphane/media/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $list = readCmsDocument($pdo, 'kasaphane_media') ?? [];
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== $id));
    writeCmsDocument($pdo, 'kasaphane_media', $list);
    jsonResponse(['success' => true, 'message' => 'Kasaphane medyası silindi.']);
}

if ($uri === '/api/corporate/entities' && $method === 'GET') {
    $doc = readCmsDocument($pdo, 'corporate_entities') ?? [];
    jsonResponse(['success' => true, 'data' => $doc]);
}
if ($uri === '/api/admin/corporate/entities' && $method === 'POST') {
    $input = getJsonInput();
    $list = readCmsDocument($pdo, 'corporate_entities') ?? [];
    $id = (int)($input['id'] ?? 0);
    if ($id <= 0) $input['id'] = (int)(microtime(true) * 1000) % 1000000;
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== (int)$input['id']));
    array_unshift($list, $input);
    writeCmsDocument($pdo, 'corporate_entities', $list);
    jsonResponse(['success' => true, 'message' => 'Kurumsal kayıt kaydedildi.']);
}
if ($uri === '/api/admin/corporate/entities/delete' && $method === 'POST') {
    $input = getJsonInput();
    $id = (int)($input['id'] ?? 0);
    $list = readCmsDocument($pdo, 'corporate_entities') ?? [];
    $list = array_values(array_filter($list, fn($e) => (int)($e['id'] ?? 0) !== $id));
    writeCmsDocument($pdo, 'corporate_entities', $list);
    jsonResponse(['success' => true, 'message' => 'Kurumsal kayıt silindi.']);
}

if (($uri === '/api/subdomains' || $uri === '/api/admin/subdomains') && $method === 'GET') {
    $doc = readCmsDocument($pdo, 'subdomains') ?? [];
    jsonResponse(['success' => true, 'data' => $doc]);
}
if ($uri === '/api/admin/subdomains' && $method === 'POST') {
    $input = getJsonInput();
    $list = readCmsDocument($pdo, 'subdomains') ?? [];
    $slug = strtolower(trim((string)($input['subdomain'] ?? '')));
    if ($slug === '') jsonResponse(['success' => false, 'message' => 'Subdomain slug zorunludur.'], 422);
    $list = array_values(array_filter($list, fn($e) => strtolower((string)($e['subdomain'] ?? '')) !== $slug));
    $list[] = $input;
    writeCmsDocument($pdo, 'subdomains', $list);
    jsonResponse(['success' => true, 'message' => 'Subdomain sayfası kaydedildi.']);
}
if ($uri === '/api/admin/subdomains/delete' && $method === 'POST') {
    $input = getJsonInput();
    $slug = strtolower(trim((string)($input['subdomain'] ?? '')));
    $id = (int)($input['id'] ?? 0);
    $list = readCmsDocument($pdo, 'subdomains') ?? [];
    $list = array_values(array_filter($list, function ($e) use ($slug, $id) {
        if ($slug !== '' && strtolower((string)($e['subdomain'] ?? '')) === $slug) return false;
        if ($id > 0 && (int)($e['id'] ?? 0) === $id) return false;
        return true;
    }));
    writeCmsDocument($pdo, 'subdomains', $list);
    jsonResponse(['success' => true, 'message' => 'Subdomain sayfası silindi.']);
}

jsonResponse(['success' => false, 'message' => 'API uç noktası bulunamadı.'], 404);
