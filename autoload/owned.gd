extends Node
## Dükkândan alınanlar (autoload: Owned). Etikete konan her para hemen ortak paradan (Wallet) düşer ve o
## ürünün yarım ödemesine yazılır; ödeme fiyata ulaşınca ürün alınmış olur (purchased) ve bir daha satılmaz.
## İçerik SaveGame'in "shop" bölümünde kalıcı tutulur: alınanlar ve yarım ödemeler. Ürün kimlikleri ve
## fiyatlar ShopItems'tadır.

signal paid_changed(item: StringName, paid: int)
signal purchased(item: StringName)

const SECTION: String = "shop"

var _owned: Array[StringName] = []
var _paid: Dictionary[StringName, int] = {}


func _ready() -> void:
	var saved: Dictionary = SaveGame.get_section(SECTION)
	var owned: Variant = saved.get("owned")
	if owned is Array:
		for value: Variant in owned:
			var item: StringName = StringName(str(value))
			if ShopItems.PRICES.has(item) and not _owned.has(item):
				_owned.append(item)
	var paid: Variant = saved.get("paid")
	if paid is Dictionary:
		for key: Variant in paid:
			var item: StringName = StringName(str(key))
			if ShopItems.PRICES.has(item) and not _owned.has(item):
				_paid[item] = clampi(int(paid[key]), 0, ShopItems.price(item) - 1)


func has(item: StringName) -> bool:
	return _owned.has(item)


func paid(item: StringName) -> int:
	return _paid.get(item, 0)


## Ürünün tamamlanması için daha kaç para gerektiği (alınmışsa 0).
func remaining(item: StringName) -> int:
	return 0 if has(item) else ShopItems.price(item) - paid(item)


## Ürüne bir para öder (Wallet'tan düşer). Para yoksa ya da ürün alınmışsa false döner.
func pay(item: StringName) -> bool:
	if has(item) or not ShopItems.PRICES.has(item) or not Wallet.take(1):
		return false
	_paid[item] = paid(item) + 1
	if _paid[item] >= ShopItems.price(item):
		_paid.erase(item)
		_owned.append(item)
		_store()
		paid_changed.emit(item, ShopItems.price(item))
		purchased.emit(item)
	else:
		_store()
		paid_changed.emit(item, _paid[item])
	return true


func _store() -> void:
	var owned: Array[String] = []
	for item: StringName in _owned:
		owned.append(String(item))
	var paid: Dictionary = {}
	for item: StringName in _paid:
		paid[String(item)] = _paid[item]
	SaveGame.set_section(SECTION, {"owned": owned, "paid": paid})
	SaveGame.request_save()
