class_name CoinHand
extends Node
## Dükkânda kumbaradan parayı parmakla çekip ürünün etiketine koyma. Kumbaraya basıp parmak biraz kayınca
## bir para kumbaranın deliğinden çıkar ve parmağı izler; üstüne gelinen ürün parlar. Henüz alınmamış bir
## ürünün üstünde bırakılırsa para o anda ortak paradan düşüp ürünün ödemesine yazılır (Owned.pay), etiketin
## sıradaki yuvasına uçar ve tın sesiyle oturur (coin_placed). Başka yerde bırakılırsa kumbaraya geri
## uçar. Kumbarada çekilecek para yoksa hiçbir şey çıkmaz ve refused yayılır. Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki kumbaraya basış önce buraya ulaşsın.

signal coin_placed(item: ShelfItem)
signal refused

const NO_TOUCH: int = -1
## Parmak bu kadar kaymadan para çıkmaz.
const DRAG_START_DISTANCE: float = 24.0
## Paranın parmağa göre yeri: parmak parayı örtmesin.
const HOLD_OFFSET: Vector2 = Vector2(0.0, -60.0)
const FOLLOW_SHARPNESS: float = 28.0
const JAR_SCALE: float = 0.6
const CARRY_SCALE: float = 1.5
const LIFT_TIME: float = 0.15
const RETURN_TIME: float = 0.3
const PLACE_TIME: float = 0.25
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var jar: CoinJar
## Çocukları ShelfItem olan düğüm.
@export var shelf_items: Node2D
## Taşınan para burada, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer
@export var coin_texture: Texture2D
@export_file("*.ogg", "*.wav") var clink_sound_path: String = "res://assets/audio/sfx/coin_clink.ogg"

var _touch_index: int = NO_TOUCH
var _start: Vector2
## Parmak bu basışta para çıkaramadı.
var _refused: bool = false
var _held: Sprite2D
var _target: Vector2
var _hovered: ShelfItem
var _clink_sound: AudioStream


func _ready() -> void:
	if ResourceLoader.exists(clink_sound_path):
		_clink_sound = load(clink_sound_path) as AudioStream


func _process(delta: float) -> void:
	if _held != null:
		_held.position = _held.position.lerp(_target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var point: Vector2 = _to_world(touch.position)
			if jar.contains(point):
				_touch_index = touch.index
				_start = point
				_refused = false
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release(_to_world(touch.position))
			_touch_index = NO_TOUCH
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_move(_to_world(drag.position))
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: parayı kumbaraya geri gönder.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_touch_index = NO_TOUCH
			if _held != null:
				_set_hovered(null)
				_return()


func _move(point: Vector2) -> void:
	if _held == null:
		if not _refused and point.distance_to(_start) >= DRAG_START_DISTANCE:
			_lift(point)
		return
	_target = _to_screen(point) + HOLD_OFFSET
	_set_hovered(_item_at(point))


func _release(point: Vector2) -> void:
	if _held == null:
		if not _refused:
			jar.bounce()
		return
	var item: ShelfItem = _item_at(point)
	_set_hovered(null)
	if item != null:
		_place(item)
	else:
		_return()


## Para kumbaranın deliğinden çıkıp parmağa doğru büyüyerek gelir.
func _lift(point: Vector2) -> void:
	_refused = true
	if not jar.take_out():
		jar.bounce()
		refused.emit()
		return
	_refused = false
	_held = Sprite2D.new()
	_held.texture = coin_texture
	drag_layer.add_child(_held)
	_held.position = _to_screen(jar.mouth())
	_held.scale = Vector2.ONE * JAR_SCALE
	_target = _to_screen(point) + HOLD_OFFSET
	create_tween().tween_property(_held, ^"scale", Vector2.ONE * CARRY_SCALE, LIFT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Para o anda ödenir, sonra etiketin yuvasına küçülerek uçar ve oturur.
func _place(item: ShelfItem) -> void:
	var held: Sprite2D = _held
	_held = null
	jar.spend()
	Owned.pay(item.item)
	var tween: Tween = held.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(item.coin_target()), PLACE_TIME)
	tween.tween_property(held, ^"scale", Vector2.ONE * item.coin_scale(), PLACE_TIME)
	tween.chain().tween_callback(func() -> void:
		held.queue_free()
		item.coin_arrived()
		var pan: float = clampf((item.global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
		AudioManager.play_sfx(_clink_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.94, 1.08), pan)
		coin_placed.emit(item))


## Para küçülerek kumbaranın deliğine döner ve içine düşer.
func _return() -> void:
	var held: Sprite2D = _held
	_held = null
	var tween: Tween = held.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(held, ^"position", _to_screen(jar.mouth()), RETURN_TIME)
	tween.tween_property(held, ^"scale", Vector2.ONE * JAR_SCALE, RETURN_TIME)
	tween.chain().tween_callback(func() -> void:
		held.queue_free()
		jar.put_back())


## Parmağın altındaki, henüz parası tamamlanmamış ürün.
func _item_at(point: Vector2) -> ShelfItem:
	for node: Node in shelf_items.get_children():
		var item: ShelfItem = node as ShelfItem
		if item != null and item.remaining() > 0 and item.contains(point):
			return item
	return null


func _set_hovered(item: ShelfItem) -> void:
	if item == _hovered:
		return
	if _hovered != null:
		_hovered.set_highlighted(false)
	_hovered = item
	if _hovered != null:
		_hovered.set_highlighted(true)


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
