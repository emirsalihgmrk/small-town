extends Node2D
## Kümes bölümü: eve dönüş, sepetten yemliğe buğday, kovayla suluğa su, folluktan sepete yumurta ve
## kızın tepkileri. Tavuklar yemliği, suluğu ve folluklarını kendileri kullanır (Hen).
## Yemlik ya da suluk dolunca ve yumurta toplanınca kız sevinir; bir tavuk yumurtlayınca kümese el
## sallar; kedi uyanınca şaşırır; uzun süre dokunulmazsa esner. Folluğa dokununca içindeki yumurtalar
## ortak sepete eklenir ve sepete uçar.
## Sepette buğday yokken demet çekilmeye çalışılırsa yemliğin balonu zıplar; balonda tarla görünürken
## balona dokununca tarlaya gidilir. Sepete dokununca sepetin içi açılır.
## Yemlik, suluk, folluklar ve tavuklar açılışta kayıttan geri yüklenir; sahne kapalıyken geçen oyun
## süresi kadar tavukların döngüsü ileri sarılır (Hen.load_state). Yemlik ya da suluk dolunca, yumurta
## yumurtlanınca ya da toplanınca, sahneden çıkarken ve SaveGame diske yazmadan hemen önce durum kayda
## geçer.
## El göstergesi (HintDirector): yemlik dolu değilken ve sepette buğday varken sepetten yemliğe demet
## çekmeyi, suluk dolu değilken kovayı suluğa götürmeyi gösterir.

const SECTION: String = "coop"
const FIELD_SECTION: StringName = &"field"
## El göstergesindeki işlerin kimlikleri (öğrenme sayısı kayıtta bu adlarla tutulur).
const HINT_FEED: StringName = &"coop_feed"
const HINT_WATER: StringName = &"coop_water"
## Kova suluğun üstünde bu kadar bekler (Waterer.water_needed'dan biraz uzun).
const HINT_WATER_HOLD: float = 1.6
## El göstergesinde taşınan demetin boyu (FeedHand'deki taşıma boyuna yakın).
const HINT_WHEAT_SCALE: float = 0.75
## Kızın kümese (sağa) bakan kolu.
const GIRL_COOP_ARM: int = 1
## Bir folluktan birden çok yumurta toplanınca üst üste binmesinler diye yan yana havalanırlar.
const EGG_SPREAD: float = 26.0
## Esneme zamanı geldiğinde kız başka bir hareketteyse bu kadar sonra yeniden denenir.
const YAWN_RETRY_TIME: float = 2.0

## Bu kadar süre hiç dokunulmazsa kız esner (sonra yine aynı süre beklenir).
@export_range(5.0, 120.0, 1.0, "suffix:s") var idle_yawn_time: float = 25.0

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _feeder: Feeder = $World/Farmyard/Feeder
@onready var _waterer: Waterer = $World/Farmyard/Waterer
@onready var _girl: Girl = $World/Girl
@onready var _feed_hand: FeedHand = $FeedHand
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _cat: SleepyCat = $World/Cat
@onready var _bucket: Node2D = $World/Bucket
@onready var _hints: HintDirector = $HintDirector

var _nests: Array[Nest] = []
var _hens: Array[Hen] = []
var _idle_time: float = 0.0
## El göstergesinin taşıdığı buğday demeti (sahnede değil, yalnızca örnek).
var _hint_wheat: Sprite2D


