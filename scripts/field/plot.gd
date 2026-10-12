class_name Plot
extends Node2D
## Tarladaki bir parsel: otlu -> (çapa) -> sürülmüş -> (tohum) -> ekili, büyüyor -> hazır -> (hasat) -> otlu.
## Çapanın her vuruşu (chop) vurulan noktaya en yakın ot kümesini söker ve sürülmüş toprağı biraz daha
## belirginleştirir; son ot da gidince parsel sürülmüş olur.
## Sürülmüş parsele havuç ya da çilek (3 çukura birer tohum), balkabağı (ortadaki tek iri çukura bir
## çekirdek) veya buğday (yüzeye serpilir) ekilir; ilk tohum parselin ürününü belirler, yarım kalan ekim
## sonra tamamlanabilir.
## Ekili bitki tohum -> filiz -> yapraklı -> hazır aşamalarından geçer. Tohumken ve yapraklıyken susar:
## toprak kurur, su balonu çıkar, bitki boynunu büker; sulanana kadar büyüme durur (bitki asla ölmez).
## Sahne açıkken büyüme gerçek zamanlı ilerler; sahne kapalıyken geçen süre geri dönüldüğünde
## load_state ile sessizce ileri sarılır (susamış bitki yine bekler).
## Hazır havuçlar parmakla tek tek çekilip çıkarılır, hazır buğday orakla biçilir, çilekler (her çalıda
## iki tane) dokununca tek tek kopar, balkabağı parmakla yana yuvarlanarak parselden çıkarılır (hazır
## balkabağı arada bir ve dokunulunca yerinde sallanır). Hasat bitince parsel
## tamamen başa dönmez: toprak yarı sürülmüş kalır, üstünde birkaç ot çıkar.
## Her aşamanın sonunda parsel sevinçle zıplar.

signal tilled
signal sown
signal watered
signal ripened
## Topraktan bir ürün çıktı (havuç ve çilek başına bir, buğday parseli başına bir demet); görseli
## dinleyen çizer.
signal harvested(harvested_crop: Crop, global_point: Vector2)

enum State { WEEDY, TILLED, SOWN, READY }
## Kayıtta sayı olarak tutulur: yeni ürün yalnızca sona eklenmeli.
enum Crop { NONE, CARROT, WHEAT, STRAWBERRY, PUMPKIN }

## Çukurlara (Spots) ekilen ürünler ve her çukurdaki bitki düğümünün adı.
const SPOT_PLANTS: Dictionary[Crop, NodePath] = {
	Crop.CARROT: ^"Plant",
	Crop.STRAWBERRY: ^"StrawberryPlant",
}

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

const WHEAT_SWAY_DEGREES: float = 4.0
const WHEAT_SWAY_PERIOD: float = 2.6
## Komşu başaklar arasındaki faz farkı (radyan): dalga parsel boyunca yürür.
const WHEAT_SWAY_PHASE_STEP: float = 0.7

## Hazır havucun dokunulabilir alanı (çukura göre yerel): yapraklar ve görünen tepe.
const CARROT_HIT: Rect2 = Rect2(-48.0, -100.0, 96.0, 115.0)
## Tam çekilmiş (amount = 1) havucun ölçek değişimi, yükselişi ve yana eğilişi.
const PULL_STRETCH: Vector2 = Vector2(-0.12, 0.35)
const PULL_LIFT: float = 16.0
const PULL_TILT_DEGREES_PER_PX: float = 0.15
const PULL_MAX_TILT_DEGREES: float = 18.0
const SNAP_BACK_TIME: float = 0.5
## Hazır çilek çalısının dokunulabilir alanı (çukura göre yerel); içindeki en yakın çilek kopar.
const STRAWBERRY_HIT: Rect2 = Rect2(-56.0, -90.0, 112.0, 110.0)
const BERRY_PICK_PITCH: float = 1.35
const BERRY_PICK_VOLUME_DB: float = -3.0
const BUSH_WIGGLE_DEGREES: float = 7.0
const BUSH_WIGGLE_TIME: float = 0.4
## Hasattan sonra yerinde kalan çilek çalısı ve balkabağı sarmaşığı bu sürede solup gider.
const PLANT_FADE_TIME: float = 0.3
## Hazır balkabağının dokunulabilir alanı (balkabağı çukuruna göre yerel).
const PUMPKIN_HIT: Rect2 = Rect2(-76.0, -112.0, 152.0, 122.0)
const PUMPKIN_SOW_RADIUS: float = 70.0
## Balkabağı yuvarlanırken bu kadar (yerel px) yol bir radyan döndürür.
const PUMPKIN_RADIUS: float = 52.0
## Geniş sarmaşık susayınca bütün bitkiler kadar eğilmez, yalnızca biraz.
const VINE_DROOP_DEGREES: float = 4.0
const PUMPKIN_OUT_PITCH: float = 0.7
## Hazır balkabağı arada bir yerinde bir o yana bir bu yana yuvarlanır ("beni yuvarla" ipucu); dokunulunca da.
const PUMPKIN_ROCK_DEGREES: Array[float] = [9.0, -7.0, 4.0, 0.0]
const PUMPKIN_ROCK_STEP_TIME: float = 0.14
const PUMPKIN_ROCK_INTERVAL_MIN: float = 3.5
const PUMPKIN_ROCK_INTERVAL_MAX: float = 6.0
const PUMPKIN_TAP_PITCH: float = 0.75
const PUMPKIN_TAP_VOLUME_DB: float = -6.0
## Orağın ucu bir başağa bu kadar (yerel px) yaklaşınca başak kesilir.
const REAP_RADIUS: float = 60.0
const STALK_FALL_DEGREES: float = 80.0
const STALK_FALL_TIME: float = 0.35
const SWISH_SOUND_INTERVAL_MS: int = 70
const BUNDLE_HEIGHT: float = 30.0
## Hasat kutlaması görünsün, sonra parsel yeniden otlansın.
const REGROW_DELAY: float = 0.9
## Hasattan sonra çıkan ot sayısı; toprağın geri kalanı sürülmüş durur.
const REGROW_WEEDS: int = 2

