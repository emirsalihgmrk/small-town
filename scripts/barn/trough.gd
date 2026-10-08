class_name Trough
extends WaterTarget
## Ahırdaki suluk. Kova üstünde tutulup su döküldükçe dolar; su yüzeyi doldukça genişleyip belirginleşir.
## İnek yalnızca tam dolu suluktan içer: içmeye başlarken suluğu ayırır (reserve), her yudumda (sip) su
## SIPS'te biri kadar azalır. İnek içerken suluğa su dökülmez; su bitince suluk yeniden doldurulabilir.
## İçilmekte olan suluk kayıtta boş sayılır (inek içmiş sayılır). Kök noktası ayakların ortasıdır.

signal filled

const SIPS: int = 3
const LEVEL_TIME: float = 0.3
## Su yüzeyi boşa yakınken bu ölçekte görünür, doldukça 1'e çıkar.
const LOW_WATER_SCALE: float = 0.35
## Su azaldıkça yüzey bu kadar aşağıda görünür.
const LOW_WATER_DROP: float = 6.0
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const SPLASH_SOUND_INTERVAL_MS: int = 300
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Boş suluğu doldurmak için kovanın üstünde dökmesi gereken süre.
@export_range(0.1, 5.0, 0.1, "suffix:s") var water_needed: float = 1.5
## Kovanın ucu bu alandayken su suluğa dökülür (kök noktasına göre).
@export var pour_area: Rect2 = Rect2(-130.0, -255.0, 260.0, 220.0)
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var splash_sound_path: String = "res://assets/audio/sfx/water_splash.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var splash_volume_db: float = -4.0
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var sip_volume_db: float = -14.0

## Sudaki doluluk (0..1).
var level: float = 0.0

var _reserved: bool = false
var _splash_sound: AudioStream
var _last_splash_ms: int = -SPLASH_SOUND_INTERVAL_MS
var _level_tween: Tween
var _water_rest: Vector2

@onready var _body: Node2D = $Body
@onready var _water: Sprite2D = $Body/Water


func _ready() -> void:
	if ResourceLoader.exists(splash_sound_path):
		_splash_sound = load(splash_sound_path) as AudioStream
	_water_rest = _water.position
	_show_level(level)


func contains(global_point: Vector2) -> bool:
	return pour_area.has_point(to_local(global_point))


func needs_water() -> bool:
	return level < 1.0 and not _reserved


func is_full() -> bool:
	return level >= 1.0


## İnek içmeye başlıyor; suluk tam dolu değilse false döner.
func reserve() -> bool:
	if not is_full() or _reserved:
		return false
	_reserved = true
	return true


## İnek bir yudum içti. Son yudumda suluk boşalır ve yeniden doldurulabilir.
func sip() -> void:
	level = maxf(level - 1.0 / SIPS, 0.0)
	if level < 0.001:
		level = 0.0
		_reserved = false
	AudioManager.play_sfx(_splash_sound, AudioManager.BUS_SFX, sip_volume_db, randf_range(1.3, 1.45), _pan())
	if _level_tween != null:
		_level_tween.kill()
	_level_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_level_tween.tween_method(_show_level, _shown_level(), level, LEVEL_TIME)


func save_state() -> Dictionary:
	return {"level": 0.0 if _reserved else level}


## Kayıttan animasyonsuz kurar.
func load_state(data: Dictionary) -> void:
	_set_level_now(clampf(float(data.get("level", 0.0)), 0.0, 1.0))


## İleri sararken inek suluğu bir anda içip bitirdi. Suluk tam dolu değilse false döner (içilmez).
func drain_now() -> bool:
	if not is_full() or _reserved:
		return false
	_set_level_now(0.0)
	return true


func _set_level_now(value: float) -> void:
	level = value
	_reserved = false
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
		sparkle.position = _water_rest
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	filled.emit()


## Su yüzeyi doldukça genişler, yükselir ve belirginleşir; hiç su yokken görünmez.
func _show_level(value: float) -> void:
	_water.visible = value > 0.0
	_water.scale = Vector2.ONE * lerpf(LOW_WATER_SCALE, 1.0, value)
	_water.position = _water_rest + Vector2(0.0, LOW_WATER_DROP * (1.0 - value))
	_water.modulate.a = clampf(0.4 + value, 0.0, 1.0)


func _shown_level() -> float:
	return inverse_lerp(LOW_WATER_SCALE, 1.0, _water.scale.x) if _water.visible else 0.0


func _pan() -> float:
	return clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
