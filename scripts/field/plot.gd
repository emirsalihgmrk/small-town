class_name Plot
extends Node2D
## Tarladaki bir parsel: otlu -> (çapa) -> sürülmüş -> (tohum) -> ekili.
## Çapanın her vuruşu (chop) vurulan noktaya en yakın ot kümesini söker ve sürülmüş toprağı biraz daha
## belirginleştirir; son ot da gidince parsel sürülmüş olur.
## Sürülmüş parsele havuç (3 çukura birer tohum) ya da buğday (yüzeye serpilir) ekilir; ilk tohum
## parselin ürününü belirler, yarım kalan ekim sonra tamamlanabilir. Her aşamanın sonunda parsel
## sevinçle zıplar.

signal tilled
signal sown

enum State { WEEDY, TILLED, SOWN }
enum Crop { NONE, CARROT, WHEAT }

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
## Torbanın ağzı bir çukura / tohum noktasına bu kadar (yerel px) yaklaşınca tohum düşer.
const CARROT_SOW_RADIUS: float = 50.0
const WHEAT_SOW_RADIUS: float = 60.0
const HOLE_FADE_TIME: float = 0.2
const SEED_FALL_TIME: float = 0.16
const SEED_POP_TIME: float = 0.25
## Serpme sesi en fazla bu sıklıkta çalar; aynı anda düşen tohumlar ses yığını yapmasın.
const SPRINKLE_SOUND_INTERVAL_MS: int = 90
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.1
const SETTLE_TIME: float = 0.35
const SPARKLE_HEIGHT: float = 50.0
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var dirt_burst_scene: PackedScene
@export var sparkle_scene: PackedScene
@export var carrot_seed_texture: Texture2D

@export_group("Sesler")
@export_file("*.ogg", "*.wav") var chop_sound_path: String = "res://assets/audio/sfx/hoe_chop.ogg"
@export_range(0.0, 0.3, 0.01) var chop_pitch_variation: float = 0.1
@export_file("*.ogg", "*.wav") var plop_sound_path: String = "res://assets/audio/sfx/seed_plop.ogg"
@export_file("*.ogg", "*.wav") var sprinkle_sound_path: String = "res://assets/audio/sfx/seed_sprinkle.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var sprinkle_volume_db: float = -6.0
@export_range(0.0, 0.3, 0.01) var seed_pitch_variation: float = 0.12
@export_file("*.ogg", "*.wav") var ready_sound_path: String = "res://assets/audio/sfx/plot_ready.ogg"

var state: State = State.WEEDY
var crop: Crop = Crop.NONE

var _weeds_left: Array[Node2D] = []
var _weed_count: int = 0
var _carrot_spots: Array[Node2D] = []
var _carrot_spots_left: Array[Node2D] = []
var _carrot_seeds_landed: int = 0
var _wheat_seeds_left: Array[Node2D] = []
var _last_sprinkle_ms: int = -SPRINKLE_SOUND_INTERVAL_MS
var _chop_sound: AudioStream
var _plop_sound: AudioStream
var _sprinkle_sound: AudioStream
var _ready_sound: AudioStream

@onready var _tilled_soil: CanvasItem = $TilledSoil
@onready var _weeds: Node2D = $Weeds
@onready var _carrot_spots_root: Node2D = $CarrotSpots
@onready var _wheat_seeds: Node2D = $WheatSeeds


func _ready() -> void:
	_chop_sound = _load_stream(chop_sound_path)
	_plop_sound = _load_stream(plop_sound_path)
	_sprinkle_sound = _load_stream(sprinkle_sound_path)
	_ready_sound = _load_stream(ready_sound_path)
	for weed: Node in _weeds.get_children():
		_weeds_left.append(weed as Node2D)
	_weed_count = _weeds_left.size()
	_tilled_soil.modulate.a = 0.0
	for spot: Node in _carrot_spots_root.get_children():
		var spot_2d: Node2D = spot as Node2D
		_carrot_spots.append(spot_2d)
		_hole(spot_2d).modulate.a = 0.0
		_mound(spot_2d).hide()
	_carrot_spots_left = _carrot_spots.duplicate()
	for seed: Node in _wheat_seeds.get_children():
		var seed_2d: Node2D = seed as Node2D
		seed_2d.hide()
		_wheat_seeds_left.append(seed_2d)


func contains(global_point: Vector2) -> bool:
	return AREA.has_point(to_local(global_point))


func can_till() -> bool:
	return state == State.WEEDY


func can_sow(seed_crop: Crop) -> bool:
	return state == State.TILLED and (crop == Crop.NONE or crop == seed_crop)


