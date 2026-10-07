class_name MixingBowl
extends Node2D
## Fırındaki karıştırma kasesi. Bir tarif seçilince (set_recipe) kasede o tarifin her malzemesi için bir
## yuva açılır; sepetten getirilen malzeme konunca (add) yuva dolar ve kasede görünür: buğday un yığını
## olur (her demetle büyür, un tozu kalkar), yumurtanın sarısı, havucun rendesi çıkar. Bütün yuvalar
## dolunca completed yayılır.
## Tarif seçiliyken ortak sepette eksik bir malzeme varsa kasenin yanında bir düşünce balonu durur ve
## o malzemenin nereden geldiğini gösterir (tarla ya da kümes). Balona dokununca bubble_tapped o bölümle
## yayılır. Kök noktası kasenin dibidir.

signal slot_filled(index: int)
signal completed
signal bubble_tapped(section_id: StringName)

## Malzemenin toplandığı bölüm (balonda gösterilir, balona dokununca oraya gidilir).
const SOURCE_SECTIONS: Dictionary[StringName, StringName] = {
	Items.WHEAT: &"field",
	Items.CARROT: &"field",
	Items.EGG: &"coop",
}
const HIGHLIGHT_SCALE: Vector2 = Vector2(1.06, 1.06)
const HIGHLIGHT_TIME: float = 0.12
## Malzeme kasenin üstünde dökülmeye başladıktan sonra kasede görünür.
const CONTENT_DELAY: float = 0.2
const CONTENT_POP_TIME: float = 0.35
## Tek demetlik un yığını tam yığının bu oranında başlar (yükseklikte), demet geldikçe tamamlanır.
const FLOUR_MIN_HEIGHT: float = 0.45
const FLOUR_MIN_WIDTH: float = 0.8
const ADD_TIME: float = 0.55
const SQUASH: Vector2 = Vector2(1.06, 0.94)
const SQUASH_TIME: float = 0.08
const SETTLE_TIME: float = 0.4
const BUBBLE_POP_TIME: float = 0.25
const BUBBLE_BOB: float = 8.0
const BUBBLE_BOB_PERIOD: float = 1.8
const NUDGE_SCALE: float = 1.25
const NUDGE_TIME: float = 0.12
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Malzemenin bırakılınca kaseye sayıldığı alan (kök noktasına göre); küçük parmaklar için cömert.
@export var drop_area: Rect2 = Rect2(-170.0, -230.0, 340.0, 270.0)
@export var sparkle_scene: PackedScene
## Malzeme kaseye dökülürken çalan ses (Items kimliği -> ses dosyası).
@export var add_sound_paths: Dictionary[StringName, String] = {
	Items.WHEAT: "res://assets/audio/sfx/seed_sprinkle.ogg",
	Items.EGG: "res://assets/audio/sfx/egg_pick.ogg",
	Items.CARROT: "res://assets/audio/sfx/seed_plop.ogg",
}

## Seçili tarif; seçilmemişse boş.
var recipe: StringName = &""

var _items: Array[StringName] = []
var _filled: Array[bool] = []
var _add_sounds: Dictionary[StringName, AudioStream] = {}
var _highlighted: bool = false
var _highlight_tween: Tween
var _bubble_tween: Tween
var _bubble_shown: bool = false
var _bubble_scale: Vector2
var _flour_scale: Vector2

@onready var _body: Node2D = $Body
@onready var _flour: Sprite2D = $Body/Contents/Flour
@onready var _yolk: Sprite2D = $Body/Contents/Yolk
@onready var _carrot: Sprite2D = $Body/Contents/Carrot
@onready var _puff: CPUParticles2D = $Puff
@onready var _bubble: Node2D = $Bubble
@onready var _bubble_field: Node2D = $Bubble/Field
@onready var _bubble_coop: Node2D = $Bubble/Coop
@onready var _bubble_tap: Tappable = $Bubble/TapArea


func _ready() -> void:
	for item: StringName in add_sound_paths:
		if ResourceLoader.exists(add_sound_paths[item]):
			_add_sounds[item] = load(add_sound_paths[item]) as AudioStream
	_flour_scale = _flour.scale
	_flour.hide()
	_yolk.hide()
	_carrot.hide()
	_bubble_scale = _bubble.scale
	_bubble.hide()
	_bubble_tap.enabled = false
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)
	_bubble_tap.tapped.connect(_on_bubble_tapped)
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh_bubble())


func contains(global_point: Vector2) -> bool:
	return drop_area.has_point(to_local(global_point))


func has_recipe() -> bool:
	return not recipe.is_empty()


## Kaseye henüz hiç malzeme konmadı (tarif değiştirilebilir).
func is_empty() -> bool:
	return not _filled.has(true)


func is_complete() -> bool:
	return has_recipe() and not _filled.has(false)


