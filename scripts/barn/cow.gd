class_name Cow
extends Node2D
## Ahırdaki inek. Yemlikte saman varken yemliğe yürür ve BITES lokmada yer, sonra yerine döner ve sağındaki
## suluktan içer (yemlikle yeri arasında yürürken suluğun üstünden geçmesin diye suluk arkasında durur). Suluk tam dolu değilse başının üstünde su balonuyla bekler (susar); su gelince içer. İnek asla
## üzülüp kaybolmaz: aç ya da susuzsa yalnızca süt vermez. İçtikten sonra milk_time kadar bekler, sonra
## sırtının üstünde süt balonu belirir ve milk_ready yayılır (sağma sonraki adımda).
## Her zaman nefes alır, başı ve kuyruğu salınır; boşta dururken ara sıra başını silker. Yürürken
## bacaklarını çaprazlama sallayıp hafifçe sekerek gider.
## Kök noktası ineğin ayaklarının ortasıdır; görsel sola (yemliğe ve suluğa) bakar, sağa yürürken kök
## aynalanır.

signal milk_ready

enum State { HUNGRY, GOING_TO_MANGER, EATING, GOING_HOME, THIRSTY, DRINKING, MAKING_MILK, MILK_READY }

const SHAKE_DEGREES: float = 7.0
const SHAKE_TIME: float = 0.12
const SHAKE_COUNT: int = 2
const WALK_SPEED: float = 150.0
const STEP_TIME: float = 0.28
const STEP_DEGREES: float = 14.0
const STEP_BOB: float = 5.0
const SETTLE_TIME: float = 0.15
## Yerken ve içerken baş bu kadar öne eğilir ve boyunla birlikte aşağı iner (yemlikte samana, sulukta suya
## değecek kadar).
const HEAD_DOWN_DEGREES: float = -15.0
const EAT_NECK_DROP: float = 75.0
const DRINK_NECK_DROP: float = 85.0
const HEAD_DOWN_TIME: float = 0.35
const HEAD_UP_TIME: float = 0.4
## Her lokmada baş birkaç kez kısa kısa oynar (çiğner).
const CHEW_DEGREES: float = 5.0
const CHEW_TIME: float = 0.12
const CHEWS_PER_BITE: int = 3
const BITE_PAUSE: float = 0.3
## Her yudumda baş biraz kalkıp yeniden suya iner.
const SIP_LIFT_DEGREES: float = 7.0
const SIP_TIME: float = 0.3
const SIP_PAUSE: float = 0.2
## Saman görününce hemen değil, kısa bir an sonra yemliğe yürür.
const REACT_DELAY_MIN: float = 0.3
const REACT_DELAY_MAX: float = 0.8
const BUBBLE_POP_TIME: float = 0.25
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var manger: Manger
@export var trough: Trough
## Yemlikten yerken kök noktası yemliğin bu kadar sağında durur (ağız yemliğin üstüne gelsin).
@export var manger_reach: float = 274.0
## İçtikten sonra süt hazır olana kadar geçen süre.
@export_range(1.0, 300.0, 1.0, "suffix:s") var milk_time: float = 30.0
@export_range(0.5, 30.0, 0.5, "suffix:s") var shake_interval_min: float = 4.0
@export_range(0.5, 30.0, 0.5, "suffix:s") var shake_interval_max: float = 9.0
@export_file("*.ogg", "*.wav") var munch_sound_path: String = "res://assets/audio/sfx/bunny_munch.ogg"

var state: State = State.HUNGRY

var _home: Vector2
## Aç iken tepki gecikmesi, süt yaparken kalan süre.
var _wait_left: float = 0.0
var _move_tween: Tween
var _walk_tween: Tween
var _head_tween: Tween
var _bubble_tweens: Dictionary[Node2D, Tween] = {}
var _munch_sound: AudioStream

