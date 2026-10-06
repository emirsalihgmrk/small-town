class_name FieldTools
extends Node
## Alt raftaki araçları parmakla kullanma. Araç raftan tutulunca parmağın hemen üstünde belirir,
## parmak kalkınca rafa geri uçar. Tek parmak izlenir; araç tutulurken gelen diğer dokunuşlar bu
## düğümü ilgilendirmez.
## - Çapa: otlu parselin üstünde ovuşturuldukça her stroke_distance yolda bir vurur.
## - Havuç tohumu: tutulunca ekilebilir parsellerde çukurlar belirir; torba bir çukurun üstünden
##   geçince içine tohum düşer.
## - Buğday tohumu: torba ekilebilir parselin üstünde gezdikçe tohum serpilir.
## - Kova: susamış parselin üstünde öne eğilip su döker; başka yerde dökmez.
## Tohum ve su, araç parselin üstüne girdikten sonra sow_arm_time kadar orada kalınca dökülmeye başlar:
## raf ön sıranın altında olduğundan arka sıraya giderken yoldaki parsele istemeden dökülmesin.
## Not: Sahnede kamera yok, dünya ve ekran koordinatları canvas dönüşümüyle çevrilir.

enum Tool { HOE, CARROT_SEEDS, WHEAT_SEEDS, BUCKET }

const NO_TOUCH: int = -1
const SLOT_BOUNCE_SCALE: float = 1.15
const SLOT_BOUNCE_TIME: float = 0.25

@export_group("Raf")
@export var hoe_slot: Control
@export var carrot_seed_slot: Control
@export var wheat_seed_slot: Control
@export var bucket_slot: Control

@export_group("Tutulan araçlar")
@export var hoe_scene: PackedScene
@export var carrot_bag_scene: PackedScene
@export var wheat_bag_scene: PackedScene
@export var bucket_scene: PackedScene

@export_group("")
@export var plots_root: Node2D
## Tutulan araç bu katmanda çizilir; araç rafının (UI) da üstünde kalmalı.
@export var drag_layer: CanvasLayer
## Aracın çalışan ucu parmağın bu kadar uzağında durur; parmak ucu örtmesin.
@export var hold_offset: Vector2 = Vector2(0.0, -36.0)
@export_range(20.0, 400.0, 5.0, "suffix:px") var stroke_distance: float = 100.0
## Parsele girer girmez ilk vuruş çabuk gelsin diye yolun bu oranı peşin sayılır.
@export_range(0.0, 1.0, 0.05) var first_stroke_head_start: float = 0.6
@export_range(0.0, 1.0, 0.05, "suffix:s") var sow_arm_time: float = 0.2

var _slots: Dictionary[Tool, Control] = {}
var _scenes: Dictionary[Tool, PackedScene] = {}
var _icons: Dictionary[Tool, Node2D] = {}
var _icon_scales: Dictionary[Tool, Vector2] = {}
var _returning: Dictionary[Tool, HeldTool] = {}
var _touch_index: int = NO_TOUCH
var _held: Tool
var _tool: HeldTool
var _plot: Plot
var _stroke_progress: float = 0.0
var _time_on_plot: float = 0.0
var _last_tip: Vector2


func _ready() -> void:
	_slots = {Tool.HOE: hoe_slot, Tool.CARROT_SEEDS: carrot_seed_slot, Tool.WHEAT_SEEDS: wheat_seed_slot,
			Tool.BUCKET: bucket_slot}
	_scenes = {Tool.HOE: hoe_scene, Tool.CARROT_SEEDS: carrot_bag_scene, Tool.WHEAT_SEEDS: wheat_bag_scene,
			Tool.BUCKET: bucket_scene}
	for kind: Tool in _slots:
		_icons[kind] = _slots[kind].get_node(^"Icon") as Node2D
		_icon_scales[kind] = _icons[kind].scale


