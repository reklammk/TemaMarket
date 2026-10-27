-- TEMASAN API — MySQL production bootstrap schema
-- Bu dosya veri silmez, test kullanıcısı veya gizli anahtar oluşturmaz.
-- Uygulamanın geriye dönük kolon geçişleri backend/db.php tarafından yönetilir.

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
  otp_code VARCHAR(255),
  otp_expires_at DATETIME,
  otp_attempts INT DEFAULT 0,
  otp_last_sent_at DATETIME,
  birth_date VARCHAR(20),
  special_day VARCHAR(50),
  sms_consent INT DEFAULT 0,
  push_consent INT DEFAULT 0,
  kvkk_consent INT DEFAULT 0,
  user_barcode VARCHAR(50),
  discount_preferences TEXT,
  branch_id INT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_users_role_status (role, status),
  INDEX idx_users_branch (branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  last_used_at DATETIME,
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

CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  sub_brand VARCHAR(100) NOT NULL,
  icon VARCHAR(20) DEFAULT '🛒',
  sort_order INT DEFAULT 0,
  is_active INT DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(255) NOT NULL,
  sub_brand VARCHAR(100) NOT NULL,
  barcode VARCHAR(100) UNIQUE,
  base_price DECIMAL(10,2) NOT NULL,
  original_price DECIMAL(10,2),
  stock INT NOT NULL DEFAULT 0,
  status VARCHAR(50) NOT NULL DEFAULT 'Stokta',
  image TEXT,
  unit VARCHAR(50) DEFAULT 'Adet',
  branch_id INT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_products_branch (branch_id),
  INDEX idx_products_sub_brand (sub_brand)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS campaigns (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  badge VARCHAR(100),
  code VARCHAR(100),
  description TEXT,
  image TEXT,
  bg_gradient TEXT,
  target_phone VARCHAR(50),
  is_active INT DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_campaign_target (target_phone, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_number VARCHAR(100) NOT NULL UNIQUE,
  customer_name VARCHAR(255) NOT NULL,
  phone VARCHAR(50) NOT NULL,
  delivery_address TEXT NOT NULL,
  items LONGTEXT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(100) NOT NULL DEFAULT 'Nakit',
  payment_status VARCHAR(50) NOT NULL DEFAULT 'Bekliyor',
  status VARCHAR(50) NOT NULL DEFAULT 'Alındı',
  branch_id INT NOT NULL,
  courier_id INT,
  courier_name VARCHAR(255),
  idempotency_key VARCHAR(120),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY idx_orders_idempotency (idempotency_key),
  INDEX idx_orders_phone (phone),
  INDEX idx_orders_branch_status (branch_id, status),
  INDEX idx_orders_courier (courier_id)
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

INSERT INTO feature_flags (id, flags_json)
VALUES (1, '{"sanal_market":true,"bayi_stok":true,"temapuan":true,"api_entegrasyon":false,"sms_gonderim":false,"kampanyalar":true,"sanal_pos":false,"soft_pos":false,"e_fatura":false,"serbest_kurye":false}')
ON DUPLICATE KEY UPDATE id = id;
