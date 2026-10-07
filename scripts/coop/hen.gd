class_name Hen
extends Node2D
## Kümesteki tavuk. Yemlikte ayrılmamış pay varken yemliğe yürüyüp yer, sonra suluğa gidip içer. Sulukta
## su yoksa başının üstünde su balonuyla bekler (susar); su gelince içer. Tavuk asla üzülüp kaybolmaz.
## Yiyip içtikten sonra doğrudan kümesteki kendi folluğuna yürüyüp üstüne oturur ve lay_wait_time
## kadar orada bekler. Sonra yumurtlar, folluktan kalkıp avludaki yerine döner ve yeniden acıkır;
## yumurta folluğa kalır (toplanmasını beklemez).
## Her zaman nefes alır ve başını hafifçe sallar; avluda aç beklerken ara sıra yere gagalar.
## Kayıtta tavuk üç durgun evreden biriyle tutulur (aç, susamış, follukta); yoldaki ya da işin ortasındaki
## tavuk, işi henüz yapılmamış evreye sayılır. Kayıttan açılırken sahne kapalıyken geçen süre kadar
## döngü ileri sarılır: yemlikte ve sulukta pay varsa yer, içer, follukta bekleyip yumurtlar.
## Kök noktası tavuğun ayaklarıdır; görsel sağa bakar, sola baksın diye kök aynalanır.

enum State { HUNGRY, GOING_TO_FEEDER, EATING, GOING_TO_WATERER, THIRSTY, DRINKING, GOING_TO_NEST, NESTING,
		GOING_HOME }

const PECK_DEGREES: float = 38.0
const PECK_TIME: float = 0.11
const PECK_COUNT: int = 2
const WALK_SPEED: float = 230.0
const WADDLE_DEGREES: float = 7.0
const WADDLE_STEP_TIME: float = 0.14
const WADDLE_HOP: float = 6.0
const SETTLE_TIME: float = 0.12
## Yemlikte ardı ardına gagalar; aralarda kısa duraklar.
const EAT_PECKS: int = 8
const EAT_PAUSE: float = 0.12
## İçerken gagasını suya daldırıp başını kaldırır (yutar).
const DRINK_SIPS: int = 3
const DRINK_DOWN_DEGREES: float = 45.0
const DRINK_UP_DEGREES: float = -25.0
const DRINK_DOWN_TIME: float = 0.25
const DRINK_UP_TIME: float = 0.35
## Yem görününce hepsi aynı anda koşmasın diye her tavuk bu aralıkta biraz bekler.
const REACT_DELAY_MIN: float = 0.2
const REACT_DELAY_MAX: float = 1.0
const BUBBLE_POP_TIME: float = 0.25
## Folluğa otururken kök noktası folluğun bu kadar üstünde durur; bacaklar folluğun önünde kaybolur.
const NEST_SEAT: Vector2 = Vector2(0.0, -8.0)
const NEST_HOP: float = 30.0
const NEST_HOP_TIME: float = 0.18
## Yumurtlarken hafifçe çöküp kalkar.
const LAY_PUSH: float = 6.0
const LAY_PUSH_TIME: float = 0.15
## İleri sararken yemliğe gidip yemenin ve suluğa gidip içmenin aldığı varsayılan süre.
const EAT_SIM_TIME: float = 5.0
const DRINK_SIM_TIME: float = 4.0
## İleri sarmada bir tavuğun en fazla bu kadar adım atması (sonsuz döngüye karşı).
const MAX_FAST_FORWARD_STEPS: int = 30
const PHASE_HUNGRY: String = "hungry"
const PHASE_THIRSTY: String = "thirsty"
const PHASE_NESTING: String = "nesting"

@export var feeder: Feeder
@export var waterer: Waterer
## Kümesteki kendi folluğu.
@export var nest: Nest
## Yemlikte ve sulukta durduğu yer (0, 1, 2); her tavuk ayrı yerde durur.
@export_range(0, 2) var spot_index: int = 0
## Folluğa oturduktan sonra yumurtlayana kadar orada beklediği süre.
@export_range(1.0, 300.0, 1.0, "suffix:s") var lay_wait_time: float = 30.0
@export_range(0.5, 30.0, 0.5, "suffix:s") var peck_interval_min: float = 2.5
@export_range(0.5, 30.0, 0.5, "suffix:s") var peck_interval_max: float = 6.0

var state: State = State.HUNGRY

var _home: Vector2
## Aç iken tepki gecikmesi, follukta yumurtlamaya kalan süre.
var _wait_left: float = 0.0
var _move_tween: Tween
var _waddle_tween: Tween
var _head_tween: Tween
var _bubble_tween: Tween

