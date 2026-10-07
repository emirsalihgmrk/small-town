extends Node2D
## Fırın bölümü: eve dönüş, tarif panosundan tarif seçme, sepetten kaseye malzeme koyma ve kızın
## tepkileri. Sepete dokununca sepetin içi açılır.
## Kase boşken başka bir karta dokununca tarif değişir; kaseye ilk malzeme konunca öteki kartlar kilitlenir.
## Tarif seçilmeden sepetten malzeme çekilmeye çalışılırsa kartlar sallanır; gereken malzeme sepette
## yoksa kasenin balonu zıplar, balona dokununca malzemenin geldiği bölüme gidilir. Kase dolunca kız sevinir.
## Kasedeki malzemeler henüz kayda geçmiyor: sahneden çıkarken ortak sepete geri konur.

@onready var _home_button: Button = $UI/Root/HomeButton
@onready var _basket: BasketView = $World/Basket
@onready var _basket_menu: BasketMenu = $BasketMenu
@onready var _bowl: MixingBowl = $World/Bowl
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
	_bowl.bubble_tapped.connect(SceneRouter.go_to_section)
	_ingredient_hand.no_recipe.connect(_nudge_cards)
	_ingredient_hand.missing.connect(_bowl.nudge_bubble)


func _exit_tree() -> void:
	for item: StringName in _bowl.contents():
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


func _nudge_cards() -> void:
	for card: RecipeCard in _cards:
		card.nudge()
