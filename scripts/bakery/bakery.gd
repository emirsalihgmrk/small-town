extends Node2D
## Fırın bölümü: eve dönüş, tarif panosundan tarif seçme, sepetten kaseye malzeme koyma, kaşıkla
## karıştırma (StirHand), hazır hamuru fırına koyma (DoughHand), pişen ürünü fırından sepete alma ve
## kızın tepkileri. Sepete dokununca sepetin içi açılır.
## Kase boşken başka bir karta dokununca tarif değişir; kaseye ilk malzeme konunca öteki kartlar kilitlenir.
## Tarif seçilmeden sepetten malzeme çekilmeye çalışılırsa kartlar sallanır; gereken malzeme sepette
## yoksa kasenin balonu zıplar, balona dokununca malzemenin geldiği bölüme gidilir. Kase dolunca ve
## karışım hamur olunca kız sevinir. Hamur hazırken boş fırın parlayarak çağırır; hamur fırına girince kase
## boşalır, kartlar sıfırlanır (yeni tarife başlanabilir), kapak kapanınca kız fırına el sallar, ürün
## pişince sevinir. Pişen ürün fırından çıkınca ortak sepete eklenir, sepete uçar ve kız yine sevinir.
## Kız tarladaki ve kümesteki gibi uzun süre dokunulmazsa esner.
## Kase ve fırın SaveGame'in "bakery" bölümünde tutulur: seçili tarif, kasedeki malzemeler, karışma
## miktarı ve fırındaki ürünle pişmesine kalan süre. Tarif seçilince, kaseye malzeme konunca, hamur olunca,
## hamur fırına girince, sahneden çıkarken ve SaveGame diske yazmadan hemen önce kayda geçer. Açılışta
## sahne kapalıyken geçen oyun süresi kadar pişme ileri sarılır.

const SECTION: String = "bakery"

## Kızın fırına (sağa) bakan kolu.
const GIRL_OVEN_ARM: int = 1
## Esneme zamanı geldiğinde kız başka bir hareketteyse bu kadar sonra yeniden denenir.
const YAWN_RETRY_TIME: float = 2.0

## Bu kadar süre hiç dokunulmazsa kız esner (sonra yine aynı süre beklenir).
@export_range(5.0, 120.0, 1.0, "suffix:s") var idle_yawn_time: float = 25.0

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _bowl: MixingBowl = $World/Bowl
@onready var _oven: Oven = $World/Oven
@onready var _girl: Girl = $World/Girl
@onready var _ingredient_hand: IngredientHand = $IngredientHand

var _cards: Array[RecipeCard] = []
var _selected: RecipeCard
var _idle_time: float = 0.0


func _ready() -> void:
	_cards.assign($World/RecipeBoard/Cards.get_children())
	_restore()
	_home_button.pressed.connect(SceneRouter.go_home)
	_basket.tapped.connect(_basket_menu.open)
	for card: RecipeCard in _cards:
		card.tapped.connect(_on_card_tapped.bind(card))
	_bowl.slot_filled.connect(_on_slot_filled)
	_bowl.completed.connect(_girl.cheer)
	_bowl.mixed.connect(_girl.cheer)
	_bowl.mixed.connect(_refresh_oven_invite)
	_bowl.cleared.connect(_on_bowl_cleared)
	_oven.door_closed.connect(_girl.wave.bind(GIRL_OVEN_ARM))
	_oven.baked.connect(_girl.cheer)
	_oven.taken_out.connect(_on_taken_out)
	_bowl.bubble_tapped.connect(SceneRouter.go_to_section)
	_ingredient_hand.no_recipe.connect(_nudge_cards)
	_ingredient_hand.missing.connect(_bowl.nudge_bubble)
	_bowl.slot_filled.connect(func(_index: int) -> void: SaveGame.request_save())
	_bowl.mixed.connect(SaveGame.request_save)
	_bowl.cleared.connect(SaveGame.request_save)
	SaveGame.before_save.connect(_store)


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


func _store() -> void:
	SaveGame.set_section(SECTION, {
		"saved_at": SaveGame.play_time,
		"bowl": _bowl.save_state(),
		"oven": _oven.save_state(),
	})


## Kase ve fırın animasyonsuz kurulur; kasedeki tarifin kartı seçili, konmuş malzemeleri renkli olur.
func _restore() -> void:
	var data: Dictionary = SaveGame.get_section(SECTION)
	if data.is_empty():
		return
	var elapsed: float = maxf(SaveGame.play_time - float(data.get("saved_at", SaveGame.play_time)), 0.0)
	var bowl_data: Variant = data.get("bowl")
	if bowl_data is Dictionary:
		_bowl.load_state(bowl_data)
	var oven_data: Variant = data.get("oven")
	if oven_data is Dictionary:
		_oven.load_state(oven_data, elapsed)
	for card: RecipeCard in _cards:
		if card.recipe == _bowl.recipe:
			_selected = card
	if _selected == null:
		return
	_selected.set_selected(true, false)
	var empty_slots: Array[int] = _bowl.open_slots()
	for i: int in Recipes.ingredients(_bowl.recipe).size():
		if not empty_slots.has(i):
			_selected.fill_slot(i, false)
	if not _bowl.is_empty():
		for card: RecipeCard in _cards:
			card.set_locked(card != _selected)
	_refresh_oven_invite()


func _on_card_tapped(card: RecipeCard) -> void:
	if card == _selected or not _bowl.is_empty():
		return
	_selected = card
	for other: RecipeCard in _cards:
		other.set_selected(other == card)
		other.clear_slots()
	_bowl.set_recipe(card.recipe)
	SaveGame.request_save()


func _on_slot_filled(index: int) -> void:
	_selected.fill_slot(index)
	for card: RecipeCard in _cards:
		card.set_locked(card != _selected)


## Ürün ortak sepete hemen eklenir (sahne kapansa da kaybolmaz); uçuş yalnızca görünüştür.
func _on_taken_out(item: StringName, global_point: Vector2) -> void:
	Basket.add(item)
	_basket.receive(item, global_point)
	_girl.cheer()


func _on_bowl_cleared() -> void:
	_selected = null
	for card: RecipeCard in _cards:
		card.set_selected(false)
		card.set_locked(false)
		card.clear_slots()
	_refresh_oven_invite()


func _refresh_oven_invite() -> void:
	_oven.set_inviting(_bowl.has_dough())


func _nudge_cards() -> void:
	for card: RecipeCard in _cards:
		card.nudge()
