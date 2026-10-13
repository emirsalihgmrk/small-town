extends Node2D
## Ahır bölümü: eve dönüş, sepete dokununca sepetin içini açma, saman yığınından yemliğe saman (HayHand),
## kovayla suluğa su (WaterHand), süt kovasıyla sağma (MilkHand) ve kızın tepkileri. İnek yemliği ve
## suluğu kendisi kullanır (Cow). Yemlik ya da suluk dolunca ve inek sağılınca kız sevinir; ineğin sütü
## hazır olunca ahıra el sallar; uzun süre dokunulmazsa esner. İneğe dokunulabilir (Cow).
## Yemlik, suluk ve inek açılışta kayıttan geri yüklenir; sahne kapalıyken geçen oyun süresi kadar ineğin
## döngüsü ileri sarılır (Cow.load_state). Yemlik ya da suluk dolunca, süt hazır olunca, inek sağılınca,
## sahneden çıkarken ve SaveGame diske yazmadan hemen önce durum kayda geçer.
## El göstergesi (HintDirector) sırayla şunları gösterir: süt hazırsa kovayı ineğin altına götürmeyi ya da
## kova yerindeyse memeye dokunmayı, yemlik boşsa yığından saman çekmeyi, suluk dolu değilse kovayla su
## dökmeyi.

const SECTION: String = "barn"
## El göstergesindeki işlerin kimlikleri (öğrenme sayısı kayıtta bu adlarla tutulur).
const HINT_HAY: StringName = &"barn_hay"
const HINT_WATER: StringName = &"barn_water"
const HINT_PAIL: StringName = &"barn_pail"
const HINT_MILK: StringName = &"barn_milk"
## Kova suluğun üstünde bu kadar bekler (Trough.water_needed'dan biraz uzun).
const HINT_WATER_HOLD: float = 1.6
## Kızın ahıra (sağa) bakan kolu.
const GIRL_BARN_ARM: int = 1
## Esneme zamanı geldiğinde kız başka bir hareketteyse bu kadar sonra yeniden denenir.
const YAWN_RETRY_TIME: float = 2.0

## Bu kadar süre hiç dokunulmazsa kız esner (sonra yine aynı süre beklenir).
@export_range(5.0, 120.0, 1.0, "suffix:s") var idle_yawn_time: float = 25.0

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _manger: Manger = $World/Manger
@onready var _trough: Trough = $World/Trough
@onready var _cow: Cow = $World/Cow
@onready var _girl: Girl = $World/Girl
@onready var _milk_hand: MilkHand = $MilkHand
@onready var _hay_hand: HayHand = $HayHand
@onready var _hay_pile: HayPile = $World/HayPile
@onready var _bucket: Node2D = $World/Bucket
@onready var _pail: MilkPail = $World/MilkPail
@onready var _hints: HintDirector = $HintDirector

var _idle_time: float = 0.0
## El göstergesinin taşıdığı saman tutamı ve boş süt kovası (sahnede değil, yalnızca örnek).
var _hint_hay: Sprite2D
var _hint_pail: Sprite2D


func _ready() -> void:
	_restore()
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	_manger.filled.connect(_girl.cheer)
	_trough.filled.connect(_girl.cheer)
	_cow.milk_ready.connect(_girl.wave.bind(GIRL_BARN_ARM))
	_milk_hand.milked.connect(_girl.cheer)
	_manger.filled.connect(SaveGame.request_save)
	_trough.filled.connect(SaveGame.request_save)
	_cow.milk_ready.connect(SaveGame.request_save)
	_milk_hand.milked.connect(SaveGame.request_save)
	SaveGame.before_save.connect(_store)
	_hint_hay = Sprite2D.new()
	_hint_hay.texture = _hay_hand.tuft_texture
	_hint_hay.scale = Vector2.ONE * HayHand.CARRY_SCALE / HintHand.CARRY_SCALE
	var pail_sprite: Sprite2D = _pail.get_node(^"Body/Sprite") as Sprite2D
	_hint_pail = pail_sprite.duplicate() as Sprite2D
	_hint_pail.scale = pail_sprite.global_scale / HintHand.CARRY_SCALE
	_hints.provider = _current_hint
	_manger.filled.connect(_hints.learned.bind(HINT_HAY))
	_trough.filled.connect(_hints.learned.bind(HINT_WATER))
	_milk_hand.placed.connect(_hints.learned.bind(HINT_PAIL))
	_milk_hand.milked.connect(_hints.learned.bind(HINT_MILK))


func _process(delta: float) -> void:
	_idle_time += delta
	if _idle_time >= idle_yawn_time:
		_idle_time = 0.0 if _girl.yawn() else idle_yawn_time - YAWN_RETRY_TIME


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_idle_time = 0.0


func _exit_tree() -> void:
	_store()
	SaveGame.save_now()
	_hint_hay.free()
	_hint_pail.free()


## El göstergesi için o an yapılabilecek ilk iş (bkz. HintDirector.provider).
func _current_hint() -> Dictionary:
	if _basket_menu.is_open:
		return {}
	if _cow.is_milk_ready():
		if _milk_hand.is_pail_placed():
			return {"id": HINT_MILK, "points": PackedVector2Array([_to_screen(_cow.udder_point())])}
		if _milk_hand.is_pail_resting():
			return {"id": HINT_PAIL, "carry": _hint_pail, "carry_offset": MilkHand.HOLD_OFFSET,
					"points": PackedVector2Array([_to_screen(_milk_hand.pail_grip(_pail.global_position)),
					_to_screen(_milk_hand.pail_grip(_cow.pail_spot()))])}
	if _manger.can_fill():
		return {"id": HINT_HAY, "carry": _hint_hay, "points": PackedVector2Array([
				_to_screen(_hay_pile.to_global(_hay_pile.grab_area.get_center())),
				_to_screen(_manger.to_global(_manger.drop_area.get_center()))])}
	if _trough.needs_water():
		return {"id": HINT_WATER, "carry": _bucket, "hold": HINT_WATER_HOLD, "points": PackedVector2Array([
				_to_screen(_bucket.global_position),
				_to_screen(_trough.to_global(_trough.pour_area.get_center())) - Finger.lift(get_viewport())])}
	return {}


func _to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point


func _store() -> void:
	SaveGame.set_section(SECTION, {
		"saved_at": SaveGame.play_time,
		"manger": _manger.save_state(),
		"trough": _trough.save_state(),
		"cow": _cow.save_state(),
	})


## Yemlik ve suluk inekten önce yüklenir: inek ileri sararken onları kullanır.
func _restore() -> void:
	var data: Dictionary = SaveGame.get_section(SECTION)
	if data.is_empty():
		return
	var elapsed: float = maxf(SaveGame.play_time - float(data.get("saved_at", SaveGame.play_time)), 0.0)
	var manger_data: Variant = data.get("manger")
	if manger_data is Dictionary:
		_manger.load_state(manger_data)
	var trough_data: Variant = data.get("trough")
	if trough_data is Dictionary:
		_trough.load_state(trough_data)
	var cow_data: Variant = data.get("cow")
	if cow_data is Dictionary:
		_cow.load_state(cow_data, elapsed)
	_milk_hand.refresh_invite()
