class_name BasketMenu
extends CanvasLayer
## Ortak sepetin (Basket) içini gösteren menü. Her ürün kendi kutusunda, büyük resmi ve altında
## sayısıyla durur; sepette olmayan ürün soluk görünür, sayısı 0'dır. Menü açıkken sepet değişirse
## sayılar hemen güncellenir.
## Açılınca arkadaki her şey kararır ve dokunuşları yutar: menü açıkken tarlada iş yapılmaz.
## Çarpıya ya da karartılmış arka plana dokununca kapanır.
## Kutular, sahnedeki gizli şablon kutudan (Template) item_icons sırasıyla çoğaltılır. Kutunun
## kendisini sıra (Items) yerleştirir; büyüyerek belirme, konteynerin ölçeğe dokunmadığı iç düğümde
## (Content) oynar.

const DIM_ALPHA: float = 0.4
const FADE_TIME: float = 0.2
const POP_START_SCALE: float = 0.6
const POP_TIME: float = 0.35
const CELL_POP_DELAY: float = 0.08
const CELL_POP_TIME: float = 0.3
const CLOSE_SCALE: float = 0.85
const CLOSE_TIME: float = 0.15
const EMPTY_ALPHA: float = 0.3

## Menüde gösterilecek ürünler (Items kimliği -> resmi), soldan sağa bu sırayla.
@export var item_icons: Dictionary[StringName, Texture2D] = {}

var is_open: bool = false

var _cells: Dictionary[StringName, Control] = {}
var _tween: Tween

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _panel: Control = $Root/Panel
@onready var _items: Container = %Items
@onready var _template: Control = %Template
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_root.hide()
	_template.hide()
	for item: StringName in item_icons:
		var cell: Control = _template.duplicate() as Control
		cell.name = String(item).capitalize()
		(cell.get_node(^"Content/Slot/Icon") as TextureRect).texture = item_icons[item]
		_items.add_child(cell)
		cell.show()
		_cells[item] = cell.get_node(^"Content") as Control
	_keep_pivot_centered(_panel)
	for content: Control in _cells.values():
		_keep_pivot_centered(content)
	_dim.gui_input.connect(_on_dim_input)
	_close_button.pressed.connect(close)
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh())


func open() -> void:
	if is_open:
		return
	is_open = true
	_refresh()
	_root.show()
	_panel.scale = Vector2.ONE * POP_START_SCALE
	_panel.modulate.a = 0.0
	_dim.color.a = 0.0
	_restart_tween()
	_tween.tween_property(_dim, ^"color:a", DIM_ALPHA, FADE_TIME)
	_tween.tween_property(_panel, ^"modulate:a", 1.0, FADE_TIME)
	_tween.tween_property(_panel, ^"scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay: float = FADE_TIME
	for content: Control in _cells.values():
		content.scale = Vector2.ZERO
		_tween.tween_property(content, ^"scale", Vector2.ONE, CELL_POP_TIME).from(Vector2.ZERO).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += CELL_POP_DELAY


func close() -> void:
	if not is_open:
		return
	is_open = false
	_restart_tween()
	_tween.tween_property(_dim, ^"color:a", 0.0, CLOSE_TIME)
	_tween.tween_property(_panel, ^"modulate:a", 0.0, CLOSE_TIME)
	_tween.tween_property(_panel, ^"scale", Vector2.ONE * CLOSE_SCALE, CLOSE_TIME).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_root.hide)


func _keep_pivot_centered(control: Control) -> void:
	control.resized.connect(func() -> void: control.pivot_offset = control.size * 0.5)
	control.pivot_offset = control.size * 0.5


func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()


func _on_dim_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.pressed:
		close()


func _refresh() -> void:
	for item: StringName in _cells:
		var content: Control = _cells[item]
		var amount: int = Basket.count(item)
		(content.get_node(^"Count") as Label).text = str(amount)
		(content.get_node(^"Slot/Icon") as CanvasItem).modulate.a = 1.0 if amount > 0 else EMPTY_ALPHA