## Toprağın dokunulabilir yüzü (yerel); ön kenarın kalınlığı da dahil.
const AREA: Rect2 = Rect2(-165.0, -60.0, 330.0, 125.0)
## El göstergesinde buğday serperken ve biçerken parmağın parsel ortasından iki yana gittiği yol (yerel).
const HINT_SWEEP: float = 120.0
const TILL_REVEAL_TIME: float = 0.25
const WEED_RISE: float = 70.0
const WEED_DRIFT_MIN: float = 40.0
const WEED_DRIFT_MAX: float = 80.0
const WEED_SPIN_DEGREES: float = 50.0
const WEED_RISE_TIME: float = 0.18
const WEED_FALL_TIME: float = 0.24
const WEED_END_SCALE: float = 0.6
## Torbanın ağzı bir çukura / tohum noktasına bu kadar (yerel px) yaklaşınca tohum düşer.
const SPOT_SOW_RADIUS: float = 50.0
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
@export var strawberry_seed_texture: Texture2D
@export var pumpkin_seed_texture: Texture2D

@export_group("Büyüme")
## Sulamayı bekleme süresi hariç, tohumdan hazır olana kadar geçen süre.
@export_range(1.0, 600.0, 1.0, "suffix:s") var carrot_grow_time: float = 35.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var wheat_grow_time: float = 45.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var strawberry_grow_time: float = 45.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var pumpkin_grow_time: float = 50.0
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
@export_file("*.ogg", "*.wav") var carrot_pop_sound_path: String = "res://assets/audio/sfx/carrot_pop.ogg"
@export_file("*.ogg", "*.wav") var swish_sound_path: String = "res://assets/audio/sfx/sickle_swish.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var swish_volume_db: float = -4.0

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
var _ready_carrots: Array[Node2D] = []
var _stalks_left: Array[Node2D] = []
var _plant_rest: Dictionary[Node2D, Vector2] = {}
var _weed_rest: Dictionary[Node2D, Transform2D] = {}
var _last_swish_ms: int = -SWISH_SOUND_INTERVAL_MS
var _sway_time: float = 0.0
var _carrot_pop_sound: AudioStream
var _swish_sound: AudioStream

var _weeds_left: Array[Node2D] = []
var _weed_count: int = 0
var _all_weeds: Array[Node2D] = []
var _all_wheat_seeds: Array[Node2D] = []
var _all_wheat_plants: Array[Node2D] = []
var _spots: Array[Node2D] = []
var _spots_left: Array[Node2D] = []
var _seeds_landed: int = 0
## Bütün çilekler çukur sırasıyla (her çalıda Berry1, Berry2) ve henüz koparılmamış hazır olanlar.
var _berries: Array[Node2D] = []
var _ready_berries: Array[Node2D] = []
var _berry_spots: Dictionary[Node2D, Node2D] = {}
var _pumpkin_sown: bool = false
var _pumpkin_ready: bool = false
var _pumpkin_rest: Vector2
## Parmak balkabağını tutuyor (yuvarlıyor); kendi kendine sallanmaz.
var _pumpkin_held: bool = false
var _pumpkin_rock_left: float = 0.0
var _pumpkin_tween: Tween
var _wheat_seeds_left: Array[Node2D] = []
var _last_sprinkle_ms: int = -SPRINKLE_SOUND_INTERVAL_MS
var _chop_sound: AudioStream
var _plop_sound: AudioStream
var _sprinkle_sound: AudioStream
var _ready_sound: AudioStream

