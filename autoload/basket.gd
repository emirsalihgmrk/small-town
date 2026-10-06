extends Node
## Oyun genelinde ortak sepet (autoload: Basket). Tarlada toplanan ürünler buraya girer; ileride Fırın ve
## Ahır da buradan alacak. İçerik SaveGame'in "basket" bölümünde kalıcı tutulur.
## Ürün kimlikleri Items sınıfındadır.

signal changed(item: StringName, count: int)

const SECTION: String = "basket"

var _items: Dictionary[StringName, int] = {}


func _ready() -> void:
	var saved: Dictionary = SaveGame.get_section(SECTION)
	for key: Variant in saved:
		_items[StringName(str(key))] = maxi(int(saved[key]), 0)


func count(item: StringName) -> int:
	return _items.get(item, 0)


func add(item: StringName, amount: int = 1) -> void:
	_items[item] = count(item) + amount
	_on_changed(item)


## Yeterince yoksa hiçbir şey almaz ve false döner.
func take(item: StringName, amount: int = 1) -> bool:
	if count(item) < amount:
		return false
	_items[item] = count(item) - amount
	_on_changed(item)
	return true


func _on_changed(item: StringName) -> void:
	var data: Dictionary = {}
	for key: StringName in _items:
		data[String(key)] = _items[key]
	SaveGame.set_section(SECTION, data)
	SaveGame.request_save()
	changed.emit(item, count(item))
