class_name PlayBirdhouse
extends Node2D
## Ana ekrandaki kuş evi (Dükkân'dan alınınca görünür). Kuş evine dokununca sepetten bir buğday alınır,
## demet evin sekisinde belirip tanelere dağılır ve taneler önündeki çimene saçılır. Evde yaşayan kuşlar
## sırayla deliğinden çıkıp tanelere uçar ve gagalar; taneler bitince birer birer deliğe geri girer.
## Sepette buğday yoksa ev sallanır ve tarla balonu çıkar (dokununca tarlaya gider). Kuşlar yerdeyken
## dokununca zıplayıp cıvıldar. Kayıt yoktur: sahneden çıkılırsa yerdeki taneler kaybolur.
## Kök noktası direğin yerdeki ortasıdır; ölçüler birdhouse.svg'nin 0.85 ölçekli hâline göredir.

const FIELD_SECTION: StringName = &"field"
const HOLE: Vector2 = Vector2(0.0, -117.0)
## Demetin belirdiği yer: deliğin altındaki seki.
const LEDGE: Vector2 = Vector2(0.0, -96.0)
## Tanelerin saçıldığı çimen: evin sağında, havuzun arkasında (kart ile havuz arası çok dar).
const GRAIN_AREA: Rect2 = Rect2(60.0, -55.0, 200.0, 32.0)
## Kuşların ayaklarının durabildiği yatay aralık.
const STAND_MIN_X: float = 30.0
const STAND_MAX_X: float = 290.0
const GRAIN_COUNT: int = 12
const GRAIN_SCALE: float = 1.6
const BUNDLE_SCALE: float = 0.45
const BUNDLE_POP_TIME: float = 0.2
const BUNDLE_HOLD_TIME: float = 0.15
const SCATTER_TIME: float = 0.45
const SCATTER_ARC: float = 50.0
const SCATTER_STAGGER: float = 0.03
const EAT_TIME: float = 0.15
const BIRD_DELAY: float = 0.7
const BIRD_STAGGER: float = 0.6
## Delikteyken kuşun boyu (tam boyun katı).
const HOLE_SIZE: float = 0.2
const OUT_TIME: float = 0.9
const OUT_ARC: float = 70.0
const HOME_TIME: float = 0.8
const HOP_TIME: float = 0.35
const HOP_ARC: float = 22.0
const PECK_PAUSE_MIN: float = 0.3
const PECK_PAUSE_MAX: float = 0.8
## Gaga ucu taneye bu kadar yakınsa tane yenir.
const BEAK_REACH: float = 22.0
const WIGGLE_DEGREES: float = 4.0
const WIGGLE_TIME: float = 0.08
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_STAY_TIME: float = 5.0
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var girl: Girl
@export var grain_texture: Texture2D
@export var bundle_texture: Texture2D
@export_file("*.ogg", "*.wav") var sprinkle_sound_path: String = "res://assets/audio/sfx/seed_sprinkle.ogg"

var _grains: Array[Sprite2D] = []
var _birds_out: int = 0
var _sprinkle_sound: AudioStream
var _wiggle_tween: Tween
var _bubble_tween: Tween
var _bubble_scale: Vector2

@onready var _house: Node2D = $House
@onready var _grains_root: Node2D = $Grains
@onready var _birds: Node2D = $Birds
@onready var _bubble: Node2D = $Bubble
@onready var _bubble_tap: Tappable = $Bubble/TapArea


func _ready() -> void:
	if ResourceLoader.exists(sprinkle_sound_path):
		_sprinkle_sound = load(sprinkle_sound_path) as AudioStream
	($HouseTap as Tappable).tapped.connect(_on_house_tapped)
	_bubble_tap.tapped.connect(func(_point: Vector2) -> void: SceneRouter.go_to_section(FIELD_SECTION))
	_bubble_scale = _bubble.scale
	_bubble.hide()


func _on_house_tapped(_point: Vector2) -> void:
	_wiggle()
	if not _grains.is_empty() or _birds_out > 0:
		return
	if not Basket.take(Items.WHEAT):
		_show_bubble()
		return
	_hide_bubble()
	_scatter()


