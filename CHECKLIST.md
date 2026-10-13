# Yayın Kontrol Listesi (Android)

Minik Kasaba'yı Google Play'e hazırlarken yapılacaklar. Bitenler `[x]` ile işaretlenir.

## 🔴 Yayını engelleyenler

- [x] **1. Debug paneli** — release export'ta görünmesin. `DebugPanel` artık yalnız editörde ve debug
	  export'ta çalışıyor (`OS.is_debug_build()`), release'te kendini siliyor.
	  _Release APK'da gerçekten kaybolduğu 2. maddeden sonra cihazda doğrulanacak._
- [ ] **2. Android export ayarı** — ⏸ _Sona bırakıldı, manuel yapılacak (oyunun adı henüz belli değil)._
	  - Ortam hazır (2026-10-12): JDK 17 (Temurin), Android SDK (build-tools 36, platform 36/37),
		Godot 4.7.2 Android şablonları; Godot editör ayarlarında SDK/JDK yolları ve debug keystore tanımlı.
	  - Kalan: oyun adı (`config/name`) → paket adı (Play'de sonradan değişmez), release keystore
		(repo dışında tut, şifresiyle birlikte yedekle), Android preset'i, AAB çıktısı.
	  - Play AAB istiyor: preset'te "Use Gradle Build" açık olmalı; önce Proje → Android Build Şablonunu Yükle
		(`android/` klasörü zaten `.gitignore`'da).
	  - Mimari: `arm64-v8a` (+ isteğe bağlı `armeabi-v7a`). İnternet izni gerekmiyor, hiçbir izin açılmasın.
	  - Keystore şifreleri `export_presets.cfg`'ye değil `.godot/export_credentials.cfg`'ye yazılır (repoya girmez).
	  - Sürüm (8. madde buraya taşındı): preset'te `version/name` (ör. `1.0.0`, görünen sürüm) ve
		`version/code` (`1`'den başlar, Play'e her yüklemede bir artmalı).
	  - Bittiğinde 1. maddeyi release APK'da cihazda doğrula.
- [ ] **3. Uygulama simgesi ve açılış ekranı** — `config/icon`, Android adaptif simge (ön + arka plan katmanı),
	  Godot logosu yerine kendi boot splash'ı.
- [x] **4. Android geri tuşu** — açık sepet menüsünü kapatır; menü kapalıysa bölümden ana ekrana döner;
	  ana ekranda hiçbir şey yapmaz (`quit_on_go_back=false`, `SceneRouter.go_back`, `back_handlers` grubu).
	  _Benzetimle denendi; gerçek cihazda 9. maddede bakılacak._
- [x] **5. Godot lisans bildirimi** — ana ekranın sol üstündeki soluk çark 2 sn basılı tutulunca
	  "Ebeveyn Köşesi" açılır (`ParentGateButton`, `ParentMenu`); "Lisanslar ve emeği geçenler" sayfası metni
	  Godot'dan alır (`Engine.get_license_text/get_copyright_info/get_license_info`), motor güncellenince kendiliğinden güncel kalır.
	  _Lisans sayfası ilk açılışta masaüstünde ~0,26 sn'de doluyor; telefondaki süreye 9. maddede bakılacak._

## 🟠 Önemli

- [x] **6. Kayıt güvenliği** — her yazışta önceki kayıt `save.json.bak` olur; asıl kayıt okunamazsa yedekten
	  açılır, bozuk dosya `save.json.corrupt` olarak saklanır (silinmez); yazma hatasında (ör. disk dolu) eski kayıt
	  korunur; sürüm geçişleri `SaveGame._migrate`'e eklenecek. 5 senaryo (normal, asıl bozuk, ikisi bozuk,
	  asıl yok, yeni sürüm) denendi.
- [x] **7. Ebeveyn ses ayarı** — Ebeveyn Köşesi'nde "Müzik ve doğa sesleri" (Music + Ambience kanalları) ve
	  "Oyun sesleri" (SFX) düğmeleri; durum kayıtta "audio" bölümünde, açılışta geri yüklenir
	  (SaveGame artık autoload listesinin başında, AudioManager kaydı okuyabilsin diye).
- [ ] **8. Sürüm numarası** — ⏸ _Export sırasında ayarlanacak, 2. maddeye taşındı._
- [ ] **9. Gerçek cihaz testi** — tablette ve telefonda dokunma, performans, farklı ekran oranları, kenar boşlukları.
- [x] **10. Sıfır kayıtla baştan sona oynanış** — yeni yükleyen çocuk yolunu bulabiliyor mu?
	  El göstergesi (`HintHand` + `HintDirector`; iş 3 kez yapılana dek 4 sn, sonra 15 sn beklemede çıkar,
	  hareketi 2 kez gösterir; dokunulmadan yeniden çıkacaksa bekleme her seferinde ikiye katlanır (en fazla 4×),
	  dokununca başa döner; öğrenme sayıları kayıtta "hints"). Tespit ve sıra: `~/.claude/plans/golden-exploring-starlight.md`.
	  - [x] Ortak parçalar + Tarla (çapa, tohum, sulama, havuç çekme, balkabağı itme, orak)
	  - [x] Kümes (sepetten buğday → yemlik, kova → suluk)
	  - [x] Ahır (saman → yemlik, kova → suluk, süt kovası → inek, memeye dokunma)
	  - [x] Fırın (tarif kartı, sepetten malzeme → kase, karıştırma, hamur → fırın)
	  - [x] Pazar (reyondan ürün → müşteri) ve Dükkân (kumbaradan para → ürün)
	  - [x] Ana ekran (tarlada hiç parsel çapalanmadıysa Tarla kartı)
	  - [x] Fırın ürünlerinin kayıtta hep 0 görünmesinin nedeni — hata değil: pazarda sepette fırın ürünü
		varken müşteriler yalnız fırın ürünü ister (`MarketOrders.make`), başka hiçbir yer fırın ürünü harcamaz.
		Pişen her ürün pazarda ilk satılanlar arasında olur; kayıtta anahtarların bulunması eklenip yazıldıklarını gösterir.

## 🟡 Temizlik

- [x] **11. Kullanılmayan çizimler** — `assets/art/animals/` içindeki `chick`, `chicken_body`, `chicken_head`,
	  `lamb_body`, `lamb_head`, `cat_sleep`, `cat_tail` silindi (yolla da `uid://` ile de hiçbir yerde geçmiyorlardı;
	  uyuyan kedi `assets/art/coop/` altındaki kopyaları kullanıyor). Klasörde yalnız tarladaki `bunny` kaldı.
- [ ] **12. Boş klasörler** — `data/*`, `scenes/town`, `scripts/resources`, `tests`, `scenes/ui/theme`, `assets/fonts`.
- [ ] **13. CREDITS.md** — eksik `coin_clink.ogg` satırı.
- [ ] **14. Export filtresi** — `tools/` oyuna girmesin; `previews/` (14,6 MB) repoda kalsın mı?
- [ ] **15. Yaş açıklaması** — `config/description` "5-7 yaş" diyor, tasarım 5-6.
- [ ] **16. Uzak inek sesi** — ana ekran, tarla, kümes ve fırında hâlâ çalıyor; kalsın mı?

## 📋 Google Play

- [ ] Google Play geliştirici hesabı
- [ ] Gizlilik politikası adresi (veri toplanmasa da zorunlu)
- [ ] Hedef kitle ve içerik (Aileler politikası), içerik derecelendirme anketi, Veri Güvenliği formu
- [ ] Mağaza görselleri: 512×512 simge, 1024×500 öne çıkan görsel, ekran görüntüleri
- [ ] Mağaza metni (kısa ve uzun açıklama)
- [ ] Önce dahili test kanalında yayın

## Son kararlar

- [ ] Oyun alanı denemesi (salıncak, havuz, uçurtma, kuş evi) kalıyor mu?
- [ ] Dinlenmemiş sesler: dükkân zili, salıncak itme, havuz damlası
