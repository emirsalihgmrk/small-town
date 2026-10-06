extends Node2D
## Tarla bölümü: eve dönüş, hasadın ortak sepete girmesi ve parsellerin kaydı.
## Parseller açılışta kayıttan geri yüklenir; sahne kapalıyken geçen oyun süresi kadar büyüme ileri
## sarılır. Parselde bir aşama bittiğinde, sahneden çıkarken ve SaveGame diske yazmadan hemen önce
## parsellerin durumu kayda geçer.

const SECTION: String = "field"
const CROP_ITEMS: Dictionary = {
	Plot.Crop.CARROT: Items.CARROT,
	Plot.Crop.WHEAT: Items.WHEAT,
}

var _plots: Array[Plot] = []

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket


func _ready() -> void:
	_home_button.pressed.connect(SceneRouter.go_home)
	_plots.assign($World/Plots.get_children())
	_restore_plots()
	for plot: Plot in _plots:
		plot.harvested.connect(_on_harvested)
		plot.tilled.connect(SaveGame.request_save)
		plot.sown.connect(SaveGame.request_save)
		plot.ripened.connect(SaveGame.request_save)
	SaveGame.before_save.connect(_store_plots)


func _exit_tree() -> void:
	_store_plots()
	SaveGame.save_now()


func _on_harvested(crop: Plot.Crop, global_point: Vector2) -> void:
	var item: StringName = CROP_ITEMS[crop]
	Basket.add(item)
	_basket.receive(item, global_point)


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