## Çapa bu noktaya bir kez vurdu.
func chop(global_point: Vector2) -> void:
	if not can_till():
		return
	_play_sound(_chop_sound, 0.0, 1.0 + randf_range(-chop_pitch_variation, chop_pitch_variation))
	_spawn_effect(dirt_burst_scene, global_point)
	var local_point: Vector2 = to_local(global_point)
	if not _weeds_left.is_empty():
		_uproot(_take_nearest_weed(local_point), local_point)
	var progress: float = 1.0 - float(_weeds_left.size()) / maxf(_weed_count, 1)
	create_tween().tween_property(_tilled_soil, ^"modulate:a", progress, TILL_REVEAL_TIME)
	if _weeds_left.is_empty():
		state = State.TILLED
		_celebrate()
		tilled.emit()


## Havuç torbası tutulurken boş çukurları gösterir; bırakılınca, ekimine başlanmamış parselde gizler.
func set_carrot_holes_visible(holes_visible: bool) -> void:
	if not can_sow(Crop.CARROT):
		return
	var alpha: float = 1.0 if holes_visible or crop == Crop.CARROT else 0.0
	for spot: Node2D in _carrot_spots_left:
		create_tween().tween_property(_hole(spot), ^"modulate:a", alpha, HOLE_FADE_TIME)


## Torbanın ağzı bu noktadayken tohum düşer mi? Düştüyse true.
## Havuçta bir seferde en fazla bir çukur dolar; buğdayda yakındaki tüm noktalara serpilir.
func sow_at(global_point: Vector2, seed_crop: Crop) -> bool:
	if not can_sow(seed_crop):
		return false
	var local_point: Vector2 = to_local(global_point)
	match seed_crop:
		Crop.CARROT:
			return _sow_carrot(local_point)
		Crop.WHEAT:
			return _sow_wheat(local_point)
	return false


func _sow_carrot(local_point: Vector2) -> bool:
	for spot: Node2D in _carrot_spots_left:
		if spot.position.distance_to(local_point) <= CARROT_SOW_RADIUS:
			_carrot_spots_left.erase(spot)
			crop = Crop.CARROT
			_drop_carrot_seed(local_point, spot)
			return true
	return false


## Tohum torbanın ağzından çukura düşer; değince çukur kapanıp tümseğe döner.
func _drop_carrot_seed(from_local: Vector2, spot: Node2D) -> void:
	var seed: Sprite2D = Sprite2D.new()
	seed.texture = carrot_seed_texture
	seed.position = from_local
	add_child(seed)
	var tween: Tween = create_tween()
	tween.tween_property(seed, ^"position", spot.position, SEED_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		seed.queue_free()
		_plant_carrot_seed(spot))


func _plant_carrot_seed(spot: Node2D) -> void:
	_play_sound(_plop_sound, 0.0, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	_hole(spot).modulate.a = 0.0
	_pop_in(_mound(spot))
	_carrot_seeds_landed += 1
	if _carrot_seeds_landed == _carrot_spots.size():
		_finish_sowing()


func _sow_wheat(local_point: Vector2) -> bool:
	var sowed: bool = false
	for seed: Node2D in _wheat_seeds_left.duplicate():
		if seed.position.distance_to(local_point) <= WHEAT_SOW_RADIUS:
			_wheat_seeds_left.erase(seed)
			_pop_in(seed)
			sowed = true
	if not sowed:
		return false
	crop = Crop.WHEAT
	var now: int = Time.get_ticks_msec()
	if now - _last_sprinkle_ms >= SPRINKLE_SOUND_INTERVAL_MS:
		_last_sprinkle_ms = now
		_play_sound(_sprinkle_sound, sprinkle_volume_db, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	if _wheat_seeds_left.is_empty():
		_finish_sowing()
	return true


func _finish_sowing() -> void:
	state = State.SOWN
	_celebrate()
	sown.emit()


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


## Bir aşama bitti: sevinç sesi, yıldızlar ve küçük bir zıplama.
func _celebrate() -> void:
	_play_sound(_ready_sound, 0.0, 1.0)
	_spawn_effect(sparkle_scene, to_global(Vector2(0.0, -SPARKLE_HEIGHT)))
	var base_scale: Vector2 = scale
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"scale", base_scale * SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", base_scale, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pop_in(item: Node2D) -> void:
	var target: Vector2 = item.scale
	item.scale = Vector2.ZERO
	item.show()
	create_tween().tween_property(item, ^"scale", target, SEED_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hole(spot: Node2D) -> CanvasItem:
	return spot.get_node(^"Hole") as CanvasItem


func _mound(spot: Node2D) -> Node2D:
	return spot.get_node(^"Mound") as Node2D


## Tek atımlık parçacık sahnesini bu noktada patlatır; bitince kendini siler.
func _spawn_effect(scene: PackedScene, global_point: Vector2) -> void:
	if scene == null:
		return
	var effect: CPUParticles2D = scene.instantiate() as CPUParticles2D
	add_child(effect)
	effect.global_position = global_point
	effect.finished.connect(effect.queue_free)
	effect.emitting = true


func _play_sound(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(stream, AudioManager.BUS_SFX, volume_db, pitch_scale, pan)


func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
