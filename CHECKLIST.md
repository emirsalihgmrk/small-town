# Yayın Kontrol Listesi (Android)

Lina'nın Çiftliği'ni (Lina's Farm) Google Play'e hazırlarken yapılacaklar. Bitenler `[x]` ile işaretlenir.

## 🔴 Yayını engelleyenler

- [x] **1. Debug paneli** — release export'ta görünmesin. `DebugPanel` artık yalnız editörde ve debug
	  export'ta çalışıyor (`OS.is_debug_build()`), release'te kendini siliyor.
	  _Release APK'da gerçekten kaybolduğu 2. maddeden sonra cihazda doğrulanacak._
- [x] **2. Android export ayarı** — release AAB (`build/LinasFarm.aab`, ~30 MB) ve release APK
	  (`build/LinasFarm.apk`) derlendi, ikisi de release keystore'la imzalı (jarsigner/apksigner ile doğrulandı).
	  Komut satırından: `godot --headless --path . --export-release "Android" build/LinasFarm.aab`.
	  - Ad: `config/name` = "Lina's Farm", `config/name_localized` tr = "Lina'nın Çiftliği" (bilgisayardaki
		kayıt `app_userdata/Lina's Farm/`'a kopyalandı, eski `Minik Kasaba/` yedek). Paket: `com.kidolab.linasfarm`.
	  - `export_presets.cfg`: "Android" (Gradle, AAB → `build/LinasFarm.aab`) ve "Android APK (cihaz testi)"
		(aynı ayarlar, APK → `build/LinasFarm.apk`). İkisi de yalnız `arm64-v8a`, hiçbir izin yok, simgeler
		`assets/branding/`'den. Android şablonu kuruldu (`android/`, `.gitignore`'da); `import_etc2_astc` açıldı.
	  - Release keystore: `C:\Users\emirs\Desktop\kidolab-release.keystore` (repo dışında, yedekli), alias `kidolab`.
		Yolu ve alias `.godot/export_credentials.cfg`'de (repoya girmez); şifre iki preset için editörde
		Proje → Dışa Aktar → Keystore → Release Password alanında (girildi).
	  - Kalan (9. madde): 1. maddeyi release APK'da cihazda doğrula.
- [x] **3. Uygulama simgesi ve açılış ekranı** — simge: hasır şapkalı kız (`config/icon` = `icon_512.png`, Android
	  adaptif katmanları ve tek renkli sürümü preset'lerde); açılış: krem zeminde
	  "kidolab" logosu, yalnız yükleme süresince. Kaynaklar `assets/branding/` (`icon_background.svg`,
	  `kidolab_logo.svg`; kız oyundaki parça çizimlerinden birleştirilir), PNG'leri
	  `tools/branding/render_branding.gd` üretir. _Android 12+ sistem açılışı ve gerçek görünüm 9. maddede bakılacak._
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
- [x] **8. Sürüm numarası** — preset'lerde `version/name` = `1.0.0` (görünen sürüm), `version/code` = `1`;
	  Play'e her yüklemede `version/code` bir artmalı (iki preset'te de).
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
- [x] **12. Boş klasörler** — `data/*`, `scenes/town`, `scripts/resources`, `tests`, `scenes/ui/theme`, `assets/fonts`
	  silindi; yalnız `.gitkeep` içeren `scripts/town` de onlarla gitti.
- [x] **13. CREDITS.md** — eksik `coin_clink.ogg` satırı eklendi; ses klasöründeki 32 dosyanın hepsi artık listede.
- [x] **14. Export filtresi** — `tools/` artık `.gdignore` içeriyor, oyuna girmiyor (preset'ten bağımsız).
	  `previews/`'teki eski geliştirme görüntüleri (14,6 MB) silindi, klasör `.gitignore`'da;
	  `tools/screenshot.gd` oraya yazarken `.gdignore`'u kendisi koyuyor.
- [x] **15. Yaş açıklaması** — `config/description` artık tasarımdaki gibi "5-6 yaş" diyor.
- [x] **16. Uzak inek sesi** — ana ekran, tarla, kümes ve fırında çalmaya devam ediyor; kalmasına karar verildi.

## 📋 Google Play

- [x] Google Play geliştirici hesabı
- [ ] Gizlilik politikası adresi (veri toplanmasa da zorunlu)
- [ ] Hedef kitle ve içerik (Aileler politikası), içerik derecelendirme anketi, Veri Güvenliği formu
- [ ] Mağaza görselleri: 512×512 simge (hazır: `assets/branding/icon_512.png`), 1024×500 öne çıkan görsel, ekran görüntüleri
- [ ] Mağaza metni (kısa ve uzun açıklama)
- [ ] Önce dahili test kanalında yayın

## Son kararlar

- [x] Oyun alanı denemesi (salıncak, havuz, uçurtma, kuş evi) kalıyor mu?
- [x] Dinlenmemiş sesler: dükkân zili, salıncak itme, havuz damlası