@onready var _body: Node2D = $Body
@onready var _neck: Node2D = $Body/Neck
@onready var _head: Node2D = $Body/Neck/Head
@onready var _neck_rest: Vector2 = _neck.position
@onready var _legs: Array[Node2D] = [$NearLegs/Front, $FarLegs/Back, $NearLegs/Back, $FarLegs/Front]
@onready var _water_bubble: Node2D = $WaterBubble
@onready var _milk_bubble: Node2D = $MilkBubble
@onready var _shake_timer: Timer = $ShakeTimer


func _ready() -> void:
	_home = global_position
	_water_bubble.hide()
	_milk_bubble.hide()
	if ResourceLoader.exists(munch_sound_path):
		_munch_sound = load(munch_sound_path) as AudioStream
	_shake_timer.timeout.connect(_on_shake_timer)
	_shake_timer.start(randf_range(shake_interval_min, shake_interval_max))


func _process(delta: float) -> void:
	match state:
		State.HUNGRY:
			if not manger.has_hay():
				_wait_left = randf_range(REACT_DELAY_MIN, REACT_DELAY_MAX)
				return
			_wait_left -= delta
			if _wait_left <= 0.0:
				state = State.GOING_TO_MANGER
				_walk_to(manger.global_position + Vector2(manger_reach, 0.0), _eat)
		State.THIRSTY:
			if trough.reserve():
				_hide_bubble(_water_bubble)
				_drink()
		State.MAKING_MILK:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_make_milk_ready()


## Başını eğip lokma lokma yer; her lokmada çiğner ve yemlikteki saman azalır. Bitince yerine döner.
func _eat() -> void:
	state = State.EATING
	_face_left()
	_kill_head_tween()
	_head_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_head_down(_head_tween, EAT_NECK_DROP)
	for i: int in Manger.BITES:
		_head_tween.tween_callback(_play_munch)
		for j: int in CHEWS_PER_BITE:
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(HEAD_DOWN_DEGREES + CHEW_DEGREES), CHEW_TIME)
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(HEAD_DOWN_DEGREES), CHEW_TIME)
		_head_tween.tween_callback(manger.eat_bite)
		_head_tween.tween_interval(BITE_PAUSE)
	_tween_head_up(_head_tween)
	_head_tween.tween_callback(func() -> void:
		state = State.GOING_HOME
		_walk_to(_home, _arrive_home))


func _arrive_home() -> void:
	_face_toward(trough.global_position.x)
	if trough.reserve():
		_drink()
	else:
		state = State.THIRSTY
		_show_bubble(_water_bubble)


## Başını suluğa eğip yudum yudum içer; her yudumda suluktaki su azalır. Sonra süt yapmaya başlar.
func _drink() -> void:
	state = State.DRINKING
	_kill_head_tween()
	_head_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_head_down(_head_tween, DRINK_NECK_DROP)
	for i: int in Trough.SIPS:
		_head_tween.tween_property(_head, ^"rotation", deg_to_rad(HEAD_DOWN_DEGREES + SIP_LIFT_DEGREES), SIP_TIME)
		_head_tween.tween_property(_head, ^"rotation", deg_to_rad(HEAD_DOWN_DEGREES), SIP_TIME)
		_head_tween.tween_callback(trough.sip)
		_head_tween.tween_interval(SIP_PAUSE)
	_tween_head_up(_head_tween)
	_head_tween.tween_callback(func() -> void:
		_face_left()
		state = State.MAKING_MILK
		_wait_left = milk_time)


func _make_milk_ready() -> void:
	state = State.MILK_READY
	_show_bubble(_milk_bubble)
	milk_ready.emit()


func _tween_head_down(tween: Tween, neck_drop: float) -> void:
	tween.tween_property(_head, ^"rotation", deg_to_rad(HEAD_DOWN_DEGREES), HEAD_DOWN_TIME)
	tween.parallel().tween_property(_neck, ^"position", _neck_rest + Vector2(0.0, neck_drop), HEAD_DOWN_TIME)


