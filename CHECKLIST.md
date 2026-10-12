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
      - Bittiğinde 1. maddeyi release APK'da cihazda doğrula.
- [ ] **3. Uygulama simgesi ve açılış ekranı** — `config/icon`, Android adaptif simge (ön + arka plan katmanı),
      Godot logosu yerine kendi boot splash'ı.
- [x] **4. Android geri tuşu** — açık sepet menüsünü kapatır; menü kapalıysa bölümden ana ekrana döner;
      ana ekranda hiçbir şey yapmaz (`quit_on_go_back=false`, `SceneRouter.go_back`, `back_handlers` grubu).
      _Benzetimle denendi; gerçek cihazda 9. maddede bakılacak._
- [ ] **5. Godot lisans bildirimi** — motorun MIT lisansı ve üçüncü taraf bildirimleri oyunda bulunsun.

## 🟠 Önemli

- [ ] **6. Kayıt güvenliği** — bozuk kayıtta `.bak` yedekten dönülsün; sürüm geçişi (migration) yeri hazır olsun.
- [ ] **7. Ebeveyn ses ayarı** — müzik/efekt aç-kapa, çocuğun açamayacağı bir "ebeveyn kapısı" arkasında.
- [ ] **8. Sürüm numarası** — `application/config/version` ve Android `version/code`.
- [ ] **9. Gerçek cihaz testi** — tablette ve telefonda dokunma, performans, farklı ekran oranları, kenar boşlukları.
- [ ] **10. Sıfır kayıtla baştan sona oynanış** — yeni yükleyen çocuk yolunu bulabiliyor mu?
      Fırın ürünlerinin kayıtta hep 0 görünmesinin nedeni de bakılacak.

## 🟡 Temizlik

- [ ] **11. Kullanılmayan çizimler** — `assets/art/animals/` içindeki `chick`, `chicken_body`, `chicken_head`,
      `lamb_body`, `lamb_head`, `cat_sleep`, `cat_tail`.
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
