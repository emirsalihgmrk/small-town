class_name PondDuck
extends Node2D
## Havuzda yüzen ördek. Kendi kendine ara ara başka bir yere süzülür; swim_to ile çağrılınca (suya
## dokunulunca) halkaların biraz önüne yüzer. Yüzerken arkasında küçük halkalar bırakır (wake sinyali).
## Kök noktası gövdenin ortasıdır (su çizgisi); Body yön ve zıplama, Sprite sallanma içindir.

signal wake(local_position: Vector2)

const SPEED: float = 55.0
const ARRIVE_DISTANCE: float = 3.0
## Dokunulan noktanın bu kadar önünde durur (halkanın ortasına girmesin).
const STOP_SHORT: float = 30.0
const WANDER_MIN: float = 3.0
const WANDER_MAX: float = 7.0
const TURN_SPEED: float = 8.0
const BOB_PERIOD: float = 1.6
const BOB_DEGREES: float = 4.0
const BOB_PIXELS: float = 1.5
const WAKE_INTERVAL: float = 0.45
## Dümen suyunun çıktığı yer: kuyruğun arkası, su çizgisinin biraz altı (yöne göre aynalanır).
const WAKE_OFFSET: Vector2 = Vector2(-26.0, 10.0)
const HOP_HEIGHT: float = 18.0
const HOP_UP_TIME: float = 0.15
const HOP_DOWN_TIME: float = 0.3

## Ördeğin yüzebildiği elips (ebeveyne göre): merkez ve yarıçaplar.
var swim_center: Vector2 = Vector2.ZERO
var swim_radii: Vector2 = Vector2(80.0, 16.0)

var _target: Vector2
var _moving: bool = false
var _facing: float = 1.0
var _wander_left: float = 0.0
var _wake_left: float = 0.0
var _time: float = 0.0
var _hop: Tween

@onready var _body: Node2D = $Body
@onready var _sprite: Node2D = $Body/Sprite


func _ready() -> void:
	_time = randf() * BOB_PERIOD
	_wander_left = randf_range(WANDER_MIN, WANDER_MAX)


func swim_to(point: Vector2) -> void:
	var away: Vector2 = position - point
	_go(point + away.normalized() * STOP_SHORT if away.length() > STOP_SHORT else position)


## Durup zıplar ve arkasını döner (dokununca).
func hop() -> void:
	if _hop != null and _hop.is_running():
		return
	_facing = -_facing
	_moving = false
	_wander_left = randf_range(WANDER_MIN, WANDER_MAX)
	_hop = create_tween()
	_hop.tween_property(_body, ^"position:y", -HOP_HEIGHT, HOP_UP_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	_hop.tween_property(_body, ^"position:y", 0.0, HOP_DOWN_TIME).set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	var phase: float = _time * TAU / BOB_PERIOD
	_sprite.rotation = sin(phase) * deg_to_rad(BOB_DEGREES)
	_sprite.position.y = sin(phase + 1.0) * BOB_PIXELS
	_body.scale.x = move_toward(_body.scale.x, _facing, TURN_SPEED * delta)
	if _moving:
		position = position.move_toward(_target, SPEED * delta)
		_wake_left -= delta
		if _wake_left <= 0.0:
			_wake_left = WAKE_INTERVAL
			wake.emit(position + Vector2(WAKE_OFFSET.x * _facing, WAKE_OFFSET.y))
		if position.distance_to(_target) <= ARRIVE_DISTANCE:
			_moving = false
			_wander_left = randf_range(WANDER_MIN, WANDER_MAX)
		return
	_wander_left -= delta
	if _wander_left <= 0.0:
		var angle: float = randf() * TAU
		_go(swim_center + Vector2(cos(angle), sin(angle)) * swim_radii * sqrt(randf()))


## Hedef yüzme elipsinin dışındaysa en yakın kenarına çekilir.
func _go(point: Vector2) -> void:
	var normalized: Vector2 = (point - swim_center) / swim_radii
	if normalized.length() > 1.0:
		point = swim_center + normalized.normalized() * swim_radii
	_target = point
	_moving = position.distance_to(point) > ARRIVE_DISTANCE
	_wake_left = 0.0
	if absf(point.x - position.x) > 1.0:
		_facing = signf(point.x - position.x)
