extends Node2D
## Tarla bölümü: eve dönüş, hasadın ortak sepete girmesi, parsellerin kaydı ve kızın tepkileri.
## Parseller açılışta kayıttan geri yüklenir; sahne kapalıyken geçen oyun süresi kadar büyüme ileri
## sarılır. Parselde bir aşama bittiğinde, sahneden çıkarken ve SaveGame diske yazmadan hemen önce
## parsellerin durumu kayda geçer.
## Kız; parsel sürülünce, ekilince, ürün çıkınca ve tavşan havucu yiyince sevinir; bir parsel hazır
## olunca tarlaya el sallar; tavşan görününce şaşırır; uzun süre dokunulmazsa esner.
## Sepete dokununca sepetin içini gösteren menü açılır.
## El göstergesi (HintDirector) sırayla şunları gösterir: hazır ürünün hasadı (havucu yukarı çekmek,
## balkabağını yana itmek, orağı buğdayın üstünden geçirmek), susamış parseli kovayla sulamak, sürülmüş
## parsele tohum ekmek, otlu parseli çapayla ovmak. Çilek hasadı (dokunmak) gösterilmez.
## Boş sürülmüş parsele ekim gösterilirken torba her gösterimde sıradakine geçer (havuç, buğday, çilek,
## balkabağı; rafta olmayan atlanır), çocuk her tohumun ekilebildiğini görsün. Yarım ekilmiş parselde o
## parselin torbası gösterilir.

const SECTION: String = "field"
const CROP_ITEMS: Dictionary = {
	Plot.Crop.CARROT: Items.CARROT,
	Plot.Crop.WHEAT: Items.WHEAT,
	Plot.Crop.STRAWBERRY: Items.STRAWBERRY,
	Plot.Crop.PUMPKIN: Items.PUMPKIN,
}
## Ürünün tohum torbası.
const SEED_TOOLS: Dictionary = {
	Plot.Crop.CARROT: FieldTools.Tool.CARROT_SEEDS,
	Plot.Crop.WHEAT: FieldTools.Tool.WHEAT_SEEDS,
	Plot.Crop.STRAWBERRY: FieldTools.Tool.STRAWBERRY_SEEDS,
	Plot.Crop.PUMPKIN: FieldTools.Tool.PUMPKIN_SEEDS,
}
## Boş parsele ekim gösterilirken torbaların sırası.
const SOW_HINT_ORDER: Array[Plot.Crop] = [Plot.Crop.CARROT, Plot.Crop.WHEAT, Plot.Crop.STRAWBERRY, Plot.Crop.PUMPKIN]
## El göstergesindeki işlerin kimlikleri (öğrenme sayısı kayıtta bu adlarla tutulur).
const HINT_TILL: StringName = &"field_till"
const HINT_SOW: StringName = &"field_sow"
const HINT_WATER: StringName = &"field_water"
const HINT_PULL_CARROT: StringName = &"field_pull_carrot"
const HINT_ROLL_PUMPKIN: StringName = &"field_roll_pumpkin"
const HINT_REAP: StringName = &"field_reap"
## Hasat edilen ürün -> öğrenilen iş.
const HARVEST_HINTS: Dictionary = {
	Plot.Crop.CARROT: HINT_PULL_CARROT,
	Plot.Crop.PUMPKIN: HINT_ROLL_PUMPKIN,
	Plot.Crop.WHEAT: HINT_REAP,
}
## El göstergesinde çapanın parsel ortasından iki yana gidip geldiği yol (ekran px).
const HINT_RUB: float = 90.0
## Havucu çekerken parmağın yukarı, balkabağını iterken yana gittiği yol (ekran px); HarvestHand'deki
## pull_distance ve roll_distance'tan biraz uzun.
const HINT_PULL: float = 140.0
const HINT_ROLL: float = 180.0
## Kova parselin üstünde bu kadar bekler (sulama bir saniyede biter).
const HINT_WATER_HOLD: float = 1.0
## Kızın tarlaya (sağa) bakan kolu.
const GIRL_FIELD_ARM: int = 1
## Esneme zamanı geldiğinde kız başka bir hareketteyse bu kadar sonra yeniden denenir.
const YAWN_RETRY_TIME: float = 2.0

