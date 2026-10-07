class_name WaterHand
extends Node
## Yerdeki kovayı parmakla tutup suluğa su dökme. Kovaya basınca kova yerden kalkıp parmağın hemen
## üstünde belirir (tarladaki kovanın aynısı). Ucu dolu olmayan suluğun üstündeyken öne eğilip su döker
## ve suluk dolar; başka yerde dökmez. Parmak kalkınca kova yerine uçar. Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki kovaya basış önce buraya ulaşsın.

const NO_TOUCH: int = -1

## Yerde duran kova (kök noktası görselin ortası); tutulunca gizlenir, kova geri gelince yeniden görünür.
@export var bucket: Node2D
## Kovaya basılabilecek alan (kovanın ortasına göre); küçük parmaklar için cömert.
@export var bucket_area: Rect2 = Rect2(-65.0, -65.0, 130.0, 130.0)
@export var waterer: Waterer
## Tutulan kova bu katmanda, dünyanın üstünde çizilir.
@export var drag_layer: CanvasLayer
@export var bucket_scene: PackedScene
## Kovanın ağzı parmağın bu kadar uzağında durur; parmak kovayı örtmesin.
@export var hold_offset: Vector2 = Vector2(0.0, -36.0)

var _touch_index: int = NO_TOUCH
var _tool: HeldTool
var _returning: HeldTool


func _process(delta: float) -> void:
	if _tool == null:
		return
	var pouring: bool = waterer.needs_water() and waterer.contains(_to_world(_tool.position))
	_tool.set_pouring(pouring)
	if pouring:
		waterer.water(delta)


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			if bucket_area.has_point(bucket.to_local(_to_world(touch.position))):
				_pick_up(touch.index, touch.position)
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_drop()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_tool.position = drag.position + hold_offset
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: kovayı bırak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_drop()


func _pick_up(index: int, screen_point: Vector2) -> void:
	if _returning != null:
		_returning.queue_free()
		_returning = null
	_touch_index = index
	bucket.hide()
	_tool = bucket_scene.instantiate() as HeldTool
	drag_layer.add_child(_tool)
	_tool.position = screen_point + hold_offset
	_tool.pop_in()


func _drop() -> void:
	_touch_index = NO_TOUCH
	_returning = _tool
	_tool = null
	_returning.return_to(_to_screen(bucket.global_position), func() -> void:
		_returning = null
		bucket.show())


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point
