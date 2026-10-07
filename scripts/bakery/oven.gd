class_name Oven
extends Node2D
## Taş fırın. Hamur getirilince (bake) çiğ ürün fırının ağzına oturur ve camlı kapak kapanır; camdan
## bakınca ürün bake_time boyunca yavaş yavaş kabarıp kızarır (çiğ resmin üstünde pişmiş resim belirir).
## Pişince zil çalar, kapak parlar ve baked yayılır. Fırın asla yakmaz: ürün çıkarılmazsa fırında sıcak
## bekler, kapağın üstünden buhar tüter. Fırında ürün varken yeni hamur girmez (nudge ile fırın "dolu" diye
## sallanır).
## Pişmiş ürün varken fırına dokununca kapak açılır, ürün buharla öne çıkar ve fırın boşalır; ürün
## çıkınca taken_out o ürünle ve bulunduğu yerle yayılır (sepete uçurmak için). Pişerken dokunulursa
## fırın kısaca sallanır.
## Durum kayda save_state ile yazılır (çıkarılmakta olan ürün fırında pişmiş sayılır); load_state sahne
## kapalıyken geçen süre kadar pişmeyi ileri sarar.
## Hamur hazırken ve fırın boşken fırının ağzı yavaşça parlayarak çağırır (set_inviting). Pişerken ışık
## daha hızlı titrer ve közler ara ara çıtırdar; fırın boş ve beklerken közler yine hafifçe kızarır.
## Kök noktası fırının dibinin ortasıdır.

signal door_closed
signal baked
signal taken_out(item: StringName, global_point: Vector2)

## Ürünün fırında oturduğu yer (altının ortası) ve sığdırıldığı kutu; ürün buradan yukarı kabarır.
const PRODUCT_POINT: Vector2 = Vector2(0.0, -313.0)
const PRODUCT_SIZE: Vector2 = Vector2(150.0, 100.0)
## Çiğ ürün bu ölçekle başlar, piştikçe tam boyuna kabarır.
const RISE_START: Vector2 = Vector2(0.92, 0.8)
## Pişmiş resim pişmenin bu kısmından sonra belirmeye başlar.
const BROWN_START: float = 0.2
const DOOR_CLOSE_TIME: float = 0.4
const HIGHLIGHT_SCALE: Vector2 = Vector2(1.03, 1.03)
const HIGHLIGHT_TIME: float = 0.12
const NUDGE_DEGREES: float = 1.5
const NUDGE_TIME: float = 0.06
const READY_SQUASH: Vector2 = Vector2(1.03, 0.97)
const READY_SQUASH_TIME: float = 0.1
const SETTLE_TIME: float = 0.4
const GLOW_INVITE_MIN: float = 0.15
const GLOW_INVITE_MAX: float = 1.0
const GLOW_INVITE_PERIOD: float = 1.4
const GLOW_BAKING_MIN: float = 0.35
const GLOW_BAKING_MAX: float = 0.7
const GLOW_BAKING_PERIOD: float = 0.9
const GLOW_WARM: float = 0.45
const GLOW_IDLE_MIN: float = 0.0
const GLOW_IDLE_MAX: float = 0.22
const GLOW_IDLE_PERIOD: float = 2.6
const GLOW_FADE_TIME: float = 0.3
const DOOR_OPEN_TIME: float = 0.25
## Çıkarılan ürün fırının ağzından bu kadar öne (aşağı) kayar.
const TAKE_OUT_SLIDE: Vector2 = Vector2(0.0, 40.0)
const TAKE_OUT_TIME: float = 0.3
## Ürün sepete uçmadan önce bu ölçeğe (resmin kendi boyuna göre) küçülür; sepete uçuş bu boydan başlar.
const HANDOFF_SCALE: float = 0.6
const HANDOFF_TIME: float = 0.08
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.6

