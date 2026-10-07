class_name Nest
extends Node2D
## Kümesteki saman folluk. Tavuk üstüne oturup yumurtlayınca (lay) yumurta folluğun içinde belirir ve
## üstünde yıldızlar parlar. Folluğa dokununca içindeki bütün yumurtalar collected ile verilir (kümes
## onları sepete uçurur) ve folluk boşalır. Toplanmayan yumurtalar birikir; en fazla üçü görünür.
## Yumurtalar folluğun arkası ile önü arasında çizilir: önü (z_index 1) üstüne oturan tavuğun da önündedir.
## Kök noktası folluğun dibinin ortasıdır.

signal laid
signal collected(count: int, global_point: Vector2)

const EGG_POP_TIME: float = 0.3
const SQUASH: Vector2 = Vector2(1.08, 0.92)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.35

@export var sparkle_scene: PackedScene

var eggs: int = 0

var _egg_sprites: Array[Node2D] = []
var _egg_scales: Array[Vector2] = []

@onready var _body: Node2D = $Body
@onready var _glint: CPUParticles2D = $Glint
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_egg_sprites.assign($Body/Eggs.get_children())
	for egg: Node2D in _egg_sprites:
		_egg_scales.append(egg.scale)
	_tap_area.tapped.connect(func(_point: Vector2) -> void: _collect())
	_refresh(false)


## Görünen ilk yumurtanın dünya konumu (yumurtalar buradan uçar).
func egg_position() -> Vector2:
	return _egg_sprites[0].global_position


func lay() -> void:
	eggs += 1
	_refresh(true)
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _egg_sprites[0].position
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	laid.emit()


func _collect() -> void:
	if eggs == 0:
		return
	var count: int = eggs
	var from: Vector2 = egg_position()
	eggs = 0
	_refresh(false)
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	collected.emit(count, from)


func _refresh(animate: bool) -> void:
	for i: int in _egg_sprites.size():
		var egg: Node2D = _egg_sprites[i]
		var was_visible: bool = egg.visible
		egg.visible = i < eggs
		if animate and egg.visible and not was_visible:
			egg.scale = Vector2.ZERO
			create_tween().tween_property(egg, ^"scale", _egg_scales[i], EGG_POP_TIME) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_glint.emitting = eggs > 0
	_tap_area.enabled = eggs > 0
