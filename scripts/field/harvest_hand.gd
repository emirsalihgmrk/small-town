class_name HarvestHand
extends Node
## Hazır havuçları parmakla çekip çıkarma. Parmak bir havucun yapraklarına basıp yukarı çektikçe havuç
## esner ve topraktan biraz yükselir; pull_distance kadar çekilince "pop!" diye fırlar. Erken bırakılırsa
## yerine yaylanarak oturur. Tek parmak izlenir; raftan araç taşıyan parmaktan bağımsızdır.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir.

const NO_TOUCH: int = -1

@export var plots_root: Node2D
## Havucu çıkarmak için parmağın yukarı gitmesi gereken yol.
@export_range(20.0, 400.0, 5.0, "suffix:px") var pull_distance: float = 110.0

var _touch_index: int = NO_TOUCH
var _plot: Plot
var _carrot: int = -1
var _start: Vector2


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			if _grab(_to_world(touch.position)):
				_touch_index = touch.index
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_plot.release_carrot(_carrot)
			_let_go()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		var moved: Vector2 = _to_world(drag.position) - _start
		var amount: float = clampf(-moved.y / pull_distance, 0.0, 1.0)
		if amount >= 1.0:
			_plot.uproot_carrot(_carrot)
			_let_go()
		else:
			_plot.pull_carrot(_carrot, amount, moved.x)
		get_viewport().set_input_as_handled()


## Arka ve ön sıra üst üste bindiğinde öndeki (ekranda aşağıdaki) parseldeki havuç kazanır.
func _grab(world_point: Vector2) -> bool:
	_plot = null
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot == null or (_plot != null and plot.global_position.y < _plot.global_position.y):
			continue
		var carrot: int = plot.carrot_at(world_point)
		if carrot >= 0:
			_plot = plot
			_carrot = carrot
	_start = world_point
	return _plot != null


## Havuç çıktıysa parmak kalkana kadar gelen olaylar artık bu düğümü ilgilendirmez.
func _let_go() -> void:
	_touch_index = NO_TOUCH
	_plot = null
	_carrot = -1


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point
