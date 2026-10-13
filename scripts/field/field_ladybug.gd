class_name FieldLadybug
extends Node2D
## Tarlada çiçek açmış çilek çalılarına (yapraklı aşama) arada bir uçarak gelen uğur böceği. Kabuğu açık,
## kanatları çırparak ekranın üstünden kavisle gelir, çalının tepesine konup kabuğunu kapatır ve yaprağın
## üstünde yavaşça bir o yana bir bu yana yürür. Dokununca tüy sesiyle kabuğunu açıp uçar gider; çalı meyve
## verince ya da parsel değişince de gider (meyveli çalıda dokunuş çilek koparmaya ayrılmıştır). Bir süre
## sonra yine çiçekli bir çalıya gelir; çiçekli çalı yoksa bekler.
## Kök noktası ayaklarıdır; görsel Visual altında sağa bakar, sola giderken aynalanır. Çalı susayıp
## eğilirse uğur böceği de onunla eğilir.

enum Mode { AWAY, ARRIVING, SITTING, LEAVING }

const SCREEN_WIDTH: float = 1920.0
const OFFSCREEN_MARGIN: float = 80.0
const ENTRY_Y_MIN: float = 140.0
const ENTRY_Y_MAX: float = 320.0
const FLIGHT_TIME: float = 2.0
const ARC_HEIGHT: float = 140.0
## Uçarken yolun iki yanına bu kadar dalgalanır.
const FLUTTER: float = 10.0
const FLUTTER_SPEED: float = 9.0
## Çalının tepesi (yapraklı çalı düğümüne göre) ve uğur böceğinin orada yürüyebildiği yarı genişlik.
const PERCH: Vector2 = Vector2(0.0, -46.0)
const PERCH_SPREAD: float = 16.0
const WALK_RANGE: float = 14.0
const WALK_SPEED: float = 9.0
const SHELL_OPEN_DEGREES: float = -55.0
const SHELL_TIME: float = 0.15
const WING_FLAP_DEGREES: float = 30.0
const WING_FLAP_TIME: float = 0.06
const RETRY_TIME: float = 3.0
const MAX_SOUND_PAN: float = 0.6

@export var plots_root: Node2D
@export_range(1.0, 120.0, 0.5, "suffix:s") var visit_interval_min: float = 8.0
@export_range(1.0, 120.0, 0.5, "suffix:s") var visit_interval_max: float = 18.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var stay_min: float = 10.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var stay_max: float = 20.0
@export_file("*.ogg", "*.wav") var tap_sound_path: String = "res://assets/audio/sfx/feather_fluff.ogg"

var _mode: Mode = Mode.AWAY
var _timer: float = 0.0
var _plot: Plot
var _plant: Node2D
var _perch: Vector2
var _walk_x: float = 0.0
var _walk_dir: float = 1.0
var _flight: Tween
var _shell_tween: Tween
var _flap_tween: Tween
var _tap_sound: AudioStream

@onready var _visual: Node2D = $Visual
@onready var _shell: Node2D = $Visual/Shell
@onready var _wings: Node2D = $Visual/Wings
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	if ResourceLoader.exists(tap_sound_path):
		_tap_sound = load(tap_sound_path) as AudioStream
	hide()
	_wings.hide()
	_tap_area.tapped.connect(func(_point: Vector2) -> void: _on_tapped())
	_timer = randf_range(visit_interval_min, visit_interval_max) * 0.5


func _process(delta: float) -> void:
	match _mode:
		Mode.AWAY:
			_timer -= delta
			if _timer <= 0.0:
				var plant: Node2D = _pick_plant()
				if plant == null:
					_timer = RETRY_TIME
				else:
					_arrive(plant)
		Mode.SITTING:
			if not _still_flowering():
				_leave()
				return
			_timer -= delta
			if _timer <= 0.0:
				_leave()
				return
			_walk_x += _walk_dir * WALK_SPEED * delta
			if absf(_walk_x) >= WALK_RANGE:
				_walk_x = clampf(_walk_x, -WALK_RANGE, WALK_RANGE)
				_walk_dir = -_walk_dir
			_visual.scale.x = _walk_dir
			_sit_on_plant()
		Mode.ARRIVING:
			if not _still_flowering():
				_leave()


## Çiçekli çilek çalılarından rastgele biri; yoksa null.
func _pick_plant() -> Node2D:
	var plants: Array[Node2D] = []
	for node: Node in plots_root.get_children():
		var plot: Plot = node as Plot
		if plot != null and _is_flowering(plot):
			for spot: Node in plot.get_node(^"Spots").get_children():
				plants.append(spot.get_node(^"StrawberryPlant") as Node2D)
	return plants.pick_random() if not plants.is_empty() else null


