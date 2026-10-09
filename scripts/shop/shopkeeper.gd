class_name Shopkeeper
extends Node2D
## Tezgâhın arkasındaki tilki satıcı. Bir ürün satılınca sevinçle zıplar, başını yana eğer ve paketi
## uzatır (cheer); paket hand_point'ten çıkar. Dokununca yumuşak bir tüy sesiyle zıplar ve başından kalpler
## çıkar (hayvan sesi yoktur).
## Kök noktası ayaklarının ortasıdır (tezgâhın arkasında kalır).

## Paketin çıktığı yer (kök noktasına göre): tezgâhın hemen üstü, sağ elinin önü.
const HAND: Vector2 = Vector2(-40.0, -150.0)
const HOP_HEIGHT: float = 24.0
const HOP_UP_TIME: float = 0.16
const HOP_DOWN_TIME: float = 0.3
const TILT_DEGREES: float = 10.0
const TILT_TIME: float = 0.2
const TILT_HOLD: float = 0.5
## Kalplerin çıktığı yer (kök noktasına göre): başın üstü.
const HEARTS: Vector2 = Vector2(0.0, -330.0)
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var heart_scene: PackedScene
@export_file("*.ogg", "*.wav") var tap_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"

var _tween: Tween
var _rest_y: float
var _tap_sound: AudioStream

@onready var _head: Node2D = $Head
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_rest_y = position.y
	if ResourceLoader.exists(tap_sound_path):
		_tap_sound = load(tap_sound_path) as AudioStream
	_tap_area.tapped.connect(_on_tapped)


func hand_point() -> Vector2:
	return to_global(HAND)


func cheer() -> void:
	if _tween != null:
		_tween.kill()
	position.y = _rest_y
	_tween = create_tween()
	_tween.tween_property(self, ^"position:y", _rest_y - HOP_HEIGHT, HOP_UP_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"position:y", _rest_y, HOP_DOWN_TIME).set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)
	var tilt: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tilt.tween_property(_head, ^"rotation", deg_to_rad(-TILT_DEGREES), TILT_TIME)
	tilt.tween_interval(TILT_HOLD)
	tilt.tween_property(_head, ^"rotation", 0.0, TILT_TIME)



## Önceki zıplama bitmeden gelen dokunuş yok sayılır.
func _on_tapped(_point: Vector2) -> void:
	if _tween != null and _tween.is_running():
		return
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_tap_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.9, 1.1), pan)
	if heart_scene != null:
		var hearts: CPUParticles2D = heart_scene.instantiate() as CPUParticles2D
		add_child(hearts)
		hearts.position = HEARTS
		hearts.finished.connect(hearts.queue_free)
		hearts.emitting = true
	cheer()
