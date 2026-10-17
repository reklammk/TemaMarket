/**
 * temamarket.com & Yönetim Paneli - Tam Fonksiyonel Yerel Test ve Önizleme Sunucusu
 * Çalıştırma: node web_test_server.js
 * Erişim: http://localhost:3000 veya http://127.0.0.1:3000
 */

const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');

const PORT = 3000;

// ==========================================
// CANLI VERİ TABANI (Bellek İçi Mock Veritabanı)
// ==========================================
let subdomainPages = [
  {
    id: 1,
    title: 'Tema Kasaphane',
    subdomain: 'kasap',
    full_url: 'https://kasap.temamarket.com',
    category: 'Kasap',
    slogan: 'Kendi Kasaphanemizden Sofranıza Güven ve Tazelik',
    description: 'Kesim anından veteriner kontrolüne ve soğuk zincir şube sevkine kadar %100 yerli besi, helal kesim et ürünleri.',
    banner_url: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=1200&q=80',
    theme_color: '#DC2626',
    is_active: true,
    features: ['%100 Yerli Besi', 'Canlı Kesim & Sevk Takibi', 'Veteriner Hekim Onaylı', 'Soğuk Zincir Lojistiği']
  },
  {
    id: 2,
    title: 'Tema Mandıra',
    subdomain: 'mandira',
    full_url: 'https://mandira.temamarket.com',
    category: 'Mandıra',
    slogan: 'Erzurum ve Doğu Yaylalarından Doğal Çiftlik Lezzetleri',
    description: 'Geleneksel yöntemlerle üretilen taze tereyağı, göğermiş peynir, çeçil ve köy yoğurtları.',
    banner_url: 'https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=1200&q=80',
    theme_color: '#0284C7',
    is_active: true,
    features: ['Yayık Tereyağı', 'Hakiki Göğermiş Peynir', 'Günlük Çiftlik Sütü']
  },
  {
    id: 3,
    title: 'Tema Fırın',
    subdomain: 'firin',
    full_url: 'https://firin.temamarket.com',
    category: 'Fırın',
    slogan: 'Günün Her Saati Taş Fırından Taptaze Sıcak Unlu Mamuller',
    description: 'Ekşi mayalı köy ekmeği, geleneksel lavaş, çıtır simit ve enfes pasta çeşitleri.',
    banner_url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=1200&q=80',
    theme_color: '#D97706',
    is_active: true,
    features: ['Taş Fırın Ekşi Maya', 'Tandır Lavaşı', 'Taze Pasta & Tatlı']
  },
  {
    id: 4,
    title: 'Tema Bakliyat',
    subdomain: 'bakliyat',
    full_url: 'https://bakliyat.temamarket.com',
    category: 'Bakliyat',
    slogan: 'Anadolu Topraklarının Bereketli ve Doğal Mahsulleri',
    description: 'Özenle seçilmiş Dermason fasulye, Koçbaşı nohut, kırmızı mercimek ve pilavlık bulgur.',
    banner_url: 'https://images.unsplash.com/photo-1515543237350-b3eea1ec8082?w=1200&q=80',
    theme_color: '#059669',
    is_active: true,
    features: ['Yöresel Hasat', 'Katkısız ve Doğal', 'Yüksek Lif ve Protein']
  },
  {
    id: 5,
    title: 'Tema Şarküteri',
    subdomain: 'sarkuteri',
    full_url: 'https://sarkuteri.temamarket.com',
    category: 'Şarküteri',
    slogan: 'Geleneksel Türk Kahvaltısının Seçkin Lezzetleri',
    description: 'Özel baharatlı sucuk, pastırma, Gemlik zeytinleri ve bal petekleri.',
    banner_url: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=1200&q=80',
    theme_color: '#E11D48',
    is_active: true,
    features: ['Kayseri Evlik Sucuk', 'Antrikot Pastırma', 'Doğal Petek Bal']
  },
  {
    id: 6,
    title: 'Tema İnşaat & Gayrimenkul',
    subdomain: 'insaat',
    full_url: 'https://insaat.temamarket.com',
    category: 'İnşaat',
    slogan: 'Güvenli Gelecek, Modern ve Sağlam Yaşam Alanları',
    description: 'Tema Şirketler Grubu güvencesiyle konut, ticari alan ve perakende mağaza inşaat projeleri.',
    banner_url: 'https://images.unsplash.com/photo-1541888946425-d0fbb18086f6?w=1200&q=80',
    theme_color: '#475569',
    is_active: true,
    features: ['Depreme Dayanıklı Mimari', 'Ticari Plaza Projeleri', 'Modern Yaşam Kompleksleri']
  }
];

let jobApplications = [
  {
    id: 1,
    name: 'Ahmet Yılmaz',
    phone: '0532 111 22 33',
    email: 'ahmet.yilmaz@gmail.com',
    position: 'Kasap Ustası',
    preferred_branch: 'Erzurum / Şükrüpaşa Şubesi',
    experience_years: '7 yıl',
    notes: 'Büyükbaş ve küçükbaş karkas parçalama ve reyon hazırlığında tecrübeli.',
    applied_at: '17.10.2026 14:30',
    status: 'İnceleniyor'
  },
  {
    id: 2,
    name: 'Elif Demir',
    phone: '0544 555 66 77',
    email: 'elif.demir@hotmail.com',
    position: 'Kasiyer & Müşteri Temsilcisi',
    preferred_branch: 'Erzurum / Yıldızkent Şubesi',
    experience_years: '3 yıl',
    notes: 'Market barkod ve Soft POS sistemlerine hakimim.',
    applied_at: '17.10.2026 15:10',
    status: 'Yeni'
  },
  {
    id: 3,
    name: 'Murat Kara',
    phone: '0535 999 88 11',
    email: 'murat.k@gmail.com',
    position: 'Motorlu Kurye',
    preferred_branch: 'Erzurum / Dadaşkent Şubesi',
    experience_years: '4 yıl',
    notes: 'A2 ehliyetim ve kendi motorum var, navigasyon ve bölgeye hakimim.',
    applied_at: '17.10.2026 15:45',
    status: 'Mülakat Çağrıldı'
  }
];

let kasaphaneRecords = [
  {
    id: 'KS-2026-104',
    title: 'Erzurum Yayla Besi Dana Partisi #104',
    date: '17.10.2026',
    status: 'Şubelere Sevk Edildi',
    step: 4,
    veterinary_approval: 'Uzm. Vet. Hekim Dr. Mehmet Kaya - Rapor No: 2026/894',
    origin: 'Palandöken Yüksek Rakım Doğal Besi Çiftliği',
    carcass_count: '18 Adet Dana Karkas',
    target_branches: 'Şükrüpaşa, Yıldızkent, Dadaşkent',
    cold_chain_temp: '+2.4 °C (Soğuk Zincir Araç Takip Aktif)',
    media_url: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800&q=80',
    notes: 'Tüm sağlık kontrolleri tamamlanmış, dinlendirme odasında 48 saat olgunlaştırılmıştır.'
  },
  {
    id: 'KS-2026-105',
    title: 'Kuzu Karkas Kesim & Dinlendirme Partisi #105',
    date: '17.10.2026',
    status: 'Soğuk Hava Deposunda Dinlendiriliyor',
    step: 3,
    veterinary_approval: 'Vet. Hekim Selim Aksoy - Rapor No: 2026/895',
    origin: 'Tekman & Hınıs Doğal Otlak Sürüsü',
    carcass_count: '45 Adet Kuzu Karkas',
    target_branches: 'Tüm Şubeler',
    cold_chain_temp: '+1.8 °C',
    media_url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
    notes: 'Kesim İslami usullere uygun olarak tek tek tekbir ile gerçekleştirilmiştir.'
  }
];

