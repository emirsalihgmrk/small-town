class_name Cow
extends Node2D
## Ahırdaki inek. Yemlikte saman varken yemliğe yürür ve BITES lokmada yer, sonra yerine döner ve sağındaki
## suluktan içer (yemlikle yeri arasında yürürken suluğun üstünden geçmesin diye suluk arkasında durur). Suluk tam dolu değilse başının üstünde su balonuyla bekler (susar); su gelince içer. İnek asla
## üzülüp kaybolmaz: aç ya da susuzsa yalnızca süt vermez. İçtikten sonra milk_time kadar bekler, sonra
## sırtının üstünde süt balonu belirir ve milk_ready yayılır. Sağılırken (MilkHand) her squirt'te memesi
## basılır ve kovaya süt fışkırır; sağılınca (milked) balon kaybolur ve yeniden acıkır.
## Her zaman nefes alır, başı ve kuyruğu salınır; boşta dururken ara sıra başını silker. Yürürken
## bacaklarını çaprazlama sallayıp hafifçe sekerek gider.
## Kayıtta inek dört durgun evreden biriyle tutulur (aç, susamış, süt yapıyor, süt hazır); yoldaki ya da
## işin ortasındaki inek, işi yapılmış evreye sayılır (yiyen inek susamış, içen inek süt yapıyor). Kayıttan
## açılırken sahne kapalıyken geçen süre kadar döngü ileri sarılır: yemlikte saman varsa yer, suluk doluysa
## içer, süt zamanı geçtiyse süt hazır olur. İnek her zaman yerinde kurulur.
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
## İleri sararken yemliğe gidip yemenin ve suluktan içmenin aldığı varsayılan süre.
const EAT_SIM_TIME: float = 6.0
const DRINK_SIM_TIME: float = 4.0
## İleri sarmada en fazla bu kadar adım atılır (sonsuz döngüye karşı).
const MAX_FAST_FORWARD_STEPS: int = 10
const PHASE_HUNGRY: String = "hungry"
const PHASE_THIRSTY: String = "thirsty"
const PHASE_MAKING_MILK: String = "making_milk"
const PHASE_MILK_READY: String = "milk_ready"
## Sağarken kova, kök noktasına göre burada (memenin altında, biraz önde) durur.
const PAIL_SPOT: Vector2 = Vector2(46.0, 50.0)
## Sağmak için dokunulabilecek alan (kök noktasına göre: meme ve altındaki kova); cömert.
const UDDER_AREA: Rect2 = Rect2(-60.0, -190.0, 210.0, 260.0)
const UDDER_SQUASH: Vector2 = Vector2(1.12, 0.82)
const UDDER_SQUASH_TIME: float = 0.07
const UDDER_SETTLE_TIME: float = 0.35
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
@export_file("*.ogg", "*.wav") var squirt_sound_path: String = "res://assets/audio/sfx/milk_squirt.ogg"

var state: State = State.HUNGRY

var _home: Vector2
## Aç iken tepki gecikmesi, süt yaparken kalan süre.
var _wait_left: float = 0.0
var _move_tween: Tween
var _walk_tween: Tween
var _head_tween: Tween
var _bubble_tweens: Dictionary[Node2D, Tween] = {}
var _munch_sound: AudioStream
var _squirt_sound: AudioStream
var _udder_tween: Tween

@onready var _body: Node2D = $Body
@onready var _neck: Node2D = $Body/Neck
@onready var _head: Node2D = $Body/Neck/Head
@onready var _neck_rest: Vector2 = _neck.position
@onready var _udder: Node2D = $Body/Udder
@onready var _squirt: CPUParticles2D = $Squirt
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
	if ResourceLoader.exists(squirt_sound_path):
		_squirt_sound = load(squirt_sound_path) as AudioStream
	_shake_timer.timeout.connect(_on_shake_timer)
	_shake_timer.start(randf_range(shake_interval_min, shake_interval_max))


func is_milk_ready() -> bool:
	return state == State.MILK_READY


