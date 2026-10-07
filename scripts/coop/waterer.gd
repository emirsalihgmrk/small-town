class_name Waterer
extends Node2D
## Kümesteki suluk. Kova üstünde tutulup su döküldükçe dolar; dolu suluk üç tavuğa birer pay yeter ve
## her üçte biri dolunca bir pay hazır olur. Tavuk içmeye gelince payını ayırır (reserve), içince pay
## düşer (drink) ve su azalır. Tavukların sulukta durduğu yerler Spots altındaki işaretlerdir.
## Kök noktası suluğun tabanının ortasıdır.

signal filled

const PORTIONS: int = 3
const LEVEL_TIME: float = 0.3
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const SPLASH_SOUND_INTERVAL_MS: int = 300
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Boş suluğu doldurmak için kovanın üstünde dökmesi gereken süre.
@export_range(0.1, 5.0, 0.1, "suffix:s") var water_needed: float = 1.5
## Kovanın ucu bu alandayken su suluğa dökülür (kök noktasına göre).
@export var pour_area: Rect2 = Rect2(-110.0, -260.0, 220.0, 270.0)
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var splash_sound_path: String = "res://assets/audio/sfx/water_splash.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var splash_volume_db: float = -4.0

## Sudaki doluluk (0..1).
var level: float = 0.0

var _reserved: int = 0
var _splash_sound: AudioStream
var _last_splash_ms: int = -SPLASH_SOUND_INTERVAL_MS
var _level_tween: Tween
var _spots: Array[Node2D] = []
var _water_size: Vector2
var _water_top: Vector2

@onready var _body: Node2D = $Body
@onready var _water: Sprite2D = $Body/Water
@onready var _dish_water: Sprite2D = $Body/DishWater


func _ready() -> void:
	if ResourceLoader.exists(splash_sound_path):
		_splash_sound = load(splash_sound_path) as AudioStream
	_spots.assign($Spots.get_children())
	_water_size = _water.texture.get_size()
	_water_top = _water.offset
	_water.region_enabled = true
	_show_level(level)


func contains(global_point: Vector2) -> bool:
	return pour_area.has_point(to_local(global_point))


## index. tavuğun sulukta durduğu yer (dünya konumu).
func spot(index: int) -> Vector2:
	return _spots[index].global_position


## İçilmeye hazır pay sayısı: her üçte bir dolulukta bir pay.
func portions() -> int:
	return floori(level * PORTIONS + 0.001)


func needs_water() -> bool:
	return level < 1.0


## Henüz bir tavuğa ayrılmamış pay var mı.
func has_free_portion() -> bool:
	return portions() - _reserved > 0


## Bir payı tavuk için ayırır; ayrılacak pay yoksa false döner.
func reserve() -> bool:
	if not has_free_portion():
		return false
	_reserved += 1
	return true


## Ayrılmış payı tavuk içti.
func drink() -> void:
	_reserved = maxi(_reserved - 1, 0)
	level = maxf(level - 1.0 / PORTIONS, 0.0)
	if _level_tween != null:
		_level_tween.kill()
	_level_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_level_tween.tween_method(_show_level, _shown_level(), level, LEVEL_TIME)


func save_state() -> Dictionary:
	return {"level": level}


## Kayıttan animasyonsuz kurar; ayrılmış paylar sıfırlanır (tavuklar kendi kayıtlarından yeniden kurulur).
func load_state(data: Dictionary) -> void:
	level = clampf(float(data.get("level", 0.0)), 0.0, 1.0)
	_reserved = 0
	if _level_tween != null:
		_level_tween.kill()
	_show_level(level)


## Kova bu suluğun üstünde delta saniye su döktü.
func water(delta: float) -> void:
	if not needs_water():
		return
	if _level_tween != null:
		_level_tween.kill()
	level = minf(level + delta / water_needed, 1.0)
	_show_level(level)
	var now: int = Time.get_ticks_msec()
	if now - _last_splash_ms >= SPLASH_SOUND_INTERVAL_MS:
		_last_splash_ms = now
		AudioManager.play_sfx(_splash_sound, AudioManager.BUS_SFX, splash_volume_db, randf_range(0.92, 1.08), _pan())
	if level >= 1.0:
		_on_filled()


func _on_filled() -> void:
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _water_top + _water_size * 0.5
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	filled.emit()


## Çandaki su alttan yükselir: dokunun yalnızca alttaki value kadarı çizilir. Çanakta su, biraz bile
## su varken görünür.
func _show_level(value: float) -> void:
	var hidden: float = _water_size.y * (1.0 - value)
	_water.region_rect = Rect2(0.0, hidden, _water_size.x, _water_size.y - hidden)
	_water.offset = _water_top + Vector2(0.0, hidden)
	_water.visible = value > 0.0
	_dish_water.modulate.a = clampf(value * PORTIONS, 0.0, 1.0)


func _shown_level() -> float:
	return 1.0 - _water.region_rect.position.y / _water_size.y if _water.visible else 0.0


func _pan() -> float:
	return clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