func _tween_head_up(tween: Tween) -> void:
	tween.tween_property(_head, ^"rotation", 0.0, HEAD_UP_TIME)
	tween.parallel().tween_property(_neck, ^"position", _neck_rest, HEAD_UP_TIME)


## Bacaklarını çaprazlama sallayıp hafifçe sekerek target'a yürür; varınca on_arrived çağrılır.
func _walk_to(target: Vector2, on_arrived: Callable) -> void:
	_face_toward(target.x)
	_kill_head_tween()
	_head.rotation = 0.0
	_neck.position = _neck_rest
	if _move_tween != null:
		_move_tween.kill()
	_start_walk()
	_move_tween = create_tween()
	_move_tween.tween_property(self, ^"global_position", target, global_position.distance_to(target) / WALK_SPEED)
	_move_tween.tween_callback(func() -> void:
		_stop_walk()
		on_arrived.call())


## Görsel sola bakar; sağa dönmek için kök aynalanır.
func _face_left() -> void:
	scale.x = absf(scale.x)


## İnek x'e doğru döner; tam önündeyse yönünü değiştirmez.
func _face_toward(x: float) -> void:
	var dx: float = x - global_position.x
	if absf(dx) >= 1.0:
		scale.x = absf(scale.x) * (1.0 if dx < 0.0 else -1.0)


## Çaprazdaki bacaklar (ön yakın + arka uzak, arka yakın + ön uzak) birlikte öne, öbür çift arkaya
## sallanır; her adımda gövde hafifçe seker.
func _start_walk() -> void:
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0]:
		_walk_tween.tween_interval(0.0)
		for i: int in _legs.size():
			var swing: float = deg_to_rad(STEP_DEGREES) * (side if i < 2 else -side)
			_walk_tween.parallel().tween_property(_legs[i], ^"rotation", swing, STEP_TIME)
		_walk_tween.parallel().tween_property(_body, ^"position:y", -STEP_BOB, STEP_TIME * 0.5)
		_walk_tween.parallel().tween_property(_body, ^"position:y", 0.0, STEP_TIME * 0.5).set_delay(STEP_TIME * 0.5)


func _stop_walk() -> void:
	if _walk_tween != null:
		_walk_tween.kill()
		_walk_tween = null
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for leg: Node2D in _legs:
		tween.tween_property(leg, ^"rotation", 0.0, SETTLE_TIME)
	tween.tween_property(_body, ^"position:y", 0.0, SETTLE_TIME)


func _play_munch() -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_munch_sound, AudioManager.BUS_SFX, -2.0, randf_range(0.75, 0.85), pan)


## Boşta dururken (aç, susamış, süt yaparken ya da süt hazırken) ara sıra başını silker.
func _on_shake_timer() -> void:
	if state in [State.HUNGRY, State.THIRSTY, State.MAKING_MILK, State.MILK_READY]:
		_kill_head_tween()
		_head_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for i: int in SHAKE_COUNT:
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(SHAKE_DEGREES), SHAKE_TIME)
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(-SHAKE_DEGREES), SHAKE_TIME)
		_head_tween.tween_property(_head, ^"rotation", 0.0, SHAKE_TIME)
	_shake_timer.start(randf_range(shake_interval_min, shake_interval_max))


func _kill_head_tween() -> void:
	if _head_tween != null:
		_head_tween.kill()
		_head_tween = null


func _show_bubble(bubble: Node2D) -> void:
	var tween: Tween = _restart_bubble_tween(bubble)
	bubble.scale = Vector2.ZERO
	bubble.show()
	tween.tween_property(bubble, ^"scale", Vector2.ONE, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_bubble(bubble: Node2D) -> void:
	var tween: Tween = _restart_bubble_tween(bubble)
	tween.tween_property(bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(bubble.hide)


func _restart_bubble_tween(bubble: Node2D) -> Tween:
	var old: Tween = _bubble_tweens.get(bubble)
	if old != null:
		old.kill()
	var tween: Tween = create_tween()
	_bubble_tweens[bubble] = tween
	return tween
