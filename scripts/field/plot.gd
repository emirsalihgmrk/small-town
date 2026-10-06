class_name Plot
extends Node2D
## Tarladaki bir parsel. Şimdilik iki hâli var: otlu (sürülmemiş) ve sürülmüş.
## Çapanın her vuruşu (chop) vurulan noktaya en yakın ot kümesini söker ve sürülmüş toprağı biraz daha
## belirginleştirir; son ot da gidince parsel sürülmüş olur, sevinçle zıplar.

signal tilled

enum State { WEEDY, TILLED }

## Toprağın dokunulabilir yüzü (yerel); ön kenarın kalınlığı da dahil.
const AREA: Rect2 = Rect2(-165.0, -60.0, 330.0, 125.0)
const TILL_REVEAL_TIME: float = 0.25
const WEED_RISE: float = 70.0
const WEED_DRIFT_MIN: float = 40.0
const WEED_DRIFT_MAX: float = 80.0
const WEED_SPIN_DEGREES: float = 50.0
const WEED_RISE_TIME: float = 0.18
const WEED_FALL_TIME: float = 0.24
const WEED_END_SCALE: float = 0.6
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.1
const SETTLE_TIME: float = 0.35
const SPARKLE_HEIGHT: float = 50.0
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var dirt_burst_scene: PackedScene
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var chop_sound_path: String = "res://assets/audio/sfx/hoe_chop.ogg"
@export_range(0.0, 0.3, 0.01) var chop_pitch_variation: float = 0.1
@export_file("*.ogg", "*.wav") var ready_sound_path: String = "res://assets/audio/sfx/plot_ready.ogg"

var state: State = State.WEEDY

var _weeds_left: Array[Node2D] = []
var _weed_count: int = 0
var _chop_sound: AudioStream
var _ready_sound: AudioStream

@onready var _tilled_soil: CanvasItem = $TilledSoil
@onready var _weeds: Node2D = $Weeds


func _ready() -> void:
	_chop_sound = _load_stream(chop_sound_path)
	_ready_sound = _load_stream(ready_sound_path)
	for weed: Node in _weeds.get_children():
		_weeds_left.append(weed as Node2D)
	_weed_count = _weeds_left.size()
	_tilled_soil.modulate.a = 0.0


func contains(global_point: Vector2) -> bool:
	return AREA.has_point(to_local(global_point))


func can_till() -> bool:
	return state == State.WEEDY


## Çapa bu noktaya bir kez vurdu.
func chop(global_point: Vector2) -> void:
	if not can_till():
		return
	_play_sound(_chop_sound, 1.0 + randf_range(-chop_pitch_variation, chop_pitch_variation))
	_spawn_effect(dirt_burst_scene, global_point)
	var local_point: Vector2 = to_local(global_point)
	if not _weeds_left.is_empty():
		_uproot(_take_nearest_weed(local_point), local_point)
	var progress: float = 1.0 - float(_weeds_left.size()) / maxf(_weed_count, 1)
	create_tween().tween_property(_tilled_soil, ^"modulate:a", progress, TILL_REVEAL_TIME)
	if _weeds_left.is_empty():
		_finish_tilling()


func _take_nearest_weed(local_point: Vector2) -> Node2D:
	var nearest: Node2D = _weeds_left[0]
	for weed: Node2D in _weeds_left:
		if weed.position.distance_squared_to(local_point) < nearest.position.distance_squared_to(local_point):
			nearest = weed
	_weeds_left.erase(nearest)
	return nearest


## Ot, çapanın vurduğu yerden uzağa doğru havalanıp düşerken kaybolur.
func _uproot(weed: Node2D, from_local: Vector2) -> void:
	var side: float = signf(weed.position.x - from_local.x)
	if side == 0.0:
		side = 1.0 if randf() < 0.5 else -1.0
	var drift: float = side * randf_range(WEED_DRIFT_MIN, WEED_DRIFT_MAX)
	var start: Vector2 = weed.position
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(weed, ^"position:y", start.y - WEED_RISE, WEED_RISE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(weed, ^"position:y", start.y - WEED_RISE * 0.4, WEED_FALL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(WEED_RISE_TIME)
	tween.tween_property(weed, ^"position:x", start.x + drift, WEED_RISE_TIME + WEED_FALL_TIME)
	tween.tween_property(weed, ^"rotation", deg_to_rad(WEED_SPIN_DEGREES) * side, WEED_RISE_TIME + WEED_FALL_TIME)
	tween.tween_property(weed, ^"scale", weed.scale * WEED_END_SCALE, WEED_RISE_TIME + WEED_FALL_TIME)
	tween.tween_property(weed, ^"modulate:a", 0.0, WEED_FALL_TIME).set_delay(WEED_RISE_TIME)
	tween.chain().tween_callback(weed.hide)


func _finish_tilling() -> void:
	state = State.TILLED
	_play_sound(_ready_sound, 1.0)
	_spawn_effect(sparkle_scene, to_global(Vector2(0.0, -SPARKLE_HEIGHT)))
	var base_scale: Vector2 = scale
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"scale", base_scale * SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", base_scale, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tilled.emit()


## Tek atımlık parçacık sahnesini bu noktada patlatır; bitince kendini siler.
func _spawn_effect(scene: PackedScene, global_point: Vector2) -> void:
	if scene == null:
		return
	var effect: CPUParticles2D = scene.instantiate() as CPUParticles2D
	add_child(effect)
	effect.global_position = global_point
	effect.finished.connect(effect.queue_free)
	effect.emitting = true


func _play_sound(stream: AudioStream, pitch_scale: float) -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(stream, AudioManager.BUS_SFX, 0.0, pitch_scale, pan)


func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
