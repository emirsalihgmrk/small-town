class_name FieldBird
extends Node2D
## Tarlaya arada bir uçarak gelen kuş. Tercihen ekili bir parselin üstüne, yoksa çitin üstüne konar;
## gagalar, bir süre sonra uçup gider. Dokununca cıvıldayıp hemen kaçar. Bitkilere dokunmaz.
## Parsel kökü verilmezse (ör. pazarda) hep çite, yani fence_top_y yüksekliğinde perch_x_min..perch_x_max
## arasına (pazarda tentenin üstü) konar.
## Kök noktası kuşun ayaklarıdır; görsel Body altında sağa bakar, ters yöne giderken kök aynalanır.

enum Mode { AWAY, ARRIVING, PERCHED, LEAVING }

const SCREEN_WIDTH: float = 1920.0
const OFFSCREEN_MARGIN: float = 100.0
const ENTRY_Y_MIN: float = 160.0
const ENTRY_Y_MAX: float = 340.0
const FLIGHT_TIME: float = 1.6
## Uçuş kavisinin, başlangıç ile varış arasındaki doğrunun ortasından ne kadar yukarı çıktığı.
const ARC_HEIGHT: float = 120.0
const FLAP_DEGREES: float = 50.0
const FLAP_TIME: float = 0.08
const PECK_DEGREES: float = 28.0
const PECK_TIME: float = 0.12
const PECK_INTERVAL_MIN: float = 0.6
const PECK_INTERVAL_MAX: float = 1.4
## Ekili parsel varken bile ara sıra çite konsun.
const FENCE_CHANCE: float = 0.25
const PLOT_PERCH_X: float = 110.0
const PLOT_PERCH_Y: float = 20.0
const MAX_SOUND_PAN: float = 0.7

@export var plots_root: Node2D
## Çitin üst kalasının üstü (dünya y).
@export var fence_top_y: float = 584.0
## Çitin üstünde konulabilecek yatay aralık (dünya x).
@export var perch_x_min: float = 80.0
@export var perch_x_max: float = 1840.0
@export_range(1.0, 120.0, 0.5, "suffix:s") var visit_interval_min: float = 12.0
@export_range(1.0, 120.0, 0.5, "suffix:s") var visit_interval_max: float = 25.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var stay_min: float = 6.0
@export_range(1.0, 60.0, 0.5, "suffix:s") var stay_max: float = 10.0
@export var chirp_paths: Array[String] = [
	"res://assets/audio/ambience/bird_chirp_1.ogg",
	"res://assets/audio/ambience/bird_chirp_3.ogg",
	"res://assets/audio/ambience/bird_chirp_5.ogg",
]

var mode: Mode = Mode.AWAY

var _chirps: Array[AudioStream] = []
var _visit_timer: Timer
var _stay_timer: Timer
var _peck_timer: Timer
var _flap_tween: Tween

@onready var _body: Node2D = $Body
@onready var _wing: Node2D = $Body/Wing
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	hide()
	_tap_area.enabled = false
	_tap_area.tapped.connect(func(_point: Vector2) -> void: leave())
	for path: String in chirp_paths:
		if ResourceLoader.exists(path):
			_chirps.append(load(path) as AudioStream)
	_visit_timer = _make_timer(visit)
	_stay_timer = _make_timer(leave)
	_peck_timer = _make_timer(_peck)
	_visit_timer.start(randf_range(visit_interval_min, visit_interval_max))


## Ekranın bir kenarından uçarak gelip bir yere konar.
func visit() -> void:
	if mode != Mode.AWAY:
		return
	var target: Vector2 = _pick_perch()
	var from_left: bool = randf() < 0.5
	var start: Vector2 = Vector2(-OFFSCREEN_MARGIN if from_left else SCREEN_WIDTH + OFFSCREEN_MARGIN,
			randf_range(ENTRY_Y_MIN, ENTRY_Y_MAX))
	mode = Mode.ARRIVING
	position = start
	show()
	_fly(start, target, _perch)


## Konmuşsa cıvıldayıp baktığı yöne doğru uçup gider.
func leave() -> void:
	if mode != Mode.PERCHED:
		return
	mode = Mode.LEAVING
	_tap_area.enabled = false
	_stay_timer.stop()
	_peck_timer.stop()
	_body.rotation = 0.0
	if not _chirps.is_empty():
		var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
		AudioManager.play_sfx(_chirps.pick_random(), AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.1), pan)
	var heading: float = signf(scale.x)
	var end: Vector2 = Vector2(SCREEN_WIDTH + OFFSCREEN_MARGIN if heading > 0.0 else -OFFSCREEN_MARGIN,
			randf_range(ENTRY_Y_MIN, ENTRY_Y_MAX))
	_fly(position, end, _gone)


func _perch() -> void:
	mode = Mode.PERCHED
	_set_flapping(false)
	_tap_area.enabled = true
	_stay_timer.start(randf_range(stay_min, stay_max))
	_peck_timer.start(randf_range(PECK_INTERVAL_MIN, PECK_INTERVAL_MAX))


func _gone() -> void:
	mode = Mode.AWAY
	_set_flapping(false)
	hide()
	_visit_timer.start(randf_range(visit_interval_min, visit_interval_max))


func _peck() -> void:
	if mode != Mode.PERCHED:
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"rotation", deg_to_rad(PECK_DEGREES), PECK_TIME)
	tween.tween_property(_body, ^"rotation", 0.0, PECK_TIME)
	_peck_timer.start(randf_range(PECK_INTERVAL_MIN, PECK_INTERVAL_MAX))


func _fly(from: Vector2, to: Vector2, on_arrived: Callable) -> void:
	scale.x = absf(scale.x) * (1.0 if to.x >= from.x else -1.0)
	_set_flapping(true)
	var tween: Tween = create_tween()
	tween.tween_method(_arc.bind(from, to), 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(on_arrived)


## İkinci dereceden Bezier: başlangıç ve varışın ortasının ARC_HEIGHT üstünden geçer.
func _arc(t: float, from: Vector2, to: Vector2) -> void:
	var control: Vector2 = (from + to) * 0.5 + Vector2(0.0, -ARC_HEIGHT)
	position = from.lerp(control, t).lerp(control.lerp(to, t), t)


func _set_flapping(flapping: bool) -> void:
	if _flap_tween != null:
		_flap_tween.kill()
		_flap_tween = null
	_wing.rotation = 0.0
	if flapping:
		_flap_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_flap_tween.tween_property(_wing, ^"rotation", deg_to_rad(FLAP_DEGREES), FLAP_TIME)
		_flap_tween.tween_property(_wing, ^"rotation", deg_to_rad(-FLAP_DEGREES * 0.3), FLAP_TIME)


## Ekili parsellerden birinin üstü; yoksa (ya da ara sıra) çitin üstünde bir yer.
func _pick_perch() -> Vector2:
	var spots: Array[Vector2] = []
	if plots_root != null:
		for node: Node in plots_root.get_children():
			var plot: Plot = node as Plot
			if plot != null and plot.state == Plot.State.SOWN:
				spots.append(plot.to_global(Vector2(randf_range(-PLOT_PERCH_X, PLOT_PERCH_X), randf_range(-PLOT_PERCH_Y, PLOT_PERCH_Y))))
	if spots.is_empty() or randf() < FENCE_CHANCE:
		return Vector2(randf_range(perch_x_min, perch_x_max), fence_top_y)
	return spots.pick_random()


func _make_timer(on_timeout: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer
