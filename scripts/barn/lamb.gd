class_name Lamb
extends Node2D
## Ahırın köşesindeki kuzu. Nefes alır, başını hafifçe sallar, ara sıra başını eğip yerdeki samanı
## kemirir. Dokununca sevinçle iki kez zıplar (dört ayağı birden yerden kesilir), başından kalpler çıkar
## ve yumuşak bir yün sesi ("fırt") çalar; hopped yayılır. Ekonomiye karışmaz, süstür.
## Kök noktası kuzunun ayaklarının ortasıdır; görsel sola bakar.

signal hopped

const NIBBLE_DEGREES: float = -28.0
const NIBBLE_DOWN_TIME: float = 0.3
const NIBBLE_TIME: float = 0.1
const NIBBLES: int = 3
const NIBBLE_HOLD_TIME: float = 0.2
const HOP_HEIGHT: float = 46.0
const HOP_UP_TIME: float = 0.18
const HOP_DOWN_TIME: float = 0.16
const HOPS: int = 2
const HOP_STRETCH: Vector2 = Vector2(0.92, 1.1)
const LAND_SQUASH: Vector2 = Vector2(1.12, 0.88)
const LAND_TIME: float = 0.07
const SETTLE_TIME: float = 0.35
const HEART_OFFSET: Vector2 = Vector2(-70.0, -150.0)
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export_range(0.5, 60.0, 0.5, "suffix:s") var nibble_interval_min: float = 5.0
@export_range(0.5, 60.0, 0.5, "suffix:s") var nibble_interval_max: float = 11.0
@export var heart_scene: PackedScene
@export_file("*.ogg", "*.wav") var fluff_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"

var _fluff_sound: AudioStream
var _head_tween: Tween
var _hop_tween: Tween

@onready var _hop: Node2D = $Hop
@onready var _head: Node2D = $Hop/Body/Neck/Head
@onready var _nibble_timer: Timer = $NibbleTimer


func _ready() -> void:
	if ResourceLoader.exists(fluff_sound_path):
		_fluff_sound = load(fluff_sound_path) as AudioStream
	($TapArea as Tappable).tapped.connect(func(_point: Vector2) -> void: _on_tapped())
	_nibble_timer.timeout.connect(_nibble)
	_nibble_timer.start(randf_range(nibble_interval_min, nibble_interval_max))


func _nibble() -> void:
	if _hop_tween == null or not _hop_tween.is_running():
		if _head_tween != null:
			_head_tween.kill()
		_head_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_head_tween.tween_property(_head, ^"rotation", deg_to_rad(NIBBLE_DEGREES), NIBBLE_DOWN_TIME)
		for i: int in NIBBLES:
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(NIBBLE_DEGREES + 6.0), NIBBLE_TIME)
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(NIBBLE_DEGREES), NIBBLE_TIME)
		_head_tween.tween_interval(NIBBLE_HOLD_TIME)
		_head_tween.tween_property(_head, ^"rotation", 0.0, NIBBLE_DOWN_TIME)
	_nibble_timer.start(randf_range(nibble_interval_min, nibble_interval_max))


## Önceki zıplama bitmeden gelen dokunuş yok sayılır.
func _on_tapped() -> void:
	if _hop_tween != null and _hop_tween.is_running():
		return
	if _head_tween != null:
		_head_tween.kill()
	_head.rotation = 0.0
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_fluff_sound, AudioManager.BUS_SFX, 0.0, randf_range(1.05, 1.2), pan)
	if heart_scene != null:
		var hearts: CPUParticles2D = heart_scene.instantiate() as CPUParticles2D
		add_child(hearts)
		hearts.position = HEART_OFFSET
		hearts.finished.connect(hearts.queue_free)
		hearts.emitting = true
	_hop_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	for i: int in HOPS:
		_hop_tween.tween_property(_hop, ^"scale", HOP_STRETCH, HOP_UP_TIME * 0.5).set_ease(Tween.EASE_OUT)
		_hop_tween.parallel().tween_property(_hop, ^"position:y", -HOP_HEIGHT, HOP_UP_TIME).set_ease(Tween.EASE_OUT)
		_hop_tween.tween_property(_hop, ^"position:y", 0.0, HOP_DOWN_TIME).set_ease(Tween.EASE_IN)
		_hop_tween.parallel().tween_property(_hop, ^"scale", Vector2.ONE, HOP_DOWN_TIME)
		_hop_tween.tween_property(_hop, ^"scale", LAND_SQUASH, LAND_TIME).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_hop, ^"scale", Vector2.ONE, SETTLE_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hopped.emit()