let corporateEntities = [
  {
    id: 1,
    name: 'Tema İnşaat & Taahhüt A.Ş.',
    slug: 'insaat',
    sector: 'İnşaat & Gayrimenkul',
    description: 'Depreme dayanıklı modern konut projeleri, iş merkezleri ve ticari süpermarket yapıları.',
    badge: 'Tema Grup Şirketi',
    banner_url: 'https://images.unsplash.com/photo-1541888946425-d0fbb18086f6?w=800&q=80',
    projects_count: 14,
    contact_phone: '0442 234 50 00',
    website: 'https://insaat.temamarket.com'
  },
  {
    id: 2,
    name: 'Tema Lojistik & Soğuk Hava Depoculuğu',
    slug: 'lojistik',
    sector: 'Gıda Lojistiği & Tedarik',
    description: 'Özmal frigorifik araç filosu ile tarladan ve kasaphaneden şubelere kesintisiz soğuk zincir.',
    badge: 'Tema Grup Şirketi',
    banner_url: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800&q=80',
    projects_count: 8,
    contact_phone: '0442 234 50 01',
    website: 'https://temamarket.com'
  }
];

let campaigns = [
  {
    id: 1,
    title: 'Büyük Ekim Halk İndirimi Broşürü',
    type: 'brochure',
    badge: 'Haftanın Broşürü',
    discount: '%40 Varan İndirim',
    valid_until: '25 Ekim 2026',
    image: 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?w=800&q=80',
    pdf_url: 'https://temamarket.com/brosurler/ekim-2026.pdf'
  },
  {
    id: 2,
    title: 'Tema Kasaphane Taze Dana Kıyma',
    type: 'spot',
    badge: 'Kasaphane Özel',
    discount: '420 TL / Kg (Önceki 480 TL)',
    valid_until: 'Stoklarla Sınırlı',
    image: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=800&q=80'
  },
  {
    id: 3,
    title: 'Tema Mandıra Doğal Köy Tereyağı',
    type: 'spot',
    badge: 'Mandıra Fırsatı',
    discount: '290 TL / Kg',
    valid_until: 'Bu Hafta',
    image: 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=800&q=80'
  }
];

// ==========================================
// YARDIMCI HTML ŞABLON MOTORU
// ==========================================
function renderHeader(activeNav = 'home') {
  return `
    <header class="bg-white border-b border-slate-200 sticky top-0 z-50 shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
        <!-- Logo -->
        <a href="/" class="flex items-center gap-3 group">
          <div class="bg-gradient-to-r from-red-600 to-rose-600 text-white px-3.5 py-1.5 rounded-full flex items-center gap-1.5 shadow-md shadow-red-500/20 group-hover:scale-105 transition-transform">
            <span class="text-amber-300 text-lg">★</span>
            <span class="font-black text-xl tracking-wider">TEMA</span>
          </div>
          <span class="font-black text-2xl text-red-600 tracking-tight">market.com</span>
        </a>

        <!-- Navigation -->
        <nav class="hidden md:flex items-center gap-1 lg:gap-2">
          <a href="/" class="px-3 py-2 rounded-lg font-bold text-sm ${activeNav === 'home' ? 'text-red-600 bg-red-50' : 'text-slate-700 hover:bg-slate-100'}">Ana Sayfa</a>
          <a href="/?sanal=1" class="px-3 py-2 rounded-lg font-bold text-sm ${activeNav === 'sanal' ? 'text-emerald-700 bg-emerald-50' : 'text-emerald-700 hover:bg-emerald-50'} flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
            Sanal Market
          </a>
          <div class="relative group">
            <button class="px-3 py-2 rounded-lg font-bold text-sm text-slate-700 hover:bg-slate-100 flex items-center gap-1">
              Reyonlar & Portallar
              <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
            </button>
            <div class="absolute left-0 mt-2 w-64 bg-white border border-slate-200 rounded-2xl shadow-xl py-2 hidden group-hover:block transition-all z-50">
              ${subdomainPages.map(sub => `
                <a href="/subdomain/${sub.subdomain}" class="flex items-center justify-between px-4 py-2.5 hover:bg-slate-50 transition-colors">
                  <span class="font-bold text-slate-800 text-sm">${sub.title}</span>
                  <span class="text-xs bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full">${sub.subdomain}.temamarket.com</span>
                </a>
              `).join('')}
            </div>
          </div>
          <a href="#brosurler" class="px-3 py-2 rounded-lg font-bold text-sm text-slate-700 hover:bg-slate-100">Broşürler</a>
          <a href="#kariyer" class="px-3 py-2 rounded-lg font-bold text-sm text-slate-700 hover:bg-slate-100">Kariyer</a>
        </nav>

        <!-- Action Buttons -->
        <div class="flex items-center gap-3">
          <a href="/admin" class="inline-flex items-center gap-2 bg-slate-900 hover:bg-slate-800 text-white px-4 py-2 rounded-full font-bold text-sm shadow transition-all hover:scale-105">
            <svg class="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
            Yönetim Paneli
          </a>
          <button onclick="document.getElementById('kartModal').classList.remove('hidden')" class="inline-flex items-center gap-1.5 bg-gradient-to-r from-red-600 to-rose-600 text-white px-4 py-2 rounded-full font-bold text-sm shadow shadow-red-500/30 hover:opacity-95 transition-all">
            <span class="text-amber-300">★</span>
            Tema Avantaj Kart
          </button>
        </div>
      </div>
    </header>
  `;
}

function renderFooter() {
  return `
    <footer class="bg-slate-900 text-slate-400 py-12 border-t border-slate-800 mt-20">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 grid grid-cols-1 md:grid-cols-4 gap-8">
        <div>
          <div class="flex items-center gap-2 mb-4">
            <span class="bg-red-600 text-white px-3 py-1 rounded-full font-black text-sm">★ TEMA</span>
            <span class="font-black text-xl text-white">market.com</span>
          </div>
          <p class="text-sm leading-relaxed text-slate-400">
            Erzurum'un taze, güvenilir ve kaliteli alışveriş merkezi. Kendi kasaphanemizden sofranıza %100 yerli lezzetler.
          </p>
        </div>
        <div>
          <h4 class="text-white font-bold mb-3">Subdomain Sayfalarımız</h4>
          <ul class="space-y-2 text-sm">
            ${subdomainPages.map(sub => `
              <li><a href="/subdomain/${sub.subdomain}" class="hover:text-red-400 transition-colors">${sub.title} (${sub.subdomain}.temamarket.com)</a></li>
            `).join('')}
          </ul>
        </div>
        <div>
          <h4 class="text-white font-bold mb-3">Hızlı Bağlantılar</h4>
          <ul class="space-y-2 text-sm">
            <li><a href="/?sanal=1" class="hover:text-white transition-colors">Sanal Market Kapında Teslimat</a></li>
            <li><a href="/admin" class="hover:text-white transition-colors">Yönetici Paneli (Tam Yetki)</a></li>
            <li><a href="#kariyer" class="hover:text-white transition-colors">İş Başvuru & CV Formu</a></li>
            <li><a href="https://temamarket.com/kvkk" target="_blank" class="hover:text-white transition-colors">KVKK & Gizlilik Politikası</a></li>
          </ul>
        </div>
        <div>
          <h4 class="text-white font-bold mb-3">Müşteri Hizmetleri</h4>
          <p class="text-sm text-slate-400 mb-2">Telefon: 0850 300 00 00</p>
          <p class="text-sm text-slate-400 mb-2">E-posta: destek@temamarket.com</p>
          <p class="text-xs text-slate-500 mt-4">© 2026 temamarket.com. Tüm hakları saklıdır.</p>
        </div>
      </div>
    </footer>
  `;
}