## Hamurun pişme süresi (oyun açıkken geçen süre).
@export_range(1.0, 300.0, 1.0, "suffix:s") var bake_time: float = 25.0
## Hamurun bırakılınca fırına sayıldığı alan (kök noktasına göre); küçük parmaklar için cömert.
@export var drop_area: Rect2 = Rect2(-270.0, -560.0, 540.0, 440.0)
## Tarifin fırındaki çiğ ve pişmiş hali (Recipes kimliği -> resmi); ikisi aynı çerçevede çizilmeli.
@export var raw_textures: Dictionary[StringName, Texture2D] = {}
@export var baked_textures: Dictionary[StringName, Texture2D] = {}
@export var sparkle_scene: PackedScene
@export_file("*.ogg", "*.wav") var door_sound_path: String = "res://assets/audio/sfx/oven_door.ogg"
@export_file("*.ogg", "*.wav") var ready_sound_path: String = "res://assets/audio/sfx/oven_ding.ogg"
@export_file("*.ogg", "*.wav") var take_out_sound_path: String = "res://assets/audio/sfx/steam_puff.ogg"
@export_file("*.ogg", "*.wav") var crackle_sound_path: String = "res://assets/audio/sfx/fire_crackle.ogg"
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var crackle_volume_db: float = -8.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var crackle_interval_min: float = 0.6
@export_range(0.1, 10.0, 0.1, "suffix:s") var crackle_interval_max: float = 1.8

## Fırındaki tarif; fırın boşsa boş.
var recipe: StringName = &""

var _time_left: float = 0.0
var _inviting: bool = false
var _door_sound: AudioStream
var _ready_sound: AudioStream
var _take_out_sound: AudioStream
var _crackle_sound: AudioStream
var _crackle_timer: Timer
var _taking_out: bool = false
var _highlighted: bool = false
var _highlight_tween: Tween
var _glow_tween: Tween
var _nudge_tween: Tween
var _product_scale: Vector2 = Vector2.ONE

@onready var _body: Node2D = $Body
@onready var _glow: Sprite2D = $Body/Glow
@onready var _product: Node2D = $Body/Product
@onready var _raw: Sprite2D = $Body/Product/Raw
@onready var _baked: Sprite2D = $Body/Product/Baked
@onready var _door: Node2D = $Body/Door
@onready var _steam: CPUParticles2D = $Body/Steam
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	if ResourceLoader.exists(door_sound_path):
		_door_sound = load(door_sound_path) as AudioStream
	if ResourceLoader.exists(ready_sound_path):
		_ready_sound = load(ready_sound_path) as AudioStream
	if ResourceLoader.exists(take_out_sound_path):
		_take_out_sound = load(take_out_sound_path) as AudioStream
	if ResourceLoader.exists(crackle_sound_path):
		_crackle_sound = load(crackle_sound_path) as AudioStream
	_crackle_timer = Timer.new()
	_crackle_timer.one_shot = true
	_crackle_timer.timeout.connect(_on_crackle_timer_timeout)
	add_child(_crackle_timer)
	_tap_area.tapped.connect(_on_tapped)
	_product.position = PRODUCT_POINT
	_product.hide()
	_door.hide()
	_glow.modulate.a = 0.0
	_refresh_glow()


func _process(delta: float) -> void:
	if is_baking():
		_time_left = maxf(_time_left - delta, 0.0)
		_show_progress()
		if _time_left <= 0.0:
			_on_baked()


func contains(global_point: Vector2) -> bool:
	return drop_area.has_point(to_local(global_point))


func can_bake() -> bool:
	return recipe.is_empty()


func is_baking() -> bool:
	return not recipe.is_empty() and _time_left > 0.0


## Pişmiş ürün fırında bekliyor (çıkarılmakta olan sayılmaz).
func is_baked() -> bool:
	return has_baked_product() and not _taking_out


## Fırında pişmiş bir ürün var (çıkarılmaktaysa da).
func has_baked_product() -> bool:
	return not recipe.is_empty() and _time_left <= 0.0


