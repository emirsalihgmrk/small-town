class_name RecipeCard
extends Node2D
## Tarif panosundaki resimli kart: üstte pişecek ürün, altta malzemeleri. Kaseye konmamış malzeme soluk
## durur, konunca renklenip zıplar. Seçilen kartın çevresi parlar, kart biraz büyür ve kâğıt sesi çıkar;
## kasede başka bir tarifin malzemesi varken kart kilitlenir (soluklaşır). Dokununca tapped yayılır.
## Malzeme simgeleri Ingredients altında, Recipes'teki sırayla çoğaltılır.

signal tapped

const SELECTED_SCALE: Vector2 = Vector2(1.08, 1.08)
const SELECT_TIME: float = 0.2
const LOCKED_ALPHA: float = 0.45
const LOCK_TIME: float = 0.2
const EMPTY_SLOT_ALPHA: float = 0.3
const SLOT_POP_SCALE: float = 1.35
const SLOT_POP_TIME: float = 0.12
const SLOT_SETTLE_TIME: float = 0.3
## Malzeme simgeleri bu yüksekliğe sığdırılır ve aralarında bu kadar mesafe olur.
const INGREDIENT_HEIGHT: float = 46.0
const INGREDIENT_SPACING: float = 50.0
## Ürün resmi bu kutuya sığdırılır.
const PRODUCT_SIZE: Vector2 = Vector2(130.0, 112.0)
const NUDGE_DEGREES: float = 6.0
const NUDGE_TIME: float = 0.07
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

@export var recipe: StringName
@export var product_texture: Texture2D
## Malzeme simgeleri (Items kimliği -> resmi).
@export var ingredient_textures: Dictionary[StringName, Texture2D] = {}
@export_file("*.ogg", "*.wav") var select_sound_path: String = "res://assets/audio/sfx/card_flip.ogg"

var _slots: Array[Sprite2D] = []
var _select_sound: AudioStream
var _selected: bool = false
var _select_tween: Tween
var _lock_tween: Tween
var _nudge_tween: Tween

@onready var _body: Node2D = $Body
@onready var _glow: Sprite2D = $Body/Glow
@onready var _product: Sprite2D = $Body/Product
@onready var _ingredients: Node2D = $Body/Ingredients
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_glow.hide()
	if ResourceLoader.exists(select_sound_path):
		_select_sound = load(select_sound_path) as AudioStream
	_product.texture = product_texture
	if product_texture != null:
		var size: Vector2 = product_texture.get_size()
		_product.scale = Vector2.ONE * minf(PRODUCT_SIZE.x / size.x, PRODUCT_SIZE.y / size.y)
	var items: Array[StringName] = Recipes.ingredients(recipe)
	var x: float = -INGREDIENT_SPACING * (items.size() - 1) * 0.5
	for item: StringName in items:
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = ingredient_textures.get(item)
		if icon.texture != null:
			icon.scale = Vector2.ONE * (INGREDIENT_HEIGHT / icon.texture.get_height())
		icon.position.x = x
		_ingredients.add_child(icon)
		_slots.append(icon)
		x += INGREDIENT_SPACING
	clear_slots()
	_tap_area.tapped.connect(func(_point: Vector2) -> void: tapped.emit())


## animate değilse (kayıttan kurulurken) ses çalmaz.
func set_selected(selected: bool, animate: bool = true) -> void:
	if selected == _selected:
		return
	_selected = selected
	if selected and animate:
		var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
		AudioManager.play_sfx(_select_sound, AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.05), pan)
	_glow.visible = selected
	if _select_tween != null:
		_select_tween.kill()
	_select_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_select_tween.tween_property(_body, ^"scale", SELECTED_SCALE if selected else Vector2.ONE, SELECT_TIME)


func set_locked(locked: bool) -> void:
	if _lock_tween != null:
		_lock_tween.kill()
	_lock_tween = create_tween()
	_lock_tween.tween_property(self, ^"modulate:a", LOCKED_ALPHA if locked else 1.0, LOCK_TIME)


## index. malzeme kasaya kondu: simge renklenir (animate ise zıplar).
func fill_slot(index: int, animate: bool = true) -> void:
	var icon: Sprite2D = _slots[index]
	icon.modulate.a = 1.0
	if not animate:
		return
	var rest: Vector2 = Vector2.ONE * (INGREDIENT_HEIGHT / icon.texture.get_height())
	var tween: Tween = create_tween()
	tween.tween_property(icon, ^"scale", rest * SLOT_POP_SCALE, SLOT_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, ^"scale", rest, SLOT_SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func clear_slots() -> void:
	for icon: Sprite2D in _slots:
		icon.modulate.a = EMPTY_SLOT_ALPHA


## Dikkat çekmek için bir kez sağa sola sallanır (tarif seçilmeden sepetten malzeme çekilmeye çalışılınca).
func nudge() -> void:
	if _nudge_tween != null and _nudge_tween.is_running():
		return
	_nudge_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0, 1.0, -1.0]:
		_nudge_tween.tween_property(_body, ^"rotation", deg_to_rad(NUDGE_DEGREES * side), NUDGE_TIME)
	_nudge_tween.tween_property(_body, ^"rotation", 0.0, NUDGE_TIME)
