class_name PlayPond
extends Node2D
## Ana ekrandaki küçük havuz (Dükkân'dan alınınca görünür). Suya dokununca halkalar yayılır ve ördek oraya
## yüzer; birkaç dokunuşta bir sudan bir balık sıçrayıp dalar, kız şaşırır. Ördeğe dokununca zıplayıp
## arkasını döner, başından kalpler çıkar (hayvan sesi yoktur). Kayıt yoktur.
## Kök noktası havuzun yerdeki ortasıdır; aşağıdaki ölçüler pond_basin.svg'nin 1.15 ölçekli hâline göredir.

const WATER_CENTER: Vector2 = Vector2(0.0, -48.0)
## Halkaların ve balığın çıkabildiği iç elips (halkalar taş kenara taşmasın).
const RIPPLE_RADII: Vector2 = Vector2(90.0, 24.0)
## Ördeğin yüzdüğü elips: soldaki nilüfer ve sazların üstüne çıkmasın diye biraz sağda.
const SWIM_CENTER: Vector2 = Vector2(10.0, -46.0)
const SWIM_RADII: Vector2 = Vector2(80.0, 16.0)
const WAKE_SIZE: float = 0.45
## Balık bu kadar dokunuşta bir sıçrar (aradaki sayı her seferinde rastgele).
const FISH_TAPS_MIN: int = 2
const FISH_TAPS_MAX: int = 4
const FISH_HEIGHT: float = 70.0
const FISH_DISTANCE: float = 60.0
const FISH_TIME: float = 0.8
## Balığın burnu çıkarken yukarı, dalarken aşağı bakar (radyan).
const FISH_TILT: float = 0.9
## Kalplerin çıktığı yer, ördeğe göre.
const DUCK_HEARTS: Vector2 = Vector2(0.0, -50.0)
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var girl: Girl
@export var heart_scene: PackedScene
@export_file("*.ogg", "*.wav") var splash_sound_path: String = "res://assets/audio/sfx/water_splash.ogg"
@export_range(-30.0, 6.0, 0.5, "suffix:dB") var drop_volume_db: float = -8.0
@export_file("*.ogg", "*.wav") var duck_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"

var _taps_until_fish: int
var _splash_sound: AudioStream
var _duck_sound: AudioStream

@onready var _ripples: PondRipples = $Ripples
@onready var _duck: PondDuck = $Duck
@onready var _fish: Node2D = $Fish


func _ready() -> void:
	if ResourceLoader.exists(splash_sound_path):
		_splash_sound = load(splash_sound_path) as AudioStream
	if ResourceLoader.exists(duck_sound_path):
		_duck_sound = load(duck_sound_path) as AudioStream
	_taps_until_fish = randi_range(FISH_TAPS_MIN, FISH_TAPS_MAX)
	_fish.visible = false
	_duck.swim_center = SWIM_CENTER
	_duck.swim_radii = SWIM_RADII
	_duck.wake.connect(func(point: Vector2) -> void: _ripples.splash(point, WAKE_SIZE, 1))
	($WaterTap as Tappable).tapped.connect(_on_water_tapped)
	($Duck/TapArea as Tappable).tapped.connect(_on_duck_tapped)


func _on_water_tapped(global_point: Vector2) -> void:
	var point: Vector2 = _inside(to_local(global_point), WATER_CENTER, RIPPLE_RADII)
	_ripples.splash(point)
	_play(_splash_sound, drop_volume_db, 1.35)
	_duck.swim_to(point)
	_taps_until_fish -= 1
	if _taps_until_fish <= 0 and not _fish.visible:
		_taps_until_fish = randi_range(FISH_TAPS_MIN, FISH_TAPS_MAX)
		_leap()


func _on_duck_tapped(_point: Vector2) -> void:
	_duck.hop()
	_ripples.splash(_duck.position + Vector2(0.0, 8.0), 0.8, 2)
	_play(_duck_sound, 0.0, 1.0)
	if heart_scene != null:
		var hearts: CPUParticles2D = heart_scene.instantiate() as CPUParticles2D
		add_child(hearts)
		hearts.position = _duck.position + DUCK_HEARTS
		hearts.finished.connect(hearts.queue_free)
		hearts.emitting = true


## Balık ördeğin öbür yanından çıkar, havuzun ortasına doğru bir yay çizip dalar.
func _leap() -> void:
	var start_x: float = randf_range(-70.0, -20.0) if _duck.position.x > WATER_CENTER.x else randf_range(20.0, 70.0)
	var start: Vector2 = Vector2(start_x, WATER_CENTER.y + randf_range(-8.0, 8.0))
	var direction: float = -signf(start_x)
	var end: Vector2 = _inside(start + Vector2(direction * FISH_DISTANCE, 0.0), WATER_CENTER, RIPPLE_RADII)
	_fish.visible = true
	_fish.scale.x = direction
	_ripples.splash(start, 0.7, 2)
	if girl != null:
		girl.surprise()
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		_fish.position = start.lerp(end, t) + Vector2(0.0, -sin(PI * t) * FISH_HEIGHT)
		_fish.rotation = lerpf(-FISH_TILT, FISH_TILT, t) * direction, 0.0, 1.0, FISH_TIME)
	tween.tween_callback(func() -> void:
		_fish.visible = false
		_ripples.splash(end)
		_play(_splash_sound, 0.0, 1.0))


## Nokta elipsin dışındaysa en yakın kenarına çekilir.
func _inside(point: Vector2, center: Vector2, radii: Vector2) -> Vector2:
	var normalized: Vector2 = (point - center) / radii
	return center + normalized.normalized() * radii if normalized.length() > 1.0 else point


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(stream, AudioManager.BUS_SFX, volume_db, pitch * randf_range(0.92, 1.08), pan)