## Pişmiş ürünü çıkarır: kapak açılır, ürün öne kayar, sonra fırın boşalır ve taken_out yayılır. Ürün
## yoksa hiçbir şey olmaz.
func take_out() -> void:
	if not is_baked() or _taking_out:
		return
	var item: StringName = recipe
	_taking_out = true
	_steam.emitting = false
	_steam.restart()
	_steam.emitting = true
	AudioManager.play_sfx(_take_out_sound, AudioManager.BUS_SFX, 0.0, 1.0, _pan())
	var tween: Tween = create_tween()
	tween.tween_property(_door, ^"scale:x", 0.0, DOOR_OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(_door.hide)
	tween.tween_property(_product, ^"position", PRODUCT_POINT + TAKE_OUT_SLIDE, TAKE_OUT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_product, ^"scale", Vector2.ONE * HANDOFF_SCALE, HANDOFF_TIME)
	tween.tween_callback(_on_taken_out.bind(item))


func raw_texture(recipe_id: StringName) -> Texture2D:
	return raw_textures.get(recipe_id)


## Tarifin çiğ resminin fırında çizildiği ölçek.
func product_scale(recipe_id: StringName) -> float:
	var texture: Texture2D = raw_texture(recipe_id)
	if texture == null:
		return 1.0
	return minf(PRODUCT_SIZE.x / texture.get_width(), PRODUCT_SIZE.y / texture.get_height())


## Ürünün fırındaki ortası (dünya konumu).
func product_point() -> Vector2:
	return _body.to_global(PRODUCT_POINT + Vector2(0.0, -PRODUCT_SIZE.y * 0.5))


## Hamur fırına girer ve hemen pişmeye başlar; arrive_delay sonra (hamur uçup gelince) ürün görünür ve
## kapak kapanır.
func bake(recipe_id: StringName, arrive_delay: float = 0.0) -> void:
	if not can_bake():
		return
	recipe = recipe_id
	_time_left = bake_time
	_setup_product()
	set_highlighted(false)
	_refresh_glow()
	var tween: Tween = create_tween()
	tween.tween_interval(arrive_delay)
	tween.tween_callback(_close_door)


func save_state() -> Dictionary:
	return {"recipe": String(recipe), "time_left": _time_left}


## Kayıttan animasyonsuz kurar: ürün fırında, kapak kapalı; elapsed kadar pişmiş sayılır. Tanınmayan tarif
## yok sayılır (fırın boş kalır).
func load_state(data: Dictionary, elapsed: float) -> void:
	var recipe_id: StringName = StringName(str(data.get("recipe", "")))
	if not raw_textures.has(recipe_id):
		return
	recipe = recipe_id
	_time_left = maxf(clampf(float(data.get("time_left", bake_time)), 0.0, bake_time) - elapsed, 0.0)
	_setup_product()
	_product.show()
	_door.scale = Vector2.ONE
	_door.show()
	_steam.emitting = is_baked()
	_refresh_glow()


## Hamur "fırın dolu" diye geri dönerken fırın kısaca sallanır.
func nudge() -> void:
	if _nudge_tween != null and _nudge_tween.is_running():
		return
	_nudge_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0, 1.0, -1.0]:
		_nudge_tween.tween_property(_body, ^"rotation", deg_to_rad(NUDGE_DEGREES * side), NUDGE_TIME)
	_nudge_tween.tween_property(_body, ^"rotation", 0.0, NUDGE_TIME)


## Hamur hazır mı (fırın boşken ağzı parlayarak çağırır).
func set_inviting(inviting: bool) -> void:
	if inviting == _inviting:
		return
	_inviting = inviting
	_refresh_glow()


## Parmaktaki hamur fırının üstündeyken fırın hafifçe büyür.
func set_highlighted(highlighted: bool) -> void:
	if highlighted == _highlighted:
		return
	_highlighted = highlighted
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(_body, ^"scale", HIGHLIGHT_SCALE if highlighted else Vector2.ONE, HIGHLIGHT_TIME)


