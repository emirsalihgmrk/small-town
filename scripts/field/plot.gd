class_name Plot
extends Node2D
## Tarladaki bir parsel: otlu -> (çapa) -> sürülmüş -> (tohum) -> ekili, büyüyor -> hazır.
## Çapanın her vuruşu (chop) vurulan noktaya en yakın ot kümesini söker ve sürülmüş toprağı biraz daha
## belirginleştirir; son ot da gidince parsel sürülmüş olur.
## Sürülmüş parsele havuç (3 çukura birer tohum) ya da buğday (yüzeye serpilir) ekilir; ilk tohum
## parselin ürününü belirler, yarım kalan ekim sonra tamamlanabilir.
## Ekili bitki tohum -> filiz -> yapraklı -> hazır aşamalarından geçer. Tohumken ve yapraklıyken susar:
## toprak kurur, su balonu çıkar, bitki boynunu büker; sulanana kadar büyüme durur (bitki asla ölmez).
## Büyüme yalnızca bu sahne açıkken ilerler. Her aşamanın sonunda parsel sevinçle zıplar.

signal tilled
signal sown
signal ripened

enum State { WEEDY, TILLED, SOWN, READY }
enum Crop { NONE, CARROT, WHEAT }

## Büyüme aşamaları. Bitki düğümlerinde aşamanın görseli "Stage<numara>" adlı çocuktur (tohumun yok).
const STAGE_SEED: int = 0
const STAGE_SPROUT: int = 1
const STAGE_LEAFY: int = 2
const STAGE_READY: int = 3
## Toplam büyüme süresinin aşama geçişlerine dağılımı: tohum->filiz, filiz->yapraklı, yapraklı->hazır.
const STAGE_TIME_SHARES: Array[float] = [0.25, 0.35, 0.4]
## Bitki bu aşamalara gelince susar.
const THIRSTY_STAGES: Array[int] = [STAGE_SEED, STAGE_LEAFY]
## Ekim kutlaması görünsün diye ilk susama biraz sonra başlar.
const FIRST_THIRST_DELAY: float = 0.7
const DRY_FADE_TIME: float = 0.4
const DROOP_DEGREES: float = 16.0
const DROOP_TINT: Color = Color(1.0, 0.93, 0.72)
const DROOP_TIME: float = 0.5
const PERK_TIME: float = 0.6
const BUBBLE_POP_TIME: float = 0.25
const GROW_POP_SCALE: float = 0.55
const GROW_POP_TIME: float = 0.5
## Aynı parseldeki bitkiler aynı anda değil, bu süreye yayılarak büyür.
const GROW_STAGGER: float = 0.25
## Su sesi en fazla bu sıklıkta çalar.
const SPLASH_SOUND_INTERVAL_MS: int = 300

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

@export_group("Büyüme")
## Sulamayı bekleme süresi hariç, tohumdan hazır olana kadar geçen süre.
@export_range(1.0, 600.0, 1.0, "suffix:s") var carrot_grow_time: float = 35.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var wheat_grow_time: float = 55.0
## Susamış parsel kova altında bu kadar kalınca sulanmış olur.
@export_range(0.1, 5.0, 0.1, "suffix:s") var water_needed: float = 1.0

@export_group("Sesler")
@export_file("*.ogg", "*.wav") var chop_sound_path: String = "res://assets/audio/sfx/hoe_chop.ogg"
@export_range(0.0, 0.3, 0.01) var chop_pitch_variation: float = 0.1
@export_file("*.ogg", "*.wav") var plop_sound_path: String = "res://assets/audio/sfx/seed_plop.ogg"
@export_file("*.ogg", "*.wav") var sprinkle_sound_path: String = "res://assets/audio/sfx/seed_sprinkle.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var sprinkle_volume_db: float = -6.0
@export_range(0.0, 0.3, 0.01) var seed_pitch_variation: float = 0.12
@export_file("*.ogg", "*.wav") var ready_sound_path: String = "res://assets/audio/sfx/plot_ready.ogg"
@export_file("*.ogg", "*.wav") var splash_sound_path: String = "res://assets/audio/sfx/water_splash.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var splash_volume_db: float = -4.0
@export_file("*.ogg", "*.wav") var grow_sound_path: String = "res://assets/audio/sfx/plant_grow.ogg"

var state: State = State.WEEDY
var crop: Crop = Crop.NONE
var stage: int = STAGE_SEED
var thirsty: bool = false

var _plants: Array[Node2D] = []
var _stage_time_left: float = 0.0
var _water_progress: float = 0.0
var _last_splash_ms: int = -SPLASH_SOUND_INTERVAL_MS
var _splash_sound: AudioStream
var _grow_sound: AudioStream

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
@onready var _wheat_plants: Node2D = $WheatPlants
@onready var _dry_soil: CanvasItem = $DrySoil
@onready var _water_bubble: Node2D = $WaterBubble
@onready var _ready_glint: CPUParticles2D = $ReadyGlint


