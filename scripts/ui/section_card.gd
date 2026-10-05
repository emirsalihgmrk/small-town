class_name SectionCard
extends Button
## Ana ekrandaki bir bölüm kartı (Tarla, Ahır...).
## Bölümler henüz yok; kart basılınca sadece section_selected sinyali yayar.

signal section_selected(section_id: StringName)

const CORNER_RADIUS: int = 40
const BORDER_WIDTH: int = 8
const BORDER_COLOR: Color = Color.WHITE
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.22)
const SHADOW_SIZE: int = 8
const SHADOW_OFFSET: Vector2 = Vector2(0, 6)
const HOVER_LIGHTEN: float = 0.12
const PRESSED_DARKEN: float = 0.1
## İkon sahneleri 200x200'lük bir tasarım alanında, merkezi kökte olacak şekilde çizilir.
const ICON_DESIGN_SIZE: float = 200.0

@export var section_id: StringName
@export var title: String
## Parçalı ikon sahnesi (kökü Node2D); kartın ikon alanına sığdırılır.
@export var icon_scene: PackedScene
@export var card_color: Color = Color.WHITE

@onready var _icon_holder: Control = %IconHolder
@onready var _title: Label = %Title


func _ready() -> void:
	_add_icon()
	_title.text = title
	add_theme_stylebox_override(&"normal", _make_style(card_color))
	add_theme_stylebox_override(&"hover", _make_style(card_color.lightened(HOVER_LIGHTEN)))
	add_theme_stylebox_override(&"pressed", _make_style(card_color.darkened(PRESSED_DARKEN)))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	pressed.connect(func() -> void: section_selected.emit(section_id))


func _add_icon() -> void:
	if icon_scene == null:
		return
	var icon: Node2D = icon_scene.instantiate() as Node2D
	_icon_holder.add_child(icon)
	_icon_holder.resized.connect(_fit_icon.bind(icon))
	_fit_icon(icon)


func _fit_icon(icon: Node2D) -> void:
	var holder_size: Vector2 = _icon_holder.size
	var fit: float = minf(holder_size.x, holder_size.y) / ICON_DESIGN_SIZE
	icon.position = holder_size * 0.5
	icon.scale = Vector2(fit, fit)


func _make_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BORDER_COLOR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = SHADOW_SIZE
	style.shadow_offset = SHADOW_OFFSET
	return style
