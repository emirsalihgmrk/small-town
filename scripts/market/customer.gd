class_name Customer
extends Node2D
## Pazara alışverişe gelen hayvan dost (tavşan, ayıcık ya da kirpi; görünüşü Looks altındaki çocuklardan
## biridir). Sağdan yürüyerek gelir, tezgâhın önünde durur ve başının üstünde isteğinin balonu açılır.
## Beklerken nefes alır, başını hafifçe sallar. Önden görünür, yürürken aynalanmaz; her adımda seker ve
## iki yana sallanır (bu hareket Hop düğümünde oynar).
## Her görünüşün BubbleAnchor işareti, balonun kuyruk ucunun duracağı yerdir. Kök noktası ayaklardır.
## Beklerken istediği ürünleri alır (SellHand getirir): her ürün balondaki yuvasını doldurur, müşteri
## sevinçle zıplar. Ürün müşterinin üstüne ya da balonuna bırakılabilir; parmaktaki ürün oradayken müşteri
## hafifçe büyür.
## İsteği tamamlanınca balonu kapanır ve başından kalpler çıkar (thank); sonra sağa yürüyüp gider (leave).

signal arrived
signal item_received(slot: int)
signal order_completed
signal left

enum State { AWAY, WALKING_IN, WAITING, LEAVING }

const WALK_SPEED: float = 280.0
const STEP_TIME: float = 0.16
const STEP_HOP: float = 12.0
const WADDLE_DEGREES: float = 5.0
const SETTLE_TIME: float = 0.15
const BUBBLE_DELAY: float = 0.25
const BREATH_SCALE: float = 1.025
const BREATH_PERIOD: float = 2.6
const HEAD_SWAY_DEGREES: float = 3.0
const HEAD_SWAY_PERIOD: float = 3.2
## Ürünün bırakılınca müşteriye sayıldığı alanın genişliği; yüksekliği ayaklardan balonun üstüne kadardır.
const DROP_WIDTH: float = 300.0
## Balonun kuyruk ucundan yukarı, balonun üstüne kadar olan yükseklik.
const BUBBLE_HEIGHT: float = 180.0
## Verilen ürünün uçtuğu yer (göğsü, kök noktasına göre).
const HAND_POINT: Vector2 = Vector2(0.0, -100.0)
const HIGHLIGHT_SCALE: Vector2 = Vector2(1.06, 1.06)
const HIGHLIGHT_TIME: float = 0.12
const HAPPY_HOP: float = 30.0
const HAPPY_HOP_TIME: float = 0.15
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6
## Kalpler balonun kuyruk ucunun bu kadar altından çıkar (başının üstü).
const HEART_BELOW_BUBBLE: float = 40.0

@export var heart_scene: PackedScene
@export_file("*.ogg", "*.wav") var receive_sound_path: String = "res://assets/audio/sfx/basket_drop.ogg"

var state: State = State.AWAY
## Görünüşün Looks altındaki sırası.
var kind: int = 0
var order: Array[StringName] = []

var _filled: Array[bool] = []
var _move_tween: Tween
var _waddle_tween: Tween
var _highlight_tween: Tween
var _hop_tween: Tween
var _highlighted: bool = false
var _looks: Array[Node2D] = []
var _receive_sound: AudioStream

@onready var _hop: Node2D = $Hop
@onready var _bubble: RequestBubble = $Bubble


func _ready() -> void:
	if ResourceLoader.exists(receive_sound_path):
		_receive_sound = load(receive_sound_path) as AudioStream
	_looks.assign($Hop/Looks.get_children())
	for look: Node2D in _looks:
		Oscillation.ping_pong(self, look, ^"scale:y", 1.0, BREATH_SCALE, BREATH_PERIOD, 0.1)
		Oscillation.ping_pong(self, look.get_node(^"Head"), ^"rotation", deg_to_rad(-HEAD_SWAY_DEGREES),
				deg_to_rad(HEAD_SWAY_DEGREES), HEAD_SWAY_PERIOD, 0.15)
	hide()


func look_count() -> int:
	return _looks.size()