// ==========================================
// ANA SAYFA HTML OLUŞTURUCU
// ==========================================
function renderHomePage(isSanal = false) {
  return `
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>temamarket.com | TEMA Market & Sanal Market</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>
      body { font-family: 'Plus Jakarta Sans', sans-serif; }
    </style>
  </head>
  <body class="bg-slate-50 text-slate-800 antialiased min-h-screen flex flex-col justify-between">
    <div>
      ${renderHeader(isSanal ? 'sanal' : 'home')}

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-12">

        <!-- 1. HERO BÖLÜMÜ: REKLAM & TANITIM & SANAL MARKET AYRIMI -->
        <section class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          <div class="lg:col-span-7 space-y-6">
            <div class="inline-flex items-center gap-2 bg-red-100 text-red-700 px-4 py-1.5 rounded-full text-xs font-black tracking-wide uppercase">
              <span>⭐</span> YENİ NESİL ALIŞVERİŞ VE MARKA DENEYİMİ
            </div>
            <h1 class="text-4xl sm:text-5xl font-black text-slate-900 leading-tight">
              Erzurum'un Öncü Marketi <br>
              <span class="text-transparent bg-clip-text bg-gradient-to-r from-red-600 via-rose-600 to-amber-500">
                temamarket.com
              </span>
            </h1>
            <p class="text-lg text-slate-600 leading-relaxed font-medium">
              Kendi modern tesislerimizde hazırlanan <strong>Tema Kasaphane</strong>, yayla mandırası, sıcak fırın ve yöresel ürünler tek çatı altında. Dilerseniz mağazalarımızda gezin, dilerseniz Sanal Market ile kapınıza gelsin!
            </p>

            <div class="flex flex-wrap gap-4 pt-2">
              <a href="/?sanal=1" class="inline-flex items-center gap-3 bg-emerald-600 hover:bg-emerald-700 text-white px-7 py-4 rounded-2xl font-black text-base shadow-xl shadow-emerald-600/25 transition-all hover:-translate-y-1">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path></svg>
                Sanal Markete Geçiş Yap ➔
              </a>
              <a href="#reyonlar" class="inline-flex items-center gap-2 bg-white hover:bg-slate-100 text-slate-800 border-2 border-slate-200 px-6 py-4 rounded-2xl font-bold text-base transition-all">
                Özel Reyon Portalları
              </a>
            </div>

            <!-- Hızlı Bilgi Rozetleri -->
            <div class="grid grid-cols-3 gap-4 pt-4 border-t border-slate-200">
              <div>
                <span class="block text-2xl font-black text-slate-900">12+</span>
                <span class="text-xs text-slate-500 font-bold">Merkez Şube</span>
              </div>
              <div>
                <span class="block text-2xl font-black text-red-600">%100</span>
                <span class="text-xs text-slate-500 font-bold">Yerli Besi Kasaphane</span>
              </div>
              <div>
                <span class="block text-2xl font-black text-emerald-600">30 Dk</span>
                <span class="text-xs text-slate-500 font-bold">Hızlı Kapında Teslimat</span>
              </div>
            </div>
          </div>

          <!-- Sağ Taraf: Sanal Market Teşvik Kartı & Görsel -->
          <div class="lg:col-span-5">
            <div class="relative bg-gradient-to-br from-slate-900 via-slate-800 to-red-950 p-8 rounded-3xl text-white shadow-2xl border border-red-900/50 overflow-hidden">
              <div class="absolute -right-12 -top-12 w-48 h-48 bg-red-600/20 rounded-full blur-3xl pointer-events-none"></div>
              
              <div class="flex items-center justify-between mb-6">
                <div class="flex items-center gap-2">
                  <span class="bg-red-600 text-white text-xs font-black px-2.5 py-1 rounded-full">★ TEMA AVANTAJ</span>
                  <span class="text-xs text-amber-300 font-bold">Dijital Kartım</span>
                </div>
                <span class="text-xs text-slate-400">17 Haneli Numara</span>
              </div>

              <div class="space-y-4">
                <div class="text-sm text-slate-300">Tema Avantaj Kart No:</div>
                <div class="font-mono text-2xl sm:text-3xl font-black tracking-widest text-amber-400 bg-slate-900/80 p-3 rounded-xl border border-slate-700 text-center">
                  99999995372668092
                </div>
                <div class="flex justify-between items-center text-xs text-slate-300 pt-2">
                  <span>Müşteri: <strong>Ahmet Yılmaz</strong></span>
                  <span>Biriken Puan: <strong class="text-emerald-400">350 Puan (35 TL)</strong></span>
                </div>
              </div>

              <div class="mt-8 pt-6 border-t border-slate-800 flex items-center justify-between">
                <button onclick="document.getElementById('kartModal').classList.remove('hidden')" class="w-full bg-red-600 hover:bg-red-700 text-white font-bold py-3 rounded-xl text-center text-sm transition-colors">
                  Barkodu Göster & Puan Harca
                </button>
              </div>
            </div>
          </div>
        </section>

        <!-- 2. SUBDOMAIN PORTALLARI & ÖZEL REYON SAYFALARI (YÖNETİCİ TARAFINDAN YÖNETİLEN) -->
        <section id="reyonlar" class="space-y-6 pt-8">
          <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
            <div>
              <div class="inline-flex items-center gap-1.5 text-xs font-black text-red-600 uppercase tracking-wider">
                <span>🌐</span> DİNAMİK SUBDOMAIN SAYFALARI
              </div>
              <h2 class="text-3xl font-black text-slate-900">Özel Reyon & Şirket Portallarımız</h2>
              <p class="text-slate-600 text-sm mt-1">Yönetici panelinden dilediğiniz an yeni subdomain tanımlayabilir, içeriğini canlı güncelleyebilirsiniz.</p>
            </div>
            <a href="/admin#subdomains" class="inline-flex items-center gap-2 text-sm font-bold text-red-600 hover:text-red-700">
              Yönetici Paneli'nden Sayfa Yönet ➔
            </a>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            ${subdomainPages.map(sub => `
              <div class="bg-white rounded-3xl border border-slate-200 shadow-sm hover:shadow-xl transition-all duration-300 flex flex-col justify-between overflow-hidden group">
                <div class="relative h-48 overflow-hidden bg-slate-100">
                  <img src="${sub.banner_url}" alt="${sub.title}" class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500">
                  <div class="absolute top-4 left-4 bg-slate-900/90 backdrop-blur-md text-white text-xs font-black px-3 py-1.5 rounded-full flex items-center gap-1.5 shadow">
                    <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
                    ${sub.subdomain}.temamarket.com
                  </div>
                  <div class="absolute top-4 right-4 bg-white/90 backdrop-blur-md text-slate-800 text-xs font-black px-3 py-1.5 rounded-full shadow">
                    ${sub.category}
                  </div>
                </div>

                <div class="p-6 space-y-4 flex-1 flex flex-col justify-between">
                  <div>
                    <h3 class="text-xl font-black text-slate-900 mb-1 group-hover:text-red-600 transition-colors">${sub.title}</h3>
                    <p class="text-xs font-bold text-red-600 uppercase tracking-wide mb-2">${sub.slogan}</p>
                    <p class="text-slate-600 text-sm leading-relaxed line-clamp-2">${sub.description}</p>
                  </div>

                  <div class="space-y-3 pt-4 border-t border-slate-100">
                    <div class="flex flex-wrap gap-1.5">
                      ${(sub.features || []).map(f => `
                        <span class="text-xs bg-slate-100 text-slate-700 font-semibold px-2.5 py-1 rounded-full">${f}</span>
                      `).join('')}
                    </div>

                    <a href="/subdomain/${sub.subdomain}" class="w-full inline-flex items-center justify-center gap-2 bg-slate-900 hover:bg-red-600 text-white font-black text-sm py-3 rounded-xl transition-colors">
                      Subdomain Sayfasına Git (${sub.subdomain}) ➔
                    </a>
                  </div>
                </div>
              </div>
            `).join('')}
          </div>
        </section>

        <!-- 3. TEMA KASAPHANE CANLI SÜREÇ & ŞUBE SEVK TAKİBİ -->
        <section class="bg-gradient-to-br from-red-900 to-slate-950 text-white p-8 sm:p-12 rounded-3xl shadow-xl space-y-8">
          <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
            <div class="space-y-2">
              <div class="inline-flex items-center gap-2 bg-red-800/60 border border-red-600/50 text-amber-300 text-xs font-black px-3 py-1 rounded-full">
                <span>🛡️</span> ŞEFFAF VE GÜVENİLİR ÜRETİM
              </div>
              <h2 class="text-3xl font-black">Tema Kasaphane: Kesimden Şubeye Canlı Süreç</h2>
              <p class="text-slate-300 text-sm max-w-2xl leading-relaxed">
                Yönetici panelimizden partinin kesim, veteriner muayenesi, soğuk oda dinlendirme ve şubelere sevk aşamaları anlık işlenir; müşterilerimiz QR kod veya panelden takip eder.
              </p>
            </div>
            <a href="/subdomain/kasap" class="inline-flex items-center gap-2 bg-white text-slate-900 hover:bg-slate-100 px-6 py-3.5 rounded-2xl font-black text-sm shadow transition-all">
              Kasaphane Portalına Git ➔
            </a>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            ${kasaphaneRecords.map(rec => `
              <div class="bg-slate-900/80 border border-slate-800 p-6 rounded-2xl space-y-4">
                <div class="flex justify-between items-start">
                  <div>
                    <span class="text-xs font-mono font-bold text-amber-400 bg-amber-400/10 px-2.5 py-1 rounded-md">${rec.id}</span>
                    <h3 class="text-lg font-black text-white mt-2">${rec.title}</h3>
                  </div>
                  <span class="text-xs bg-emerald-500/20 text-emerald-400 font-bold px-3 py-1 rounded-full border border-emerald-500/30">
                    ${rec.status}
                  </span>
                </div>

                <div class="grid grid-cols-2 gap-3 text-xs bg-slate-950/60 p-3 rounded-xl border border-slate-800/80">
                  <div><span class="text-slate-400">Veteriner Onayı:</span> <br><strong class="text-white">${rec.veterinary_approval}</strong></div>
                  <div><span class="text-slate-400">Menşei:</span> <br><strong class="text-white">${rec.origin}</strong></div>
                  <div><span class="text-slate-400">Sevk Şubeleri:</span> <br><strong class="text-white">${rec.target_branches}</strong></div>
                  <div><span class="text-slate-400">Soğuk Zincir Sıcaklığı:</span> <br><strong class="text-emerald-400">${rec.cold_chain_temp}</strong></div>
                </div>

                <p class="text-xs text-slate-400 italic">${rec.notes}</p>
              </div>
            `).join('')}
          </div>
        </section>

        <!-- 4. HAFTALIK BROŞÜR & KAMPANYALAR BÖLÜMÜ -->
        <section id="brosurler" class="space-y-6 pt-4">
          <div class="flex justify-between items-end">
            <div>
              <div class="text-xs font-black text-red-600 uppercase tracking-wider">İNDİRİM BÜLTENİ</div>
              <h2 class="text-3xl font-black text-slate-900">Aktüel Broşürler & Fırsatlar</h2>
            </div>
            <span class="text-xs text-slate-500 font-bold">Her Perşembe Güncellenir</span>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            ${campaigns.map(camp => `
              <div class="bg-white rounded-3xl border border-slate-200 overflow-hidden shadow-sm hover:shadow-lg transition-all flex flex-col justify-between">
                <div class="relative h-56 bg-slate-100">
                  <img src="${camp.image}" alt="${camp.title}" class="w-full h-full object-cover">
                  <span class="absolute top-4 left-4 bg-red-600 text-white text-xs font-black px-3 py-1 rounded-full">
                    ${camp.badge}
                  </span>
                </div>
                <div class="p-6 space-y-4">
                  <div>
                    <h3 class="font-black text-slate-900 text-lg mb-1">${camp.title}</h3>
                    <p class="text-sm font-black text-emerald-600">${camp.discount}</p>
                    <p class="text-xs text-slate-400 mt-1">Geçerlilik: ${camp.valid_until}</p>
                  </div>
                  <button onclick="alert('Broşür PDF veya tam sayfa görüntüleyici açılıyor: ${camp.title}')" class="w-full bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold text-xs py-2.5 rounded-xl transition-colors">
                    Broşürü Tam Ekran İncele 📄
                  </button>
                </div>
              </div>
            `).join('')}
          </div>
        </section>

        <!-- 5. KARİYER VE İŞ BAŞVURU FORMU BÖLÜMÜ -->
        <section id="kariyer" class="bg-white p-8 sm:p-12 rounded-3xl border border-slate-200 shadow-sm space-y-8">
          <div class="max-w-2xl">
            <span class="bg-amber-100 text-amber-800 text-xs font-black px-3 py-1 rounded-full uppercase">Kariyer & İstihdam</span>
            <h2 class="text-3xl font-black text-slate-900 mt-2">TEMA Market Ailesine Katılın</h2>
            <p class="text-slate-600 text-sm mt-2">
              Kasaphane ustası, şube sorumlusu, kasiyer, kurye veya unlu mamuller ekibimizde yer almak için formu doldurun. Başvurunuz doğrudan Yönetici Paneli'mize iletilir.
            </p>
          </div>

          <form action="/api/job-applications" method="POST" class="grid grid-cols-1 md:grid-cols-2 gap-6" onsubmit="event.preventDefault(); submitJobForm(this);">
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Ad Soyad *</label>
              <input type="text" name="name" required placeholder="Örn: Ahmet Yılmaz" class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm">
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Telefon Numarası *</label>
              <input type="tel" name="phone" required placeholder="05XX XXX XX XX" class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm">
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">E-posta Adresi</label>
              <input type="email" name="email" placeholder="ornek@gmail.com" class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm">
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Başvurulan Pozisyon *</label>
              <select name="position" required class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm bg-white">
                <option value="Kasap Ustası / Kasaphane Personeli">Kasap Ustası / Kasaphane Personeli</option>
                <option value="Şarküteri & Mandıra Reyon Görevlisi">Şarküteri & Mandıra Reyon Görevlisi</option>
                <option value="Fırın & Unlu Mamuller Ustası">Fırın & Unlu Mamuller Ustası</option>
                <option value="Kasiyer & Satış Danışmanı">Kasiyer & Satış Danışmanı</option>
                <option value="Motorlu Kurye (A2 Ehliyet)">Motorlu Kurye (A2 Ehliyet)</option>
                <option value="Şube Müdürü / Yönetici Adayı">Şube Müdürü / Yönetici Adayı</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Tercih Edilen Şube</label>
              <input type="text" name="preferred_branch" placeholder="Örn: Şükrüpaşa Şubesi" class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm">
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Tecrübe Süresi</label>
              <input type="text" name="experience_years" placeholder="Örn: 3 Yıl" class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm">
            </div>
            <div class="md:col-span-2">
              <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Kendinizi Tanıtın / Ek Notlar</label>
              <textarea name="notes" rows="3" placeholder="Önceki iş deneyimleriniz ve sertifikalarınız..." class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:border-red-600 text-sm"></textarea>
            </div>
            <div class="md:col-span-2 flex items-center justify-between">
              <p class="text-xs text-slate-500">Gönder butonuna basıldığında başvurunuz yönetici paneline anında düşecektir.</p>
              <button type="submit" class="bg-red-600 hover:bg-red-700 text-white font-black px-8 py-3.5 rounded-xl text-sm shadow-lg shadow-red-600/30 transition-all">
                Başvurumu İlet ➔
              </button>
            </div>
          </form>
        </section>

      </main>
    </div>

    <!-- TEMA AVANTAJ KART MODALI -->
    <div id="kartModal" class="hidden fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-slate-900 border border-slate-800 rounded-3xl p-8 max-w-md w-full text-white shadow-2xl relative">
        <button onclick="document.getElementById('kartModal').classList.add('hidden')" class="absolute top-4 right-4 text-slate-400 hover:text-white text-2xl font-bold">✕</button>
        <div class="text-center space-y-4">
          <div class="inline-flex items-center gap-1.5 bg-red-600 text-white px-3 py-1 rounded-full text-xs font-black">
            <span>★</span> TEMA AVANTAJ KART
          </div>
          <h3 class="text-2xl font-black">Kasada Barkodunuzu Okutun</h3>
          <div class="bg-white p-6 rounded-2xl shadow-inner my-4 inline-block">
            <!-- Temsili Barkod Çizgileri -->
            <div class="flex items-center justify-center gap-1 h-24 px-4 bg-slate-50 border border-slate-200 rounded">
              <div class="w-1.5 h-20 bg-black"></div>
              <div class="w-1 h-20 bg-black"></div>
              <div class="w-3 h-20 bg-black"></div>
              <div class="w-1 h-20 bg-black"></div>
              <div class="w-2 h-20 bg-black"></div>
              <div class="w-1.5 h-20 bg-black"></div>
              <div class="w-3 h-20 bg-black"></div>
              <div class="w-1 h-20 bg-black"></div>
              <div class="w-2 h-20 bg-black"></div>
              <div class="w-1 h-20 bg-black"></div>
              <div class="w-3 h-20 bg-black"></div>
              <div class="w-1.5 h-20 bg-black"></div>
            </div>
            <div class="font-mono text-slate-900 font-bold text-base mt-2 tracking-widest">99999995372668092</div>
          </div>
          <p class="text-xs text-slate-400">
            Telefon numaranız ile oluşturulan 17 haneli Tema Avantaj Kartınız tüm mağazalarımızda ve Sanal Markette geçerlidir.
          </p>
        </div>
      </div>
    </div>

    ${renderFooter()}

    <script>
      function submitJobForm(form) {
        const formData = new FormData(form);
        const data = Object.fromEntries(formData.entries());
        fetch('/api/job-applications', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data)
        })
        .then(res => res.json())
        .then(res => {
          alert('Tebrikler! İş başvurunuz başarıyla alındı ve Yönetici Paneline iletildi.');
          form.reset();
        })
        .catch(err => {
          alert('İş başvurusu iletildi!');
          form.reset();
        });
      }
    </script>
  </body>
  </html>
  `;
}

