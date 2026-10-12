extends Node
## Dükkândan alınanlar (autoload: Owned). Etikete konan her para hemen ortak paradan (Wallet) düşer ve o
## ürünün yarım ödemesine yazılır; ödeme fiyata ulaşınca ürün alınmış olur (purchased) ve bir daha satılmaz.
## Kızın taktığı aksesuar da burada tutulur (worn; boşsa hasır şapka). Kız her bölümde açılışta onu takar.
## Alınan tohum paketleri tarlada yeni ürünleri (has_seeds), tarif kartları fırında yeni tarifleri
## (has_recipe) açar.
## İçerik SaveGame'in "shop" bölümünde kalıcı tutulur: alınanlar, yarım ödemeler ve takılı aksesuar. Ürün
## kimlikleri ve fiyatlar ShopItems'tadır.

signal paid_changed(item: StringName, paid: int)
signal purchased(item: StringName)
signal worn_changed(item: StringName)

const SECTION: String = "shop"

var _owned: Array[StringName] = []
var _paid: Dictionary[StringName, int] = {}
var _worn: StringName = &""


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
	var worn: StringName = StringName(str(saved.get("worn", "")))
	if _owned.has(worn) and ShopItems.kind(worn) == ShopItems.Kind.ACCESSORY:
		_worn = worn


func has(item: StringName) -> bool:
	return _owned.has(item)


## Tarlada bu ürün ekilebilir mi: tohumu dükkânda satılmayan ürünler hep açıktır.
func has_seeds(crop_item: StringName) -> bool:
	return not ShopItems.SEEDS_FOR.has(crop_item) or has(ShopItems.SEEDS_FOR[crop_item])


## Fırında bu tarif görünür mü: kartı dükkânda satılmayan tarifler hep açıktır.
func has_recipe(recipe: StringName) -> bool:
	return not ShopItems.RECIPE_CARDS.has(recipe) or has(ShopItems.RECIPE_CARDS[recipe])


## Ürün dükkânın rafında görünür mü: önce alınması gereken bir ürün varsa o alınmış olmalı.
func is_offered(item: StringName) -> bool:
	return not ShopItems.NEEDS.has(item) or has(ShopItems.NEEDS[item])


func paid(item: StringName) -> int:
	return _paid.get(item, 0)


## Ürünün tamamlanması için daha kaç para gerektiği (alınmışsa 0).
func remaining(item: StringName) -> int:
	return 0 if has(item) else ShopItems.price(item) - paid(item)


## Kızın taktığı aksesuar; hasır şapkadaysa boş.
func worn() -> StringName:
	return _worn


## Alınmış bir aksesuarı takar; boş verilirse hasır şapkaya döner. Alınmamış ya da süs ise hiçbir şey yapmaz.
func wear(item: StringName) -> void:
	if item == _worn:
		return
	if item != &"" and not (has(item) and ShopItems.kind(item) == ShopItems.Kind.ACCESSORY):
		return
	_worn = item
	_store()
	worn_changed.emit(item)


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
	SaveGame.set_section(SECTION, {"owned": owned, "paid": paid, "worn": String(_worn)})
	SaveGame.request_save()
