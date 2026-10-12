extends Node2D
## Ana ekran: bölüm kartına basılınca o bölüme geçer (henüz yapılmamış bölümlerin kartı tepkisizdir).
## Dükkân'dan alınan süsler (kuş evi, uçurtma, salıncak, küçük havuz) kendi sabit yerlerinde görünür;
## alınmamışlar gizlidir. Süs düğümünün adı ürün kimliğinin PascalCase hâlidir (birdhouse -> Birdhouse).
## Sol üst köşedeki çark basılı tutulunca ebeveyn köşesi açılır.
## El göstergesi (HintDirector): çocuk tarlada henüz hiç parsel çapalamadıysa (yeni oyun) Tarla kartına
## dokunmayı gösterir; sonra ana ekranda el çıkmaz, oyun alanı serbestçe keşfedilir.

## El göstergesindeki işin kimliği (öğrenme sayısı kayıtta bu adla tutulur).
const HINT_FIELD: StringName = &"home_field"
## Tarladaki çapalama ipucunun kimliği (field.gd HINT_TILL); bir kez yapıldıysa çocuk yolu bulmuştur.
const FIELD_TILL_HINT: StringName = &"field_till"

## Ana ekrandaki bütün süs düğümleri.
@export var decorations: Array[Node2D] = []

@onready var _parent_gate: ParentGateButton = $UI/Root/ParentGateButton
@onready var _parent_menu: ParentMenu = $ParentMenu
@onready var _field_card: SectionCard = $UI/Root/LeftCards/FieldCard
@onready var _hints: HintDirector = $HintDirector


func _ready() -> void:
	_parent_gate.opened.connect(_parent_menu.open)
	for node: Node in find_children("*", "Button"):
		var card: SectionCard = node as SectionCard
		if card != null:
			card.section_selected.connect(SceneRouter.go_to_section)
	for decoration: Node2D in decorations:
		decoration.visible = Owned.has(StringName(String(decoration.name).to_snake_case()))
	_hints.provider = _current_hint
	_field_card.section_selected.connect(func(_section_id: StringName) -> void: _hints.learned(HINT_FIELD))


## El göstergesi için o an yapılabilecek iş (bkz. HintDirector.provider).
func _current_hint() -> Dictionary:
	if _parent_menu.is_open or _hints.times(FIELD_TILL_HINT) > 0:
		return {}
	return {"id": HINT_FIELD, "points": PackedVector2Array([_field_card.get_global_rect().get_center()])}