@onready var _body: Node2D = $Body
@onready var _head: Node2D = $Body/Neck/Head
@onready var _water_bubble: Node2D = $WaterBubble
@onready var _peck_timer: Timer = $PeckTimer


func _ready() -> void:
	_home = global_position
	_water_bubble.hide()
	_peck_timer.timeout.connect(_on_peck_timer)
	_peck_timer.start(randf_range(peck_interval_min, peck_interval_max))


func _process(delta: float) -> void:
	match state:
		State.HUNGRY:
			if not feeder.has_free_portion():
				_wait_left = randf_range(REACT_DELAY_MIN, REACT_DELAY_MAX)
				return
			_wait_left -= delta
			if _wait_left <= 0.0 and feeder.reserve():
				state = State.GOING_TO_FEEDER
				_walk_to(feeder.spot(spot_index), _eat)
		State.THIRSTY:
			if waterer.reserve():
				_hide_water_bubble()
				_drink()
		State.NESTING:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_lay()


func save_state() -> Dictionary:
	match state:
		State.GOING_TO_WATERER, State.THIRSTY, State.DRINKING:
			return {"phase": PHASE_THIRSTY}
		State.GOING_TO_NEST:
			return {"phase": PHASE_NESTING, "wait_left": lay_wait_time}
		State.NESTING:
			return {"phase": PHASE_NESTING, "wait_left": _wait_left}
	# Yemliğe giden ya da yiyen tavuğun payı henüz düşmedi; yumurtlayıp dönen tavuğun yumurtası folluğa
	# kalktığı anda kondu. İkisi de aç sayılır.
	return {"phase": PHASE_HUNGRY}


## Kayıttan kurar ve elapsed saniye kadar ileri sarar. Yemlik, suluk ve folluk önceden yüklenmiş olmalı;
## tavuklar sırayla yüklenir, paylar o sırayla paylaşılır.
func load_state(data: Dictionary, elapsed: float) -> void:
	var phase: String = str(data.get("phase", PHASE_HUNGRY))
	var wait: float = clampf(float(data.get("wait_left", lay_wait_time)), 0.0, lay_wait_time)
	var remaining: float = elapsed
	for i: int in MAX_FAST_FORWARD_STEPS:
		if phase == PHASE_NESTING:
			if remaining < wait:
				wait -= remaining
				break
			remaining -= wait
			nest.lay(false)
			phase = PHASE_HUNGRY
		elif phase == PHASE_THIRSTY:
			if remaining < DRINK_SIM_TIME or not waterer.reserve():
				break
			waterer.drink()
			remaining -= DRINK_SIM_TIME
			phase = PHASE_NESTING
			wait = lay_wait_time
		else:
			if remaining < EAT_SIM_TIME or not feeder.reserve():
				break
			feeder.eat()
			remaining -= EAT_SIM_TIME
			phase = PHASE_THIRSTY
	_place(phase, wait)


## Tavuğu evresinin yerine animasyonsuz koyar.
func _place(phase: String, wait: float) -> void:
	for tween: Tween in [_move_tween, _waddle_tween, _head_tween, _bubble_tween]:
		if tween != null:
			tween.kill()
	_body.rotation = 0.0
	_body.position = Vector2.ZERO
	_head.rotation = 0.0
	_water_bubble.hide()
	_water_bubble.scale = Vector2.ONE
	if phase == PHASE_NESTING:
		global_position = nest.global_position + NEST_SEAT
		state = State.NESTING
		_wait_left = wait
	elif phase == PHASE_THIRSTY:
		global_position = waterer.spot(spot_index)
		_face_toward(waterer.global_position.x)
		state = State.THIRSTY
		_water_bubble.visible = not waterer.has_free_portion()
	else:
		global_position = _home
		state = State.HUNGRY


func _eat() -> void:
	state = State.EATING
	_face_toward(feeder.global_position.x)
	_kill_head_tween()
	_head_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i: int in EAT_PECKS:
		_head_tween.tween_property(_head, ^"rotation", deg_to_rad(PECK_DEGREES), PECK_TIME)
		_head_tween.tween_property(_head, ^"rotation", 0.0, PECK_TIME)
		_head_tween.tween_interval(EAT_PAUSE * randf_range(0.5, 1.5))
	_head_tween.tween_callback(func() -> void:
		feeder.eat()
		state = State.GOING_TO_WATERER
		_walk_to(waterer.spot(spot_index), _arrive_at_waterer))