@onready var _tilled_soil: CanvasItem = $TilledSoil
@onready var _weeds: Node2D = $Weeds
@onready var _spots_root: Node2D = $Spots
@onready var _pumpkin_spot: Node2D = $PumpkinSpot
@onready var _pumpkin_plant: Node2D = $PumpkinSpot/Plant
@onready var _pumpkin: Node2D = $PumpkinSpot/Plant/Stage3/Pumpkin
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
	_carrot_pop_sound = _load_stream(carrot_pop_sound_path)
	_swish_sound = _load_stream(swish_sound_path)
	_all_weeds.assign(_weeds.get_children())
	_all_wheat_seeds.assign(_wheat_seeds.get_children())
	_all_wheat_plants.assign(_wheat_plants.get_children())
	_spots.assign(_spots_root.get_children())
	for weed: Node2D in _all_weeds:
		_weed_rest[weed] = weed.transform
	for spot: Node2D in _spots:
		for plant_path: NodePath in SPOT_PLANTS.values():
			var plant: Node2D = spot.get_node(plant_path) as Node2D
			_plant_rest[plant] = plant.position
		for berry: Node in spot.get_node(^"StrawberryPlant/Stage3").get_children():
			if berry.name.begins_with("Berry"):
				_berries.append(berry as Node2D)
				_berry_spots[berry as Node2D] = spot
	_plant_rest[_pumpkin_plant] = _pumpkin_plant.position
	_pumpkin_rest = _pumpkin.position
	_weed_count = _all_weeds.size()
	_weeds_left = _all_weeds.duplicate()
	_spots_left = _spots.duplicate()
	_wheat_seeds_left = _all_wheat_seeds.duplicate()
	_apply_visuals()


func _process(delta: float) -> void:
	_sway_wheat(delta)
	if _pumpkin_ready and not _pumpkin_held:
		_pumpkin_rock_left -= delta
		if _pumpkin_rock_left <= 0.0:
			_rock_pumpkin()
	if state != State.SOWN or thirsty:
		return
	_stage_time_left -= delta
	if _stage_time_left <= 0.0:
		_advance_stage()


## Boy atmış buğday rüzgârda dalgalanır: her başak biraz farklı fazda, kökü etrafında sallanır.
## Sallanan aşama görselidir; bitki düğümünün kendi dönüşü (susama, biçilme) bundan etkilenmez.
func _sway_wheat(delta: float) -> void:
	if crop != Crop.WHEAT or stage < STAGE_LEAFY or (state != State.SOWN and state != State.READY):
		return
	_sway_time += delta
	var stage_path: NodePath = NodePath("Stage%d" % stage)
	for i: int in _all_wheat_plants.size():
		var phase: float = _sway_time * TAU / WHEAT_SWAY_PERIOD + i * WHEAT_SWAY_PHASE_STEP
		(_all_wheat_plants[i].get_node(stage_path) as Node2D).rotation = sin(phase) * deg_to_rad(WHEAT_SWAY_DEGREES)


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


## Çukura ekilen bir ürünün torbası tutulurken bu ürünün ekilebileceği parselde boş çukurları gösterir;
## bırakılınca, ekimine başlanmamış parselde gizler.
func set_holes_visible(holes_visible: bool, seed_crop: Crop) -> void:
	if not can_sow(seed_crop):
		return
	if seed_crop == Crop.PUMPKIN:
		create_tween().tween_property(_hole(_pumpkin_spot), ^"modulate:a", 1.0 if holes_visible else 0.0, HOLE_FADE_TIME)
		return
	var alpha: float = 1.0 if holes_visible or crop != Crop.NONE else 0.0
	for spot: Node2D in _spots_left:
		create_tween().tween_property(_hole(spot), ^"modulate:a", alpha, HOLE_FADE_TIME)


## Torbanın ağzı bu noktadayken tohum düşer mi? Düştüyse true.
## Çukura ekilen üründe bir seferde en fazla bir çukur dolar; buğdayda yakındaki tüm noktalara serpilir.
func sow_at(global_point: Vector2, seed_crop: Crop) -> bool:
	if not can_sow(seed_crop):
		return false
	var local_point: Vector2 = to_local(global_point)
	if SPOT_PLANTS.has(seed_crop):
		return _sow_spot(local_point, seed_crop)
	if seed_crop == Crop.PUMPKIN:
		return _sow_pumpkin(local_point)
	if seed_crop == Crop.WHEAT:
		return _sow_wheat(local_point)
	return false


func _sow_spot(local_point: Vector2, seed_crop: Crop) -> bool:
	for spot: Node2D in _spots_left:
		if spot.position.distance_to(local_point) <= SPOT_SOW_RADIUS:
			_spots_left.erase(spot)
			crop = seed_crop
			_drop_seed(local_point, spot)
			return true
	return false


func _sow_pumpkin(local_point: Vector2) -> bool:
	if _pumpkin_sown or _pumpkin_spot.position.distance_to(local_point) > PUMPKIN_SOW_RADIUS:
		return false
	_pumpkin_sown = true
	crop = Crop.PUMPKIN
	_drop_seed(local_point, _pumpkin_spot)
	return true


## Tohum torbanın ağzından çukura düşer; değince çukur kapanıp tümseğe döner.
func _drop_seed(from_local: Vector2, spot: Node2D) -> void:
	var seed: Sprite2D = Sprite2D.new()
	match crop:
		Crop.STRAWBERRY:
			seed.texture = strawberry_seed_texture
		Crop.PUMPKIN:
			seed.texture = pumpkin_seed_texture
		_:
			seed.texture = carrot_seed_texture
	seed.position = from_local
	add_child(seed)
	var tween: Tween = create_tween()
	tween.tween_property(seed, ^"position", spot.position, SEED_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		seed.queue_free()
		_plant_seed(spot))