func _ready() -> void:
	_nests.assign($World/House/Nests.get_children())
	for node: Node in $World/Farmyard.get_children():
		if node is Hen:
			_hens.append(node as Hen)
	_restore()
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_feeder.filled.connect(_girl.cheer)
	_waterer.filled.connect(_girl.cheer)
	_feeder.bubble_tapped.connect(SceneRouter.go_to_section.bind(FIELD_SECTION))
	_feed_hand.no_wheat.connect(_feeder.nudge_bubble)
	_feeder.filled.connect(SaveGame.request_save)
	_waterer.filled.connect(SaveGame.request_save)
	for nest: Nest in _nests:
		nest.laid.connect(_girl.wave.bind(GIRL_COOP_ARM))
		nest.laid.connect(SaveGame.request_save)
		nest.collected.connect(_on_eggs_collected)
	_cat.woke.connect(_girl.surprise)
	SaveGame.before_save.connect(_store)
	_hint_wheat = Sprite2D.new()
	_hint_wheat.texture = _feed_hand.wheat_texture
	_hint_wheat.scale = Vector2.ONE * HINT_WHEAT_SCALE
	_hints.provider = _current_hint
	_feeder.filled.connect(_hints.learned.bind(HINT_FEED))
	_waterer.filled.connect(_hints.learned.bind(HINT_WATER))


func _process(delta: float) -> void:
	_idle_time += delta
	if _idle_time >= idle_yawn_time:
		_idle_time = 0.0 if _girl.yawn() else idle_yawn_time - YAWN_RETRY_TIME


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_idle_time = 0.0


func _exit_tree() -> void:
	_store()
	SaveGame.save_now()
	_hint_wheat.free()


## El göstergesi için o an yapılabilecek ilk iş (bkz. HintDirector.provider).
func _current_hint() -> Dictionary:
	if _basket_menu.is_open:
		return {}
	if _feeder.can_fill() and Basket.count(Items.WHEAT) > 0:
		return {"id": HINT_FEED, "carry": _hint_wheat, "points": PackedVector2Array([
				_to_screen(_basket.center()), _to_screen(_feeder.to_global(_feeder.drop_area.get_center()))])}
	if _waterer.needs_water():
		return {"id": HINT_WATER, "carry": _bucket, "hold": HINT_WATER_HOLD, "points": PackedVector2Array([
				_to_screen(_bucket.global_position), _to_screen(_waterer.to_global(_waterer.pour_area.get_center()))])}
	return {}


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point


## Yumurtalar ortak sepete hemen eklenir (sahne kapansa da kaybolmaz); uçuş yalnızca görünüştür.
func _on_eggs_collected(count: int, global_point: Vector2) -> void:
	Basket.add(Items.EGG, count)
	for i: int in count:
		_basket.receive(Items.EGG, global_point + Vector2((i - (count - 1) * 0.5) * EGG_SPREAD, 0.0))
	_girl.cheer()


func _store() -> void:
	SaveGame.set_section(SECTION, {
		"saved_at": SaveGame.play_time,
		"feeder": _feeder.save_state(),
		"waterer": _waterer.save_state(),
		"nests": _nests.map(func(nest: Nest) -> Dictionary: return nest.save_state()),
		"hens": _hens.map(func(hen: Hen) -> Dictionary: return hen.save_state()),
	})


## Yemlik, suluk ve folluklar tavuklardan önce yüklenir: tavuklar ileri sararken onları kullanır.
## Folluk ya da tavuk sayısı kayıttakiyle uyuşmazsa o kısım yok sayılır.
func _restore() -> void:
	var data: Dictionary = SaveGame.get_section(SECTION)
	if data.is_empty():
		return
	var elapsed: float = maxf(SaveGame.play_time - float(data.get("saved_at", SaveGame.play_time)), 0.0)
	var feeder_data: Variant = data.get("feeder")
	if feeder_data is Dictionary:
		_feeder.load_state(feeder_data)
	var waterer_data: Variant = data.get("waterer")
	if waterer_data is Dictionary:
		_waterer.load_state(waterer_data)
	var nests: Variant = data.get("nests")
	if nests is Array and (nests as Array).size() == _nests.size():
		for i: int in _nests.size():
			if (nests as Array)[i] is Dictionary:
				_nests[i].load_state((nests as Array)[i])
	var hens: Variant = data.get("hens")
	if hens is Array and (hens as Array).size() == _hens.size():
		for i: int in _hens.size():
			if (hens as Array)[i] is Dictionary:
				_hens[i].load_state((hens as Array)[i], elapsed)