func _close_door() -> void:
	_product.show()
	_door.scale = Vector2(0.0, 1.0)
	_door.show()
	create_tween().tween_property(_door, ^"scale:x", 1.0, DOOR_CLOSE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx(_door_sound, AudioManager.BUS_SFX, 0.0, 0.9, _pan())
	door_closed.emit()


## Fırındaki tarifin çiğ ve pişmiş resmi, ürün altından oturacak şekilde.
func _setup_product() -> void:
	_raw.texture = raw_texture(recipe)
	_baked.texture = baked_textures.get(recipe)
	for sprite: Sprite2D in [_raw, _baked]:
		if sprite.texture != null:
			sprite.offset = Vector2(0.0, -sprite.texture.get_height() * 0.5)
	_product_scale = Vector2.ONE * product_scale(recipe)
	_show_progress()


## Ürün piştikçe kabarır, pişmiş resmi çiğin üstünde belirir.
func _show_progress() -> void:
	var progress: float = 1.0 - _time_left / bake_time
	_baked.modulate.a = clampf((progress - BROWN_START) / (1.0 - BROWN_START), 0.0, 1.0)
	_product.scale = _product_scale * RISE_START.lerp(Vector2.ONE, progress)


func _on_baked() -> void:
	_show_progress()
	_refresh_glow()
	AudioManager.play_sfx(_ready_sound, AudioManager.BUS_SFX, 0.0, 1.0, _pan())
	if sparkle_scene != null:
		var sparkle: CPUParticles2D = sparkle_scene.instantiate() as CPUParticles2D
		_body.add_child(sparkle)
		sparkle.position = PRODUCT_POINT + Vector2(0.0, -PRODUCT_SIZE.y * 0.5)
		sparkle.finished.connect(sparkle.queue_free)
		sparkle.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_body, ^"scale", READY_SQUASH, READY_SQUASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_steam.emitting = true
	baked.emit()


func _on_taken_out(item: StringName) -> void:
	var point: Vector2 = product_point() + _body.global_transform.basis_xform(TAKE_OUT_SLIDE)
	_product.hide()
	_product.position = PRODUCT_POINT
	_steam.emitting = false
	recipe = &""
	_taking_out = false
	_refresh_glow()
	taken_out.emit(item, point)


func _on_tapped(_point: Vector2) -> void:
	if is_baked():
		take_out()
	elif is_baking():
		nudge()


## Işık: pişerken hızlı titrer, pişince sabit ve ılık kalır, boşken hamur hazırsa yavaşça çağırır.
func _refresh_glow() -> void:
	if _glow_tween != null:
		_glow_tween.kill()
	if is_baking():
		_glow_tween = Oscillation.ping_pong(self, _glow, ^"modulate:a", GLOW_BAKING_MIN, GLOW_BAKING_MAX,
				GLOW_BAKING_PERIOD, 0.0, false)
		if _crackle_timer.is_stopped():
			_crackle_timer.start(randf_range(crackle_interval_min, maxf(crackle_interval_min, crackle_interval_max)))
	elif can_bake() and _inviting:
		_glow_tween = Oscillation.ping_pong(self, _glow, ^"modulate:a", GLOW_INVITE_MIN, GLOW_INVITE_MAX,
				GLOW_INVITE_PERIOD, 0.0, false)
	elif can_bake():
		_glow_tween = Oscillation.ping_pong(self, _glow, ^"modulate:a", GLOW_IDLE_MIN, GLOW_IDLE_MAX,
				GLOW_IDLE_PERIOD, 0.0, false)
	else:
		_glow_tween = create_tween()
		_glow_tween.tween_property(_glow, ^"modulate:a", GLOW_WARM if is_baked() else 0.0, GLOW_FADE_TIME)


## Pişerken közler rastgele aralıklarla çıtırdar.
func _on_crackle_timer_timeout() -> void:
	if not is_baking():
		return
	AudioManager.play_sfx(_crackle_sound, AudioManager.BUS_SFX, crackle_volume_db, randf_range(0.85, 1.2), _pan())
	_crackle_timer.start(randf_range(crackle_interval_min, maxf(crackle_interval_min, crackle_interval_max)))


func _pan() -> float:
	return clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