func _plant_seed(spot: Node2D) -> void:
	_play_sound(_plop_sound, 0.0, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	_hole(spot).modulate.a = 0.0
	_pop_in(_mound(spot))
	_seeds_landed += 1
	if crop == Crop.PUMPKIN or _seeds_landed == _spots.size():
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
	_plants = _crop_plants()
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
		tween.tween_property(plant, ^"rotation", _droop_angle(plant) * side, DROOP_TIME)
		tween.tween_property(plant, ^"modulate", DROOP_TINT, DROOP_TIME)


## Sulandı: toprak koyulaşır, balon söner, bitkiler dikleşir ve büyüme sürer.
func _quench() -> void:
	thirsty = false
	watered.emit()
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
	_step_stage()
	_play_sound(_grow_sound, 0.0, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	if stage == STAGE_SPROUT and crop == Crop.WHEAT:
		_wheat_seeds.hide()
	# Sarmaşık tümseği örtmez; filiz çıkınca tümsek kalkar.
	if stage == STAGE_SPROUT and crop == Crop.PUMPKIN:
		_mound(_pumpkin_spot).hide()
	for i: int in _plants.size():
		var plant: Node2D = _plants[i]
		var delay: float = GROW_STAGGER * float(i) / maxf(_plants.size() - 1, 1)
		var tween: Tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(_set_plant_stage.bind(plant, stage))
		tween.tween_callback(func() -> void: plant.scale = Vector2.ONE * GROW_POP_SCALE)
		tween.tween_property(plant, ^"scale", Vector2.ONE, GROW_POP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if state == State.READY:
		_celebrate()
		_ready_glint.emitting = true
		ripened.emit()
	elif thirsty:
		_become_thirsty()


## Bir aşama ilerletir (yalnızca veri; görünüşe dokunmaz).
func _step_stage() -> void:
	stage += 1
	if stage == STAGE_READY:
		state = State.READY
		match crop:
			Crop.CARROT:
				_ready_carrots = _spots.duplicate()
			Crop.STRAWBERRY:
				_ready_berries = _berries.duplicate()
			Crop.PUMPKIN:
				_pumpkin_ready = true
				_pumpkin_rock_left = randf_range(PUMPKIN_ROCK_INTERVAL_MIN, PUMPKIN_ROCK_INTERVAL_MAX)
			_:
				_stalks_left = _plants.duplicate()
	elif stage in THIRSTY_STAGES:
		thirsty = true
	else:
		_stage_time_left = _grow_time() * STAGE_TIME_SHARES[stage]


## Kayıt için parselin durumu (yalnızca JSON'a yazılabilir değerler; düğümler sıralarıyla tutulur).
## "carrot_sown" bütün çukurlu ürünlerin çukurlarını tutar (ad eski kayıtlar bozulmasın diye kaldı).
func save_state() -> Dictionary:
	return {
		"state": state,
		"crop": crop,
		"stage": stage,
		"thirsty": thirsty,
		"stage_time_left": _stage_time_left,
		"weeds": _all_weeds.map(func(weed: Node2D) -> bool: return weed in _weeds_left),
		"carrot_sown": _spots.map(func(spot: Node2D) -> bool: return spot not in _spots_left),
		"carrot_ready": _spots.map(func(spot: Node2D) -> bool: return spot in _ready_carrots),
		"strawberry_ready": _berries.map(func(berry: Node2D) -> bool: return berry in _ready_berries),
		"pumpkin_sown": _pumpkin_sown,
		"pumpkin_ready": _pumpkin_ready,
		"wheat_sown": _all_wheat_seeds.map(func(seed: Node2D) -> bool: return seed not in _wheat_seeds_left),
		"wheat_standing": _all_wheat_plants.map(func(plant: Node2D) -> bool: return plant in _stalks_left),
	}


## Kayıttan geri yükler, sahne kapalıyken geçen elapsed saniye kadar büyümeyi sessizce ileri sarar ve
## görünüşü animasyonsuz kurar. Kayıt bir geçişin ortasında alındıysa (tohum düşerken, hasat
## kutlamasında) o geçiş tamamlanmış sayılır.
func load_state(data: Dictionary, elapsed: float) -> void:
	state = clampi(int(data.get("state", State.WEEDY)), State.WEEDY, State.READY) as State
	crop = clampi(int(data.get("crop", Crop.NONE)), Crop.NONE, Crop.size() - 1) as Crop
	stage = clampi(int(data.get("stage", STAGE_SEED)), STAGE_SEED, STAGE_READY)
	thirsty = bool(data.get("thirsty", false))
	_stage_time_left = float(data.get("stage_time_left", 0.0))
	_water_progress = 0.0
	_weeds_left = _pick(_all_weeds, data.get("weeds", []), true)
	_spots_left = _pick(_spots, data.get("carrot_sown", []), false)
	_seeds_landed = _spots.size() - _spots_left.size()
	_ready_carrots = _pick(_spots, data.get("carrot_ready", []), true)
	_ready_berries = _pick(_berries, data.get("strawberry_ready", []), true)
	_pumpkin_sown = crop == Crop.PUMPKIN and bool(data.get("pumpkin_sown", false))
	_pumpkin_ready = crop == Crop.PUMPKIN and bool(data.get("pumpkin_ready", false))
	_wheat_seeds_left = _pick(_all_wheat_seeds, data.get("wheat_sown", []), false)
	_stalks_left = _pick(_all_wheat_plants, data.get("wheat_standing", []), true)
	var fully_sown: bool = (SPOT_PLANTS.has(crop) and _spots_left.is_empty()) \
			or (crop == Crop.PUMPKIN and _pumpkin_sown) \
			or (crop == Crop.WHEAT and _wheat_seeds_left.is_empty())
	if state == State.TILLED and fully_sown:
		state = State.SOWN
		stage = STAGE_SEED
		thirsty = true
	_plants.clear()
	if state == State.SOWN or state == State.READY:
		_plants = _crop_plants()
	if state == State.SOWN:
		_fast_forward(elapsed)
	_apply_visuals()
	if state == State.READY and _ready_carrots.is_empty() and _ready_berries.is_empty() and _stalks_left.is_empty() \
			and not _pumpkin_ready:
		_regrow()


func _fast_forward(seconds: float) -> void:
	while seconds > 0.0 and state == State.SOWN and not thirsty:
		if _stage_time_left > seconds:
			_stage_time_left -= seconds
			return
		seconds -= _stage_time_left
		_step_stage()


## Görünüşü o anki verilerden, animasyonsuz kurar.
func _apply_visuals() -> void:
	var growing: bool = state == State.SOWN or state == State.READY
	_tilled_soil.modulate.a = 1.0 - float(_weeds_left.size()) / maxf(_weed_count, 1) if state == State.WEEDY else 1.0
	for weed: Node2D in _all_weeds:
		weed.transform = _weed_rest[weed]
		weed.modulate.a = 1.0
		weed.visible = weed in _weeds_left
	for spot: Node2D in _spots:
		var sown: bool = SPOT_PLANTS.has(crop) and spot not in _spots_left
		var picked: bool = state == State.READY and crop == Crop.CARROT and spot not in _ready_carrots
		var waiting_hole: bool = state == State.TILLED and SPOT_PLANTS.has(crop) and not sown
		_mound(spot).visible = sown and not picked
		_hole(spot).modulate.a = 1.0 if picked or waiting_hole else 0.0
		for plant_crop: Crop in SPOT_PLANTS:
			var plant: Node2D = spot.get_node(SPOT_PLANTS[plant_crop]) as Node2D
			_reset_plant(plant)
			if growing and crop == plant_crop and not picked:
				_set_plant_stage(plant, stage)
	for berry: Node2D in _berries:
		berry.visible = state != State.READY or berry in _ready_berries
	_hole(_pumpkin_spot).modulate.a = 0.0
	_mound(_pumpkin_spot).visible = _pumpkin_sown and stage == STAGE_SEED
	_reset_plant(_pumpkin_plant)
	if growing and crop == Crop.PUMPKIN:
		_set_plant_stage(_pumpkin_plant, stage)
	_pumpkin.position = _pumpkin_rest
	_pumpkin.rotation = 0.0
	_pumpkin.visible = state != State.READY or _pumpkin_ready
	_wheat_seeds.visible = stage == STAGE_SEED
	for seed: Node2D in _all_wheat_seeds:
		seed.scale = Vector2.ONE
		seed.visible = seed not in _wheat_seeds_left
	for plant: Node2D in _all_wheat_plants:
		_reset_plant(plant)
		if growing and crop == Crop.WHEAT and (state != State.READY or plant in _stalks_left):
			_set_plant_stage(plant, stage)
	_dry_soil.modulate.a = 1.0 if thirsty else 0.0
	_water_bubble.visible = thirsty
	_water_bubble.scale = Vector2.ONE
	if thirsty:
		for plant: Node2D in _plants:
			plant.rotation = _droop_angle(plant) * (1.0 if randf() < 0.5 else -1.0)
			plant.modulate = DROOP_TINT
	_ready_glint.emitting = state == State.READY


func _crop_plants() -> Array[Node2D]:
	var plants: Array[Node2D] = []
	if SPOT_PLANTS.has(crop):
		for spot: Node2D in _spots:
			plants.append(spot.get_node(SPOT_PLANTS[crop]) as Node2D)
	elif crop == Crop.PUMPKIN:
		plants.append(_pumpkin_plant)
	elif crop == Crop.WHEAT:
		plants = _all_wheat_plants.duplicate()
	return plants


## Kayıttaki bayrak listesine göre düğüm seçer: bayrağı wanted olanlar. Liste eksik/bozuksa
## eksik kalan düğümler bayrağı wanted'ın tersiymiş gibi sayılır.
func _pick(nodes: Array[Node2D], flags: Variant, wanted: bool) -> Array[Node2D]:
	var picked: Array[Node2D] = []
	var list: Array = flags if flags is Array else []
	for i: int in nodes.size():
		if i < list.size() and bool(list[i]) == wanted:
			picked.append(nodes[i])
	return picked


## El göstergesi için bu ürünün tohumunun sıradaki düşeceği yerler (dünya koordinatı): çukurlu üründe boş
## çukurlar, balkabağında iri çukur, buğdayda parselin bir ucundan öbürüne.
func sow_hint_points(seed_crop: Crop) -> PackedVector2Array:
	var points: PackedVector2Array = []
	if SPOT_PLANTS.has(seed_crop):
		for spot: Node2D in _spots_left:
			points.append(spot.global_position)
	elif seed_crop == Crop.PUMPKIN:
		points.append(_pumpkin_spot.global_position)
	else:
		points.append(to_global(Vector2(-HINT_SWEEP, 0.0)))
		points.append(to_global(Vector2(HINT_SWEEP, 0.0)))
	return points


## El göstergesi için hasadın başladığı yer (dünya koordinatı): ilk hazır havucun yaprakları, balkabağı ya da
## buğdayın ortası. Çilekte ve hasat edilecek bir şey yoksa Vector2.INF.
func harvest_hint_point() -> Vector2:
	if state != State.READY:
		return Vector2.INF
	match crop:
		Crop.CARROT:
			if not _ready_carrots.is_empty():
				return _ready_carrots[0].to_global(CARROT_HIT.get_center())
		Crop.PUMPKIN:
			if _pumpkin_ready:
				return _pumpkin_spot.to_global(PUMPKIN_HIT.get_center())
		Crop.WHEAT:
			if can_reap():
				return global_position
	return Vector2.INF


## Noktadaki hazır havucun çukur sırası; yoksa -1.
func carrot_at(global_point: Vector2) -> int:
	if state != State.READY or crop != Crop.CARROT:
		return -1
	var local_point: Vector2 = to_local(global_point)
	for spot: Node2D in _ready_carrots:
		if CARROT_HIT.has_point(local_point - spot.position):
			return _spots.find(spot)
	return -1


## Havuç parmakla çekiliyor. amount: 0 (yerinde) .. 1 (çıkmak üzere); sideways: parmağın yana kayması (px).
func pull_carrot(index: int, amount: float, sideways: float) -> void:
	var plant: Node2D = _carrot_plant(index)
	plant.scale = Vector2.ONE + PULL_STRETCH * amount
	plant.position = _plant_rest[plant] + Vector2(0.0, -PULL_LIFT * amount)
	plant.rotation = deg_to_rad(clampf(sideways * PULL_TILT_DEGREES_PER_PX, -PULL_MAX_TILT_DEGREES, PULL_MAX_TILT_DEGREES))


## Erken bırakıldı: havuç yaylanarak yerine oturur.
func release_carrot(index: int) -> void:
	var plant: Node2D = _carrot_plant(index)
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(plant, ^"scale", Vector2.ONE, SNAP_BACK_TIME)
	tween.tween_property(plant, ^"position", _plant_rest[plant], SNAP_BACK_TIME)
	tween.tween_property(plant, ^"rotation", 0.0, SNAP_BACK_TIME)


## Havuç "pop!" diye topraktan fırlar; yerinde çukur kalır.
func uproot_carrot(index: int) -> void:
	var spot: Node2D = _spots[index]
	if spot not in _ready_carrots:
		return
	_ready_carrots.erase(spot)
	var plant: Node2D = _carrot_plant(index)
	var from: Vector2 = plant.global_position
	_reset_plant(plant)
	_mound(spot).hide()
	_hole(spot).modulate.a = 1.0
	_play_sound(_carrot_pop_sound, 0.0, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	_spawn_effect(dirt_burst_scene, spot.global_position)
	harvested.emit(crop, from)
	if _ready_carrots.is_empty():
		_finish_harvest()


func pumpkin_at(global_point: Vector2) -> bool:
	return state == State.READY and _pumpkin_ready \
			and PUMPKIN_HIT.has_point(to_local(global_point) - _pumpkin_spot.position)


## Balkabağı parmakla yana itiliyor: sideways, parmağın yana kayması (dünya px). Kabak gittiği yöne
## doğru yuvarlanır.
func roll_pumpkin(sideways: float) -> void:
	_hold_pumpkin()
	_set_pumpkin_roll(sideways / global_scale.x)


## Erken bırakıldı: balkabağı geri yuvarlanıp yerine oturur.
func release_pumpkin() -> void:
	_hold_pumpkin()
	_pumpkin_held = false
	_pumpkin_rock_left = randf_range(PUMPKIN_ROCK_INTERVAL_MIN, PUMPKIN_ROCK_INTERVAL_MAX)
	_pumpkin_tween = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pumpkin_tween.tween_property(_pumpkin, ^"position", _pumpkin_rest, SNAP_BACK_TIME)
	_pumpkin_tween.tween_property(_pumpkin, ^"rotation", 0.0, SNAP_BACK_TIME)


## Balkabağına kaydırmadan dokunuldu: "tok" diye yerinde sallanır.
func tap_pumpkin() -> void:
	if not _pumpkin_ready:
		return
	_pumpkin_held = false
	_play_sound(_plop_sound, PUMPKIN_TAP_VOLUME_DB, PUMPKIN_TAP_PITCH + randf_range(-seed_pitch_variation, seed_pitch_variation))
	_rock_pumpkin()


## Parmak balkabağını tuttu: süren sallanma ya da geri dönüş durur.
func _hold_pumpkin() -> void:
	_pumpkin_held = true
	if _pumpkin_tween != null:
		_pumpkin_tween.kill()


## Balkabağı yerinde bir o yana bir bu yana yuvarlanıp durur.
func _rock_pumpkin() -> void:
	_pumpkin_rock_left = randf_range(PUMPKIN_ROCK_INTERVAL_MIN, PUMPKIN_ROCK_INTERVAL_MAX)
	if _pumpkin_tween != null:
		_pumpkin_tween.kill()
	_pumpkin_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var angle: float = _pumpkin.rotation
	for degrees: float in PUMPKIN_ROCK_DEGREES:
		_pumpkin_tween.tween_method(_set_pumpkin_roll_angle, angle, deg_to_rad(degrees), PUMPKIN_ROCK_STEP_TIME)
		angle = deg_to_rad(degrees)


## offset: balkabağının yerinden yana kayması (yerel px); kayan kabak kayma kadar döner.
func _set_pumpkin_roll(offset: float) -> void:
	_pumpkin.position = _pumpkin_rest + Vector2(offset, 0.0)
	_pumpkin.rotation = offset / PUMPKIN_RADIUS


func _set_pumpkin_roll_angle(angle: float) -> void:
	_set_pumpkin_roll(angle * PUMPKIN_RADIUS)


## Balkabağı sapından kopup parselden yuvarlanarak çıktı; sarmaşık yerinde kalır, sonra solar.
func roll_out_pumpkin() -> void:
	if not _pumpkin_ready:
		return
	_pumpkin_ready = false
	_hold_pumpkin()
	_pumpkin_held = false
	var from: Vector2 = _pumpkin.global_position
	_pumpkin.hide()
	_play_sound(_carrot_pop_sound, 0.0, PUMPKIN_OUT_PITCH + randf_range(-seed_pitch_variation, seed_pitch_variation))
	_spawn_effect(dirt_burst_scene, _pumpkin_spot.global_position)
	harvested.emit(crop, from)
	_finish_harvest()


## Noktadaki çalının, noktaya en yakın hazır çileğinin sırası; yoksa -1. Çilek küçük olduğundan çalının
## herhangi bir yerine dokunmak yeter.
func berry_at(global_point: Vector2) -> int:
	if state != State.READY or crop != Crop.STRAWBERRY:
		return -1
	var local_point: Vector2 = to_local(global_point)
	var best: Node2D = null
	for berry: Node2D in _ready_berries:
		if not STRAWBERRY_HIT.has_point(local_point - _berry_spots[berry].position):
			continue
		if best == null or to_local(berry.global_position).distance_squared_to(local_point) \
				< to_local(best.global_position).distance_squared_to(local_point):
			best = berry
	return _berries.find(best) if best != null else -1


## Çilek dalından kopar, çalı sallanır; çalı yerinde kalır, parsel hasat bitince temizlenir.
func pick_berry(index: int) -> void:
	var berry: Node2D = _berries[index]
	if berry not in _ready_berries:
		return
	_ready_berries.erase(berry)
	var from: Vector2 = berry.global_position
	berry.hide()
	var plant: Node2D = _berry_spots[berry].get_node(SPOT_PLANTS[Crop.STRAWBERRY]) as Node2D
	plant.rotation = deg_to_rad(BUSH_WIGGLE_DEGREES) * signf(berry.position.x)
	create_tween().tween_property(plant, ^"rotation", 0.0, BUSH_WIGGLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_play_sound(_carrot_pop_sound, BERRY_PICK_VOLUME_DB, BERRY_PICK_PITCH + randf_range(-seed_pitch_variation, seed_pitch_variation))
	_spawn_effect(sparkle_scene, from)
	harvested.emit(crop, from)
	if _ready_berries.is_empty():
		_finish_harvest()


func can_reap() -> bool:
	return state == State.READY and crop == Crop.WHEAT and not _stalks_left.is_empty()


## Orağın ucu bu noktadan geçti: yakındaki başaklar devrilir. Kesilen başak sayısını döndürür.
func reap_at(global_point: Vector2) -> int:
	if not can_reap():
		return 0
	var local_point: Vector2 = to_local(global_point)
	var cut: int = 0
	for stalk: Node2D in _stalks_left.duplicate():
		if stalk.position.distance_to(local_point) <= REAP_RADIUS:
			_stalks_left.erase(stalk)
			_fell(stalk, local_point)
			cut += 1
	if cut == 0:
		return 0
	var now: int = Time.get_ticks_msec()
	if now - _last_swish_ms >= SWISH_SOUND_INTERVAL_MS:
		_last_swish_ms = now
		_play_sound(_swish_sound, swish_volume_db, 1.0 + randf_range(-seed_pitch_variation, seed_pitch_variation))
	if _stalks_left.is_empty():
		harvested.emit(crop, to_global(Vector2(0.0, -BUNDLE_HEIGHT)))
		_finish_harvest()
	return cut


## Başak orağın geçtiği yerden öteye doğru devrilip kaybolur.
func _fell(stalk: Node2D, from_local: Vector2) -> void:
	var side: float = signf(stalk.position.x - from_local.x)
	if side == 0.0:
		side = 1.0 if randf() < 0.5 else -1.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(stalk, ^"rotation", deg_to_rad(STALK_FALL_DEGREES) * side, STALK_FALL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(stalk, ^"modulate:a", 0.0, STALK_FALL_TIME * 0.6).set_delay(STALK_FALL_TIME * 0.4)
	tween.chain().tween_callback(stalk.hide)


func _finish_harvest() -> void:
	_ready_glint.emitting = false
	_celebrate()
	var tween: Tween = create_tween()
	tween.tween_interval(REGROW_DELAY)
	tween.tween_callback(_regrow)


## Hasattan sonra: toprak yarı sürülmüş kalır, üstünde birkaç ot çıkar; parsel yeniden çapalanabilir.
func _regrow() -> void:
	# Ürünü toplanmış çilek çalısı ve balkabağı sarmaşığı birden kaybolmasın, solarak gitsin.
	var leaving: Array[Node2D] = []
	if crop == Crop.STRAWBERRY or crop == Crop.PUMPKIN:
		leaving = _plants.duplicate()
	state = State.WEEDY
	crop = Crop.NONE
	stage = STAGE_SEED
	thirsty = false
	_plants.clear()
	_ready_carrots.clear()
	_ready_berries.clear()
	_stalks_left.clear()
	_pumpkin_sown = false
	_pumpkin_ready = false
	_seeds_landed = 0
	_spots_left = _spots.duplicate()
	for spot: Node2D in _spots:
		create_tween().tween_property(_hole(spot), ^"modulate:a", 0.0, HOLE_FADE_TIME)
		_mound(spot).hide()
		_reset_plant(spot.get_node(SPOT_PLANTS[Crop.CARROT]) as Node2D)
		var bush: Node2D = spot.get_node(SPOT_PLANTS[Crop.STRAWBERRY]) as Node2D
		if bush not in leaving:
			_restore_plant(bush)
	_hole(_pumpkin_spot).modulate.a = 0.0
	_mound(_pumpkin_spot).hide()
	if _pumpkin_plant not in leaving:
		_restore_plant(_pumpkin_plant)
	for plant: Node2D in leaving:
		var tween: Tween = create_tween()
		tween.tween_property(plant, ^"modulate:a", 0.0, PLANT_FADE_TIME)
		tween.tween_callback(_restore_plant.bind(plant))
	_wheat_seeds.show()
	_wheat_seeds_left = _all_wheat_seeds.duplicate()
	for seed: Node2D in _all_wheat_seeds:
		seed.hide()
	for plant: Node2D in _all_wheat_plants:
		_reset_plant(plant)
	_dry_soil.modulate.a = 0.0
	_water_bubble.hide()
	var weeds: Array[Node2D] = _all_weeds.duplicate()
	weeds.shuffle()
	_weeds_left.assign(weeds.slice(0, REGROW_WEEDS))
	for weed: Node2D in _weeds_left:
		weed.transform = _weed_rest[weed]
		weed.modulate.a = 1.0
		_pop_in(weed)
	var progress: float = 1.0 - float(_weeds_left.size()) / maxf(_weed_count, 1)
	create_tween().tween_property(_tilled_soil, ^"modulate:a", progress, TILL_REVEAL_TIME)


## Biçilen başak düğümüyle birlikte gizlenir (_fell); yeniden kullanılmadan önce görünür yapılmalı.
func _reset_plant(plant: Node2D) -> void:
	plant.show()
	_set_plant_stage(plant, STAGE_SEED)
	plant.position = _plant_rest.get(plant, plant.position)
	plant.rotation = 0.0
	plant.scale = Vector2.ONE
	plant.modulate = Color.WHITE


## Çilek çalısı ya da balkabağı sarmaşığı gizlenir; toplanan ürünü bir sonraki ekim için yerine geri
## takılır (çilekler dallarına, balkabağı sarmaşığın ortasına).
func _restore_plant(plant: Node2D) -> void:
	_reset_plant(plant)
	for berry: Node2D in _berries:
		if plant.is_ancestor_of(berry):
			berry.show()
	if plant == _pumpkin_plant:
		_pumpkin.position = _pumpkin_rest
		_pumpkin.rotation = 0.0
		_pumpkin.show()


func _droop_angle(plant: Node2D) -> float:
	return deg_to_rad(VINE_DROOP_DEGREES if plant == _pumpkin_plant else DROOP_DEGREES)


func _carrot_plant(index: int) -> Node2D:
	return _spots[index].get_node(^"Plant") as Node2D


func _grow_time() -> float:
	match crop:
		Crop.CARROT:
			return carrot_grow_time
		Crop.STRAWBERRY:
			return strawberry_grow_time
		Crop.PUMPKIN:
			return pumpkin_grow_time
	return wheat_grow_time


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
