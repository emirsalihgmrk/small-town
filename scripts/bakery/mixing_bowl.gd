class_name MixingBowl
extends Node2D
## Fırındaki karıştırma kasesi. Bir tarif seçilince (set_recipe) kasede o tarifin her malzemesi için bir
## yuva açılır; sepetten getirilen malzeme konunca (add) yuva dolar ve kasede görünür: buğday un yığını
## olur (her demetle büyür, un tozu kalkar), yumurtanın sarısı, havucun rendesi çıkar. Bütün yuvalar
## dolunca completed yayılır.
## Kase dolunca içinde tahta bir kaşık belirir ve karıştırılmayı beklerken hafifçe sallanır. Kaşık parmağı
## kasenin içinde izler (move_spoon). Karıştırdıkça (stir) malzemeler soluklaşıp sallanır, yerlerinde
## tarifin hamuru büyür; yeterince karıştırılınca kaşık kaybolur, hamur zıplar ve mixed yayılır.
## Tarif seçiliyken ortak sepette eksik bir malzeme varsa kasenin yanında bir düşünce balonu durur ve
## o malzemenin nereden geldiğini gösterir (tarla ya da kümes). Balona dokununca bubble_tapped o bölümle
## yayılır. Kök noktası kasenin dibidir.

signal slot_filled(index: int)
signal completed
signal mixed
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
## Kaşığın dinlenirken durduğu yer ve eğimi (kasenin iç ağzının ortasına göre).
const SPOON_REST: Vector2 = Vector2(26.0, -6.0)
const SPOON_REST_DEGREES: float = 14.0
## Kaşığın alt ucu bu elipsin içinde kalır; kenara gittikçe dışa doğru bu kadar eğilir.
const SPOON_RANGE: Vector2 = Vector2(62.0, 9.0)
const SPOON_LEAN_DEGREES: float = 22.0
const SPOON_FOLLOW_SHARPNESS: float = 20.0
const SPOON_POP_TIME: float = 0.3
## Karıştırılmayı beklerken kaşık bu kadar sağa sola sallanır.
const SPOON_HINT_DEGREES: float = 8.0
const SPOON_HINT_PERIOD: float = 1.2
const DOUGH_START_SCALE: float = 0.5
## Karıştırırken içindekiler bu kadar sallanır; parmak durunca sallantı bu hızla söner.
const STIR_WOBBLE_DEGREES: float = 3.0
const STIR_WOBBLE_SPEED: float = 18.0
const STIR_ENERGY_DECAY: float = 4.0
const MIXED_POP_SCALE: float = 1.12
const MIXED_POP_TIME: float = 0.12
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
## Hamur olana kadar kaşığın kasede gezmesi gereken toplam yol.
@export_range(200.0, 10000.0, 50.0, "suffix:px") var mix_distance: float = 1600.0
## Kaşığı kaydırmadan kaseye bir dokunuş bu kadar yol sayılır.
@export_range(0.0, 2000.0, 10.0, "suffix:px") var tap_stir_distance: float = 200.0
## Tarifin hamuru (Recipes kimliği -> resmi).
@export var dough_textures: Dictionary[StringName, Texture2D] = {}
@export_file("*.ogg", "*.wav") var mixed_sound_path: String = "res://assets/audio/sfx/plot_ready.ogg"

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
var _mix: float = 0.0
var _mixed_sound: AudioStream
var _spoon_target: Vector2 = SPOON_REST
var _spoon_held: bool = false
var _spoon_hint_tween: Tween
var _stir_energy: float = 0.0
var _stir_time: float = 0.0

@onready var _body: Node2D = $Body
@onready var _contents: Node2D = $Body/Contents
@onready var _flour: Sprite2D = $Body/Contents/Flour
@onready var _yolk: Sprite2D = $Body/Contents/Yolk
@onready var _carrot: Sprite2D = $Body/Contents/Carrot
@onready var _dough: Sprite2D = $Body/Contents/Dough
## Kaşık düğümü kasenin iç ağzının ortasında durur; konumları ona göredir.
@onready var _spoon_anchor: Node2D = $Body/SpoonAnchor
@onready var _spoon: Node2D = $Body/SpoonAnchor/Spoon
@onready var _spoon_sprite: Sprite2D = $Body/SpoonAnchor/Spoon/Sprite
@onready var _puff: CPUParticles2D = $Puff
@onready var _bubble: Node2D = $Bubble
@onready var _bubble_field: Node2D = $Bubble/Field
@onready var _bubble_coop: Node2D = $Bubble/Coop
@onready var _bubble_tap: Tappable = $Bubble/TapArea


func _ready() -> void:
	for item: StringName in add_sound_paths:
		if ResourceLoader.exists(add_sound_paths[item]):
			_add_sounds[item] = load(add_sound_paths[item]) as AudioStream
	if ResourceLoader.exists(mixed_sound_path):
		_mixed_sound = load(mixed_sound_path) as AudioStream
	_flour_scale = _flour.scale
	_flour.hide()
	_yolk.hide()
	_carrot.hide()
	_dough.hide()
	_spoon.hide()
	_bubble_scale = _bubble.scale
	_bubble.hide()
	_bubble_tap.enabled = false
	Oscillation.ping_pong(self, _bubble, ^"position:y", _bubble.position.y, _bubble.position.y - BUBBLE_BOB,
			BUBBLE_BOB_PERIOD)
	_bubble_tap.tapped.connect(_on_bubble_tapped)
	Basket.changed.connect(func(_item: StringName, _count: int) -> void: _refresh_bubble())


