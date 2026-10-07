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
## Kasedeki ve fırındaki ürünler henüz kayda geçmiyor: sahneden çıkarken ortak sepete konur (pişmiş ürün
## olarak ya da, pişmemişse, malzemeleri olarak).

## Kızın fırına (sağa) bakan kolu.
const GIRL_OVEN_ARM: int = 1

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _bowl: MixingBowl = $World/Bowl
@onready var _oven: Oven = $World/Oven
@onready var _girl: Girl = $World/Girl
@onready var _ingredient_hand: IngredientHand = $IngredientHand

var _cards: Array[RecipeCard] = []
var _selected: RecipeCard


func _ready() -> void:
	_cards.assign($World/RecipeBoard/Cards.get_children())
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


func _exit_tree() -> void:
	for item: StringName in _bowl.contents():
		Basket.add(item)
	if _oven.has_baked_product():
		Basket.add(_oven.recipe)
	elif not _oven.can_bake():
		for item: StringName in Recipes.ingredients(_oven.recipe):
			Basket.add(item)
	SaveGame.save_now()


func _on_card_tapped(card: RecipeCard) -> void:
	if card == _selected or not _bowl.is_empty():
		return
	_selected = card
	for other: RecipeCard in _cards:
		other.set_selected(other == card)
		other.clear_slots()
	_bowl.set_recipe(card.recipe)


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
