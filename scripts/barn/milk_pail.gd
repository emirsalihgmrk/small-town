class_name MilkPail
extends Node2D
## Ahırdaki süt kovası. Kovadaki süt yüzeyi doldukça genişleyip belirginleşir (set_level). İnek sağılmaya
## hazırken yerde dururken hafifçe zıplayıp dikkat çeker (set_inviting). Kök noktası kovanın tabanının
## ortasıdır.

const LEVEL_TIME: float = 0.25
## Süt yüzeyi boşa yakınken bu ölçekte görünür, doldukça 1'e çıkar.
const LOW_MILK_SCALE: float = 0.4
## Süt azken yüzey bu kadar aşağıda görünür.
const LOW_MILK_DROP: float = 8.0
const INVITE_HOP: float = 10.0
const INVITE_HOP_TIME: float = 0.18
const INVITE_PAUSE: float = 1.2
const SQUASH: Vector2 = Vector2(1.08, 0.92)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4

## Kovaya parmakla basılabilecek alan (kök noktasına göre); küçük parmaklar için cömert.
@export var grab_area: Rect2 = Rect2(-90.0, -150.0, 180.0, 170.0)
@export var sparkle_scene: PackedScene

var level: float = 0.0

var _level_tween: Tween
var _invite_tween: Tween
var _milk_rest: Vector2

@onready var _body: Node2D = $Body
@onready var _milk: Sprite2D = $Body/Milk
@onready var _top: Marker2D = $Top


func _ready() -> void:
	_milk_rest = _milk.position
	_show_level(level)


func contains(global_point: Vector2) -> bool:
	return grab_area.has_point(to_local(global_point))


## Kovanın ağzının ortası (dünya konumu); süt şişesi buradan çıkar.
func top() -> Vector2:
	return _top.global_position


func set_level(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if _level_tween != null:
		_level_tween.kill()
	_level_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_level_tween.tween_method(_show_level, level, value, LEVEL_TIME)
	level = value


func set_inviting(inviting: bool) -> void:
	if _invite_tween != null:
		_invite_tween.kill()
		_invite_tween = null
	_body.position = Vector2.ZERO
	if not inviting:
		return
	_invite_tween = create_tween().set_loops().set_trans(Tween.TRANS_QUAD)
	_invite_tween.tween_interval(INVITE_PAUSE)
	for i: int in 2:
		_invite_tween.tween_property(_body, ^"position:y", -INVITE_HOP, INVITE_HOP_TIME).set_ease(Tween.EASE_OUT)
		_invite_tween.tween_property(_body, ^"position:y", 0.0, INVITE_HOP_TIME).set_ease(Tween.EASE_IN)


## Süt kovaya düştü ya da kova yere kondu: kısa bir basılıp esneme.
func squash(with_sparkle: bool = false) -> void:
	if with_sparkle and sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _milk_rest
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_level(value: float) -> void:
	_milk.visible = value > 0.0
	_milk.scale = Vector2.ONE * lerpf(LOW_MILK_SCALE, 1.0, value)
	_milk.position = _milk_rest + Vector2(0.0, LOW_MILK_DROP * (1.0 - value))