## Kasede henüz malzeme yoksa tarifi değiştirir; malzeme varsa hiçbir şey yapmaz.
func set_recipe(recipe_id: StringName) -> void:
	if not is_empty():
		return
	recipe = recipe_id
	_items = Recipes.ingredients(recipe_id)
	_filled.resize(_items.size())
	_filled.fill(false)
	_refresh_bubble()


## Boş yuvalar, tarifteki sırayla.
func open_slots() -> Array[int]:
	var slots: Array[int] = []
	for i: int in _filled.size():
		if not _filled[i]:
			slots.append(i)
	return slots


func ingredient(slot: int) -> StringName:
	return _items[slot]


## Kasedeki malzemeler.
func contents() -> Array[StringName]:
	var items: Array[StringName] = []
	for i: int in _filled.size():
		if _filled[i]:
			items.append(_items[i])
	return items


## Parmaktaki malzeme kasenin üstündeyken kase hafifçe büyür.
func set_highlighted(highlighted: bool) -> void:
	if highlighted == _highlighted:
		return
	_highlighted = highlighted
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_body, ^"scale", HIGHLIGHT_SCALE if highlighted else Vector2.ONE, HIGHLIGHT_TIME)


## Yuva hemen dolu sayılır; malzeme kısa bir dökülmeyle kasede görünür olur.
func add(slot: int) -> void:
	if slot < 0 or slot >= _filled.size() or _filled[slot]:
		return
	_filled[slot] = true
	var item: StringName = _items[slot]
	set_highlighted(false)
	_refresh_bubble()
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_add_sounds.get(item), AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.05), pan)
	slot_filled.emit(slot)
	var tween: Tween = create_tween()
	tween.tween_interval(CONTENT_DELAY)
	tween.tween_callback(_show_content.bind(item))
	tween.tween_interval(maxf(ADD_TIME - CONTENT_DELAY, 0.0))
	tween.tween_callback(_on_added)


## Balon görünürken dikkat çekmek için bir kez zıplar (sepette eksik malzeme çekilmeye çalışılınca).
func nudge_bubble() -> void:
	if not _bubble_shown or (_bubble_tween != null and _bubble_tween.is_running()):
		return
	_bubble_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale * NUDGE_SCALE, NUDGE_TIME)
	_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, NUDGE_TIME * 2.0)


func _show_content(item: StringName) -> void:
	match item:
		Items.WHEAT:
			_puff.restart()
			var wheat_total: int = _items.count(Items.WHEAT)
			var ratio: float = float(contents().count(Items.WHEAT)) / maxi(wheat_total, 1)
			var target: Vector2 = _flour_scale * Vector2(lerpf(FLOUR_MIN_WIDTH, 1.0, ratio),
					lerpf(FLOUR_MIN_HEIGHT, 1.0, ratio))
			if not _flour.visible:
				_flour.scale = Vector2(target.x, 0.0)
				_flour.show()
			_pop(_flour, target)
		Items.EGG:
			_yolk.scale = Vector2.ZERO
			_yolk.show()
			_pop(_yolk, Vector2.ONE)
		Items.CARROT:
			_carrot.scale = Vector2.ZERO
			_carrot.show()
			_pop(_carrot, Vector2.ONE)


func _pop(sprite: Sprite2D, to_scale: Vector2) -> void:
	create_tween().tween_property(sprite, ^"scale", to_scale, CONTENT_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_added() -> void:
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = $Body/Contents.position
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", SQUASH, SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_complete():
		completed.emit()


## Boş yuvalar için ortak sepette yetmeyen ilk malzeme; hepsi varsa boş.
func _missing_item() -> StringName:
	var needed: Dictionary[StringName, int] = {}
	for slot: int in open_slots():
		var item: StringName = _items[slot]
		needed[item] = needed.get(item, 0) + 1
		if Basket.count(item) < needed[item]:
			return item
	return &""


func _refresh_bubble() -> void:
	var missing: StringName = _missing_item() if has_recipe() else &""
	var section: StringName = SOURCE_SECTIONS.get(missing, &"")
	if not section.is_empty():
		_bubble_field.visible = section == &"field"
		_bubble_coop.visible = section == &"coop"
	var shown: bool = not section.is_empty()
	_bubble_tap.enabled = shown
	if shown == _bubble_shown:
		return
	_bubble_shown = shown
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	if shown:
		_bubble.scale = Vector2.ZERO
		_bubble.show()
		_bubble_tween.tween_property(_bubble, ^"scale", _bubble_scale, BUBBLE_POP_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_bubble_tween.tween_property(_bubble, ^"scale", Vector2.ZERO, BUBBLE_POP_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_bubble_tween.tween_callback(_bubble.hide)


func _on_bubble_tapped(_point: Vector2) -> void:
	var section: StringName = SOURCE_SECTIONS.get(_missing_item(), &"")
	if not section.is_empty():
		bubble_tapped.emit(section)