## Bu kadar süre hiç dokunulmazsa kız esner (sonra yine aynı süre beklenir).
@export_range(5.0, 120.0, 1.0, "suffix:s") var idle_yawn_time: float = 25.0

var _plots: Array[Plot] = []
var _idle_time: float = 0.0
## Boş parsel için sıradaki torbanın SOW_HINT_ORDER'daki yeri ve son sorulan ipucunda seçilen ürün
## (yarım ekilmiş parsel seçildiyse NONE: o gösterim sırayı ilerletmez).
var _sow_hint_turn: int = 0
var _sow_hint_crop: Plot.Crop = Plot.Crop.NONE

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _girl: Girl = $World/Girl
@onready var _bunny: FieldBunny = $World/Bushes/Bunny
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _tools: FieldTools = $FieldTools
@onready var _hints: HintDirector = $HintDirector


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_plots.assign($World/Plots.get_children())
	_restore_plots()
	_hints.provider = _current_hint
	_hints.shown.connect(_on_hint_shown)
	for plot: Plot in _plots:
		plot.tilled.connect(_hints.learned.bind(HINT_TILL))
		plot.sown.connect(_hints.learned.bind(HINT_SOW))
		plot.watered.connect(_hints.learned.bind(HINT_WATER))
		plot.harvested.connect(_on_harvested)
		plot.tilled.connect(SaveGame.request_save)
		plot.sown.connect(SaveGame.request_save)
		plot.ripened.connect(SaveGame.request_save)
		plot.tilled.connect(_girl.cheer)
		plot.sown.connect(_girl.cheer)
		plot.ripened.connect(_girl.wave.bind(GIRL_FIELD_ARM))
	_bunny.peeked.connect(_girl.surprise)
	_bunny.fed.connect(_girl.cheer)
	_basket.tapped.connect(_basket_menu.open)
	SaveGame.before_save.connect(_store_plots)


func _process(delta: float) -> void:
	_idle_time += delta
	if _idle_time >= idle_yawn_time:
		_idle_time = 0.0 if _girl.yawn() else idle_yawn_time - YAWN_RETRY_TIME


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_idle_time = 0.0


func _exit_tree() -> void:
	_store_plots()
	SaveGame.save_now()


func _on_harvested(crop: Plot.Crop, global_point: Vector2) -> void:
	var item: StringName = CROP_ITEMS[crop]
	Basket.add(item)
	_basket.receive(item, global_point)
	_girl.cheer()
	if HARVEST_HINTS.has(crop):
		_hints.learned(HARVEST_HINTS[crop])


## El göstergesi için o an yapılabilecek ilk iş (bkz. HintDirector.provider).
func _current_hint() -> Dictionary:
	if _basket_menu.is_open:
		return {}
	for plot: Plot in _plots:
		var hint: Dictionary = _harvest_hint(plot)
		if not hint.is_empty():
			return hint
	for plot: Plot in _plots:
		if plot.needs_water():
			return _tool_hint(HINT_WATER, FieldTools.Tool.BUCKET, [_to_screen(plot.global_position)], HINT_WATER_HOLD)
	for plot: Plot in _plots:
		if plot.state == Plot.State.TILLED:
			_sow_hint_crop = _next_sow_crop() if plot.crop == Plot.Crop.NONE else Plot.Crop.NONE
			var seed_crop: Plot.Crop = plot.crop if plot.crop != Plot.Crop.NONE else _sow_hint_crop
			# Torba her çukurda kısa bir an bekler (FieldTools.sow_arm_time); aynı nokta iki kez bekleme demek.
			var points: Array[Vector2] = []
			for point: Vector2 in plot.sow_hint_points(seed_crop):
				points.append(_to_screen(point))
				points.append(_to_screen(point))
			var hint: Dictionary = _tool_hint(HINT_SOW, SEED_TOOLS[seed_crop], points)
			if not hint.is_empty():
				return hint
	for plot: Plot in _plots:
		if plot.can_till():
			var center: Vector2 = _to_screen(plot.global_position)
			var left: Vector2 = center - Vector2(HINT_RUB, 0.0)
			var right: Vector2 = center + Vector2(HINT_RUB, 0.0)
			return _tool_hint(HINT_TILL, FieldTools.Tool.HOE, [center, left, right, left, right])
	return {}