// ==========================================
// SUBDOMAIN PORTAL SAYFASI HTML OLUŞTURUCU
// ==========================================
function renderSubdomainPortal(slug) {
  const page = subdomainPages.find(p => p.subdomain.toLowerCase() === slug.toLowerCase()) || subdomainPages[0];

  return `
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${page.title} | ${page.subdomain}.temamarket.com</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>body { font-family: 'Plus Jakarta Sans', sans-serif; }</style>
  </head>
  <body class="bg-slate-50 text-slate-800 antialiased min-h-screen flex flex-col justify-between">
    <div>
      <!-- Subdomain Üst Barı -->
      <div class="bg-slate-900 text-white py-2 px-4 text-xs">
        <div class="max-w-7xl mx-auto flex justify-between items-center">
          <div class="flex items-center gap-2">
            <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            <span>Resmi Subdomain Portalı: <strong>${page.subdomain}.temamarket.com</strong></span>
          </div>
          <a href="/" class="text-slate-300 hover:text-white font-bold">← temamarket.com Ana Sayfasına Dön</a>
        </div>
      </div>

      ${renderHeader()}

      <!-- Hero Banner -->
      <div class="relative bg-slate-900 text-white py-16 overflow-hidden">
        <div class="absolute inset-0 z-0">
          <img src="${page.banner_url}" class="w-full h-full object-cover opacity-35" alt="${page.title}">
          <div class="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/70 to-transparent"></div>
        </div>

        <div class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-4">
          <div class="inline-flex items-center gap-2 bg-red-600 text-white text-xs font-black px-3.5 py-1.5 rounded-full shadow-lg">
            <span>🌐</span> ${page.subdomain}.temamarket.com
          </div>
          <h1 class="text-4xl sm:text-5xl font-black text-white">${page.title}</h1>
          <p class="text-xl text-amber-300 font-bold">${page.slogan}</p>
          <p class="text-slate-300 max-w-3xl text-sm leading-relaxed">${page.description}</p>
        </div>
      </div>

      <!-- Portal İçeriği -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-10">
        <!-- Özellikler -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          ${(page.features || []).map((feat, idx) => `
            <div class="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
              <div class="w-12 h-12 rounded-xl bg-red-50 text-red-600 flex items-center justify-center font-black text-lg">
                0${idx + 1}
              </div>
              <div>
                <h4 class="font-bold text-slate-900 text-base">${feat}</h4>
                <p class="text-xs text-slate-500">TEMA standartlarında kalite garantisi</p>
              </div>
            </div>
          `).join('')}
        </div>

        ${page.subdomain === 'kasap' ? `
          <!-- Kasaphane Canlı Süreç Paneli -->
          <div class="bg-white p-8 rounded-3xl border border-slate-200 shadow-sm space-y-6">
            <div class="flex justify-between items-center">
              <div>
                <span class="text-xs font-bold text-red-600 uppercase">Canlı Süreç ve Sevk Takibi</span>
                <h3 class="text-2xl font-black text-slate-900 mt-1">Kesimhaneden Şubelerimize Canlı Durum</h3>
              </div>
              <span class="text-xs bg-emerald-100 text-emerald-800 font-bold px-3 py-1.5 rounded-full">● Canlı Takip Açık</span>
            </div>

            <div class="space-y-4">
              ${kasaphaneRecords.map(r => `
                <div class="bg-slate-50 p-5 rounded-2xl border border-slate-200 flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div>
                    <div class="flex items-center gap-2">
                      <span class="text-xs font-mono font-bold bg-slate-200 px-2 py-0.5 rounded">${r.id}</span>
                      <h4 class="font-black text-slate-900 text-base">${r.title}</h4>
                    </div>
                    <p class="text-xs text-slate-500 mt-1">Menşei: <strong>${r.origin}</strong> | Veteriner: <strong>${r.veterinary_approval}</strong></p>
                  </div>
                  <div class="text-right">
                    <span class="inline-block bg-red-600 text-white font-bold text-xs px-3 py-1 rounded-full">${r.status}</span>
                    <p class="text-xs text-slate-400 mt-1">Sıcaklık: ${r.cold_chain_temp}</p>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}

        <div class="bg-gradient-to-r from-red-600 to-rose-600 text-white p-8 rounded-3xl flex flex-col md:flex-row items-center justify-between gap-6 shadow-xl shadow-red-600/20">
          <div>
            <h3 class="text-2xl font-black">Bu Reyondaki Ürünleri Sanal Market ile Sipariş Edin</h3>
            <p class="text-white/80 text-sm mt-1">30 dakikada kapınıza gelsin veya şubemizden taze teslim alın.</p>
          </div>
          <a href="/?sanal=1" class="bg-white text-slate-900 hover:bg-slate-100 px-8 py-3.5 rounded-2xl font-black text-sm shadow transition-all whitespace-nowrap">
            Sanal Markette Gör ➔
          </a>
        </div>
      </main>
    </div>

    ${renderFooter()}
  </body>
  </html>
  `;
}

// ==========================================
// YÖNETİM PANELİ (ADMIN DASHBOARD) HTML OLUŞTURUCU
// ==========================================
function renderAdminDashboard() {
  return `
  <!DOCTYPE html>
  <html lang="tr">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>temamarket.com Yönetici Paneli</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>body { font-family: 'Plus Jakarta Sans', sans-serif; }</style>
  </head>
  <body class="bg-slate-100 text-slate-800 antialiased min-h-screen">

    <!-- Üst Yönetici Başlığı -->
    <header class="bg-slate-900 text-white border-b border-slate-800 sticky top-0 z-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="bg-red-600 text-white px-3 py-1 rounded-full font-black text-xs">★ TEMA</div>
          <span class="font-black text-lg tracking-tight">temamarket.com Yönetim Konsolu</span>
          <span class="bg-amber-400/20 text-amber-300 text-xs px-2.5 py-0.5 rounded-full font-bold border border-amber-400/30">SuperAdmin</span>
        </div>

        <div class="flex items-center gap-4">
          <a href="/" class="text-xs bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-1.5 rounded-lg font-bold flex items-center gap-1.5 transition-colors">
            🏪 Mağazaya / Müşteri Görünümüne Dön
          </a>
          <span class="text-xs text-slate-400">Yönetici: <strong>Sistem Yöneticisi</strong></span>
        </div>
      </div>
    </header>

    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">

      <!-- Hızlı İstatistik Kartları -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <div class="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <div class="text-xs font-bold text-slate-500 uppercase">Aktif Subdomain Sayfaları</div>
          <div class="text-3xl font-black text-slate-900 mt-2" id="statSubdomains">${subdomainPages.length} Adet</div>
          <div class="text-xs text-emerald-600 font-bold mt-1">● Yayında ve Dinamik</div>
        </div>
        <div class="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <div class="text-xs font-bold text-slate-500 uppercase">Gelen İş Başvuruları</div>
          <div class="text-3xl font-black text-blue-600 mt-2" id="statApplications">${jobApplications.length} Aday</div>
          <div class="text-xs text-slate-500 font-bold mt-1">CV & Başvuru Havuzu</div>
        </div>
        <div class="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <div class="text-xs font-bold text-slate-500 uppercase">Kasaphane Sevk Partileri</div>
          <div class="text-3xl font-black text-red-600 mt-2">${kasaphaneRecords.length} Parti</div>
          <div class="text-xs text-slate-500 font-bold mt-1">Canlı Takip Aktif</div>
        </div>
        <div class="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <div class="text-xs font-bold text-slate-500 uppercase">Grup Şirketleri / Projeler</div>
          <div class="text-3xl font-black text-slate-900 mt-2">${corporateEntities.length} Şirket</div>
          <div class="text-xs text-slate-500 font-bold mt-1">Tema İnşaat & Lojistik</div>
        </div>
      </div>

      <!-- TAB MENÜSÜ -->
      <div class="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
        <div class="flex border-b border-slate-200 overflow-x-auto bg-slate-50/50 p-2 gap-2" id="adminTabs">
          <button onclick="switchTab('subdomains')" id="btn-subdomains" class="tab-btn px-4 py-2.5 rounded-xl font-black text-sm text-red-600 bg-white shadow-sm">
            🌐 Subdomain & Sayfalar
          </button>
          <button onclick="switchTab('jobs')" id="btn-jobs" class="tab-btn px-4 py-2.5 rounded-xl font-bold text-sm text-slate-600 hover:text-slate-900">
            💼 İş Başvuruları (${jobApplications.length})
          </button>
          <button onclick="switchTab('kasaphane')" id="btn-kasaphane" class="tab-btn px-4 py-2.5 rounded-xl font-bold text-sm text-slate-600 hover:text-slate-900">
            🥩 Tema Kasaphane Canlı Süreç
          </button>
          <button onclick="switchTab('insaat')" id="btn-insaat" class="tab-btn px-4 py-2.5 rounded-xl font-bold text-sm text-slate-600 hover:text-slate-900">
            🏢 Tema İnşaat & Grup
          </button>
          <button onclick="switchTab('campaigns')" id="btn-campaigns" class="tab-btn px-4 py-2.5 rounded-xl font-bold text-sm text-slate-600 hover:text-slate-900">
            📢 Kampanyalar & Broşürler
          </button>
        </div>

        <div class="p-6">

          <!-- 1. SUBDOMAIN & SAYFALAR YÖNETİMİ TABI -->
          <div id="tab-subdomains" class="tab-content space-y-6">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <h3 class="text-xl font-black text-slate-900">Subdomain & Özel Reyon Sayfaları</h3>
                <p class="text-xs text-slate-500 mt-0.5">Yönetici panelinden yeni subdomain tanımlayın (Örn: firin.temamarket.com, bakliyat.temamarket.com)</p>
              </div>
              <button onclick="document.getElementById('newSubdomainModal').classList.remove('hidden')" class="inline-flex items-center gap-2 bg-red-600 hover:bg-red-700 text-white font-black text-sm px-4 py-2.5 rounded-xl shadow transition-all">
                <span>+</span> Yeni Subdomain Sayfası Ekle
              </button>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-left text-sm">
                <thead class="bg-slate-50 text-slate-500 uppercase text-xs border-y border-slate-200">
                  <tr>
                    <th class="py-3 px-4">Sayfa Adı</th>
                    <th class="py-3 px-4">Subdomain URL</th>
                    <th class="py-3 px-4">Kategori</th>
                    <th class="py-3 px-4">Slogan</th>
                    <th class="py-3 px-4">Durum</th>
                    <th class="py-3 px-4 text-right">İşlemler</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100" id="subdomainTableBody">
                  ${subdomainPages.map(s => `
                    <tr class="hover:bg-slate-50/80">
                      <td class="py-3 px-4 font-black text-slate-900">${s.title}</td>
                      <td class="py-3 px-4">
                        <span class="font-mono text-xs bg-slate-100 text-red-600 px-2 py-1 rounded font-bold">
                          ${s.subdomain}.temamarket.com
                        </span>
                      </td>
                      <td class="py-3 px-4 font-semibold text-slate-700">${s.category}</td>
                      <td class="py-3 px-4 text-slate-500 text-xs">${s.slogan}</td>
                      <td class="py-3 px-4">
                        <span class="text-xs bg-emerald-100 text-emerald-800 font-bold px-2.5 py-0.5 rounded-full">Yayında</span>
                      </td>
                      <td class="py-3 px-4 text-right space-x-2">
                        <a href="/subdomain/${s.subdomain}" target="_blank" class="text-xs bg-slate-900 hover:bg-slate-800 text-white px-2.5 py-1.5 rounded-lg font-bold">
                          Önizle ↗
                        </a>
                        <button onclick="deleteSubdomain(${s.id})" class="text-xs text-red-600 hover:text-red-700 font-bold px-2 py-1">
                          Sil
                        </button>
                      </td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            </div>
          </div>

          <!-- 2. İŞ BAŞVURULARI TABI -->
          <div id="tab-jobs" class="tab-content hidden space-y-6">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="text-xl font-black text-slate-900">Gelen İş Başvuruları & CV Havuzu</h3>
                <p class="text-xs text-slate-500 mt-0.5">Web sitesi ve uygulamadan yapılan kariyer başvuruları anlık olarak buraya yansır.</p>
              </div>
              <span class="text-xs bg-blue-100 text-blue-800 font-bold px-3 py-1.5 rounded-full">Toplam: ${jobApplications.length} Aday</span>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-left text-sm">
                <thead class="bg-slate-50 text-slate-500 uppercase text-xs border-y border-slate-200">
                  <tr>
                    <th class="py-3 px-4">Aday Adı</th>
                    <th class="py-3 px-4">Telefon</th>
                    <th class="py-3 px-4">Pozisyon</th>
                    <th class="py-3 px-4">Tercih Edilen Şube</th>
                    <th class="py-3 px-4">Tecrübe</th>
                    <th class="py-3 px-4">Durum</th>
                    <th class="py-3 px-4 text-right">İşlem</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  ${jobApplications.map(j => `
                    <tr class="hover:bg-slate-50/80">
                      <td class="py-3 px-4 font-black text-slate-900">${j.name}</td>
                      <td class="py-3 px-4 font-mono text-xs">${j.phone}</td>
                      <td class="py-3 px-4 font-bold text-red-600">${j.position}</td>
                      <td class="py-3 px-4 text-slate-600 text-xs">${j.preferred_branch}</td>
                      <td class="py-3 px-4 text-slate-600 text-xs">${j.experience_years}</td>
                      <td class="py-3 px-4">
                        <span class="text-xs bg-amber-100 text-amber-800 font-bold px-2.5 py-0.5 rounded-full">${j.status}</span>
                      </td>
                      <td class="py-3 px-4 text-right">
                        <button onclick="alert('Aday Notu:\\n${j.notes || 'Not bulunmuyor'}')" class="text-xs bg-slate-100 hover:bg-slate-200 font-bold px-3 py-1.5 rounded-lg text-slate-700">
                          Detay Gör
                        </button>
                      </td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            </div>
          </div>

          <!-- 3. TEMA KASAPHANE TABI -->
          <div id="tab-kasaphane" class="tab-content hidden space-y-6">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="text-xl font-black text-slate-900">Tema Kasaphane Canlı Süreç & Sevk Yönetimi</h3>
                <p class="text-xs text-slate-500 mt-0.5">Kesim anından şubelere ulaştırılana kadarki tüm aşamaları güncelleyin.</p>
              </div>
              <button onclick="alert('Yeni kesim ve parti kaydı oluşturma formu açılıyor.')" class="bg-red-600 hover:bg-red-700 text-white font-bold text-xs px-4 py-2 rounded-xl">
                + Yeni Kesim Partisi Ekle
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              ${kasaphaneRecords.map(k => `
                <div class="bg-slate-50 p-6 rounded-2xl border border-slate-200 space-y-3">
                  <div class="flex justify-between items-center">
                    <span class="text-xs font-mono font-bold bg-red-100 text-red-700 px-2 py-0.5 rounded">${k.id}</span>
                    <span class="text-xs bg-emerald-100 text-emerald-800 font-bold px-2.5 py-1 rounded-full">${k.status}</span>
                  </div>
                  <h4 class="text-base font-black text-slate-900">${k.title}</h4>
                  <div class="text-xs text-slate-600 space-y-1">
                    <p><strong>Veteriner Raporu:</strong> ${k.veterinary_approval}</p>
                    <p><strong>Karkas Adedi:</strong> ${k.carcass_count}</p>
                    <p><strong>Hedef Şubeler:</strong> ${k.target_branches}</p>
                    <p><strong>Sıcaklık:</strong> <span class="text-emerald-700 font-bold">${k.cold_chain_temp}</span></p>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- 4. İNŞAAT & GRUP TABI -->
          <div id="tab-insaat" class="tab-content hidden space-y-6">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="text-xl font-black text-slate-900">Tema İnşaat & Grup Şirketleri Yönetimi</h3>
                <p class="text-xs text-slate-500 mt-0.5">Tema şirketler grubunun iştiraklerini ve projelerini yönetin.</p>
              </div>
              <button onclick="alert('Yeni grup şirketi ekleme penceresi')" class="bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs px-4 py-2 rounded-xl">
                + Şirket / Proje Ekle
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              ${corporateEntities.map(c => `
                <div class="bg-slate-50 p-6 rounded-2xl border border-slate-200 space-y-2">
                  <div class="flex justify-between items-center">
                    <h4 class="text-base font-black text-slate-900">${c.name}</h4>
                    <span class="text-xs bg-slate-200 text-slate-700 font-bold px-2.5 py-0.5 rounded-full">${c.sector}</span>
                  </div>
                  <p class="text-xs text-slate-600">${c.description}</p>
                  <div class="text-xs text-slate-500 pt-2 border-t border-slate-200 flex justify-between">
                    <span>Tamamlanan Proje: <strong>${c.projects_count}</strong></span>
                    <span>İletişim: <strong>${c.contact_phone}</strong></span>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- 5. KAMPANYALAR TABI -->
          <div id="tab-campaigns" class="tab-content hidden space-y-6">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="text-xl font-black text-slate-900">Aktüel Broşürler & Spot Kampanyalar</h3>
                <p class="text-xs text-slate-500 mt-0.5">Kullanıcıların ilk sayfada göreceği broşür ve tekil indirimleri buradan yönetin.</p>
              </div>
              <button onclick="alert('Broşür yükleme penceresi')" class="bg-red-600 hover:bg-red-700 text-white font-bold text-xs px-4 py-2 rounded-xl">
                + Yeni Broşür / Afiş Ekle
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              ${campaigns.map(cp => `
                <div class="bg-slate-50 p-4 rounded-2xl border border-slate-200 space-y-2">
                  <img src="${cp.image}" class="w-full h-32 object-cover rounded-xl">
                  <h4 class="font-bold text-slate-900 text-sm">${cp.title}</h4>
                  <p class="text-xs text-emerald-600 font-bold">${cp.discount}</p>
                </div>
              `).join('')}
            </div>
          </div>

        </div>
      </div>
    </div>

    <!-- YENİ SUBDOMAIN EKLEME MODALI -->
    <div id="newSubdomainModal" class="hidden fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-3xl p-8 max-w-lg w-full shadow-2xl relative">
        <button onclick="document.getElementById('newSubdomainModal').classList.add('hidden')" class="absolute top-4 right-4 text-slate-400 hover:text-slate-800 text-2xl font-bold">✕</button>
        <h3 class="text-xl font-black text-slate-900 mb-1">Yeni Subdomain Sayfası Oluştur</h3>
        <p class="text-xs text-slate-500 mb-6">Örn: firin.temamarket.com, bakliyat.temamarket.com</p>

        <form id="newSubdomainForm" onsubmit="event.preventDefault(); createSubdomain(this);" class="space-y-4">
          <div>
            <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Sayfa Başlığı *</label>
            <input type="text" name="title" required placeholder="Örn: Tema Doğal Mandıra" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm">
          </div>
          <div>
            <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Subdomain Adı (Slug) *</label>
            <div class="flex items-center">
              <span class="bg-slate-100 border border-r-0 border-slate-300 px-3 py-2.5 text-xs text-slate-500 font-mono rounded-l-xl">https://</span>
              <input type="text" name="subdomain" required placeholder="mandira" class="w-full px-3 py-2.5 border border-slate-300 text-sm font-mono">
              <span class="bg-slate-100 border border-l-0 border-slate-300 px-3 py-2.5 text-xs text-slate-500 font-mono rounded-r-xl">.temamarket.com</span>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Kategori</label>
              <input type="text" name="category" placeholder="Mandıra / Şarküteri" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm">
            </div>
            <div>
              <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Tema Rengi (HEX)</label>
              <input type="text" name="theme_color" value="#DC2626" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm font-mono">
            </div>
          </div>
          <div>
            <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Slogan</label>
            <input type="text" name="slogan" placeholder="Yaylalardan sofranıza taptaze lezzet" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm">
          </div>
          <div>
            <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Açıklama</label>
            <textarea name="description" rows="2" placeholder="Sayfa tanıtım metni..." class="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm"></textarea>
          </div>
          <div>
            <label class="block text-xs font-bold text-slate-700 uppercase mb-1">Hero Banner Görsel URL</label>
            <input type="url" name="banner_url" value="https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=1200&q=80" class="w-full px-3.5 py-2.5 rounded-xl border border-slate-300 text-sm">
          </div>

          <div class="pt-4 flex justify-end gap-3">
            <button type="button" onclick="document.getElementById('newSubdomainModal').classList.add('hidden')" class="px-4 py-2.5 rounded-xl text-slate-600 font-bold text-xs hover:bg-slate-100">İptal</button>
            <button type="submit" class="bg-red-600 hover:bg-red-700 text-white font-bold text-xs px-6 py-2.5 rounded-xl shadow">Subdomaini Yayınla</button>
          </div>
        </form>
      </div>
    </div>

    <script>
      function switchTab(tabId) {
        document.querySelectorAll('.tab-content').forEach(el => el.classList.add('hidden'));
        document.querySelectorAll('.tab-btn').forEach(btn => {
          btn.classList.remove('bg-white', 'text-red-600', 'shadow-sm', 'font-black');
          btn.classList.add('text-slate-600', 'font-bold');
        });

        const activeContent = document.getElementById('tab-' + tabId);
        if (activeContent) activeContent.classList.remove('hidden');

        const activeBtn = document.getElementById('btn-' + tabId);
        if (activeBtn) {
          activeBtn.classList.add('bg-white', 'text-red-600', 'shadow-sm', 'font-black');
          activeBtn.classList.remove('text-slate-600', 'font-bold');
        }
      }

      function createSubdomain(form) {
        const formData = new FormData(form);
        const data = Object.fromEntries(formData.entries());
        data.features = ['%100 Doğal', 'Hızlı Teslimat', 'TEMA Güvencesi'];

        fetch('/api/subdomain-pages', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data)
        })
        .then(res => res.json())
        .then(res => {
          alert('Subdomain başarıyla oluşturuldu ve anında yayına alındı: ' + data.subdomain + '.temamarket.com');
          location.reload();
        })
        .catch(err => {
          alert('Hata oluştu!');
        });
      }

      function deleteSubdomain(id) {
        if (!confirm('Bu subdomain sayfasını silmek istediğinizden emin misiniz?')) return;
        fetch('/api/subdomain-pages?id=' + id, { method: 'DELETE' })
          .then(res => res.json())
          .then(() => location.reload());
      }
    </script>
  </body>
  </html>
  `;
}

// ==========================================
// HTTP İSTEK YÖNLENDİRİCİSİ (REQUEST ROUTER)
// ==========================================
const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  // CORS başlıkları
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // 1. API: SUBDOMAIN PAGES
  if (pathname === '/api/subdomain-pages') {
    if (method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ success: true, data: subdomainPages }));
      return;
    } else if (method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        try {
          const item = JSON.parse(body);
          item.id = Date.now();
          item.full_url = `https://${item.subdomain}.temamarket.com`;
          item.is_active = true;
          subdomainPages.unshift(item);
          res.writeHead(201, { 'Content-Type': 'application/json; charset=utf-8' });
          res.end(JSON.stringify({ success: true, data: item }));
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, message: 'Geçersiz veri' }));
        }
      });
      return;
    } else if (method === 'DELETE') {
      const id = parseInt(parsedUrl.query.id);
      subdomainPages = subdomainPages.filter(p => p.id !== id);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ success: true, message: 'Silindi' }));
      return;
    }
  }

  // 2. API: JOB APPLICATIONS
  if (pathname === '/api/job-applications') {
    if (method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ success: true, data: jobApplications }));
      return;
    } else if (method === 'POST') {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        try {
          const app = JSON.parse(body);
          app.id = Date.now();
          app.applied_at = new Date().toLocaleString('tr-TR');
          app.status = 'Yeni';
          jobApplications.unshift(app);
          res.writeHead(201, { 'Content-Type': 'application/json; charset=utf-8' });
          res.end(JSON.stringify({ success: true, data: app }));
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, message: 'Hata' }));
        }
      });
      return;
    }
  }

  // 3. API: KASAPHANE TRACKING
  if (pathname === '/api/kasaphane/tracking') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ success: true, data: kasaphaneRecords }));
    return;
  }

  // 4. API: CORPORATE ENTITIES
  if (pathname === '/api/corporate-entities') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ success: true, data: corporateEntities }));
    return;
  }

  // 5. HTML GÖRÜNÜMLERİ
  // Yönetim Paneli
  if (pathname === '/admin' || parsedUrl.query.route === 'admin') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(renderAdminDashboard());
    return;
  }

  // Subdomain Sayfası
  if (pathname.startsWith('/subdomain/')) {
    const slug = pathname.replace('/subdomain/', '').replace('/', '');
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(renderSubdomainPortal(slug));
    return;
  }

  if (parsedUrl.query.subdomain) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(renderSubdomainPortal(parsedUrl.query.subdomain));
    return;
  }

  // Ana Sayfa (temamarket.com)
  const isSanal = parsedUrl.query.sanal === '1';
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(renderHomePage(isSanal));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=======================================================`);
  console.log(`⭐ TEMA Market Test Sunucusu Başlatıldı!`);
  console.log(`🌐 Ana Sayfa:          http://localhost:${PORT}`);
  console.log(`🛒 Sanal Market:       http://localhost:${PORT}/?sanal=1`);
  console.log(`👑 Yönetim Paneli:     http://localhost:${PORT}/admin`);
  console.log(`🥩 Tema Kasaphane:     http://localhost:${PORT}/subdomain/kasap`);
  console.log(`🧀 Tema Mandıra:       http://localhost:${PORT}/subdomain/mandira`);
  console.log(`🥖 Tema Fırın:         http://localhost:${PORT}/subdomain/firin`);
  console.log(`🌾 Tema Bakliyat:      http://localhost:${PORT}/subdomain/bakliyat`);
  console.log(`🥓 Tema Şarküteri:     http://localhost:${PORT}/subdomain/sarkuteri`);
  console.log(`🏢 Tema İnşaat:        http://localhost:${PORT}/subdomain/insaat`);
  console.log(`=======================================================`);
});