func _process(delta: float) -> void:
	if _spoon.visible:
		var weight: float = 1.0 - exp(-SPOON_FOLLOW_SHARPNESS * delta)
		_spoon.position = _spoon.position.lerp(_spoon_target, weight)
		var lean: float = deg_to_rad(SPOON_REST_DEGREES)
		if _spoon_held:
			lean = deg_to_rad(SPOON_LEAN_DEGREES) * (_spoon.position.x / SPOON_RANGE.x)
		_spoon.rotation = lerpf(_spoon.rotation, lean, weight)
	if _stir_energy > 0.0:
		_stir_energy = maxf(_stir_energy - STIR_ENERGY_DECAY * delta, 0.0)
		_stir_time += delta
		_contents.rotation = sin(_stir_time * STIR_WOBBLE_SPEED) * deg_to_rad(STIR_WOBBLE_DEGREES) * _stir_energy


func contains(global_point: Vector2) -> bool:
	return drop_area.has_point(to_local(global_point))


func has_recipe() -> bool:
	return not recipe.is_empty()


## Kaseye henüz hiç malzeme konmadı (tarif değiştirilebilir).
func is_empty() -> bool:
	return not _filled.has(true)


func is_complete() -> bool:
	return has_recipe() and not _filled.has(false)


## Bütün malzemeler kasede ama henüz hamur olmadı.
func can_stir() -> bool:
	return is_complete() and not is_mixed()


func is_mixed() -> bool:
	return has_recipe() and _mix >= mix_distance


## Kasede henüz malzeme yoksa tarifi değiştirir; malzeme varsa hiçbir şey yapmaz.
func set_recipe(recipe_id: StringName) -> void:
	if not is_empty():
		return
	recipe = recipe_id
	_items = Recipes.ingredients(recipe_id)
	_dough.texture = dough_textures.get(recipe_id)
	_mix = 0.0
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


## Kaşık kasede distance kadar yol aldı: karışım o kadar hamura döner.
func stir(distance: float) -> void:
	if not can_stir():
		return
	_mix = minf(_mix + distance, mix_distance)
	_stir_energy = 1.0
	_stop_spoon_hint()
	_show_mix()
	if is_mixed():
		_on_mixed()


## Kaşığı kaydırmadan kaseye dokunuldu.
func tap_stir() -> void:
	stir(tap_stir_distance)


## Kaşığın alt ucu parmağın altına gider, ama kasenin içinde kalır.
func move_spoon(global_point: Vector2) -> void:
	if not _spoon.visible:
		return
	_spoon_held = true
	_stop_spoon_hint()
	var local: Vector2 = _spoon_anchor.to_local(global_point)
	var reach: float = Vector2(local.x / SPOON_RANGE.x, local.y / SPOON_RANGE.y).length()
	if reach > 1.0:
		local /= reach
	_spoon_target = local


## Parmak kalktı: kaşık dinlenme yerine döner.
func rest_spoon() -> void:
	_spoon_held = false
	_spoon_target = SPOON_REST


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
		_show_spoon()


func _show_spoon() -> void:
	_spoon_held = false
	_spoon_target = SPOON_REST
	_spoon.position = SPOON_REST
	_spoon.rotation = deg_to_rad(SPOON_REST_DEGREES)
	_spoon.scale = Vector2.ZERO
	_spoon.show()
	create_tween().tween_property(_spoon, ^"scale", Vector2.ONE, SPOON_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spoon_hint_tween = Oscillation.ping_pong(self, _spoon_sprite, ^"rotation", deg_to_rad(-SPOON_HINT_DEGREES),
			deg_to_rad(SPOON_HINT_DEGREES), SPOON_HINT_PERIOD, 0.0, false)


func _stop_spoon_hint() -> void:
	if _spoon_hint_tween == null:
		return
	_spoon_hint_tween.kill()
	_spoon_hint_tween = null
	create_tween().tween_property(_spoon_sprite, ^"rotation", 0.0, HIGHLIGHT_TIME)


## Malzemeler karıştıkça soluklaşır, hamur onların yerinde büyür.
func _show_mix() -> void:
	var progress: float = _mix / mix_distance
	for layer: Sprite2D in [_flour, _yolk, _carrot]:
		layer.modulate.a = 1.0 - progress
	_dough.show()
	_dough.modulate.a = minf(progress * 2.0, 1.0)
	_dough.scale = Vector2.ONE * lerpf(DOUGH_START_SCALE, 1.0, progress)


func _on_mixed() -> void:
	_stir_energy = 0.0
	_contents.rotation = 0.0
	_flour.hide()
	_yolk.hide()
	_carrot.hide()
	var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
	AudioManager.play_sfx(_mixed_sound, AudioManager.BUS_SFX, 0.0, 1.0, pan)
	var spoon_tween: Tween = create_tween()
	spoon_tween.tween_property(_spoon, ^"scale", Vector2.ZERO, SPOON_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	spoon_tween.tween_callback(_spoon.hide)
	var dough_tween: Tween = create_tween()
	dough_tween.tween_property(_dough, ^"scale", Vector2.ONE * MIXED_POP_SCALE, MIXED_POP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dough_tween.tween_property(_dough, ^"scale", Vector2.ONE, SETTLE_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = _contents.position
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	mixed.emit()


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
