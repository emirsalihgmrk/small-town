class_name MilkHand
extends Node
## Süt kovasını ineğin altına götürüp sağma. Yerdeki kovaya basınca kova parmağı izler. Süt hazırken
## ineğin altına yakın bırakılırsa memenin altına oturur; değilse yerine döner. Kova ineğin altındayken
## memeye (ya da kovaya) her dokunuşta süt fışkırır ve kova SQUIRTS'te biri kadar dolar. Kova dolunca
## içinden bir süt şişesi sepete uçar (süt ortak sepete hemen eklenir), kova boşalıp yerine döner,
## inek yeniden acıkır ve milked yayılır. İnek sağılmaya hazırken yerdeki kova hafifçe zıplar.
## Kova kayda geçmez: sahne yarıda kapanırsa kova boş olarak yerine döner, inek sağılmaya hazır kalır.
## Tek parmak izlenir. Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir.
## Bu düğüm sahnede TapRouter'dan sonra gelmeli ki kovaya basış önce buraya ulaşsın.

signal milked

enum Phase { RESTING, DRAGGING, MOVING, PLACED }

const NO_TOUCH: int = -1
## Kovanın kök noktası (tabanı) parmağın bu kadar altında durur: parmak kovanın ortasını tutar.
const HOLD_OFFSET: Vector2 = Vector2(0.0, 60.0)
## Kova parmağı bu hızla yakalar (büyük = sıkı takip).
const FOLLOW_SHARPNESS: float = 28.0
const PLACE_TIME: float = 0.2
const RETURN_TIME: float = 0.35
const SQUIRTS: int = 3
## Süt fışkırdıktan bu kadar sonra kovaya düşer.
const SQUIRT_FILL_DELAY: float = 0.12
## Kova dolduktan sonra şişe çıkmadan önceki kısa duraklama.
const FULL_PAUSE: float = 0.35

@export var pail: MilkPail
@export var cow: Cow
@export var basket: BasketView
## Kova, ineğin altındaki yerine bu kadar yakın bırakılırsa oraya oturur; küçük parmaklar için cömert.
@export var place_distance: float = 190.0

var _phase: Phase = Phase.RESTING
var _touch_index: int = NO_TOUCH
var _rest: Vector2
var _target: Vector2
var _squirts: int = 0


func _ready() -> void:
	_rest = pail.global_position
	cow.milk_ready.connect(refresh_invite)
	refresh_invite()


func _process(delta: float) -> void:
	if _phase == Phase.DRAGGING:
		pail.global_position = pail.global_position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		var point: Vector2 = _to_world(touch.position)
		if touch.pressed and _touch_index == NO_TOUCH:
			if _phase == Phase.RESTING and pail.contains(point):
				_pick_up(touch.index, point)
				get_viewport().set_input_as_handled()
			elif _phase == Phase.PLACED and (cow.udder_contains(point) or pail.contains(point)):
				_squirt()
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_target = _to_world(drag.position) + HOLD_OFFSET
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: kovayı bırak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_release()


func _pick_up(index: int, point: Vector2) -> void:
	_touch_index = index
	_phase = Phase.DRAGGING
	_target = point + HOLD_OFFSET
	pail.set_inviting(false)


func _release() -> void:
	_touch_index = NO_TOUCH
	if cow.is_milk_ready() and pail.global_position.distance_to(cow.pail_spot()) <= place_distance:
		_place()
	else:
		_return_to_rest()


## Kova memenin altına kayıp yere oturur.
func _place() -> void:
	_phase = Phase.MOVING
	_squirts = 0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pail, ^"global_position", cow.pail_spot(), PLACE_TIME)
	tween.tween_callback(func() -> void:
		_phase = Phase.PLACED
		pail.squash())


func _return_to_rest() -> void:
	_phase = Phase.MOVING
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pail, ^"global_position", _rest, RETURN_TIME)
	tween.tween_callback(func() -> void:
		_phase = Phase.RESTING
		pail.squash()
		refresh_invite())


func _squirt() -> void:
	if _squirts >= SQUIRTS:
		return
	_squirts += 1
	cow.squirt()
	var level: float = float(_squirts) / SQUIRTS
	var tween: Tween = create_tween()
	tween.tween_interval(SQUIRT_FILL_DELAY)
	tween.tween_callback(func() -> void:
		pail.set_level(level)
		pail.squash())
	if _squirts == SQUIRTS:
		_phase = Phase.MOVING
		tween.tween_interval(FULL_PAUSE)
		tween.tween_callback(_on_full)


## Süt ortak sepete hemen eklenir (sahne kapansa da kaybolmaz); şişenin uçuşu yalnızca görünüştür.
func _on_full() -> void:
	pail.squash(true)
	Basket.add(Items.MILK)
	basket.receive(Items.MILK, pail.top())
	pail.set_level(0.0)
	cow.milked()
	milked.emit()
	_return_to_rest()


## Kova yerdeyken ve inek sağılmaya hazırken kova zıplayarak çağırır (kayıttan kurulunca da çağrılır).
func refresh_invite() -> void:
	pail.set_inviting(_phase == Phase.RESTING and cow.is_milk_ready())


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point
