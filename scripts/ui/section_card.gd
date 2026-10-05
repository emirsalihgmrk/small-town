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

@export var section_id: StringName
@export var title: String
@export var icon_texture: Texture2D
@export var card_color: Color = Color.WHITE

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title


func _ready() -> void:
	_icon.texture = icon_texture
	_title.text = title
	add_theme_stylebox_override(&"normal", _make_style(card_color))
	add_theme_stylebox_override(&"hover", _make_style(card_color.lightened(HOVER_LIGHTEN)))
	add_theme_stylebox_override(&"pressed", _make_style(card_color.darkened(PRESSED_DARKEN)))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	pressed.connect(func() -> void: section_selected.emit(section_id))


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
