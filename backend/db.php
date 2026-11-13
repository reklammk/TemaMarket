<?php
// TEMASAN ERP — MySQL & SQLite Real Database Engine

$app_env = getenv('APP_ENV') ?: 'production';
$db_host = getenv('DB_HOST') ?: 'localhost';
$db_name = getenv('DB_NAME') ?: '';
$db_user = getenv('DB_USER') ?: '';
$db_pass = getenv('DB_PASS') ?: '';
$configured_db_type = strtolower(trim((string)(getenv('DB_TYPE') ?: '')));
$sqlite_file = getenv('DB_SQLITE_PATH') ?: (__DIR__ . '/database.sqlite');

if ($configured_db_type !== '') {
    $db_type = $configured_db_type;
} elseif ($db_name !== '' || $db_user !== '' || $db_pass !== '') {
    // Herhangi bir MySQL değişkeni tanımlanmışsa eksik/hatalı yapılandırmayı
    // SQLite'a sessizce düşürmek yerine aşağıdaki doğrulama açıkça reddeder.
    $db_type = 'mysql';
} elseif (is_file($sqlite_file)) {
    // Mevcut Hostinger kurulumu veritabanını web kökü dışındaki backend
    // dizininde tutar. Bu, üretimdeki eski ve güvenli SQLite kurulumudur.
    $db_type = 'sqlite';
} else {
    $db_type = $app_env === 'development' ? 'sqlite' : 'mysql';
}

try {
    if ($db_type === 'mysql') {
        if ($db_name === '' || $db_user === '' || $db_pass === '') {
            throw new RuntimeException('Production database environment variables are missing.');
        }
        $pdo = new PDO("mysql:host={$db_host};dbname={$db_name};charset=utf8mb4", $db_user, $db_pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
        ]);
    } else {
        $pdo = new PDO('sqlite:' . $sqlite_file);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
} catch (Exception $e) {
    // Production'da sessizce eski SQLite verisine düşmek veri tutarsızlığı yaratır.
    if ($app_env !== 'development') {
        throw $e;
    }
    try {
        $pdo = new PDO('sqlite:' . $sqlite_file);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    } catch (Exception $ex) {
        die(json_encode(['success' => false, 'message' => 'Database connection failed: ' . $ex->getMessage()]));
    }
}

// Kolon Güncellemeleri
try { $pdo->exec("ALTER TABLE categories ADD COLUMN icon VARCHAR(20) DEFAULT '🛍️'"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE categories ADD COLUMN sort_order INT DEFAULT 0"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE categories ADD COLUMN is_active INT DEFAULT 1"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE campaigns ADD COLUMN target_phone VARCHAR(50)"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN otp_code VARCHAR(20)"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN otp_expires_at DATETIME"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN birth_date VARCHAR(20)"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN special_day VARCHAR(50)"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN email VARCHAR(255)"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN sms_consent INT DEFAULT 0"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN push_consent INT DEFAULT 0"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN kvkk_consent INT DEFAULT 0"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN user_barcode VARCHAR(50)"); } catch (Exception $e) {}
try { $pdo->exec("ALTER TABLE users ADD COLUMN discount_preferences TEXT"); } catch (Exception $e) {}

$isMySQL = ($pdo->getAttribute(PDO::ATTR_DRIVER_NAME) === 'mysql');

