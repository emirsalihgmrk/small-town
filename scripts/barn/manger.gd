class_name Manger
extends Node2D
## Ahırdaki yemlik. Saman yığınından getirilen bir tutam bırakılınca dolar; içinde saman yığını belirir.
## Dolu yemlik ineğe BITES lokma yeter; her lokmada (eat_bite) yığın basıklaşır. Yalnızca boş yemlik
## doldurulabilir. Boşken üstünde bir düşünce balonu durur ve balonda saman tutamı görünür (ne yapılacağını
## hatırlatır). Kök noktası ayakların ortasıdır.

signal filled

const BITES: int = 3
const HIGHLIGHT_SCALE: Vector2 = Vector2(1.06, 1.06)
const HIGHLIGHT_TIME: float = 0.12
## Tutam bırakıldıktan sonra saman yemlikte görünür.
const HAY_DELAY: float = 0.2
const HAY_RISE_TIME: float = 0.35
const HAY_SHRINK_TIME: float = 0.3
const FALL_TIME: float = 0.55
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Saman tutamının bırakılınca yemliğe sayıldığı alan (kök noktasına göre); küçük parmaklar için cömert.
@export var drop_area: Rect2 = Rect2(-180.0, -260.0, 360.0, 300.0)
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var fill_sound_path: String = "res://assets/audio/sfx/hay_rustle.ogg"

## Yemlikte kalan lokma sayısı (0..BITES).
var bites: int = 0

var _fill_sound: AudioStream
var _highlighted: bool = false
var _highlight_tween: Tween
var _hay_tween: Tween
var _bubble_tween: Tween
var _bubble_scale: Vector2

@onready var _body: Node2D = $Body
@onready var _hay: Node2D = $Body/Hay
@onready var _fall: CPUParticles2D = $Fall
@onready var _bubble: Node2D = $Bubble


func _ready() -> void:
	if ResourceLoader.exists(fill_sound_path):
		_fill_sound = load(fill_sound_path) as AudioStream
	_hay.hide()
	_bubble_scale = _bubble.scale
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)


func contains(global_point: Vector2) -> bool:
	return drop_area.has_point(to_local(global_point))


func can_fill() -> bool:
	return bites == 0


func has_hay() -> bool:
	return bites > 0


## İnek bir lokma yedi; saman bitince balon geri gelir.
func eat_bite() -> void:
	if bites == 0:
		return
	bites -= 1
	if _hay_tween != null:
		_hay_tween.kill()
	_hay_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hay_tween.tween_property(_hay, ^"scale:y", float(bites) / BITES, HAY_SHRINK_TIME)
	if bites == 0:
		_hay_tween.tween_callback(_hay.hide)
		_show_bubble()


## Parmaktaki tutam yemliğin üstündeyken yemlik hafifçe büyür.
func set_highlighted(highlighted: bool) -> void:
	if highlighted == _highlighted:
		return
	_highlighted = highlighted
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_body, ^"scale", HIGHLIGHT_SCALE if highlighted else Vector2.ONE, HIGHLIGHT_TIME)


## Yemlik hemen dolu sayılır; saman kısa bir dökülmeyle görünür olur.
func fill() -> void:
	if not can_fill():
		return
	bites = BITES
	set_highlighted(false)
	_hide_bubble()
	_fall.emitting = true
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_fill_sound, AudioManager.BUS_SFX, 0.0, 0.9, pan)
	if _hay_tween != null:
		_hay_tween.kill()
	_hay_tween = create_tween()
	_hay_tween.tween_interval(HAY_DELAY)
	_hay_tween.tween_callback(func() -> void:
		_hay.scale = Vector2(1.0, 0.0)
		_hay.show())
	_hay_tween.tween_property(_hay, ^"scale", Vector2.ONE, HAY_RISE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hay_tween.tween_interval(maxf(FALL_TIME - HAY_DELAY - HAY_RISE_TIME, 0.0))
	_hay_tween.tween_callback(_on_filled)


func _on_filled() -> void:
	_fall.emitting = false
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _hay.position + Vector2(0.0, -60.0)
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	filled.emit()


func _show_bubble() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble.scale = Vector2.ZERO
	_bubble.show()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_bubble() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_bubble_tween.tween_callback(_bubble.hide)
