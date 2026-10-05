class_name SpringFollowComponent
extends Node
## Ebeveyn Node2D'ye (şapka, saç örgüsü...) ikincil hareket verir: bağlı olduğu düğüm dönünce
## ya da ivmelenince geriden gelir, sonra yaylanarak yerine oturur. Pivotu ebeveynin orijini belirler.

## Yay sertliği: büyüdükçe parça yerine daha çabuk döner.
@export_range(1.0, 400.0, 0.5) var stiffness: float = 60.0
## Sönüm: büyüdükçe salınım daha çabuk biter.
@export_range(0.0, 40.0, 0.1) var damping: float = 6.0
## Bağlı düğüm döndüğünde parçanın geride kalma çarpanı (1 = dünyada sabit kalır, büyük değer abartır).
@export_range(0.0, 10.0, 0.1) var rotation_inertia: float = 3.0
## İvmenin açıya etkisi (radyan / (px/s²)), eksen başına. Sol ve sağ örgüde dikey değer zıt işaretli olmalı.
@export var acceleration_influence: Vector2 = Vector2(0.00004, 0.0)
@export_range(0.0, 45.0, 0.5, "suffix:°") var max_angle_degrees: float = 12.0

var _target: Node2D
var _anchor: Node2D
var _rest_rotation: float = 0.0
var _angle: float = 0.0
var _angular_velocity: float = 0.0
var _previous_anchor_rotation: float = 0.0
var _previous_position: Vector2 = Vector2.ZERO
var _previous_velocity: Vector2 = Vector2.ZERO
var _primed: bool = false


func _ready() -> void:
	_target = get_parent() as Node2D
	_anchor = _target.get_parent() as Node2D if _target != null else null
	if _anchor == null:
		push_warning("SpringFollowComponent, başka bir Node2D'ye bağlı bir Node2D'nin altında olmalı: %s" % get_path())
		set_process(false)
		return
	_rest_rotation = _target.rotation


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var anchor_rotation: float = _anchor.global_rotation
	var position: Vector2 = _target.global_position
	if not _primed:
		_previous_anchor_rotation = anchor_rotation
		_previous_position = position
		_primed = true
		return
	var velocity: Vector2 = (position - _previous_position) / delta
	var acceleration: Vector2 = (velocity - _previous_velocity) / delta
	var turn: float = wrapf(anchor_rotation - _previous_anchor_rotation, -PI, PI)
	_previous_anchor_rotation = anchor_rotation
	_previous_position = position
	_previous_velocity = velocity

	_angle -= turn * rotation_inertia
	var push: float = acceleration.x * acceleration_influence.x + acceleration.y * acceleration_influence.y
	_angular_velocity += (-stiffness * (_angle + push) - damping * _angular_velocity) * delta
	var max_angle: float = deg_to_rad(max_angle_degrees)
	_angle = clampf(_angle + _angular_velocity * delta, -max_angle, max_angle)
	_target.rotation = _rest_rotation + _angle