func _arrive_at_waterer() -> void:
	_face_toward(waterer.global_position.x)
	if waterer.reserve():
		_drink()
	else:
		state = State.THIRSTY
		_show_water_bubble()


func _drink() -> void:
	state = State.DRINKING
	_kill_head_tween()
	_head_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i: int in DRINK_SIPS:
		_head_tween.tween_property(_head, ^"rotation", deg_to_rad(DRINK_DOWN_DEGREES), DRINK_DOWN_TIME)
		_head_tween.tween_property(_head, ^"rotation", deg_to_rad(DRINK_UP_DEGREES), DRINK_UP_TIME)
	_head_tween.tween_property(_head, ^"rotation", 0.0, DRINK_DOWN_TIME)
	_head_tween.tween_callback(func() -> void:
		waterer.drink()
		state = State.GOING_TO_NEST
		_walk_to(nest.global_position + NEST_SEAT, _sit_on_nest))


## Folluğa varınca küçük bir sıçrayışla üstüne yerleşir; yumurtlama zamanı _process'te sayılır.
func _sit_on_nest() -> void:
	state = State.NESTING
	_wait_left = lay_wait_time
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(SETTLE_TIME)
	tween.tween_property(_body, ^"position:y", -NEST_HOP, NEST_HOP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"position:y", 0.0, NEST_HOP_TIME).set_ease(Tween.EASE_IN)


## Yumurtlar (yumurta hemen folluğa konur; tavuğun altında kalır), hafifçe çöküp kalkar, folluktan
## sıçrayıp avludaki yerine döner ve yeniden acıkır.
func _lay() -> void:
	state = State.GOING_HOME
	nest.lay()
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, ^"position:y", LAY_PUSH, LAY_PUSH_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"position:y", 0.0, LAY_PUSH_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(_body, ^"position:y", -NEST_HOP, NEST_HOP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"position:y", 0.0, NEST_HOP_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(_walk_to.bind(_home, _become_hungry))


func _become_hungry() -> void:
	state = State.HUNGRY


## Yürürken paytak paytak sallanıp her adımda hafifçe sekerek gider.
func _walk_to(target: Vector2, on_arrived: Callable) -> void:
	_face_toward(target.x)
	_kill_head_tween()
	_head.rotation = 0.0
	if _move_tween != null:
		_move_tween.kill()
	_start_waddle()
	_move_tween = create_tween()
	_move_tween.tween_property(self, ^"global_position", target, global_position.distance_to(target) / WALK_SPEED)
	_move_tween.tween_callback(func() -> void:
		_stop_waddle()
		on_arrived.call())


func _start_waddle() -> void:
	if _waddle_tween != null:
		_waddle_tween.kill()
	_waddle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0]:
		_waddle_tween.tween_property(_body, ^"rotation", deg_to_rad(WADDLE_DEGREES) * side, WADDLE_STEP_TIME)
		_waddle_tween.parallel().tween_property(_body, ^"position:y", -WADDLE_HOP, WADDLE_STEP_TIME * 0.5)
		_waddle_tween.parallel().tween_property(_body, ^"position:y", 0.0, WADDLE_STEP_TIME * 0.5) \
				.set_delay(WADDLE_STEP_TIME * 0.5)


func _stop_waddle() -> void:
	if _waddle_tween != null:
		_waddle_tween.kill()
		_waddle_tween = null
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"rotation", 0.0, SETTLE_TIME)
	tween.tween_property(_body, ^"position:y", 0.0, SETTLE_TIME)


## Tavuk x'e doğru döner; tam üstündeyse yönünü değiştirmez.
func _face_toward(x: float) -> void:
	var dx: float = x - global_position.x
	if absf(dx) >= 1.0:
		scale.x = absf(scale.x) * signf(dx)


func _on_peck_timer() -> void:
	if state == State.HUNGRY:
		_kill_head_tween()
		_head_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		for i: int in PECK_COUNT:
			_head_tween.tween_property(_head, ^"rotation", deg_to_rad(PECK_DEGREES), PECK_TIME)
			_head_tween.tween_property(_head, ^"rotation", 0.0, PECK_TIME)
	_peck_timer.start(randf_range(peck_interval_min, peck_interval_max))


func _kill_head_tween() -> void:
	if _head_tween != null:
		_head_tween.kill()
		_head_tween = null


func _show_water_bubble() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_water_bubble.scale = Vector2.ZERO
	_water_bubble.show()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_water_bubble, ^"scale", Vector2.ONE, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_water_bubble() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_water_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_bubble_tween.tween_callback(_water_bubble.hide)
