extends Node
## Ekranı doldurma (autoload: ScreenFit). project.godot'ta stretch aspect "expand": ekran 16:9'dan genişse
## yanlarda, darsa altta ve üstte dünyanın fazlası görünür. Oyun 1920×1080 için tasarlandı; bu alan ekranın
## ortasında kalsın diye dünya (kök görüntü alanının canvas dönüşümü) kaydırılır. Arayüz katmanları
## (CanvasLayer) bundan etkilenmez, çapalarıyla yeni ekran kenarlarına yerleşir. Sahnelerde kamera yok ve
## dünya↔ekran çevirisi hep canvas dönüşümüyle yapılıyor; dokunuş ve sürüklemeler böylece doğru kalır.
## Arka planlar tasarım alanının dışına BLEED kadar taşar (21:9 telefon ve 4:3 tablete yeter).

const DESIGN_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const BLEED: Vector2 = Vector2(320.0, 180.0)


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()


## Dünyanın ekranda görünen kısmı (dünya koordinatı); ekran dışından gelip gidenler bunun dışından yürür.
func visible_world_rect() -> Rect2:
	var root: Window = get_tree().root
	return Rect2(-root.canvas_transform.origin, root.get_visible_rect().size)


func _fit() -> void:
	var root: Window = get_tree().root
	root.canvas_transform = Transform2D(0.0, ((root.get_visible_rect().size - DESIGN_SIZE) * 0.5).round())
