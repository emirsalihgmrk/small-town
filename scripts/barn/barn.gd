extends Node2D
## Ahır bölümü: eve dönüş, sepete dokununca sepetin içini açma, saman yığınından yemliğe saman (HayHand),
## kovayla suluğa su (WaterHand), süt kovasıyla sağma (MilkHand) ve kızın tepkileri. İnek yemliği ve
## suluğu kendisi kullanır (Cow). Yemlik ya da suluk dolunca ve inek sağılınca kız sevinir; ineğin sütü
## hazır olunca ahıra el sallar.
## Yemlik, suluk ve inek açılışta kayıttan geri yüklenir; sahne kapalıyken geçen oyun süresi kadar ineğin
## döngüsü ileri sarılır (Cow.load_state). Yemlik ya da suluk dolunca, süt hazır olunca, inek sağılınca,
## sahneden çıkarken ve SaveGame diske yazmadan hemen önce durum kayda geçer.

const SECTION: String = "barn"
## Kızın ahıra (sağa) bakan kolu.
const GIRL_BARN_ARM: int = 1

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _manger: Manger = $World/Manger
@onready var _trough: Trough = $World/Trough
@onready var _cow: Cow = $World/Cow
@onready var _girl: Girl = $World/Girl
@onready var _milk_hand: MilkHand = $MilkHand


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


func _exit_tree() -> void:
	_store()
	SaveGame.save_now()


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
