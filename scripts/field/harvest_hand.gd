class_name HarvestHand
extends Node
## Hazır havuçları parmakla çekip çıkarma. Parmak bir havucun yapraklarına basıp yukarı çektikçe havuç
## esner ve topraktan biraz yükselir; pull_distance kadar çekilince "pop!" diye fırlar. Erken bırakılırsa
## yerine yaylanarak oturur. Tek parmak izlenir; raftan araç taşıyan parmaktan bağımsızdır.
## Hazır çilek çalısına dokunmak, dokunulan yere en yakın çileği hemen koparır (çekmek gerekmez).
## Hazır balkabağı parmakla sağa ya da sola itildikçe o yöne yuvarlanır; roll_distance kadar gidince
## sapından kopup çıkar. Erken bırakılırsa geri yuvarlanır.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir.

const NO_TOUCH: int = -1
## _carrot bu değerdeyse tutulan şey balkabağıdır.
const PUMPKIN: int = -2

@export var plots_root: Node2D
## Havucu çıkarmak için parmağın yukarı gitmesi gereken yol.
@export_range(20.0, 400.0, 5.0, "suffix:px") var pull_distance: float = 110.0
## Balkabağını çıkarmak için parmağın yana gitmesi gereken yol.
@export_range(20.0, 400.0, 5.0, "suffix:px") var roll_distance: float = 150.0

var _touch_index: int = NO_TOUCH
var _plot: Plot
var _carrot: int = -1
var _start: Vector2


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			if _pick_berry(_to_world(touch.position)):
				get_viewport().set_input_as_handled()
			elif _grab(_to_world(touch.position)):
				_touch_index = touch.index
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			if _carrot == PUMPKIN:
				_plot.release_pumpkin()
			else:
				_plot.release_carrot(_carrot)
			_let_go()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		var moved: Vector2 = _to_world(drag.position) - _start
		if _carrot == PUMPKIN:
			_roll(moved.x)
		else:
			_pull(moved)
		get_viewport().set_input_as_handled()


func _pull(moved: Vector2) -> void:
	var amount: float = clampf(-moved.y / pull_distance, 0.0, 1.0)
	if amount >= 1.0:
		_plot.uproot_carrot(_carrot)
		_let_go()
	else:
		_plot.pull_carrot(_carrot, amount, moved.x)


func _roll(sideways: float) -> void:
	if absf(sideways) >= roll_distance:
		_plot.roll_out_pumpkin()
		_let_go()
	else:
		_plot.roll_pumpkin(sideways)


## Arka ve ön sıra üst üste bindiğinde öndeki (ekranda aşağıdaki) parseldeki havuç ya da balkabağı kazanır.
func _grab(world_point: Vector2) -> bool:
	_plot = null
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot == null or (_plot != null and plot.global_position.y < _plot.global_position.y):
			continue
		var carrot: int = PUMPKIN if plot.pumpkin_at(world_point) else plot.carrot_at(world_point)
		if carrot != -1:
			_plot = plot
			_carrot = carrot
	_start = world_point
	return _plot != null


## Arka ve ön sıra üst üste bindiğinde öndeki parseldeki çilek kopar.
func _pick_berry(world_point: Vector2) -> bool:
	var best: Plot = null
	var best_berry: int = -1
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot == null or (best != null and plot.global_position.y < best.global_position.y):
			continue
		var berry: int = plot.berry_at(world_point)
		if berry >= 0:
			best = plot
			best_berry = berry
	if best == null:
		return false
	best.pick_berry(best_berry)
	return true


## Ürün çıktıysa parmak kalkana kadar gelen olaylar artık bu düğümü ilgilendirmez.
func _let_go() -> void:
	_touch_index = NO_TOUCH
	_plot = null
	_carrot = -1


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point
