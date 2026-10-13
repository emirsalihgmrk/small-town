extends SceneTree
## Uygulama simgesi ve açılış ekranı PNG'lerini assets/branding/ içine üretir. Kaynaklar: icon_background.svg,
## kidolab_logo.svg ve kızın oyundaki parça çizimleri (assets/art/character/girl/). Biri değişince yeniden çalıştır:
##   godot --headless --path . --script res://tools/branding/render_branding.gd

const OUT_DIR: String = "res://assets/branding/"
const GIRL_DIR: String = "res://assets/art/character/girl/"
## Kızın baş ve omuz parçaları, sahnedeki çizim sırasıyla (scenes/entities/girl.tscn): [ad, aynalı mı].
## Hepsi aynı koordinat düzleminde çizilmiş; sağ örgü, sol örgünün x = GIRL_MIRROR_X eksenindeki aynası.
const GIRL_PARTS: Array = [["pigtail", false], ["pigtail", true], ["hair_back", false], ["neck", false],
		["dress", false], ["collar", false], ["head", false], ["blush", false], ["eyes_open", false], ["mouth", false],
		["hair_front", false], ["hat", false]]
const GIRL_MIRROR_X: float = 130.0
## Parçaların düzleminde simgenin ortasına gelen nokta (şapka tepesiyle örgü altları arasının ortası).
const GIRL_ANCHOR: Vector2 = Vector2(130, 118)
const SPLASH_SIZE: Vector2i = Vector2i(1920, 1080)
## project.godot'daki application/boot_splash/bg_color ile aynı olmalı (ekran oranı farklıysa kenarları o doldurur).
const SPLASH_COLOR: Color = Color("#fff6e6")
const SPLASH_LOGO_SCALE: float = 0.8

var _failed: bool = false


func _initialize() -> void:
	_save(_full_icon(512), "icon_512.png")
	_save(_full_icon(192), "icon_192.png")
	# Android adaptif simge katmanları: 108 birimlik tuval, ön planın asıl içeriği ortadaki 66 birimlik dairede.
	_save(_svg(OUT_DIR + "icon_background.svg", 432.0 / 512.0), "icon_background_432.png")
	var foreground: Image = _girl(432, 1.05, Vector2(216, 216))
	_save(foreground, "icon_foreground_432.png")
	_save(_monochrome(foreground), "icon_monochrome_432.png")
	_save(_splash(), "splash.png")
	quit(1 if _failed else 0)


## Tam simge (arka plan + kız): Play mağazası, eski Android başlatıcıları ve masaüstü pencere simgesi.
func _full_icon(size: int) -> Image:
	var scale: float = size / 512.0
	var image: Image = _svg(OUT_DIR + "icon_background.svg", scale)
	var girl: Image = _girl(size, 1.7 * scale, Vector2(size * 0.5, size * 0.42))
	image.blend_rect(girl, Rect2i(Vector2i.ZERO, girl.get_size()), Vector2i.ZERO)
	return image


## Kızın parçalarını size×size saydam bir tuvalde birleştirir; GIRL_ANCHOR noktası center'a gelir.
func _girl(size: int, scale: float, center: Vector2) -> Image:
	var canvas: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for part: Array in GIRL_PARTS:
		var text: String = FileAccess.get_file_as_string(GIRL_DIR + str(part[0]) + ".svg")
		var view_box: Rect2 = _view_box(text)
		var image: Image = Image.new()
		image.load_svg_from_string(text, scale)
		var left: float = view_box.position.x
		if part[1]:
			image.flip_x()
			left = 2.0 * GIRL_MIRROR_X - view_box.end.x
		var at: Vector2 = (Vector2(left, view_box.position.y) - GIRL_ANCHOR) * scale + center
		canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(at.round()))
	return canvas


## Android 13 temalı simgesi yalnız saydamlığı kullanır: koyu yerler (gözler, ağız) saydamlaşsın diye saydamlık
## parlaklıkla çarpılır.
func _monochrome(source: Image) -> Image:
	var image: Image = source.duplicate()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1, 1, 1, color.a * smoothstep(0.15, 0.6, color.get_luminance())))
	return image


func _splash() -> Image:
	var image: Image = Image.create_empty(SPLASH_SIZE.x, SPLASH_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(SPLASH_COLOR)
	var logo: Image = _svg(OUT_DIR + "kidolab_logo.svg", SPLASH_LOGO_SCALE)
	image.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), (SPLASH_SIZE - logo.get_size()) / 2)
	return image


func _svg(path: String, scale: float) -> Image:
	var image: Image = Image.new()
	var err: Error = image.load_svg_from_string(FileAccess.get_file_as_string(path), scale)
	if err != OK:
		push_error("SVG okunamadı: %s (%s)" % [path, error_string(err)])
		_failed = true
	return image


func _view_box(text: String) -> Rect2:
	var regex: RegEx = RegEx.create_from_string("viewBox=\"([-\\d.]+) ([-\\d.]+) ([-\\d.]+) ([-\\d.]+)\"")
	var found: RegExMatch = regex.search(text)
	return Rect2(float(found.get_string(1)), float(found.get_string(2)), float(found.get_string(3)),
			float(found.get_string(4)))


func _save(image: Image, file_name: String) -> void:
	var err: Error = image.save_png(OUT_DIR + file_name)
	if err != OK:
		push_error("PNG kaydedilemedi: %s (%s)" % [file_name, error_string(err)])
		_failed = true
