extends Node2D
## Ana ekran: bölüm kartına basılınca o bölüme geçer (henüz yapılmamış bölümlerin kartı tepkisizdir).


func _ready() -> void:
	for node: Node in find_children("*", "Button"):
		var card: SectionCard = node as SectionCard
		if card != null:
			card.section_selected.connect(SceneRouter.go_to_section)