## Demet sekide belirip tanelere dağılır; kuşlar biraz sonra sırayla çıkar.
func _scatter() -> void:
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_sprinkle_sound, AudioManager.BUS_SFX, 0.0, 1.0, pan)
	var bundle: Sprite2D = Sprite2D.new()
	bundle.texture = bundle_texture
	bundle.position = LEDGE
	bundle.scale = Vector2.ZERO
	add_child(bundle)
	var tween: Tween = bundle.create_tween()
	tween.tween_property(bundle, ^"scale", Vector2.ONE * BUNDLE_SCALE, BUNDLE_POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_interval(BUNDLE_HOLD_TIME)
	tween.tween_callback(func() -> void:
		bundle.queue_free()
		for i: int in GRAIN_COUNT:
			_throw_grain(i * SCATTER_STAGGER))
	var birds: Array[Node] = _birds.get_children()
	for i: int in birds.size():
		var send: Tween = create_tween()
		send.tween_interval(BIRD_DELAY + i * BIRD_STAGGER)
		send.tween_callback(_send_out.bind(birds[i] as HouseBird))


func _throw_grain(delay: float) -> void:
	var grain: Sprite2D = Sprite2D.new()
	grain.texture = grain_texture
	grain.position = LEDGE
	grain.scale = Vector2.ONE * GRAIN_SCALE
	grain.rotation = randf() * TAU
	_grains_root.add_child(grain)
	_grains.append(grain)
	var to: Vector2 = GRAIN_AREA.position + Vector2(randf(), randf()) * GRAIN_AREA.size
	var control: Vector2 = (LEDGE + to) * 0.5 + Vector2(0.0, -SCATTER_ARC)
	var tween: Tween = grain.create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void:
		grain.position = LEDGE.lerp(control, t).lerp(control.lerp(to, t), t), 0.0, 1.0, SCATTER_TIME)


func _send_out(bird: HouseBird) -> void:
	var grain: Sprite2D = _grains.pick_random() if not _grains.is_empty() else null
	if grain == null:
		return
	if _birds_out == 0 and girl != null:
		girl.cheer()
	_birds_out += 1
	bird.fly(HOLE, _stand_spot(bird, HOLE, grain.position), HOLE_SIZE, 1.0, OUT_TIME, OUT_ARC, _feed.bind(bird))


## Kuş biraz bekleyip gagalar.
func _feed(bird: HouseBird) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(randf_range(PECK_PAUSE_MIN, PECK_PAUSE_MAX))
	tween.tween_callback(bird.peck.bind(_after_peck.bind(bird)))


## Gagasının ucunda tane varsa yer ve gagalamayı sürdürür; yoksa en yakın taneye seker; tane kalmadıysa
## evine döner.
func _after_peck(bird: HouseBird) -> void:
	var grain: Sprite2D = _nearest_grain(bird.beak())
	if grain == null:
		bird.fly(bird.position, HOLE, 1.0, HOLE_SIZE, HOME_TIME, OUT_ARC, _went_home.bind(bird))
	elif grain.position.distance_to(bird.beak()) <= BEAK_REACH:
		_eat(grain)
		_feed(bird)
	else:
		bird.fly(bird.position, _stand_spot(bird, bird.position, grain.position), 1.0, 1.0, HOP_TIME, HOP_ARC,
				_feed.bind(bird))


func _went_home(bird: HouseBird) -> void:
	bird.hide()
	_birds_out -= 1


func _eat(grain: Sprite2D) -> void:
	_grains.erase(grain)
	var tween: Tween = grain.create_tween()
	tween.tween_property(grain, ^"scale", Vector2.ZERO, EAT_TIME)
	tween.tween_callback(grain.queue_free)


func _nearest_grain(point: Vector2) -> Sprite2D:
	var best: Sprite2D = null
	for grain: Sprite2D in _grains:
		if best == null or grain.position.distance_to(point) < best.position.distance_to(point):
			best = grain
	return best


## Gagası taneye gelecek biçimde tanenin yanında bir yer: kuşun geldiği yönden; o yan çok dışarıdaysa öbür yan.
func _stand_spot(bird: HouseBird, from: Vector2, grain: Vector2) -> Vector2:
	var side: float = 1.0 if from.x <= grain.x else -1.0
	var spot: Vector2 = grain - Vector2(side * bird.beak_reach(), 0.0)
	if spot.x < STAND_MIN_X or spot.x > STAND_MAX_X:
		spot = grain + Vector2(side * bird.beak_reach(), 0.0)
	# Uçuş yönü kuşun bakacağı yönü belirler; tam dikey uçuşta yönü korumak için biraz kaydır.
	if absf(spot.x - from.x) <= 1.0:
		spot.x += signf(grain.x - spot.x) * 2.0
	return spot


func _wiggle() -> void:
	if _wiggle_tween != null and _wiggle_tween.is_running():
		return
	var angle: float = deg_to_rad(WIGGLE_DEGREES)
	_wiggle_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_wiggle_tween.tween_property(_house, ^"rotation", -angle, WIGGLE_TIME)
	_wiggle_tween.tween_property(_house, ^"rotation", angle, WIGGLE_TIME * 2.0)
	_wiggle_tween.tween_property(_house, ^"rotation", 0.0, WIGGLE_TIME)


func _show_bubble() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble.scale = Vector2.ZERO
	_bubble.show()
	_bubble_tap.enabled = true
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, BUBBLE_POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_interval(BUBBLE_STAY_TIME)
	_bubble_tween.tween_callback(_hide_bubble)


func _hide_bubble() -> void:
	if not _bubble.visible:
		return
	_bubble_tap.enabled = false
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
	_bubble_tween.tween_callback(_bubble.hide)