## Sağarken kovanın duracağı yer (dünya konumu).
func pail_spot() -> Vector2:
	return to_global(PAIL_SPOT)


func udder_contains(global_point: Vector2) -> bool:
	return UDDER_AREA.has_point(to_local(global_point))


## Bir kez sağılır: memesi basılıp esner, kovaya süt fışkırır.
func squirt() -> void:
	if _udder_tween != null:
		_udder_tween.kill()
	_udder.scale = Vector2.ONE
	_udder_tween = create_tween()
	_udder_tween.tween_property(_udder, ^"scale", UDDER_SQUASH, UDDER_SQUASH_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_udder_tween.tween_property(_udder, ^"scale", Vector2.ONE, UDDER_SETTLE_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_squirt.restart()
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_squirt_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.08), pan)


## Sütü alındı: balon kaybolur, inek yeniden acıkır.
func milked() -> void:
	if state != State.MILK_READY:
		return
	_hide_bubble(_milk_bubble)
	state = State.HUNGRY


func save_state() -> Dictionary:
	match state:
		State.EATING, State.GOING_HOME, State.THIRSTY:
			return {"phase": PHASE_THIRSTY}
		State.DRINKING:
			return {"phase": PHASE_MAKING_MILK, "wait_left": milk_time}
		State.MAKING_MILK:
			return {"phase": PHASE_MAKING_MILK, "wait_left": _wait_left}
		State.MILK_READY:
			return {"phase": PHASE_MILK_READY}
	return {"phase": PHASE_HUNGRY}


## Kayıttan kurar ve elapsed saniye kadar ileri sarar. Yemlik ve suluk önceden yüklenmiş olmalı.
## milk_ready yayılmaz (kız el sallamaz); süt balonu doğrudan görünür.
func load_state(data: Dictionary, elapsed: float) -> void:
	var phase: String = str(data.get("phase", PHASE_HUNGRY))
	var wait: float = clampf(float(data.get("wait_left", milk_time)), 0.0, milk_time)
	var remaining: float = elapsed
	for i: int in MAX_FAST_FORWARD_STEPS:
		if phase == PHASE_MAKING_MILK:
			if remaining < wait:
				wait -= remaining
				break
			remaining -= wait
			phase = PHASE_MILK_READY
		elif phase == PHASE_THIRSTY:
			if remaining < DRINK_SIM_TIME or not trough.drain_now():
				break
			remaining -= DRINK_SIM_TIME
			phase = PHASE_MAKING_MILK
			wait = milk_time
		elif phase == PHASE_HUNGRY:
			if remaining < EAT_SIM_TIME or not manger.has_hay():
				break
			manger.empty_now()
			remaining -= EAT_SIM_TIME
			phase = PHASE_THIRSTY
		else:
			break
	_place(phase, wait)


## İneği evresine göre yerinde, animasyonsuz kurar.
func _place(phase: String, wait: float) -> void:
	for tween: Tween in [_move_tween, _walk_tween, _head_tween]:
		if tween != null:
			tween.kill()
	for tween: Tween in _bubble_tweens.values():
		tween.kill()
	global_position = _home
	_face_left()
	_body.position = Vector2.ZERO
	for leg: Node2D in _legs:
		leg.rotation = 0.0
	_head.rotation = 0.0
	_neck.position = _neck_rest
	_water_bubble.hide()
	_water_bubble.scale = Vector2.ONE
	_milk_bubble.hide()
	_milk_bubble.scale = Vector2.ONE
	match phase:
		PHASE_THIRSTY:
			state = State.THIRSTY
			_face_toward(trough.global_position.x)
			_water_bubble.visible = not trough.is_full()
		PHASE_MAKING_MILK:
			state = State.MAKING_MILK
			_wait_left = wait
		PHASE_MILK_READY:
			state = State.MILK_READY
			_milk_bubble.show()
		_:
			state = State.HUNGRY


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
	manger.reserve()
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
