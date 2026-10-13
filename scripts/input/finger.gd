class_name Finger
extends RefCounted
## Sürüklenen nesne parmağın altında kalmasın diye parmağın üstünde taşınır. Uzaklık gerçek boyutta
## (milimetre) verilir ve ekrana çevrilir: aynı oyun pikseli telefonda tablettekinin yarısı kadar küçük
## göründüğünden telefonda daha çok oyun pikseli tutar. Taşınan nesneyi bırakmada hem nesnenin görünen
## yeri hem parmak sayılır (ekranın altındaki hedeflere parmakla da ulaşılsın); nesneyi alma parmağa göre.
## Ucuyla çalışan araçlar (çapa, kova) yalnız uca bakar. Süt kovası parmaktan ortasından tutulur, kaldırılmaz.

## Nesnenin ortası parmak ucunun bu kadar üstünde durur: alt kenarı parmak ucunun hemen üstüne gelir.
## Fazlası ekranın altındaki hedeflere (yalak, alt parseller) ulaşmayı zorlaştırır.
const LIFT_MM: float = 9.0
## Fareyle (masaüstü) ya da ekran bilgisi yanlışsa bile bu sınırlar içinde kalır (oyun pikseli).
const MIN_LIFT: float = 60.0
const MAX_LIFT: float = 160.0
const MM_PER_INCH: float = 25.4


## Parmaktan nesneye kaydırma (oyun pikseli, yukarı doğru).
static func lift(viewport: Viewport) -> Vector2:
	var window: Window = viewport.get_window()
	var base: Vector2 = Vector2(window.content_scale_size)
	var window_size: Vector2 = Vector2(window.size)
	var scale: float = minf(window_size.x / base.x, window_size.y / base.y) if base.x > 0.0 and base.y > 0.0 else 1.0
	var dpi: float = float(DisplayServer.screen_get_dpi(window.current_screen))
	var game_px: float = LIFT_MM / MM_PER_INCH * dpi / maxf(scale, 0.01)
	return Vector2(0.0, -clampf(game_px, MIN_LIFT, MAX_LIFT))
