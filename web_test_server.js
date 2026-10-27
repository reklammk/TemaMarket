/**
 * ★ temamarket.com (Tema Marketler Zinciri & Sanal Market)
 * Tam Fonksiyonel Yerel Sunucu + Gerçek temasanalmarket.com Verileri + Kalıcı Veritabanı (server_db.json)
 *
 * Çalıştır: node web_test_server.js
 * Adres:    http://localhost:3000
 * Admin:    http://localhost:3000/admin
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = 3000;
const API_TARGET = 'temasanalmarket.com';
const WEB_DIST = path.join(__dirname, 'web_dist');
const DB_PATH = path.join(__dirname, 'server_db.json');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
};

const INITIAL_PRODUCTS = [
  { id: 1, name: "Dana Kasap Parmak Sucuk 500 g", category: "Et & Tavuk & Balık", sub_brand: "Kasap", barcode: "8690000111101", base_price: 499, original_price: 625, stock: 25, status: "Stokta", image: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80", unit: "Paket" },
  { id: 2, name: "Taze Dana Kıyma (%15 Yağlı) 1 kg", category: "Et & Tavuk & Balık", sub_brand: "Kasap", barcode: "8690000111102", base_price: 390, original_price: 440, stock: 18, status: "Stokta", image: "https://images.unsplash.com/photo-1588168333986-5078d3ae3976?auto=format&fit=crop&w=400&q=80", unit: "kg" },
  { id: 3, name: "Kuzu Pirzola 1 kg", category: "Et & Tavuk & Balık", sub_brand: "Kasap", barcode: "8690000111103", base_price: 680, original_price: 750, stock: 8, status: "Kritik Stok", image: "https://images.unsplash.com/photo-1603048588665-791ca8aea617?auto=format&fit=crop&w=400&q=80", unit: "kg" },
  { id: 4, name: "Sıkma File Portakal 2 kg", category: "Meyve & Sebze", sub_brand: "Manav", barcode: "8690000222201", base_price: 49.9, original_price: 65, stock: 45, status: "Stokta", image: "https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=400&q=80", unit: "File" },
  { id: 5, name: "Salkım Domates 1 kg", category: "Meyve & Sebze", sub_brand: "Manav", barcode: "8690000222202", base_price: 28.5, original_price: 38, stock: 60, status: "Stokta", image: "https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=400&q=80", unit: "kg" },
  { id: 6, name: "Torku Tam Yağlı Taze Kaşar 600 g", category: "Süt & Şarküteri", sub_brand: "Sarkuteri", barcode: "8690000333301", base_price: 299, original_price: 479, stock: 13, status: "Stokta", image: "https://images.unsplash.com/photo-1552767059-ce182ead6c1b?auto=format&fit=crop&w=400&q=80", unit: "Adet" },
  { id: 7, name: "Ezine Tam Yağlı Olgunlaştırılmış Peynir 500 g", category: "Süt & Şarküteri", sub_brand: "Sarkuteri", barcode: "8690000333302", base_price: 165, original_price: 195, stock: 9, status: "Kritik Stok", image: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?auto=format&fit=crop&w=400&q=80", unit: "Paket" },
  { id: 8, name: "Geleneksel Ekşi Mayalı Trabzon Ekmeği 800 g", category: "Fırın & Pastane", sub_brand: "Firin", barcode: "8690000444401", base_price: 35, original_price: 42, stock: 30, status: "Stokta", image: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80", unit: "Adet" },
  { id: 9, name: "Çaykur Rize Turist Çayı 1000 g", category: "İçecek", sub_brand: "Icecek", barcode: "8690000555501", base_price: 165, original_price: 185, stock: 86, status: "Stokta", image: "https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=400&q=80", unit: "Paket" },
  { id: 901, name: "Tema Kasaphane Erzurum Yerli Besi Dana Kuşbaşı 1 kg", category: "Et & Tavuk & Balık", sub_brand: "Kasap", barcode: "8690000901001", base_price: 549, original_price: 615, stock: 35, status: "Stokta", image: "https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=500&q=80", unit: "kg" },
  { id: 902, name: "Tema Kasaphane Dinlendirilmiş Dana Antrikot 1 kg", category: "Et & Tavuk & Balık", sub_brand: "Kasap", barcode: "8690000901002", base_price: 675, original_price: 740, stock: 22, status: "Stokta", image: "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=500&q=80", unit: "kg" },
  { id: 903, name: "Tema Mandıra Erzurum Göğermiş Çeçil Peyniri 500 g", category: "Tema Mandıra", sub_brand: "Mandira", barcode: "8690000901003", base_price: 189, original_price: 225, stock: 40, status: "Stokta", image: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?auto=format&fit=crop&w=500&q=80", unit: "Paket" },
  { id: 904, name: "Tema Mandıra Doğal Yayık Köy Tereyağı 1000 g", category: "Tema Mandıra", sub_brand: "Mandira", barcode: "8690000901004", base_price: 395, original_price: 450, stock: 28, status: "Stokta", image: "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?auto=format&fit=crop&w=500&q=80", unit: "kg" },
  { id: 905, name: "Tema Mandıra Tam Yağlı Tava Yoğurdu 1500 g", category: "Tema Mandıra", sub_brand: "Mandira", barcode: "8690000901005", base_price: 89.5, original_price: 105, stock: 50, status: "Stokta", image: "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=500&q=80", unit: "Kova" },
  { id: 906, name: "Tema Fırın Sıcak Taş Fırın Erzurum Lavaşı (5'li Paket)", category: "Fırın & Pastane", sub_brand: "Firin", barcode: "8690000901006", base_price: 42, original_price: 50, stock: 60, status: "Stokta", image: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=500&q=80", unit: "Paket" },
  { id: 907, name: "Tema Fırın Geleneksel Tereyağlı Erzurum Ketesi", category: "Fırın & Pastane", sub_brand: "Firin", barcode: "8690000901007", base_price: 38, original_price: 45, stock: 45, status: "Stokta", image: "https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=500&q=80", unit: "Adet" },
  { id: 908, name: "Tema Bakliyat İspir Şeker Fasulyesi (Yerli Hasat) 1 kg", category: "Tema Bakliyat", sub_brand: "Bakliyat", barcode: "8690000901008", base_price: 158, original_price: 185, stock: 70, status: "Stokta", image: "https://images.unsplash.com/photo-1515543904379-3d757afe72e4?auto=format&fit=crop&w=500&q=80", unit: "kg" },
  { id: 909, name: "Tema Bakliyat Gönen Baldo Pirinç 2.5 kg", category: "Tema Bakliyat", sub_brand: "Bakliyat", barcode: "8690000901009", base_price: 182, original_price: 210, stock: 55, status: "Stokta", image: "https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=500&q=80", unit: "Paket" },
  { id: 910, name: "Tema Bakliyat Kırmızı Futbol Mercimek 1 kg", category: "Tema Bakliyat", sub_brand: "Bakliyat", barcode: "8690000901010", base_price: 54.9, original_price: 68, stock: 90, status: "Stokta", image: "https://images.unsplash.com/photo-1515543904379-3d757afe72e4?auto=format&fit=crop&w=500&q=80", unit: "Paket" },
];

const INITIAL_CATEGORIES = [
  { id: 1, name: "Tema Kasaphane (Et & Tavuk)", sub_brand: "Kasap", icon: "🥩", sort_order: 1, is_active: 1 },
  { id: 2, name: "Tema Şarküteri", sub_brand: "Sarkuteri", icon: "🧀", sort_order: 2, is_active: 1 },
  { id: 3, name: "Tema Mandıra (Doğal Süt Ürünleri)", sub_brand: "Mandira", icon: "🥛", sort_order: 3, is_active: 1 },
  { id: 4, name: "Tema Fırın (Taş Fırın & Unlu Mamuller)", sub_brand: "Firin", icon: "🥖", sort_order: 4, is_active: 1 },
  { id: 5, name: "Tema Bakliyat (Yerli Hasat)", sub_brand: "Bakliyat", icon: "🌾", sort_order: 5, is_active: 1 },
  { id: 6, name: "Tema Manav (Meyve & Sebze)", sub_brand: "Manav", icon: "🍎", sort_order: 6, is_active: 1 },
  { id: 7, name: "İçecekler", sub_brand: "Icecek", icon: "🥤", sort_order: 7, is_active: 1 },
];

const INITIAL_CAMPAIGNS = [
  { id: 1, title: "SANALMARKET İLK SİPARİŞE İNDİRİM!", badge: "SANALMARKET ÖZEL", code: "TEMA50", type: "Sabit İndirim", value: 50, min_order_amount: 200, description: "Gezköy OSB ve Erzurum Geneli Aynı Gün Teslimat Fırsatıyla", image: "https://images.unsplash.com/photo-1528825871115-3581a5387919?auto=format&fit=crop&w=800&q=80", bg_gradient: "linear-gradient(135deg, #dc2626 0%, #991b1b 100%)", is_active: 1, target_phone: null },
  { id: 2, title: "TEMA KASAPHANE DANA ETİ VE SUCUKTA ÖZEL FİYAT!", badge: "TEMA KASAPHANE ÖZEL", code: "KASAP30", type: "Yüzde İndirim", value: 20, min_order_amount: 300, description: "Günlük Kesim Taze Yerli Üretim Kasaphane Ürünlerinde Geçerlidir", image: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80", bg_gradient: "linear-gradient(135deg, #1e293b 0%, #0f172a 100%)", is_active: 1, target_phone: null },
  { id: 3, title: "BAHÇEDEN SOFRAYA TAZE MANAV FIRSATLARI!", badge: "TEMA MANAV ÖZEL", code: "HEMEN20", type: "Yüzde İndirim", value: 15, min_order_amount: 150, description: "30 Dakikada Ekspres Kapınıza Teslimat", image: "https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=800&q=80", bg_gradient: "linear-gradient(135deg, #16a34a 0%, #14532d 100%)", is_active: 1, target_phone: null },
];

const INITIAL_BROCHURES = [
  { id: 1, title: "EKİM AYI BÜYÜK TEMA MARKET İNDİRİM KATALOĞU (16 SAYFA KOMPLE BROŞÜR)", description: "Erzurum ve Bölge Şubelerimizde Geçerli Tema Kasaphane, Tema Mandıra, Tema Fırın ve Tema Bakliyat Özel İndirimleri", image_url: "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80", pdf_url: "https://temasanalmarket.com", start_date: "15.10.2026", end_date: "31.10.2026", is_active: 1 },
  { id: 2, title: "TEMA KASAPHANE & MANDIRA HAFTA SONU HALK GÜNÜ BROŞÜRÜ", description: "Yerli Besi Günlük Taze Kesim Dana/Kuzu Et Ürünleri ve Doğal Yayla Süt Ürünlerinde Geçerli İndirim Broşürü", image_url: "https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=1200&q=80", pdf_url: "https://temasanalmarket.com", start_date: "17.10.2026", end_date: "25.10.2026", is_active: 1 },
  { id: 3, title: "TEMA FIRIN & TEMA BAKLİYAT KIŞLIK ERZAK KATALOĞU", description: "Yerli Hasat İspir Fasulyesi, Gönen Baldo Pirinç, Mercimek ve Taş Fırın Unlu Mamullerinde Avantaj Kart Fırsatları", image_url: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1200&q=80", pdf_url: "https://temasanalmarket.com", start_date: "10.10.2026", end_date: "30.10.2026", is_active: 1 },
];

const INITIAL_COURIERS = [
  { id: 1, name: "Ahmet Yılmaz (25 AB 123 - Motosiklet)", phone: "0532 111 22 33", vehicle_type: "Motosiklet", status: "AKTIF" },
  { id: 2, name: "Mehmet Demir (25 EV 456 - Motosiklet)", phone: "0533 444 55 66", vehicle_type: "Motosiklet", status: "AKTIF" },
  { id: 3, name: "Emre Kaya (25 TK 789 - Frigorifik Panelvan)", phone: "0542 777 88 99", vehicle_type: "Frigorifik Panelvan", status: "AKTIF" },
];

const INITIAL_USERS = [
  { id: 1, name: "Yönetici Temasan", phone: "05328883344", role: "SuperAdmin", status: "AKTIF", card_number: "99999995328883344" },
  { id: 2, name: "Kadir Kuzu (Lalapaşa AVM)", phone: "05312213632", role: "Merchant", status: "AKTIF", card_number: "99999995312213632" },
  { id: 3, name: "Ahmet Yılmaz (Kurye)", phone: "05321112233", role: "Courier", status: "AKTIF", card_number: "99999995321112233" },
];

const INITIAL_ORDERS = [
  { id: 1, order_number: "#TEM-84920", customer_name: "Murat Kaya", phone: "0533 222 33 44", customer_phone: "0533 222 33 44", delivery_address: "Şükrüpaşa Mah. İstasyon Cad. No:42 Yakutiye / Erzurum", items_summary: "1x Tema Kasaphane Dana Kuşbaşı 1kg, 1x Tema Mandıra Göğermiş Çeçil 500g", total: 738, total_amount: 738, payment_method: "SANAL_POS", coupon_code: "TEMA50", discount_amount: 50, status: "Hazırlanıyor", created_at: "17.10.2026 14:20", branch_name: "Lalapaşa AVM Şubesi", courier_name: "Ahmet Yılmaz (25 AB 123 - Motosiklet)" },
  { id: 2, order_number: "#TEM-84921", customer_name: "Selim Demir", phone: "0542 333 44 55", customer_phone: "0542 333 44 55", delivery_address: "Yenişehir Mah. Atatürk Blv. No:18 Palandöken / Erzurum", items_summary: "2x Trabzon Ekmeği 800g, 1x İspir Şeker Fasulyesi 1kg", total: 228, total_amount: 228, payment_method: "KAPIDA_SOFTPOS", coupon_code: null, discount_amount: 0, status: "Kuryede", created_at: "17.10.2026 15:05", branch_name: "Yenişehir AVM Şubesi", courier_name: "Mehmet Demir (25 EV 456 - Motosiklet)" },
];

function loadDb() {
  try {
    if (fs.existsSync(DB_PATH)) {
      const parsed = JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
      if (parsed && Array.isArray(parsed.products) && parsed.products.length > 0) {
        return parsed;
      }
    }
  } catch (e) {}
  const initial = {
    products: INITIAL_PRODUCTS,
    categories: INITIAL_CATEGORIES,
    campaigns: INITIAL_CAMPAIGNS,
    brochures: INITIAL_BROCHURES,
    couriers: INITIAL_COURIERS,
    users: INITIAL_USERS,
    orders: INITIAL_ORDERS,
    applications: [
      { id: 101, name: "Serkan Öztürk", phone: "0535 612 44 88", role: "Courier", vehicle_type: "Motosiklet (25 ERZ 44)", city_district: "Yakutiye / Erzurum", status: "ONAY_BEKLIYOR" },
    ],
    sms_logs: [
      { id: 1, created_at: "17.10.2026 10:00", target_type: "CUSTOMERS", message: "Tema Avantaj Kart sahiplerine özel bu hafta sonu Tema Kasaphane ve Tema Mandıra ürünlerinde %20 indirim!", coupon_code: "KASAP30", sent_count: 240 },
    ],
    loyalty_rules: { id: 1, spend_per_point: 10, point_tl_value: 0.1, min_redeem_points: 50, applicable_categories: "Tüm Ürünler" },
    settings: {
      turk_telekom: { username: "temamrkt", password: "VN4Um9Tb", login_password: "K?DXdGPg8tOC", origin: "TEMA MARKET", brand_code: "000000", active_provider: "TURK_TELEKOM" },
      netgsm: { usercode: "8503000000", password: "", msgheader: "TEMA MARKET", endpoint: "https://api.netgsm.com.tr/sms/send/get" },
      pos: { bank_name: "QNB Finansbank Sanal POS", merchant_id: "100298374", terminal_id: "67123984", api_key: "tm_qnb_live_secret", is_test_mode: 0 },
      efatura: { integrator: "Ödeal E-Fatura", username: "temamarket_gib", password: "••••••••", tax_office: "Aziziye Vergi Dairesi", tax_number: "8390192841", is_auto_invoice: 1 },
    },
    job_applications: [],
    user_addresses: {},
  };
  saveDb(initial);
  return initial;
}

function saveDb(db) {
  try {
    fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2), 'utf8');
  } catch (e) {}
}

function readJsonBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk.toString();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        resolve({});
      }
    });
  });
}

function sendJson(res, payload, status = 200) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify(payload));
}

function proxyToLive(req, res, remotePath) {
  const options = {
    hostname: API_TARGET,
    port: 443,
    path: remotePath,
    method: req.method,
    headers: {
      Host: API_TARGET,
      Accept: req.headers['accept'] || '*/*',
      'User-Agent': req.headers['user-agent'] || 'TemaMarket-Server/1.0',
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    const headers = {
      'Access-Control-Allow-Origin': '*',
    };
    if (proxyRes.headers['content-type']) {
      headers['Content-Type'] = proxyRes.headers['content-type'];
    }
    res.writeHead(proxyRes.statusCode || 200, headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    sendJson(res, { success: false, message: err.message, data: [] }, 200);
  });

  req.pipe(proxyReq, { end: true });
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname || '/';
  const query = parsedUrl.query || {};

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Normalize API route path (strip /api/index.php or /api prefix)
  if (pathname.startsWith('/api/')) {
    const route = pathname.replace(/^\/api\/index\.php/, '').replace(/^\/api/, '') || '/';
    if (process.env.USE_LOCAL_MOCK_DB !== '1') {
      const searchStr = parsedUrl.search || '';
      proxyToLive(req, res, '/api/index.php' + route + searchStr);
      return;
    }
    const db = loadDb();

    // 1. Admin Metrics
    if (route === '/admin/metrics') {
      const totalRevenue = db.orders.reduce((sum, o) => sum + (Number(o.total_amount || o.total) || 0), 0) + 1481840;
      return sendJson(res, {
        success: true,
        data: {
          total_users: db.users.length + 240,
          pending_applications: db.applications.length + db.job_applications.length,
          total_orders: db.orders.length + 128,
          total_revenue: totalRevenue,
          active_couriers: db.couriers.length,
        },
      });
    }

    // 2. Products CRUD
    if (route === '/products' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.products });
    }
    if (route === '/products/add' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const newProd = {
        id: Date.now(),
        name: body.name || 'Yeni Ürün',
        category: body.category || 'Genel',
        sub_brand: body.sub_brand || 'Kasap',
        barcode: body.barcode || String(8690000000000 + Math.floor(Math.random() * 999999)),
        base_price: Number(body.base_price) || 0,
        original_price: body.original_price ? Number(body.original_price) : null,
        stock: body.stock !== undefined ? Number(body.stock) : 25,
        status: Number(body.stock) <= 0 ? 'Tükendi' : Number(body.stock) <= 10 ? 'Kritik Stok' : 'Stokta',
        image: body.image || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=400&q=80',
        unit: body.unit || 'Adet',
      };
      db.products.unshift(newProd);
      saveDb(db);
      return sendJson(res, { success: true, data: newProd });
    }
    if (route === '/products/update' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.products = db.products.map((p) => {
        if (String(p.id) === String(body.id)) {
          const nextStock = body.stock !== undefined ? Number(body.stock) : p.stock;
          return {
            ...p,
            ...body,
            base_price: body.base_price !== undefined ? Number(body.base_price) : p.base_price,
            original_price: body.original_price !== undefined ? (body.original_price ? Number(body.original_price) : null) : p.original_price,
            stock: nextStock,
            status: nextStock <= 0 ? 'Tükendi' : nextStock <= 10 ? 'Kritik Stok' : 'Stokta',
          };
        }
        return p;
      });
      saveDb(db);
      return sendJson(res, { success: true, data: db.products });
    }
    if (route === '/products/delete' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.products = db.products.filter((p) => String(p.id) !== String(body.id));
      saveDb(db);
      return sendJson(res, { success: true });
    }
    if (route === '/products/update-stock' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.products = db.products.map((p) =>
        String(p.id) === String(body.product_id) ? { ...p, stock: Number(body.stock) } : p
      );
      saveDb(db);
      return sendJson(res, { success: true });
    }

    // 3. Categories CRUD
    if (route === '/categories' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.categories });
    }
    if (route === '/categories/add' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const newCat = {
        id: Date.now(),
        name: body.name || 'Yeni Kategori',
        sub_brand: body.sub_brand || 'Kasap',
        icon: body.icon || '🛍️',
        sort_order: Number(body.sort_order) || db.categories.length + 1,
        is_active: 1,
      };
      db.categories.push(newCat);
      saveDb(db);
      return sendJson(res, { success: true, data: newCat });
    }
    if (route === '/categories/delete' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.categories = db.categories.filter((c) => String(c.id) !== String(body.id));
      saveDb(db);
      return sendJson(res, { success: true });
    }

    // 4. Campaigns CRUD
    if (route === '/campaigns' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.campaigns });
    }
    if (route === '/campaigns/add' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const newCamp = {
        id: Date.now(),
        title: body.title || 'Yeni Kampanya',
        badge: body.badge || 'FIRSAT',
        code: body.code || 'TEMA20',
        description: body.description || '',
        type: body.type || 'Yüzde İndirim',
        value: Number(body.value) || 20,
        min_order_amount: Number(body.min_order_amount) || 200,
        target_product_name: body.target_product_name || null,
        image: body.image || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=800&q=80',
        bg_gradient: body.bg_gradient || 'linear-gradient(135deg, #dc2626 0%, #991b1b 100%)',
        is_active: 1,
      };
      db.campaigns.unshift(newCamp);
      saveDb(db);
      return sendJson(res, { success: true, data: newCamp });
    }
    if (route === '/campaigns/toggle' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.campaigns = db.campaigns.map((c) =>
        String(c.id) === String(body.id) ? { ...c, is_active: Number(body.is_active) } : c
      );
      saveDb(db);
      return sendJson(res, { success: true });
    }
    if (route === '/campaigns/delete' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.campaigns = db.campaigns.filter((c) => String(c.id) !== String(body.id));
      saveDb(db);
      return sendJson(res, { success: true });
    }

    // 5. Brochures CRUD
    if (route === '/brochures' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.brochures });
    }
    if (route === '/admin/brochures/add' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const newBr = {
        id: Date.now(),
        title: body.title || 'Yeni Broşür',
        description: body.description || '',
        image_url: body.image_url || 'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80',
        pdf_url: body.pdf_url || '',
        start_date: body.start_date || new Date().toLocaleDateString('tr-TR'),
        end_date: body.end_date || '31.10.2026',
        is_active: 1,
      };
      db.brochures.unshift(newBr);
      saveDb(db);
      return sendJson(res, { success: true, data: newBr });
    }
    if (route === '/admin/brochures/delete' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.brochures = db.brochures.filter((b) => String(b.id) !== String(body.id));
      saveDb(db);
      return sendJson(res, { success: true });
    }

    // 6. Orders & Couriers
    if (route === '/orders' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.orders });
    }
    if (route === '/orders/create' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const created = {
        id: Date.now(),
        order_number: '#TEM-' + Math.floor(10000 + Math.random() * 90000),
        customer_name: body.customer_name || 'Müşteri',
        phone: body.phone || '',
        customer_phone: body.phone || '',
        delivery_address: body.delivery_address || '',
        items: body.items || [],
        items_summary: Array.isArray(body.items) ? body.items.map((i) => `${i.quantity}x ${i.name}`).join(', ') : '',
        total: Number(body.total_amount) || 0,
        total_amount: Number(body.total_amount) || 0,
        payment_method: body.payment_method || 'SANAL_POS',
        status: 'Hazırlanıyor',
        created_at: new Date().toLocaleString('tr-TR'),
        branch_name: body.branch_name || 'Lalapaşa AVM Şubesi',
        courier_name: null,
      };
      db.orders.unshift(created);
      saveDb(db);
      return sendJson(res, { success: true, data: created, message: 'Siparişiniz başarıyla oluşturuldu!' });
    }
    if (route === '/orders/assign-courier' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.orders = db.orders.map((o) =>
        String(o.id) === String(body.order_id)
          ? { ...o, courier_id: body.courier_id, courier_name: body.courier_name, status: 'Kuryede' }
          : o
      );
      saveDb(db);
      return sendJson(res, { success: true });
    }
    if (route === '/orders/update-status' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.orders = db.orders.map((o) =>
        String(o.id) === String(body.order_id) ? { ...o, status: body.status } : o
      );
      saveDb(db);
      return sendJson(res, { success: true });
    }
    if (route === '/couriers' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.couriers });
    }

    // 7. Users & Applications
    if (route === '/admin/users' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.users });
    }
    if (route === '/admin/users/add' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const digits = String(body.phone || '').replace(/[^0-9]/g, '').slice(-10);
      const newUser = {
        id: Date.now(),
        name: body.name || 'Kullanıcı',
        phone: body.phone || '',
        role: body.role || 'Customer',
        status: body.status || 'AKTIF',
        card_number: digits.length === 10 ? '9999999' + digits : null,
      };
      db.users = [newUser, ...db.users.filter((u) => u.phone !== newUser.phone)];
      saveDb(db);
      return sendJson(res, { success: true, data: newUser });
    }
    if (route === '/admin/users/update' && req.method === 'POST') {
      const body = await readJsonBody(req);
      db.users = db.users.map((u) => (String(u.id) === String(body.id) ? { ...u, ...body } : u));
      saveDb(db);
      return sendJson(res, { success: true });
    }
    if (route === '/admin/applications' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.applications });
    }
    if (route === '/auth/register-application' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const app = { id: Date.now(), ...body, status: 'ONAY_BEKLIYOR' };
      db.applications.unshift(app);
      saveDb(db);
      return sendJson(res, { success: true, data: app });
    }
    if (route === '/admin/approve-application' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const found = db.applications.find((a) => String(a.id) === String(body.user_id));
      db.applications = db.applications.filter((a) => String(a.id) !== String(body.user_id));
      if (found && body.action === 'APPROVE') {
        db.users.unshift({
          id: found.id,
          name: found.name,
          phone: found.phone,
          role: found.role || 'Courier',
          status: 'AKTIF',
        });
        if (found.role === 'Courier') {
          db.couriers.push({
            id: found.id,
            name: `${found.name} (${found.vehicle_type || 'Motosiklet'})`,
            phone: found.phone,
            status: 'AKTIF',
          });
        }
      }
      saveDb(db);
      return sendJson(res, { success: true });
    }

    // 8. Job Applications (İş Başvuru Formu)
    if (route === '/job-applications') {
      if (req.method === 'POST') {
        const body = await readJsonBody(req);
        const item = { id: Date.now(), ...body, created_at: body.created_at || new Date().toLocaleString('tr-TR') };
        db.job_applications.unshift(item);
        saveDb(db);
        return sendJson(res, { success: true, data: item });
      }
      return sendJson(res, { success: true, data: db.job_applications });
    }

    // 9. SMS & Loyalty & Settings
    if (route === '/admin/send-sms' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const logItem = {
        id: Date.now(),
        created_at: new Date().toLocaleString('tr-TR'),
        target_type: body.target_type || 'ALL',
        target_phone: body.target_phone || null,
        message: body.message || '',
        coupon_code: body.coupon_code || null,
        sent_count: body.target_type === 'SINGLE' ? 1 : db.users.length + 240,
      };
      db.sms_logs.unshift(logItem);
      saveDb(db);
      return sendJson(res, { success: true, message: 'SMS gönderimi başarıyla tamamlandı ve loglara kaydedildi.', data: logItem });
    }
    if (route === '/admin/sms-logs' && req.method === 'GET') {
      return sendJson(res, { success: true, data: db.sms_logs });
    }
    if (route === '/loyalty/rules') {
      if (req.method === 'POST') {
        const body = await readJsonBody(req);
        db.loyalty_rules = { ...db.loyalty_rules, ...body };
        saveDb(db);
        return sendJson(res, { success: true, data: db.loyalty_rules });
      }
      return sendJson(res, { success: true, data: db.loyalty_rules });
    }
    if (route === '/loyalty/points') {
      return sendJson(res, { success: true, points: 250, tl_value: 25, transactions: [] });
    }
    if (route.startsWith('/settings/')) {
      const key = route.replace('/settings/', '').replace('-', '_');
      if (req.method === 'POST') {
        const body = await readJsonBody(req);
        db.settings[key] = { ...(db.settings[key] || {}), ...body };
        saveDb(db);
        return sendJson(res, { success: true, data: db.settings[key] });
      }
      return sendJson(res, { success: true, data: db.settings[key] || {} });
    }

    // 10. User Profile, Addresses & Orders
    if (route === '/user/profile') {
      const phone = query.phone || '';
      const u = db.users.find((x) => x.phone === phone) || null;
      return sendJson(res, { success: true, data: u });
    }
    if (route === '/user/profile/update' && req.method === 'POST') {
      const body = await readJsonBody(req);
      return sendJson(res, { success: true, data: body });
    }
    if (route === '/user/addresses' && req.method === 'GET') {
      const phone = query.phone || 'default';
      return sendJson(res, { success: true, data: db.user_addresses[phone] || [] });
    }
    if (route === '/user/addresses/add' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const phone = body.phone || 'default';
      if (!db.user_addresses[phone]) db.user_addresses[phone] = [];
      const addr = { id: Date.now(), ...body };
      db.user_addresses[phone].push(addr);
      saveDb(db);
      return sendJson(res, { success: true, data: addr });
    }
    if (route === '/user/addresses/delete' && req.method === 'POST') {
      const body = await readJsonBody(req);
      const phone = body.phone || 'default';
      if (db.user_addresses[phone]) {
        db.user_addresses[phone] = db.user_addresses[phone].filter((a) => String(a.id) !== String(body.id));
        saveDb(db);
      }
      return sendJson(res, { success: true });
    }
    if (route === '/user/orders' && req.method === 'GET') {
      const phone = query.phone || '';
      const list = phone ? db.orders.filter((o) => String(o.phone).includes(phone)) : [];
      return sendJson(res, { success: true, data: list });
    }

    // Fallback to live API for auth/send-otp or any other endpoint
    proxyToLive(req, res, '/api/index.php' + route);
    return;
  }

  // Serve static files from web_dist
  const safePath = path.normalize(pathname).replace(/^(\.\.[\/\\])+/, '');
  const localFilePath = path.join(WEB_DIST, safePath);

  if (pathname !== '/' && fs.existsSync(localFilePath) && fs.statSync(localFilePath).isFile()) {
    const ext = path.extname(localFilePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': MIME_TYPES[ext] || 'application/octet-stream' });
    fs.createReadStream(localFilePath).pipe(res);
    return;
  }

  // Proxy static images like /tema_insaat_projeler.png from live temasanalmarket.com if not in web_dist
  if (/\.(png|jpg|jpeg|svg|webp|gif|ico|pdf)$/i.test(pathname)) {
    proxyToLive(req, res, pathname);
    return;
  }

  // SPA Fallback -> web_dist/index.html
  const indexHtmlPath = path.join(WEB_DIST, 'index.html');
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  fs.createReadStream(indexHtmlPath).pipe(res);
});

server.listen(PORT, () => {
  console.log(`\n=============================================================`);
  console.log(`  ★ temamarket.com (Gerçek Sistem + Tam Fonksiyonel ERP) Hazır!`);
  console.log(`  🌐 Ana Sayfa & Sanal Market : http://localhost:${PORT}`);
  console.log(`  🥩 Tema Kasaphane Subdomain : http://localhost:${PORT}/?subdomain=kasap`);
  console.log(`  🥛 Tema Mandıra Subdomain   : http://localhost:${PORT}/?subdomain=mandira`);
  console.log(`  🥖 Tema Fırın Subdomain     : http://localhost:${PORT}/?subdomain=firin`);
  console.log(`  🌾 Tema Bakliyat Subdomain  : http://localhost:${PORT}/?subdomain=bakliyat`);
  console.log(`  🛠️  TEMA ERP Yönetici Paneli : http://localhost:${PORT}/admin`);
  console.log(`=============================================================\n`);
});