func _is_flowering(plot: Plot) -> bool:
	return plot.state == Plot.State.SOWN and plot.crop == Plot.Crop.STRAWBERRY and plot.stage == Plot.STAGE_LEAFY


func _still_flowering() -> bool:
	return _plot != null and _is_flowering(_plot) and _plant.is_visible_in_tree()


func _arrive(plant: Node2D) -> void:
	_mode = Mode.ARRIVING
	_plant = plant
	_plot = plant.get_parent().get_parent().get_parent() as Plot
	_perch = PERCH + Vector2(randf_range(-PERCH_SPREAD, PERCH_SPREAD), 0.0)
	_walk_x = 0.0
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var start: Vector2 = Vector2(_offscreen_x(side),
			randf_range(ENTRY_Y_MIN, ENTRY_Y_MAX))
	global_position = start
	rotation = 0.0
	show()
	_take_off()
	_fly(start, _perch_point, func() -> void:
		_mode = Mode.SITTING
		_timer = randf_range(stay_min, stay_max)
		_land())


func _leave() -> void:
	if _mode != Mode.SITTING and _mode != Mode.ARRIVING:
		return
	_mode = Mode.LEAVING
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var end: Vector2 = Vector2(_offscreen_x(side),
			randf_range(ENTRY_Y_MIN, ENTRY_Y_MAX))
	rotation = 0.0
	_take_off()
	_fly(global_position, func() -> Vector2: return end, func() -> void:
		hide()
		_flap(false)
		_mode = Mode.AWAY
		_timer = randf_range(visit_interval_min, visit_interval_max))


func _on_tapped() -> void:
	if _mode != Mode.SITTING:
		return
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_tap_sound, AudioManager.BUS_SFX, 0.0, randf_range(1.2, 1.35), pan)
	_leave()


func _perch_point() -> Vector2:
	return _plant.to_global(_perch + Vector2(_walk_x, 0.0))


func _sit_on_plant() -> void:
	global_position = _perch_point()
	rotation = _plant.global_rotation


## from'dan, her an yeniden sorulan varışa (çalı büyürken ya da eğilirken yer değiştirir) kavisle uçar.
func _fly(from: Vector2, target: Callable, on_done: Callable) -> void:
	if _flight != null:
		_flight.kill()
	var step: Callable = func(t: float) -> void:
		var to: Vector2 = target.call()
		var control: Vector2 = (from + to) * 0.5 + Vector2(0.0, -ARC_HEIGHT)
		var point: Vector2 = from.lerp(control, t).lerp(control.lerp(to, t), t)
		var flutter: float = sin(t * FLIGHT_TIME * FLUTTER_SPEED) * FLUTTER * (1.0 - t)
		var heading: float = signf(to.x - from.x)
		if heading != 0.0:
			_visual.scale.x = heading
		global_position = point + Vector2(0.0, flutter)
	_flight = create_tween()
	_flight.tween_method(step, 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flight.tween_callback(on_done)


## Kabuk açılır, kanatlar çırpmaya başlar.
func _take_off() -> void:
	_set_shell(SHELL_OPEN_DEGREES)
	_flap(true)


## Kabuk kapanır, kanatlar içine girer.
func _land() -> void:
	_set_shell(0.0)
	_flap(false)


func _set_shell(degrees: float) -> void:
	if _shell_tween != null:
		_shell_tween.kill()
	_shell_tween = create_tween()
	_shell_tween.tween_property(_shell, ^"rotation", deg_to_rad(degrees), SHELL_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)


func _flap(flapping: bool) -> void:
	if _flap_tween != null:
		_flap_tween.kill()
		_flap_tween = null
	_wings.visible = flapping
	_wings.rotation = 0.0
	if flapping:
		_flap_tween = Oscillation.ping_pong(self, _wings, ^"rotation", 0.0, deg_to_rad(-WING_FLAP_DEGREES),
				WING_FLAP_TIME * 2.0)


## Görünen alanın (geniş ekranda yanlar dahil) sağ (side 1) ya da sol (side -1) kenarının dışı.
func _offscreen_x(side: float) -> float:
	var view: Rect2 = ScreenFit.visible_world_rect()
	return view.end.x + OFFSCREEN_MARGIN if side > 0.0 else view.position.x - OFFSCREEN_MARGIN
