class_name Feeder
extends Node2D
## Kümesteki yemlik. Sepetten getirilen bir buğday demeti dökülünce dolar; bir demet üç tavuğa da yeter.
## Boşken üstünde bir düşünce balonu durur: ortak sepette buğday varsa balonda buğday demeti, yoksa tarla
## görünür. Tarla görünürken balona dokununca bubble_tapped yayılır (kümes tarlaya götürür).
## Kök noktası yemliğin ayaklarının ortasıdır.

signal filled
signal bubble_tapped

const HIGHLIGHT_SCALE: Vector2 = Vector2(1.06, 1.06)
const HIGHLIGHT_TIME: float = 0.12
## Demet eğilip dökülmeye başladıktan sonra taneler yemlikte görünür.
const GRAIN_DELAY: float = 0.2
const GRAIN_RISE_TIME: float = 0.35
const POUR_TIME: float = 0.55
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
const NUDGE_SCALE: float = 1.25
const NUDGE_TIME: float = 0.12
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Buğday demetinin bırakılınca yemliğe sayıldığı alan (kök noktasına göre); küçük parmaklar için cömert.
@export var drop_area: Rect2 = Rect2(-170.0, -200.0, 340.0, 240.0)
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var pour_sound_path: String = "res://assets/audio/sfx/seed_sprinkle.ogg"

var full: bool = false

var _pour_sound: AudioStream
var _highlighted: bool = false
var _highlight_tween: Tween
var _bubble_tween: Tween
var _bubble_scale: Vector2

@onready var _body: Node2D = $Body
@onready var _grain: Node2D = $Body/Grain
@onready var _pour: CPUParticles2D = $Pour
@onready var _bubble: Node2D = $Bubble
@onready var _bubble_wheat: Node2D = $Bubble/Wheat
@onready var _bubble_field: Node2D = $Bubble/Field
@onready var _bubble_tap: Tappable = $Bubble/TapArea


func _ready() -> void:
	if ResourceLoader.exists(pour_sound_path):
		_pour_sound = load(pour_sound_path) as AudioStream
	_grain.hide()
	_bubble_scale = _bubble.scale
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)
	_bubble_tap.tapped.connect(func(_point: Vector2) -> void: bubble_tapped.emit())
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh_bubble_content())
	_refresh_bubble_content()


func contains(global_point: Vector2) -> bool:
	return drop_area.has_point(to_local(global_point))


## Parmaktaki demet yemliğin üstündeyken yemlik hafifçe büyür.
func set_highlighted(highlighted: bool) -> void:
	if highlighted == _highlighted:
		return
	_highlighted = highlighted
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_body, ^"scale", HIGHLIGHT_SCALE if highlighted else Vector2.ONE, HIGHLIGHT_TIME)


## Yemlik hemen dolu sayılır; taneler kısa bir dökülmeyle görünür olur.
func fill() -> void:
	if full:
		return
	full = true
	set_highlighted(false)
	_hide_bubble()
	_pour.emitting = true
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_pour_sound, AudioManager.BUS_SFX, 0.0, 1.0, pan)
	var tween: Tween = create_tween()
	tween.tween_interval(GRAIN_DELAY)
	tween.tween_callback(func() -> void:
		_grain.scale = Vector2(1.0, 0.0)
		_grain.show())
	tween.tween_property(_grain, ^"scale", Vector2.ONE, GRAIN_RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(POUR_TIME - GRAIN_DELAY - GRAIN_RISE_TIME, 0.0))
	tween.tween_callback(_on_poured)


## Balon boşken dikkat çekmek için bir kez zıplar (sepette buğday yokken demet çekilmeye çalışılınca).
func nudge_bubble() -> void:
	if not _bubble.visible or (_bubble_tween != null and _bubble_tween.is_running()):
		return
	_bubble_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale * NUDGE_SCALE, NUDGE_TIME)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, NUDGE_TIME * 2.0)


func _on_poured() -> void:
	_pour.emitting = false
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _grain.position
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	filled.emit()


func _refresh_bubble_content() -> void:
	var has_wheat: bool = Basket.count(Items.WHEAT) > 0
	_bubble_wheat.visible = has_wheat
	_bubble_field.visible = not has_wheat
	_bubble_tap.enabled = not full and not has_wheat


func _hide_bubble() -> void:
	_bubble_tap.enabled = false
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_bubble_tween.tween_callback(_bubble.hide)
