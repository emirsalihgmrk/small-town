# Yayın Kontrol Listesi (Android)

Minik Kasaba'yı Google Play'e hazırlarken yapılacaklar. Bitenler `[x]` ile işaretlenir.

## 🔴 Yayını engelleyenler

- [x] **1. Debug paneli** — release export'ta görünmesin. `DebugPanel` artık yalnız editörde ve debug
      export'ta çalışıyor (`OS.is_debug_build()`), release'te kendini siliyor.
      _Release APK'da gerçekten kaybolduğu 2. maddeden sonra cihazda doğrulanacak._
- [ ] **2. Android export ayarı** — `export_presets.cfg`, paket adı (ör. `com.<ad>.minikkasaba`),
      Android SDK/JDK kurulumu, export şablonları, imzalama anahtarı (keystore, yedeklenmeli!), AAB çıktısı.
- [ ] **3. Uygulama simgesi ve açılış ekranı** — `config/icon`, Android adaptif simge (ön + arka plan katmanı),
      Godot logosu yerine kendi boot splash'ı.
- [ ] **4. Android geri tuşu** — bölümlerdeyken ana ekrana dönsün; ana ekranda oyundan yanlışlıkla çıkılmasın.
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
