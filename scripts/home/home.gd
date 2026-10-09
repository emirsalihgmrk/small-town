extends Node2D
## Ana ekran: bölüm kartına basılınca o bölüme geçer (henüz yapılmamış bölümlerin kartı tepkisizdir).
## Dükkân'dan alınan süsler (kuş evi, uçurtma, salıncak, küçük havuz) kendi sabit yerlerinde görünür;
## alınmamışlar gizlidir. Süs düğümünün adı ürün kimliğinin PascalCase hâlidir (birdhouse -> Birdhouse).

## Ana ekrandaki bütün süs düğümleri.
@export var decorations: Array[Node2D] = []


func _ready() -> void:
	for node: Node in find_children("*", "Button"):
		var card: SectionCard = node as SectionCard
		if card != null:
			card.section_selected.connect(SceneRouter.go_to_section)
	for decoration: Node2D in decorations:
		decoration.visible = Owned.has(StringName(String(decoration.name).to_snake_case()))