func _ready() -> void:
	_chop_sound = _load_stream(chop_sound_path)
	_plop_sound = _load_stream(plop_sound_path)
	_sprinkle_sound = _load_stream(sprinkle_sound_path)
	_ready_sound = _load_stream(ready_sound_path)
	_splash_sound = _load_stream(splash_sound_path)
	_grow_sound = _load_stream(grow_sound_path)
	_dry_soil.modulate.a = 0.0
	_water_bubble.hide()
	for plant: Node in _wheat_plants.get_children():
		_set_plant_stage(plant as Node2D, STAGE_SEED)
	for spot: Node in _carrot_spots_root.get_children():
		_set_plant_stage(spot.get_node(^"Plant") as Node2D, STAGE_SEED)
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


func _process(delta: float) -> void:
	if state != State.SOWN or thirsty:
		return
	_stage_time_left -= delta
	if _stage_time_left <= 0.0:
		_advance_stage()


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
	stage = STAGE_SEED
	_plants.clear()
	if crop == Crop.CARROT:
		for spot: Node2D in _carrot_spots:
			_plants.append(spot.get_node(^"Plant") as Node2D)
	else:
		for plant: Node in _wheat_plants.get_children():
			_plants.append(plant as Node2D)
	_celebrate()
	sown.emit()
	_become_thirsty(FIRST_THIRST_DELAY)


func needs_water() -> bool:
	return state == State.SOWN and thirsty


## Kova bu parselin üstünde delta saniye su döktü. Toprak döküldükçe koyulaşır.
func water(delta: float) -> void:
	if not needs_water():
		return
	_water_progress += delta
	_dry_soil.modulate.a = clampf(1.0 - _water_progress / water_needed, 0.0, 1.0)
	var now: int = Time.get_ticks_msec()
	if now - _last_splash_ms >= SPLASH_SOUND_INTERVAL_MS:
		_last_splash_ms = now
		_play_sound(_splash_sound, splash_volume_db, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	if _water_progress >= water_needed:
		_quench()


## Büyüme hemen durur; görünüş (kuru toprak, balon, bükülen bitkiler) visual_delay sonra gelir
## (ekimden sonra kutlama görünsün diye). O arada sulanırsa görünüş hiç gelmez.
func _become_thirsty(visual_delay: float = 0.0) -> void:
	thirsty = true
	_water_progress = 0.0
	if visual_delay <= 0.0:
		_show_thirst()
		return
	var tween: Tween = create_tween()
	tween.tween_interval(visual_delay)
	tween.tween_callback(func() -> void:
		if thirsty:
			_show_thirst())


func _show_thirst() -> void:
	create_tween().tween_property(_dry_soil, ^"modulate:a", 1.0, DRY_FADE_TIME)
	_water_bubble.scale = Vector2.ZERO
	_water_bubble.show()
	create_tween().tween_property(_water_bubble, ^"scale", Vector2.ONE, BUBBLE_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for plant: Node2D in _plants:
		var side: float = 1.0 if randf() < 0.5 else -1.0
		var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(plant, ^"rotation", deg_to_rad(DROOP_DEGREES) * side, DROOP_TIME)
		tween.tween_property(plant, ^"modulate", DROOP_TINT, DROOP_TIME)


## Sulandı: toprak koyulaşır, balon söner, bitkiler dikleşir ve büyüme sürer.
func _quench() -> void:
	thirsty = false
	_dry_soil.modulate.a = 0.0
	_play_sound(_plop_sound, 0.0, 1.0)
	var bubble: Tween = create_tween()
	bubble.tween_property(_water_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	bubble.tween_callback(_water_bubble.hide)
	for plant: Node2D in _plants:
		var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(plant, ^"rotation", 0.0, PERK_TIME)
		tween.tween_property(plant, ^"modulate", Color.WHITE, PERK_TIME * 0.5)
	_stage_time_left = _grow_time() * STAGE_TIME_SHARES[stage]


func _advance_stage() -> void:
	stage += 1
	_play_sound(_grow_sound, 0.0, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	if stage == STAGE_SPROUT and crop == Crop.WHEAT:
		_wheat_seeds.hide()
	for i: int in _plants.size():
		var plant: Node2D = _plants[i]
		var delay: float = GROW_STAGGER * float(i) / maxf(_plants.size() - 1, 1)
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(_set_plant_stage.bind(plant, stage))
		tween.tween_callback(func() -> void: plant.scale = Vector2.ONE * GROW_POP_SCALE)
		tween.tween_property(plant, ^"scale", Vector2.ONE, GROW_POP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if stage == STAGE_READY:
		state = State.READY
		_celebrate()
		_ready_glint.emitting = true
		ripened.emit()
	elif stage in THIRSTY_STAGES:
		_become_thirsty()
	else:
		_stage_time_left = _grow_time() * STAGE_TIME_SHARES[stage]


func _grow_time() -> float:
	return carrot_grow_time if crop == Crop.CARROT else wheat_grow_time


func _set_plant_stage(plant: Node2D, plant_stage: int) -> void:
	for i: int in range(STAGE_SPROUT, STAGE_READY + 1):
		(plant.get_node(NodePath("Stage%d" % i)) as CanvasItem).visible = i == plant_stage


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