if ($isMySQL) {
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        phone VARCHAR(50) NOT NULL UNIQUE,
        role VARCHAR(50) NOT NULL DEFAULT 'Customer',
        name VARCHAR(255),
        email VARCHAR(255),
        company_name VARCHAR(255),
        vehicle_type VARCHAR(100),
        tax_no VARCHAR(100),
        city_district VARCHAR(255),
        status VARCHAR(50) NOT NULL DEFAULT 'AKTIF',
        otp_code VARCHAR(20),
        otp_expires_at DATETIME,
        birth_date VARCHAR(20),
        special_day VARCHAR(50),
        sms_consent INT DEFAULT 0,
        push_consent INT DEFAULT 0,
        kvkk_consent INT DEFAULT 0,
        user_barcode VARCHAR(50),
        discount_preferences TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS brochures (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        image_url TEXT NOT NULL,
        pdf_url TEXT,
        start_date VARCHAR(50),
        end_date VARCHAR(50),
        is_active INT DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS addresses (
        id INT AUTO_INCREMENT PRIMARY KEY,
        phone VARCHAR(50) NOT NULL,
        title VARCHAR(255) NOT NULL,
        address TEXT NOT NULL,
        city_district VARCHAR(255) NOT NULL,
        is_default INT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS netgsm_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        usercode VARCHAR(100) NOT NULL DEFAULT '',
        password VARCHAR(255) NOT NULL DEFAULT '',
        msgheader VARCHAR(100) NOT NULL DEFAULT 'TEMASAN',
        endpoint VARCHAR(255) NOT NULL DEFAULT 'https://api.netgsm.com.tr/sms/send/get',
        is_active INT DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS tt_sms_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(100) NOT NULL DEFAULT '',
        password VARCHAR(255) NOT NULL DEFAULT '',
        login_password VARCHAR(255) NOT NULL DEFAULT '',
        origin VARCHAR(100) NOT NULL DEFAULT 'TEMA MARKET',
        brand_code VARCHAR(100) NOT NULL DEFAULT '',
        token_url VARCHAR(255) NOT NULL DEFAULT 'https://restapi.ttmesaj.com/api/Login/TokenJson',
        sms_url VARCHAR(255) NOT NULL DEFAULT 'https://restapi.ttmesaj.com/api/SendSms/SendSingle',
        is_active INT DEFAULT 0,
        active_provider VARCHAR(50) DEFAULT 'TURK_TELEKOM'
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS branch_stocks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        branch_name VARCHAR(255) NOT NULL,
        product_id INT NOT NULL,
        stock INT NOT NULL DEFAULT 0,
        status VARCHAR(50) NOT NULL DEFAULT 'Stokta',
        UNIQUE(branch_name, product_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS pos_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        bank_name VARCHAR(255) NOT NULL DEFAULT '',
        merchant_id VARCHAR(255) NOT NULL DEFAULT '',
        api_key VARCHAR(255) NOT NULL DEFAULT '',
        terminal_id VARCHAR(255) NOT NULL DEFAULT '',
        is_test_mode INT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS efatura_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        integrator VARCHAR(255) NOT NULL DEFAULT '',
        username VARCHAR(255) NOT NULL DEFAULT '',
        password VARCHAR(255) NOT NULL DEFAULT '',
        tax_office VARCHAR(255) NOT NULL DEFAULT '',
        tax_number VARCHAR(100) NOT NULL DEFAULT '',
        is_auto_invoice INT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS loyalty_rules (
        id INT AUTO_INCREMENT PRIMARY KEY,
        spend_per_point DOUBLE NOT NULL DEFAULT 10.0,
        point_tl_value DOUBLE NOT NULL DEFAULT 0.10,
        min_redeem_points INT NOT NULL DEFAULT 50,
        applicable_categories VARCHAR(255) NOT NULL DEFAULT 'Tüm Ürünler',
        is_active INT DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS loyalty_points (
        id INT AUTO_INCREMENT PRIMARY KEY,
        phone VARCHAR(50) NOT NULL,
        points INT NOT NULL,
        type VARCHAR(50) NOT NULL DEFAULT 'Kazanım',
        description TEXT,
        order_number VARCHAR(100),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS sms_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        target_type VARCHAR(50) NOT NULL,
        target_phone VARCHAR(50),
        message TEXT NOT NULL,
        coupon_code VARCHAR(50),
        status VARCHAR(100) DEFAULT 'Başarılı (NETGSM İletildi)',
        sent_count INT DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS otp_rate_limits (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ip_address VARCHAR(64) NOT NULL,
        phone VARCHAR(30) NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_otp_rate_ip (ip_address, created_at),
        INDEX idx_otp_rate_phone (phone, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS cms_documents (
        doc_key VARCHAR(100) PRIMARY KEY,
        payload_json LONGTEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS categories (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        sub_brand VARCHAR(255) NOT NULL,
        icon VARCHAR(50) DEFAULT '🛍️',
        sort_order INT DEFAULT 0,
        is_active INT DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        category VARCHAR(255) NOT NULL,
        sub_brand VARCHAR(255) NOT NULL,
        barcode VARCHAR(100) UNIQUE,
        base_price DOUBLE NOT NULL,
        original_price DOUBLE,
        stock INT NOT NULL DEFAULT 0,
        status VARCHAR(50) NOT NULL DEFAULT 'Stokta',
        image TEXT,
        unit VARCHAR(50) DEFAULT 'Adet'
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS campaigns (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        badge VARCHAR(100) NOT NULL,
        code VARCHAR(100) NOT NULL,
        description TEXT NOT NULL,
        image TEXT NOT NULL,
        bg_gradient VARCHAR(255) NOT NULL,
        target_phone VARCHAR(50),
        is_active INT DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        order_number VARCHAR(100) UNIQUE NOT NULL,
        customer_name VARCHAR(255) NOT NULL,
        phone VARCHAR(50) NOT NULL,
        delivery_address TEXT NOT NULL,
        items TEXT NOT NULL,
        total_amount DOUBLE NOT NULL,
        payment_method VARCHAR(100) DEFAULT 'Nakit',
        payment_status VARCHAR(50) DEFAULT 'Bekliyor',
        status VARCHAR(50) DEFAULT 'Alındı',
        courier_id INT,
        courier_name VARCHAR(255),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS applications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        type VARCHAR(50) NOT NULL,
        name VARCHAR(255) NOT NULL,
        phone VARCHAR(50) NOT NULL,
        email VARCHAR(255),
        city_district VARCHAR(255),
        details TEXT,
        status VARCHAR(50) DEFAULT 'Yeni',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");
} else {
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL DEFAULT 'Customer',
        name TEXT,
        email TEXT,
        company_name TEXT,
        vehicle_type TEXT,
        tax_no TEXT,
        city_district TEXT,
        status TEXT NOT NULL DEFAULT 'AKTIF',
        otp_code TEXT,
        otp_expires_at DATETIME,
        birth_date TEXT,
        special_day TEXT,
        sms_consent INTEGER DEFAULT 0,
        push_consent INTEGER DEFAULT 0,
        kvkk_consent INTEGER DEFAULT 0,
        user_barcode TEXT,
        discount_preferences TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS brochures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        image_url TEXT NOT NULL,
        pdf_url TEXT,
        start_date TEXT,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS addresses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        title TEXT NOT NULL,
        address TEXT NOT NULL,
        city_district TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS netgsm_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usercode TEXT NOT NULL DEFAULT '',
        password TEXT NOT NULL DEFAULT '',
        msgheader TEXT NOT NULL DEFAULT 'TEMASAN',
        endpoint TEXT NOT NULL DEFAULT 'https://api.netgsm.com.tr/sms/send/get',
        is_active INTEGER DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS tt_sms_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL DEFAULT '',
        password TEXT NOT NULL DEFAULT '',
        login_password TEXT NOT NULL DEFAULT '',
        origin TEXT NOT NULL DEFAULT 'TEMA MARKET',
        brand_code TEXT NOT NULL DEFAULT '',
        token_url TEXT NOT NULL DEFAULT 'https://restapi.ttmesaj.com/api/Login/TokenJson',
        sms_url TEXT NOT NULL DEFAULT 'https://restapi.ttmesaj.com/api/SendSms/SendSingle',
        is_active INTEGER DEFAULT 0,
        active_provider TEXT DEFAULT 'TURK_TELEKOM'
    );

    CREATE TABLE IF NOT EXISTS branch_stocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_name TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'Stokta',
        UNIQUE(branch_name, product_id)
    );

    CREATE TABLE IF NOT EXISTS pos_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_name TEXT NOT NULL DEFAULT '',
        merchant_id TEXT NOT NULL DEFAULT '',
        api_key TEXT NOT NULL DEFAULT '',
        terminal_id TEXT NOT NULL DEFAULT '',
        is_test_mode INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS efatura_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        integrator TEXT NOT NULL DEFAULT '',
        username TEXT NOT NULL DEFAULT '',
        password TEXT NOT NULL DEFAULT '',
        tax_office TEXT NOT NULL DEFAULT '',
        tax_number TEXT NOT NULL DEFAULT '',
        is_auto_invoice INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS loyalty_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        spend_per_point REAL NOT NULL DEFAULT 10.0,
        point_tl_value REAL NOT NULL DEFAULT 0.10,
        min_redeem_points INTEGER NOT NULL DEFAULT 50,
        applicable_categories TEXT NOT NULL DEFAULT 'Tüm Ürünler',
        is_active INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS loyalty_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        points INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'Kazanım',
        description TEXT,
        order_number TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS sms_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_type TEXT NOT NULL,
        target_phone TEXT,
        message TEXT NOT NULL,
        coupon_code TEXT,
        status TEXT DEFAULT 'Başarılı (NETGSM İletildi)',
        sent_count INTEGER DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS otp_rate_limits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ip_address TEXT NOT NULL,
        phone TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS cms_documents (
        doc_key TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sub_brand TEXT NOT NULL,
        icon TEXT DEFAULT '🛍️',
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        sub_brand TEXT NOT NULL,
        barcode TEXT UNIQUE,
        base_price REAL NOT NULL,
        original_price REAL,
        stock INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'Stokta',
        image TEXT,
        unit TEXT DEFAULT 'Adet'
    );

    CREATE TABLE IF NOT EXISTS campaigns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        badge TEXT NOT NULL,
        code TEXT NOT NULL,
        description TEXT NOT NULL,
        image TEXT NOT NULL,
        bg_gradient TEXT NOT NULL,
        target_phone TEXT,
        is_active INTEGER DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        delivery_address TEXT NOT NULL,
        items TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'Nakit',
        payment_status TEXT DEFAULT 'Bekliyor',
        status TEXT DEFAULT 'Alındı',
        courier_id INTEGER,
        courier_name TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        city_district TEXT,
        details TEXT,
        status TEXT DEFAULT 'Yeni',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    ");
}

// Güvenlik, şube ve özellik tabloları (mevcut kurulumlara geriye dönük göç)
if ($isMySQL) {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS api_tokens (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            token_hash CHAR(64) NOT NULL UNIQUE,
            expires_at DATETIME NOT NULL,
            last_used_at DATETIME NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_api_tokens_user (user_id),
            INDEX idx_api_tokens_expiry (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        CREATE TABLE IF NOT EXISTS branches (
            id INT AUTO_INCREMENT PRIMARY KEY,
            code VARCHAR(30) NOT NULL UNIQUE,
            name VARCHAR(255) NOT NULL UNIQUE,
            city_district VARCHAR(255),
            address TEXT,
            phone VARCHAR(50),
            is_active INT DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        CREATE TABLE IF NOT EXISTS feature_flags (
            id INT PRIMARY KEY,
            flags_json TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        CREATE TABLE IF NOT EXISTS branch_product_stocks (
            branch_id INT NOT NULL,
            product_id INT NOT NULL,
            stock INT NOT NULL DEFAULT 0,
            status VARCHAR(50) NOT NULL DEFAULT 'Stokta',
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (branch_id, product_id),
            INDEX idx_branch_product_stock_product (product_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");
} else {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS api_tokens (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token_hash TEXT NOT NULL UNIQUE,
            expires_at DATETIME NOT NULL,
            last_used_at DATETIME,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_api_tokens_user ON api_tokens(user_id);
        CREATE INDEX IF NOT EXISTS idx_api_tokens_expiry ON api_tokens(expires_at);
        CREATE TABLE IF NOT EXISTS branches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL UNIQUE,
            city_district TEXT,
            address TEXT,
            phone TEXT,
            is_active INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS feature_flags (
            id INTEGER PRIMARY KEY,
            flags_json TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS branch_product_stocks (
            branch_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            stock INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'Stokta',
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (branch_id, product_id)
        );
        CREATE INDEX IF NOT EXISTS idx_branch_product_stock_product ON branch_product_stocks(product_id);
    ");
}

$schemaMigrations = [
    "ALTER TABLE users ADD COLUMN branch_id INT NULL",
    "ALTER TABLE users ADD COLUMN otp_attempts INT DEFAULT 0",
    "ALTER TABLE users ADD COLUMN otp_last_sent_at DATETIME NULL",
    "ALTER TABLE orders ADD COLUMN branch_id INT NULL",
    "ALTER TABLE orders ADD COLUMN idempotency_key VARCHAR(120) NULL",
    "ALTER TABLE products ADD COLUMN branch_id INT NULL",
];
foreach ($schemaMigrations as $migration) {
    try { $pdo->exec($migration); } catch (Exception $e) {}
}
if ($isMySQL) {
    try { $pdo->exec("ALTER TABLE users MODIFY otp_code VARCHAR(255) NULL"); } catch (Exception $e) {}
    try { $pdo->exec("ALTER TABLE users MODIFY sms_consent INT DEFAULT 0"); } catch (Exception $e) {}
    try { $pdo->exec("ALTER TABLE users MODIFY push_consent INT DEFAULT 0"); } catch (Exception $e) {}
    try { $pdo->exec("ALTER TABLE users MODIFY kvkk_consent INT DEFAULT 0"); } catch (Exception $e) {}
    try { $pdo->exec("CREATE UNIQUE INDEX idx_orders_idempotency ON orders (idempotency_key)"); } catch (Exception $e) {}
} else {
    try { $pdo->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_idempotency ON orders (idempotency_key)"); } catch (Exception $e) {}
}

$defaultFlags = json_encode([
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
], JSON_UNESCAPED_UNICODE);
$stmt = $pdo->query("SELECT COUNT(*) FROM feature_flags WHERE id = 1");
if ((int)$stmt->fetchColumn() === 0) {
    $stmt = $pdo->prepare("INSERT INTO feature_flags (id, flags_json) VALUES (1, ?)");
    $stmt->execute([$defaultFlags]);
}

// SMS sağlayıcıları yalnızca ortam değişkenleri açıkça verilirse etkinleşir.
// NETGSM Ayarı
$stmt = $pdo->query("SELECT COUNT(*) FROM netgsm_settings");
if ($stmt->fetchColumn() == 0) {
    $netgsmUser = getenv('NETGSM_USERCODE') ?: '';
    $netgsmPassword = getenv('NETGSM_PASSWORD') ?: '';
    $netgsmHeader = getenv('NETGSM_HEADER') ?: 'TEMASAN';
    $netgsmEndpoint = getenv('NETGSM_ENDPOINT') ?: 'https://api.netgsm.com.tr/sms/send/get';
    $stmt = $pdo->prepare("INSERT INTO netgsm_settings (usercode, password, msgheader, endpoint, is_active) VALUES (?, ?, ?, ?, ?)");
    $stmt->execute([$netgsmUser, $netgsmPassword, $netgsmHeader, $netgsmEndpoint, $netgsmPassword !== '' ? 1 : 0]);
}

// Türk Telekom REST SMS Ayarı (Birincil Sağlayıcı)
$stmt = $pdo->query("SELECT COUNT(*) FROM tt_sms_settings");
if ($stmt->fetchColumn() == 0) {
    $ttUsername = getenv('TT_SMS_USERNAME') ?: '';
    $ttPassword = getenv('TT_SMS_PASSWORD') ?: '';
    $ttLoginPassword = getenv('TT_SMS_LOGIN_PASSWORD') ?: '';
    $ttOrigin = getenv('TT_SMS_ORIGIN') ?: 'TEMA MARKET';
    $ttBrandCode = getenv('TT_SMS_BRAND_CODE') ?: '';
    $stmt = $pdo->prepare("INSERT INTO tt_sms_settings (username, password, login_password, origin, brand_code, token_url, sms_url, is_active, active_provider) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'TURK_TELEKOM')");
    $stmt->execute([
        $ttUsername,
        $ttPassword,
        $ttLoginPassword,
        $ttOrigin,
        $ttBrandCode,
        getenv('TT_SMS_TOKEN_URL') ?: 'https://restapi.ttmesaj.com/api/Login/TokenJson',
        getenv('TT_SMS_SEND_URL') ?: 'https://restapi.ttmesaj.com/api/SendSms/SendSingle',
        ($ttUsername !== '' && $ttPassword !== '' && $ttLoginPassword !== '') ? 1 : 0,
    ]);
}

// KATEGORİLERİ TOHUMLAMA
$stmt = $pdo->query("SELECT COUNT(*) FROM categories");
if ($stmt->fetchColumn() == 0) {
    $pdo->exec("INSERT INTO categories (name, sub_brand, icon, sort_order, is_active) VALUES
    ('Et & Tavuk & Balık', 'Kasap', '🥩', 1, 1),
    ('Meyve & Sebze', 'Manav', '🍎', 2, 1),
    ('Süt & Şarküteri', 'Sarkuteri', '🧀', 3, 1),
    ('Fırın & Pastane', 'Firin', '🍞', 4, 1),
    ('İçecekler', 'Icecek', '🥤', 5, 1)
    ");
}

// KULLANICILAR VE 24 ŞUBE BAYİ HESAPLARI TOHUMLAMA (MySQL & SQLite Uyumlu)
function seedUser($pdo, $phone, $role, $name, $company = null, $city = null, $vehicle = null) {
    $stmt = $pdo->prepare("SELECT id FROM users WHERE phone = ?");
    $stmt->execute([$phone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        $stmt = $pdo->prepare("INSERT INTO users (phone, role, name, company_name, city_district, vehicle_type, status, sms_consent, push_consent, kvkk_consent) VALUES (?, ?, ?, ?, ?, ?, 'AKTIF', 0, 0, 0)");
        $stmt->execute([$phone, $role, $name, $company, $city, $vehicle]);
    } else {
        $stmt = $pdo->prepare("UPDATE users SET role = ?, name = ?, status = 'AKTIF' WHERE id = ?");
        $stmt->execute([$role, $name, $user['id']]);
    }
}

$seedDemoEnabled = in_array(strtolower(trim((string)(getenv('SEED_DEMO_DATA') ?: 'false'))), ['true', '1'], true);
if ($seedDemoEnabled) {
    seedUser($pdo, '+905550000000', 'SuperAdmin', 'Sistem Yöneticisi');
    seedUser($pdo, '+905551234567', 'Customer', 'Test Müşteri');
    seedUser($pdo, '+905559991122', 'Courier', 'Test Kurye', null, null, 'Motosiklet');
}

$bootstrapAdminPhone = preg_replace('/\D+/', '', getenv('BOOTSTRAP_ADMIN_PHONE') ?: '');
if (strlen($bootstrapAdminPhone) === 10) {
    $bootstrapAdminPhone = '+90' . $bootstrapAdminPhone;
    $stmt = $pdo->prepare("SELECT id FROM users WHERE phone = ?");
    $stmt->execute([$bootstrapAdminPhone]);
    if (!$stmt->fetch(PDO::FETCH_ASSOC)) {
        $stmt = $pdo->prepare("INSERT INTO users (phone, role, name, status, sms_consent, push_consent, kvkk_consent) VALUES (?, 'SuperAdmin', ?, 'AKTIF', 0, 0, 0)");
        $stmt->execute([$bootstrapAdminPhone, getenv('BOOTSTRAP_ADMIN_NAME') ?: 'Sistem Yöneticisi']);
    }
}

// 24 Gerçek Bayi Hesabı
$branchesSeed = [
    ['phone' => '05312213632', 'name' => 'Lalapaşa AVM Bayisi', 'company' => 'Lalapaşa AVM', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05326248237', 'name' => 'Pasinler Bayisi', 'company' => 'Pasinler', 'city' => 'Pasinler / Erzurum'],
    ['phone' => '05428052946', 'name' => 'Yenişehir AVM Bayisi', 'company' => 'Yenişehir AVM', 'city' => 'Palandöken / Erzurum'],
    ['phone' => '05304652930', 'name' => 'Kelkit-1 Bayisi', 'company' => 'Kelkit-1', 'city' => 'Kelkit / Gümüşhane'],
    ['phone' => '05302645347', 'name' => 'Şenkaya Bayisi', 'company' => 'Şenkaya', 'city' => 'Şenkaya / Erzurum'],
    ['phone' => '05304652931', 'name' => 'Kelkit-2 Bayisi', 'company' => 'Kelkit-2', 'city' => 'Kelkit / Gümüşhane'],
    ['phone' => '05389431215', 'name' => 'Selimiye Bayisi', 'company' => 'Selimiye', 'city' => 'Palandöken / Erzurum'],
    ['phone' => '05327052591', 'name' => 'Uzundere Bayisi', 'company' => 'Uzundere', 'city' => 'Uzundere / Erzurum'],
    ['phone' => '05467431329', 'name' => 'Terminal Bayisi', 'company' => 'Terminal', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05312213646', 'name' => 'Çırcır Bayisi', 'company' => 'Çırcır', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05312326277', 'name' => 'Hilalkent Bayisi', 'company' => 'Hilalkent', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05069620258', 'name' => 'Dadaşkent AVM Bayisi', 'company' => 'Dadaşkent AVM', 'city' => 'Aziziye / Erzurum'],
    ['phone' => '05424269303', 'name' => 'Yıldızkent-2 Bayisi', 'company' => 'Yıldızkent-2', 'city' => 'Palandöken / Erzurum'],
    ['phone' => '05345481867', 'name' => 'Kayakyolu-1 Bayisi', 'company' => 'Kayakyolu-1', 'city' => 'Palandöken / Erzurum'],
    ['phone' => '05442415829', 'name' => 'Nenehatun Bayisi', 'company' => 'Nenehatun', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05454464811', 'name' => 'Enkule AVM Bayisi', 'company' => 'Enkule AVM', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05342716864', 'name' => 'Yunusemre Bayisi', 'company' => 'Yunusemre', 'city' => 'Palandöken / Erzurum'],
    ['phone' => '05367093278', 'name' => 'Şükrüpaşa Bayisi', 'company' => 'Şükrüpaşa', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05364852235', 'name' => 'Dadaşkent-2 Bayisi', 'company' => 'Dadaşkent-2', 'city' => 'Aziziye / Erzurum'],
    ['phone' => '05366053382', 'name' => 'Gürcükapı Bayisi', 'company' => 'Gürcükapı', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05050880891', 'name' => 'Telsizler Bayisi', 'company' => 'Telsizler', 'city' => 'Palandöken / Erzurum'],
    ['phone' => '05077621850', 'name' => 'Dadaşkent-4 Bayisi', 'company' => 'Dadaşkent-4', 'city' => 'Aziziye / Erzurum'],
    ['phone' => '05465382721', 'name' => 'Kombina Bayisi', 'company' => 'Kombina', 'city' => 'Yakutiye / Erzurum'],
    ['phone' => '05344660997', 'name' => 'Palandöken AVM Bayisi', 'company' => 'Palandöken AVM', 'city' => 'Palandöken / Erzurum'],
];

foreach ($branchesSeed as $index => $b) {
    $code = 'SUB-' . str_pad((string)($index + 1), 3, '0', STR_PAD_LEFT);
    $stmt = $pdo->prepare("SELECT id FROM branches WHERE name = ?");
    $stmt->execute([$b['company']]);
    $branchId = $stmt->fetchColumn();
    if (!$branchId) {
        $stmt = $pdo->prepare("INSERT INTO branches (code, name, city_district, address, phone, is_active) VALUES (?, ?, ?, ?, ?, 1)");
        $stmt->execute([$code, $b['company'], $b['city'], $b['city'], $b['phone']]);
        $branchId = $pdo->lastInsertId();
    }
    $stmt = $pdo->prepare("UPDATE users SET branch_id = ? WHERE role = 'Merchant' AND company_name = ?");
    $stmt->execute([$branchId, $b['company']]);
}

// Örnek ticari veriler production ortamında otomatik oluşturulmaz.
if ($seedDemoEnabled) {
  // Kampanyalar Tohumlama
  $stmt = $pdo->query("SELECT COUNT(*) FROM campaigns");
  if ($stmt->fetchColumn() == 0) {
    $pdo->exec("INSERT INTO campaigns (title, badge, code, description, image, bg_gradient) VALUES
    ('SANALMARKET İLK SİPARİŞE İNDİRİM!', 'SANALMARKET ÖZEL', 'TEMA50', 'Tüm Şubelerimizde Aynı Gün Teslimat Fırsatıyla', 'https://images.unsplash.com/photo-1528825871115-3581a5387919?auto=format&fit=crop&w=800&q=80', 'linear-gradient(135deg, #dc2626 0%, #991b1b 100%)'),
    ('TAZE KASAP DANA ETİ VE SUCUKTA ÖZEL FİYAT!', 'TEMA KASAP ÖZEL', 'KASAP30', 'Günlük Kesim Taze Yerli Üretim Kasap Ürünlerinde Geçerlidir', 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80', 'linear-gradient(135deg, #1e293b 0%, #0f172a 100%)'),
    ('BAHÇEDEN SOFRAYA TAZE MANAV FIRSATLARI!', 'TEMA MANAV ÖZEL', 'HEMEN20', '30 Dakikada Ekspres Kapınıza Teslimat', 'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=800&q=80', 'linear-gradient(135deg, #16a34a 0%, #14532d 100%)')
    ");
  }

  $stmt = $pdo->query("SELECT COUNT(*) FROM products");
  $productCount = (int)$stmt->fetchColumn();
  if ($productCount === 0 && $seedDemoEnabled) {
    $pdo->exec("INSERT INTO products (name, category, sub_brand, barcode, base_price, original_price, stock, status, image, unit) VALUES
    ('Beypiliç Baget 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100001', 79.99, 89.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Bütün 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100002', 99.99, 119.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Bonfile 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100003', 209.90, 229.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Yaprak Kanat 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100004', 459.90, 499.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Izgara Kanat 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100005', 319.90, 349.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Mini Baget 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100006', 229.90, 299.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Piliç Sarma 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100007', 169.90, 189.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Kelebek Pirzola 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100008', 149.90, 169.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Parmak Bonfile 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100009', 179.90, 199.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Taşlık 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100010', 89.99, 99.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Beypiliç Ciğer 1 Kg', 'Et & Tavuk & Balık', 'Kasap', '8690000100011', 59.99, 79.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Yumurta 30''Lu (M)', 'Süt & Şarküteri', 'Sarkuteri', '8690000100012', 139.90, 149.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1516467508483-a7212febe31a?auto=format&fit=crop&w=400&q=80', 'Koli'),
    ('Yumurta 30''Lu (L)', 'Süt & Şarküteri', 'Sarkuteri', '8690000100013', 149.90, 169.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=400&q=80', 'Koli'),
    ('Komili Ayçiçek Yağı 5 Lt', 'Meyve & Sebze', 'Manav', '8690000200001', 479.90, 519.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80', 'Teneke'),
    ('Komili Riviera Zeytinyağı 5 Lt', 'Meyve & Sebze', 'Manav', '8690000200002', 1199.00, 1395.00, 50, 'Stokta', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80', 'Teneke'),
    ('Kristal Riviera Zeytinyağı 5 Lt', 'Meyve & Sebze', 'Manav', '8690000200003', 1199.90, 1379.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80', 'Teneke'),
    ('Tema Pilavlık Bulgur 4 Kg', 'Meyve & Sebze', 'Manav', '8690000200004', 109.90, 169.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Kırmızı Mercimek Futbol 2.5 Kg', 'Meyve & Sebze', 'Manav', '8690000200005', 109.90, 165.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Osmancık Pirinç 2.5 Kg', 'Meyve & Sebze', 'Manav', '8690000200006', 159.90, 229.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Deryalım Osmancık Pirinç 4 Kg', 'Meyve & Sebze', 'Manav', '8690000200007', 199.90, 259.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Yayla Aşurelik Buğday 2 Kg', 'Meyve & Sebze', 'Manav', '8690000200008', 59.99, 79.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Barilla Penne Rigate Makarna 500 Gr', 'Meyve & Sebze', 'Manav', '8690000200009', 39.99, 52.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1551462147-ff29053bfc14?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Eti Çikolata Bol Sütlü 60 Gr', 'Fırın & Pastane', 'Firin', '8690000200010', 49.99, 72.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?auto=format&fit=crop&w=400&q=80', 'Adet'),
    ('Gürsoy Kakaolu Fındık Kreması 700 Gr', 'Süt & Şarküteri', 'Sarkuteri', '8690000200011', 159.90, 219.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=400&q=80', 'Kavanoz'),
    ('Doğadan Form Kayısılı Bitki Çayı 27 Gr', 'İçecek', 'Icecek', '8690000200012', 45.99, 89.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?auto=format&fit=crop&w=400&q=80', 'Kutu'),
    ('Lipton Yellow Label Dökme Çay 1 Kg', 'İçecek', 'Icecek', '8690000200013', 339.90, 379.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tukaş Domates Salçası 830 Gr', 'Meyve & Sebze', 'Manav', '8690000200014', 59.99, 64.50, 50, 'Stokta', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=400&q=80', 'Teneke'),
    ('Tema Kokteyl Extra Kuruyemiş 1 Kg', 'Fırın & Pastane', 'Firin', '8690000200015', 899.90, 999.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Tema Kokteyl Lüks Kuruyemiş 1 Kg', 'Fırın & Pastane', 'Firin', '8690000200016', 999.90, 1199.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Kızılay Maden Suyu 6x200 Ml', 'İçecek', 'Icecek', '8690000200017', 47.95, 53.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('İçim Vişne Meyve Suyu 1 Lt', 'İçecek', 'Icecek', '8690000200018', 44.99, 54.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?auto=format&fit=crop&w=400&q=80', 'Kutu'),
    ('İçim Meyve Suyu 200 Ml', 'İçecek', 'Icecek', '8690000200019', 10.99, 12.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?auto=format&fit=crop&w=400&q=80', 'Kutu'),
    ('Ülker Kremalı Bisküvi 61 Gr', 'Fırın & Pastane', 'Firin', '8690000200020', 7.99, 16.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Doğanay Şalgam Suyu 2 Lt', 'İçecek', 'Icecek', '8690000200021', 89.99, 124.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1527661591475-527312dd65f5?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Yayla Cips Çeşitleri (Notto/Hitos)', 'Fırın & Pastane', 'Firin', '8690000200022', 27.50, 54.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Çamlıca Portakal Gazozu 2.5 Lt', 'İçecek', 'Icecek', '8690000200023', 59.99, 79.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Coca-Cola Zero Sugar 2.5 Lt', 'İçecek', 'Icecek', '8690000200024', 59.99, 89.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Sunny Portakal Gazozu 2.5 Lt', 'İçecek', 'Icecek', '8690000200025', 49.99, 63.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Cola Turka 2.5 Lt', 'İçecek', 'Icecek', '8690000200026', 59.99, 65.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Aytaç Yarım Yağlı Süt 1 Lt', 'Süt & Şarküteri', 'Sarkuteri', '8690000200027', 42.99, 49.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=400&q=80', 'Kutu'),
    ('İçim Yarım Yağlı Süt 1 Lt', 'Süt & Şarküteri', 'Sarkuteri', '8690000200028', 44.99, 49.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=400&q=80', 'Kutu'),
    ('Karlıdağ Geleneksel Tereyağı 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000200029', 499.99, 599.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Berrak Koçan Mısır Turşusu 340 Gr', 'Süt & Şarküteri', 'Sarkuteri', '8690000200030', 149.90, 179.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1534483509719-3feaee7c30da?auto=format&fit=crop&w=400&q=80', 'Kavanoz'),
    ('Kuru Sele Siyah Zeytin 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000200031', 399.90, 559.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1541458385327-f3a388478492?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Izgara Yeşil Zeytin 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000200032', 349.90, 459.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1541458385327-f3a388478492?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Marmara Birlik Gemlik Zeytin 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000200033', 399.90, 499.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1541458385327-f3a388478492?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Aytaç Piliç Salam 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000200034', 169.90, 219.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80', 'Baton'),
    ('Namet Dana Kangal Klasik Sucuk 200 Gr', 'Et & Tavuk & Balık', 'Kasap', '8690000200035', 199.90, 239.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Bingo Matik Sık Yıkananlar 9 Kg', 'Temizlik', 'Genel', '8690000300001', 399.90, 489.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Omo Matik Renkli ve Beyazlar 9 Kg', 'Temizlik', 'Genel', '8690000300002', 419.90, 429.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Abc Sıvı Deterjan 3 Lt', 'Temizlik', 'Genel', '8690000300003', 159.90, 199.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Perwoll Yünlüler ve İpekler 2970 Ml', 'Temizlik', 'Genel', '8690000300004', 189.90, 239.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Abc Yumuşatıcı 3 Lt', 'Temizlik', 'Genel', '8690000300005', 89.99, 119.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Vernel Max Yumuşatıcı 1440 Ml', 'Temizlik', 'Genel', '8690000300006', 119.90, 199.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Bingo Sıvı Bulaşık Deterjanı 4 Lt', 'Temizlik', 'Genel', '8690000300007', 199.90, 239.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Bidon'),
    ('Bingo Bulaşık Tableti Pro 80''Li', 'Temizlik', 'Genel', '8690000300008', 439.90, 489.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Dalan Sıvı Sabun 3 Lt', 'Kişisel Bakım', 'Genel', '8690000300009', 99.99, 129.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=400&q=80', 'Bidon'),
    ('Finish Quantum Bulaşık Tableti 36''Lı', 'Temizlik', 'Genel', '8690000300010', 249.90, 355.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Finish Powerball Ultimate Tablet 30''Lu', 'Temizlik', 'Genel', '8690000300011', 249.90, 355.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Hacı Şakir Katı Sabun 4x150 Gr', 'Kişisel Bakım', 'Genel', '8690000300012', 129.90, 134.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1607006344380-b6775a0824a7?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Pantene Şampuan 400 Ml (3''ü 1 Arada)', 'Kişisel Bakım', 'Genel', '8690000300013', 135.90, 159.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Bioblas Botanik Şampuan 360 Ml', 'Kişisel Bakım', 'Genel', '8690000300014', 99.99, 159.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Signal White Now Diş Macunu + Fırça', 'Kişisel Bakım', 'Genel', '8690000300015', 99.90, 124.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1559599101-f09722fb4948?auto=format&fit=crop&w=400&q=80', 'Set'),
    ('Blendax Şampuan 500 Ml Çeşitleri', 'Kişisel Bakım', 'Genel', '8690000300016', 89.99, 99.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Head & Shoulders Dermaxpro 300 Ml', 'Kişisel Bakım', 'Genel', '8690000300017', 139.90, 159.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Sensodyne Diş Macunu 75 Ml', 'Kişisel Bakım', 'Genel', '8690000300018', 99.99, 114.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1559599101-f09722fb4948?auto=format&fit=crop&w=400&q=80', 'Tüp'),
    ('Berrak Ultra Tuvalet Kağıdı 32''Li', 'Temizlik', 'Genel', '8690000300019', 159.90, 199.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1584556812952-905ffd0c611a?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Selpak Extra Tuvalet Kağıdı 32''Li', 'Temizlik', 'Genel', '8690000300020', 299.90, 339.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1584556812952-905ffd0c611a?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Abc Çamaşır Suyu 4 Lt', 'Temizlik', 'Genel', '8690000300021', 99.99, 135.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Bidon'),
    ('Maylo Super Tuvalet Kağıdı 40''Lı', 'Temizlik', 'Genel', '8690000300022', 299.90, 329.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1584556812952-905ffd0c611a?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Smile Islak Havlu 120 Adet', 'Kişisel Bakım', 'Genel', '8690000300023', 25.99, 29.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1584556812952-905ffd0c611a?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Abc Yüzey Temizleyici 2.5 Lt', 'Temizlik', 'Genel', '8690000300024', 89.99, 115.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Şişe'),
    ('Çotanak Rafine Kanola Yağı 5 Lt', 'Meyve & Sebze', 'Manav', '8690000300025', 369.90, 439.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80', 'PET'),
    ('Söke Geleneksel Un 10 Kg', 'Fırın & Pastane', 'Firin', '8690000300026', 259.90, 299.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80', 'Çuval'),
    ('Filiz Makarna 500 Gr Çeşitleri', 'Meyve & Sebze', 'Manav', '8690000300027', 24.99, 25.99, 50, 'Stokta', 'https://images.unsplash.com/photo-1551462147-ff29053bfc14?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Gönen Baldo Pirinç 2.5 Kg', 'Meyve & Sebze', 'Manav', '8690000300028', 189.90, 239.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Abc Matik Canlı Renkliler 6 Kg', 'Temizlik', 'Genel', '8690000300029', 299.90, 339.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1585832770485-e68a5fcfad52?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Molfix Fırsat Paketi Çocuk Bezi', 'Kişisel Bakım', 'Genel', '8690000300030', 299.90, 339.90, 50, 'Stokta', 'https://images.unsplash.com/photo-1584556812952-905ffd0c611a?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Erzurum Göğermiş Peynir 450 Gr', 'Süt & Şarküteri', 'Sarkuteri', '8690000300031', 159.95, 195.00, 50, 'Stokta', 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Civil Peynir Ditme 250 Gr', 'Süt & Şarküteri', 'Sarkuteri', '8690000300032', 89.95, 109.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Az Yağlı Taze Kaşar 600 Gr', 'Süt & Şarküteri', 'Sarkuteri', '8690000300033', 169.95, 249.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80', 'Paket'),
    ('Tema Manda ve İnek Kaymağı 200 Gr', 'Süt & Şarküteri', 'Sarkuteri', '8690000300034', 89.95, 129.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=400&q=80', 'Kase'),
    ('Tema Geleneksel Yayık Tereyağı 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000300035', 579.95, 649.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=400&q=80', 'Rulo'),
    ('Tema Erzurum Oval Peynir 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000300036', 219.95, 249.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Tema Civil Salamura Peynir 1 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000300037', 229.95, 289.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80', 'Kg'),
    ('Tema Tam Yağlı Yoğurt 2 Kg', 'Süt & Şarküteri', 'Sarkuteri', '8690000300038', 129.95, 169.95, 50, 'Stokta', 'https://images.unsplash.com/photo-1571212515416-fef01fc43637?auto=format&fit=crop&w=400&q=80', 'Kova')
    ");
  }

// Aktüel Broşürler Tohumlama
  $stmt = $pdo->query("SELECT COUNT(*) FROM brochures");
  if ($stmt->fetchColumn() == 0) {
    $pdo->exec("INSERT INTO brochures (title, description, image_url, start_date, end_date, is_active) VALUES
    ('AĞUSTOS KASA BAŞI İNDİRİM KATALOĞU (SAYFA 1)', 'Şubelerimizde Geçerli Şok İndirim Kataloğu - Taze Kasap & Manav Kampanyaları', 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80', '2026-08-01', '2026-08-31', 1),
    ('TEMA KASAP VE MANAV ÖZEL İNSERTİ (SAYFA 2)', 'Erzurum Yerli Üretim Taze Kesim Et Ürünleri ve Çiftlikten Halka Meyve İndirimleri', 'https://images.unsplash.com/photo-1607344645866-009c320c5ab8?auto=format&fit=crop&w=1200&q=80', '2026-08-05', '2026-08-25', 1)
    ");
  }
}

// Global katalog ürünleri için stok her şubede ayrı tutulur. Mevcut
// değerler korunur; sadece daha önce oluşmamış şube/ürün satırları eklenir.
if ($isMySQL) {
    $pdo->exec("INSERT IGNORE INTO branch_product_stocks (branch_id, product_id, stock, status)
                SELECT b.id, p.id, p.stock, p.status FROM branches b CROSS JOIN products p WHERE p.branch_id IS NULL");
} else {
    $pdo->exec("INSERT OR IGNORE INTO branch_product_stocks (branch_id, product_id, stock, status)
                SELECT b.id, p.id, p.stock, p.status FROM branches b CROSS JOIN products p WHERE p.branch_id IS NULL");
}

return $pdo;
