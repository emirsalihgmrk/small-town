class_name StirHand
extends Node
## Kasedeki malzemeleri kaşıkla karıştırma. Kase dolu ve henüz hamur olmamışken kaseye basınca kaşık
## parmağı izler; parmak kasenin üstünde gezdikçe aldığı yol kadar karışım hamura döner (daire çizmek
## gerekmez, her hareket sayılır). Kaydırmadan bırakılan dokunuş da biraz karıştırır. Parmak kalkınca
## kaşık dinlenme yerine döner. Tek parmak izlenir.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir. Bu düğüm sahnede
## TapRouter'dan sonra gelmeli ki kaseye basış önce buraya ulaşsın.

const NO_TOUCH: int = -1
## Parmak bu kadar kaymadan bırakılırsa dokunuş sayılır.
const TAP_DISTANCE: float = 24.0
## Tek bir sürüklemede sayılan en uzun yol: parmak sıçrarsa karışım bir anda bitmesin.
const MAX_STEP: float = 60.0

@export var bowl: MixingBowl

var _touch_index: int = NO_TOUCH
var _last: Vector2
var _travelled: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var point: Vector2 = _to_world(touch.position)
			if bowl.can_stir() and bowl.contains(point):
				_touch_index = touch.index
				_last = point
				_travelled = 0.0
				bowl.move_spoon(point)
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			if _travelled < TAP_DISTANCE:
				bowl.tap_stir()
			_end()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		var point: Vector2 = _to_world(drag.position)
		var step: float = minf(point.distance_to(_last), MAX_STEP)
		_travelled += step
		_last = point
		if bowl.contains(point):
			bowl.move_spoon(point)
			bowl.stir(step)
		if not bowl.can_stir():
			_end()
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: kaşığı bırak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_end()


func _end() -> void:
	_touch_index = NO_TOUCH
	bowl.rest_spoon()


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point