## Boş parsele gösterilecek sıradaki tohum: sıradan başlayıp rafta olan ilk torba.
func _next_sow_crop() -> Plot.Crop:
	for i: int in SOW_HINT_ORDER.size():
		var crop: Plot.Crop = SOW_HINT_ORDER[(_sow_hint_turn + i) % SOW_HINT_ORDER.size()]
		if _tools.slot_center(SEED_TOOLS[crop]) != Vector2.INF:
			return crop
	return Plot.Crop.CARROT


## Boş parsele ekim gösterildiyse bir dahakine sıradaki torba gösterilir.
func _on_hint_shown(id: StringName) -> void:
	if id == HINT_SOW and _sow_hint_crop != Plot.Crop.NONE:
		_sow_hint_turn = (SOW_HINT_ORDER.find(_sow_hint_crop) + 1) % SOW_HINT_ORDER.size()


func _harvest_hint(plot: Plot) -> Dictionary:
	var start: Vector2 = plot.harvest_hint_point()
	if start == Vector2.INF:
		return {}
	var point: Vector2 = _to_screen(start)
	match plot.crop:
		Plot.Crop.CARROT:
			return {"id": HINT_PULL_CARROT, "points": PackedVector2Array([point, point - Vector2(0.0, HINT_PULL)])}
		Plot.Crop.PUMPKIN:
			return {"id": HINT_ROLL_PUMPKIN, "points": PackedVector2Array([point, point + Vector2(HINT_ROLL, 0.0)])}
		Plot.Crop.WHEAT:
			var reach: Vector2 = Vector2(Plot.HINT_SWEEP * plot.global_scale.x, 0.0)
			return _tool_hint(HINT_REAP, FieldTools.Tool.SICKLE, [point - reach, point + reach, point - reach])
	return {}


## Raftan aracı alıp noktalara götüren el; araç rafta yoksa boş. Noktalar aracın ucunun varacağı yerler
## (parmağın ne kadar aşağıdan geçeceğini HintDirector hesaplar).
func _tool_hint(id: StringName, tool: FieldTools.Tool, points: Array[Vector2], hold: float = HintHand.DEFAULT_HOLD) -> Dictionary:
	var slot: Vector2 = _tools.slot_center(tool)
	if slot == Vector2.INF:
		return {}
	var path: PackedVector2Array = [slot]
	path.append_array(PackedVector2Array(points))
	return {"id": id, "points": path, "hold": hold, "carry": _tools.slot_icon(tool)}


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point


func _store_plots() -> void:
	var plots: Array = _plots.map(func(plot: Plot) -> Dictionary: return plot.save_state())
	SaveGame.set_section(SECTION, {"saved_at": SaveGame.play_time, "plots": plots})


func _restore_plots() -> void:
	var data: Dictionary = SaveGame.get_section(SECTION)
	var saved: Variant = data.get("plots")
	if not saved is Array or (saved as Array).size() != _plots.size():
		return
	var elapsed: float = maxf(SaveGame.play_time - float(data.get("saved_at", SaveGame.play_time)), 0.0)
	for i: int in _plots.size():
		var plot_data: Variant = (saved as Array)[i]
		if plot_data is Dictionary:
			_plots[i].load_state(plot_data, elapsed)