## from'dan to'ya yürüyüp durur, sonra isteğinin balonunu açar ve arrived yayar.
func arrive(new_kind: int, new_order: Array[StringName], from: Vector2, to: Vector2) -> void:
	kind = clampi(new_kind, 0, _looks.size() - 1)
	order = new_order
	_filled.resize(order.size())
	_filled.fill(false)
	for i: int in _looks.size():
		_looks[i].visible = i == kind
	_bubble.hide()
	_bubble.position = (_looks[kind].get_node(^"BubbleAnchor") as Node2D).position
	global_position = from
	show()
	state = State.WALKING_IN
	_start_waddle()
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, ^"global_position", to, from.distance_to(to) / WALK_SPEED)
	_move_tween.tween_callback(_stop_waddle)
	_move_tween.tween_interval(BUBBLE_DELAY)
	_move_tween.tween_callback(func() -> void:
		state = State.WAITING
		_bubble.open(order)
		arrived.emit())


## Balonu kapanır, başından kalpler çıkar ve sevinçle zıplar.
func thank() -> void:
	_bubble.close()
	if heart_scene != null:
		var hearts: CPUParticles2D = heart_scene.instantiate() as CPUParticles2D
		add_child(hearts)
		hearts.position = _bubble.position + Vector2(0.0, HEART_BELOW_BUBBLE)
		hearts.finished.connect(hearts.queue_free)
		hearts.emitting = true
	_happy_hop()


## to'ya yürür, orada kaybolur ve left yayar.
func leave(to: Vector2) -> void:
	state = State.LEAVING
	set_highlighted(false)
	_start_waddle()
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, ^"global_position", to, global_position.distance_to(to) / WALK_SPEED)
	_move_tween.tween_callback(func() -> void:
		_stop_waddle()
		hide()
		state = State.AWAY
		left.emit())


func is_present() -> bool:
	return state != State.AWAY


## Tezgâhın önünde bekliyor ve isteğinde verilmemiş ürün var.
func can_receive() -> bool:
	return state == State.WAITING and _filled.has(false)


## Henüz verilmemiş yuvalar, balondaki sırayla.
func open_slots() -> Array[int]:
	var slots: Array[int] = []
	for i: int in _filled.size():
		if not _filled[i]:
			slots.append(i)
	return slots


func wanted(slot: int) -> StringName:
	return order[slot]


func contains(global_point: Vector2) -> bool:
	var top: float = (_looks[kind].get_node(^"BubbleAnchor") as Node2D).position.y - BUBBLE_HEIGHT
	return Rect2(-DROP_WIDTH * 0.5, top, DROP_WIDTH, -top).has_point(to_local(global_point))


func hand_point() -> Vector2:
	return to_global(HAND_POINT)


func set_highlighted(highlighted: bool) -> void:
	if highlighted == _highlighted:
		return
	_highlighted = highlighted
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_hop, ^"scale", HIGHLIGHT_SCALE if highlighted else Vector2.ONE, HIGHLIGHT_TIME)


## Yuva hemen dolu sayılır; müşteri sevinçle zıplar. Son ürünle order_completed da yayılır.
func receive(slot: int) -> void:
	if slot < 0 or slot >= _filled.size() or _filled[slot]:
		return
	_filled[slot] = true
	set_highlighted(false)
	_bubble.fill(slot)
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_receive_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.05), pan)
	_happy_hop()
	item_received.emit(slot)
	if not _filled.has(false):
		order_completed.emit()


func _happy_hop() -> void:
	if _hop_tween != null:
		_hop_tween.kill()
	_hop_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_hop_tween.tween_property(_hop, ^"position:y", -HAPPY_HOP, HAPPY_HOP_TIME).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_hop, ^"position:y", 0.0, HAPPY_HOP_TIME).set_ease(Tween.EASE_IN)


func _start_waddle() -> void:
	if _waddle_tween != null:
		_waddle_tween.kill()
	_waddle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0]:
		_waddle_tween.tween_property(_hop, ^"rotation", deg_to_rad(WADDLE_DEGREES) * side, STEP_TIME)
		_waddle_tween.parallel().tween_property(_hop, ^"position:y", -STEP_HOP, STEP_TIME * 0.5)
		_waddle_tween.parallel().tween_property(_hop, ^"position:y", 0.0, STEP_TIME * 0.5) \
				.set_delay(STEP_TIME * 0.5)


func _stop_waddle() -> void:
	if _waddle_tween != null:
		_waddle_tween.kill()
		_waddle_tween = null
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hop, ^"rotation", 0.0, SETTLE_TIME)
	tween.tween_property(_hop, ^"position:y", 0.0, SETTLE_TIME)
