extends CanvasLayer
## GEÇİCİ geliştirici paneli (autoload: DebugPanel). Sepetteki ürünleri, parayı, dükkândan alınanları ve
## kızın taktığı aksesuarı elle değiştirmeye yarar. Sağ üst köşedeki küçük düğmeyle ya da F1 ile açılır.
## Değerler hemen kayda geçer; panel kapanınca sahne yeniden yüklenir ki her şey yeni değerlerle görünsün.
## Silmek için: bu dosyayı (ve .uid'ini) sil, project.godot'taki [autoload] altından DebugPanel satırını kaldır.

const BASKET_ITEMS: Array[StringName] = [
	Items.CARROT, Items.WHEAT, Items.EGG, Items.MILK,
	Items.BREAD, Items.COOKIE, Items.CARROT_CAKE, Items.BIRTHDAY_CAKE,
]
const FONT_SIZE: int = 28
const MAX_COUNT: int = 999

var _toggle: Button
var _dim: ColorRect
var _basket_boxes: Dictionary[StringName, SpinBox] = {}
var _coins_box: SpinBox
var _owned_boxes: Dictionary[StringName, CheckBox] = {}
var _worn_option: OptionButton
## Doldururken değer değişim sinyalleri yok sayılır.
var _refreshing: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	var root: Control = Control.new()
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	root.add_child(_dim)
	_dim.add_child(_build_panel())

	_toggle = Button.new()
	_toggle.text = "DEBUG"
	_toggle.modulate.a = 0.45
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.position = Vector2(1920 - 150, 16)
	_toggle.size = Vector2(130, 56)
	_toggle.pressed.connect(_set_open.bind(true))
	root.add_child(_toggle)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		_set_open(not _dim.visible)
		get_viewport().set_input_as_handled()
		return
	# Fareden taklit edilen dokunuşlar oyuna geçmesin (panel açıkken ya da düğmeye basılınca).
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	var point: Vector2 = touch.position if touch != null else (drag.position if drag != null else Vector2.INF)
	if point == Vector2.INF:
		return
	if _dim.visible or _toggle.get_global_rect().has_point(point):
		get_viewport().set_input_as_handled()


func _build_panel() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 20)
	outer.add_child(columns)
	margin.add_child(outer)

	var basket_grid: GridContainer = _section(columns, "Sepet")
	for item: StringName in BASKET_ITEMS:
		_basket_boxes[item] = _spin_row(basket_grid, String(item), _on_basket_changed.bind(item))

	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	columns.add_child(right)
	var coins_grid: GridContainer = _section(right, "Para")
	_coins_box = _spin_row(coins_grid, "coins", _on_coins_changed)

	var shop_grid: GridContainer = _section(right, "Dükkândan alınanlar")
	for item: StringName in ShopItems.PRICES:
		var box: CheckBox = CheckBox.new()
		box.text = String(item)
		box.toggled.connect(_on_owned_toggled.bind(item))
		shop_grid.add_child(box)
		_owned_boxes[item] = box

	var worn_grid: GridContainer = _section(right, "Takılı aksesuar")
	_worn_option = OptionButton.new()
	_worn_option.add_item("hasır şapka")
	for item: StringName in ShopItems.ACCESSORIES:
		_worn_option.add_item(String(item))
	_worn_option.item_selected.connect(_on_worn_selected)
	worn_grid.add_child(_worn_option)

	var close: Button = Button.new()
	close.text = "Kapat (sahneyi yenile)"
	close.pressed.connect(_set_open.bind(false))
	outer.add_child(close)
	return panel


func _section(parent: Control, title: String) -> GridContainer:
	var box: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", FONT_SIZE + 6)
	box.add_child(label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	parent.add_child(box)
	return grid


func _spin_row(grid: GridContainer, title: String, on_changed: Callable) -> SpinBox:
	var label: Label = Label.new()
	label.text = title
	grid.add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.max_value = MAX_COUNT
	spin.custom_minimum_size.x = 180
	spin.value_changed.connect(func(value: float) -> void: on_changed.call(int(value)))
	grid.add_child(spin)
	return spin


func _set_open(open: bool) -> void:
	if open == _dim.visible:
		return
	if open:
		_refresh()
		_dim.show()
		_toggle.hide()
	else:
		_dim.hide()
		_toggle.show()
		get_tree().reload_current_scene()


func _refresh() -> void:
	_refreshing = true
	for item: StringName in _basket_boxes:
		_basket_boxes[item].value = Basket.count(item)
	_coins_box.value = Wallet.count()
	for item: StringName in _owned_boxes:
		_owned_boxes[item].button_pressed = Owned.has(item)
	_worn_option.selected = ShopItems.ACCESSORIES.find(Owned.worn()) + 1
	_refreshing = false


func _on_basket_changed(value: int, item: StringName) -> void:
	if _refreshing:
		return
	var delta: int = value - Basket.count(item)
	if delta > 0:
		Basket.add(item, delta)
	elif delta < 0:
		Basket.take(item, -delta)


func _on_coins_changed(value: int) -> void:
	if _refreshing:
		return
	var delta: int = value - Wallet.count()
	if delta > 0:
		Wallet.add(delta)
	elif delta < 0:
		Wallet.take(-delta)


## Owned'ın satın alma dışında yolu yok; bu geçici panel iç durumunu doğrudan değiştirir.
func _on_owned_toggled(on: bool, item: StringName) -> void:
	if _refreshing:
		return
	Owned._paid.erase(item)
	if on and not Owned.has(item):
		Owned._owned.append(item)
	elif not on:
		Owned._owned.erase(item)
		if Owned.worn() == item:
			Owned._worn = &""
	Owned._store()
	_refresh()


func _on_worn_selected(index: int) -> void:
	if _refreshing:
		return
	var item: StringName = &"" if index == 0 else ShopItems.ACCESSORIES[index - 1]
	if item != &"" and not Owned.has(item):
		Owned._owned.append(item)
	Owned._worn = item
	Owned._store()
	_refresh()
