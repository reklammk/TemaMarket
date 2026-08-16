# TEMA Sanal Market

Flutter tabanlı müşteri, bayi, kurye ve yönetici uygulaması. Uygulama veriyi
`https://temasanalmarket.com/api` adresindeki API'den alır; ürün, sipariş,
stok, kurye ve yetki bilgileri istemci içinde örnek veri olarak üretilmez.

## Gereksinimler

- Flutter 3.38.9 veya uyumlu kararlı sürüm
- Dart 3
- Android için Java 17 ve Android SDK 36
- iOS için Xcode ve geçerli App Store imzalama varlıkları

## Yerel çalıştırma

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

App Store müşteri derlemesinde personel rolleri giriş ekranında gösterilmez.
Yalnızca şirket içi dağıtımlarda gerekiyorsa açıkça etkinleştirin:

```sh
flutter run --dart-define=ENABLE_STAFF_LOGIN=true
```

Release derlemeleri HTTP API adresini reddeder. Canlı veya TestFlight derlemesi
HTTPS kullanmalıdır:

```sh
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://temasanalmarket.com/api
```

## Backend yapılandırması

PHP backend bu çalışma alanında `../backend` klasöründedir. Canlı ortamda
aşağıdaki ortam değişkenleri hosting panelinden tanımlanmalıdır. Gizli
bilgiler kaynak koda veya Git'e eklenmemelidir.

```text
APP_ENV=production
APP_ALLOWED_ORIGINS=https://temasanalmarket.com,https://www.temasanalmarket.com
DB_TYPE=mysql
DB_HOST=localhost
DB_NAME=...
DB_USER=...
DB_PASS=...

TT_SMS_USERNAME=...
TT_SMS_PASSWORD=...
TT_SMS_LOGIN_PASSWORD=...
TT_SMS_ORIGIN=TEMA MARKET
TT_SMS_BRAND_CODE=...

BOOTSTRAP_ADMIN_PHONE=5XXXXXXXXX
BOOTSTRAP_ADMIN_NAME=...
SEED_DEMO_DATA=false

# Yalnızca App Store incelemesi sırasında etkinleştirin. Gerçek kullanıcı
# numarası kullanmayın; kodu App Store Connect inceleme notlarına yazın.
APP_REVIEW_LOGIN_ENABLED=false
APP_REVIEW_ACCOUNTS_JSON={"Customer":{"phone":"+905XXXXXXXXX","code":"6_HANELI_KOD"}}
```

Geliştirme sırasında SQLite kullanmak için `APP_ENV=development`,
`DB_TYPE=sqlite` ve ayrı bir `DB_SQLITE_PATH` verilebilir. Demo verisi yalnızca
bilinçli olarak `SEED_DEMO_DATA=true` ayarlanırsa oluşturulur.

## Android release imzası

`android/key.properties` Git tarafından yok sayılır ve şu değerleri içerir:

```properties
storeFile=C:/secure/path/upload-keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Release yapılandırması debug sertifikasına geri dönmez. Codemagic'te
`CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS` ve
`CM_KEY_PASSWORD` güvenli ortam değişkenleri olarak tanımlanmalıdır.

## Codemagic / TestFlight

`codemagic.yaml` her iOS ve Android derlemesinden önce analiz ve testleri
çalıştırır. iOS için Codemagic'te tanımlı sertifika ile provisioning
profilinin aynı Apple Distribution sertifikasını içermesi gerekir. IPA ayrıca
debug Flutter motoru ve Dart kernel'i açısından doğrulanır.

## Güvenlik notları

- OTP kodu sunucu tarafında hash'lenir, süreli ve deneme limitlidir.
- App Review sabit kodu yalnızca açıkça etkinleştirilen, sunucu ortamında
  tanımlı özel inceleme hesaplarında çalışır; API kodu hiçbir yanıtta dönmez.
- Yetki istemcinin seçimine değil sunucudaki kullanıcı rolüne dayanır.
- Müşteri hesabı uygulama içinden kalıcı olarak silinebilir. Adres, izin ve
  sadakat verileri kaldırılır; tutulması gereken siparişler anonimleştirilir ve
  kullanıcının bütün API oturumları iptal edilir.
- Sipariş fiyatı ve stok kontrolü sunucuda hesaplanır; tekrar gönderimler
  idempotency anahtarıyla engellenir.
- SoftPOS, sanal POS, e-fatura ve bildirim gibi entegrasyonu tamamlanmamış
  özellikler varsayılan olarak kapalıdır ve arayüzde başarılıymış gibi
  gösterilmez.
- Daha önce kaynak kodda bulunmuş olabilecek SMS, POS veya veritabanı
  anahtarları ilgili sağlayıcı panellerinden iptal edilip yenilenmelidir.