## Parmak kıpırdamasa da süre ilerlesin (torba çukurun üstünde bekletilince tohum düşsün, kova döksün).
func _process(delta: float) -> void:
	if _tool != null:
		_update_plot(delta)


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == NO_TOUCH:
			var kind: int = _slot_at(touch.position)
			if kind >= 0:
				_pick_up(kind as Tool, touch.index, touch.position)
				get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_drop()
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_move_to(drag.position)
		get_viewport().set_input_as_handled()


## Uygulama arka plana giderse parmağın kalktığı haber gelmeyebilir: aracı bırak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != NO_TOUCH:
			_drop()


## Noktadaki rafın aracı; raf yoksa -1.
func _slot_at(screen_point: Vector2) -> int:
	for kind: Tool in _slots:
		if _slots[kind].get_global_rect().has_point(screen_point):
			return kind
	return -1


func _pick_up(kind: Tool, index: int, screen_point: Vector2) -> void:
	if _returning.has(kind):
		_returning[kind].queue_free()
		_returning.erase(kind)
	_touch_index = index
	_held = kind
	_icons[kind].hide()
	_tool = _scenes[kind].instantiate() as HeldTool
	drag_layer.add_child(_tool)
	_tool.position = screen_point + hold_offset
	_tool.pop_in()
	if kind == Tool.CARROT_SEEDS:
		_set_carrot_holes_visible(true)
	_plot = null
	_update_plot(0.0)


func _move_to(screen_point: Vector2) -> void:
	_tool.position = screen_point + hold_offset


func _drop() -> void:
	if _held == Tool.CARROT_SEEDS:
		_set_carrot_holes_visible(false)
	var kind: Tool = _held
	_touch_index = NO_TOUCH
	_plot = null
	_returning[kind] = _tool
	_tool.return_to(_slots[kind].get_global_rect().get_center(), _on_tool_returned.bind(kind))
	_tool = null


func _on_tool_returned(kind: Tool) -> void:
	_returning.erase(kind)
	var icon: Node2D = _icons[kind]
	icon.show()
	icon.scale = _icon_scales[kind] * SLOT_BOUNCE_SCALE
	create_tween().tween_property(icon, ^"scale", _icon_scales[kind], SLOT_BOUNCE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Aracın ucunun altındaki parsele aracın işini yaptırır.
func _update_plot(delta: float) -> void:
	var tip: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * _tool.position
	var plot: Plot = _plot_at(tip)
	_time_on_plot = _time_on_plot + delta if plot == _plot else 0.0
	var armed: bool = plot != null and _time_on_plot >= sow_arm_time
	match _held:
		Tool.HOE:
			_use_hoe(plot, tip)
		Tool.CARROT_SEEDS:
			if armed and plot.sow_at(tip, Plot.Crop.CARROT):
				_tool.play_use()
		Tool.WHEAT_SEEDS:
			var sowing: bool = armed and plot.can_sow(Plot.Crop.WHEAT)
			_tool.set_pouring(sowing)
			if sowing:
				plot.sow_at(tip, Plot.Crop.WHEAT)
		Tool.BUCKET:
			var watering: bool = armed and plot.needs_water()
			_tool.set_pouring(watering)
			if watering:
				plot.water(delta)
	_plot = plot
	_last_tip = tip


## Otlu bir parselin üstünde biriken yol vuruşa dönüşür.
func _use_hoe(plot: Plot, tip: Vector2) -> void:
	if plot != _plot:
		_stroke_progress = stroke_distance * first_stroke_head_start
	elif plot != null and plot.can_till():
		_stroke_progress += tip.distance_to(_last_tip)
		if _stroke_progress >= stroke_distance:
			# Hızlı bir savuruş birden çok vuruş biriktirmesin.
			_stroke_progress = 0.0
			plot.chop(tip)
			_tool.play_use()


func _set_carrot_holes_visible(holes_visible: bool) -> void:
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot != null:
			plot.set_carrot_holes_visible(holes_visible)


## Arka ve ön sıra üst üste bindiğinde öndeki (ekranda aşağıdaki) parsel kazanır.
func _plot_at(world_point: Vector2) -> Plot:
	var best: Plot = null
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot != null and plot.contains(world_point) and (best == null or plot.global_position.y > best.global_position.y):
			best = plot
	return best
