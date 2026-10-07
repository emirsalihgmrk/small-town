extends Node2D
## Tarla bölümü: eve dönüş, hasadın ortak sepete girmesi, parsellerin kaydı ve kızın tepkileri.
## Parseller açılışta kayıttan geri yüklenir; sahne kapalıyken geçen oyun süresi kadar büyüme ileri
## sarılır. Parselde bir aşama bittiğinde, sahneden çıkarken ve SaveGame diske yazmadan hemen önce
## parsellerin durumu kayda geçer.
## Kız; parsel sürülünce, ekilince, ürün çıkınca ve tavşan havucu yiyince sevinir; bir parsel hazır
## olunca tarlaya el sallar; tavşan görününce şaşırır; uzun süre dokunulmazsa esner.
## Sepete dokununca sepetin içini gösteren menü açılır.

const SECTION: String = "field"
const CROP_ITEMS: Dictionary = {
	Plot.Crop.CARROT: Items.CARROT,
	Plot.Crop.WHEAT: Items.WHEAT,
}
## Kızın tarlaya (sağa) bakan kolu.
const GIRL_FIELD_ARM: int = 1
## Esneme zamanı geldiğinde kız başka bir hareketteyse bu kadar sonra yeniden denenir.
const YAWN_RETRY_TIME: float = 2.0

## Bu kadar süre hiç dokunulmazsa kız esner (sonra yine aynı süre beklenir).
@export_range(5.0, 120.0, 1.0, "suffix:s") var idle_yawn_time: float = 25.0

var _plots: Array[Plot] = []
var _idle_time: float = 0.0

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _girl: Girl = $World/Girl
@onready var _bunny: FieldBunny = $World/Bushes/Bunny
@onready var _basket_menu: BasketMenu = $BasketMenu


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_plots.assign($World/Plots.get_children())
	_restore_plots()
	for plot: Plot in _plots:
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
