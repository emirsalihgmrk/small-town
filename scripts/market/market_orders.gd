class_name MarketOrders
extends RefCounted
## Pazardaki müşterilerin istekleri. İstek yalnızca ortak sepette (Basket) olan ürünlerden kurulur, yani
## yerine getirilemeyen bir istek hiç çıkmaz. Sepette fırın ürünü varsa istek yalnızca fırın ürünlerinden,
## yoksa ham ürünlerden olur. Aynı ürünler balonda yan yana dursun diye istek ürün sırasına göre dizilir.

const MAX_ITEMS: int = 3
const BAKED: Array[StringName] = [Items.BREAD, Items.COOKIE, Items.CARROT_CAKE, Items.BIRTHDAY_CAKE]
const RAW: Array[StringName] = [Items.CARROT, Items.WHEAT, Items.EGG, Items.MILK]
## Ürünlerin sırası (balonda soldan sağa da bu sırayla durur).
const ALL: Array[StringName] = [Items.BREAD, Items.COOKIE, Items.CARROT_CAKE, Items.BIRTHDAY_CAKE, Items.CARROT,
		Items.WHEAT, Items.EGG, Items.MILK]


static func has_anything() -> bool:
	for item: StringName in ALL:
		if Basket.count(item) > 0:
			return true
	return false


## 1..MAX_ITEMS ürünlük bir istek; sepet boşsa boş dizi.
static func make() -> Array[StringName]:
	var stock: Dictionary[StringName, int] = _stock(BAKED)
	if stock.is_empty():
		stock = _stock(RAW)
	var order: Array[StringName] = []
	if stock.is_empty():
		return order
	var total: int = 0
	for item: StringName in stock:
		total += stock[item]
	for i: int in randi_range(1, mini(MAX_ITEMS, total)):
		var item: StringName = stock.keys().pick_random()
		order.append(item)
		stock[item] -= 1
		if stock[item] == 0:
			stock.erase(item)
	order.sort_custom(func(a: StringName, b: StringName) -> bool: return ALL.find(a) < ALL.find(b))
	return order


static func _stock(items: Array[StringName]) -> Dictionary[StringName, int]:
	var stock: Dictionary[StringName, int] = {}
	for item: StringName in items:
		if Basket.count(item) > 0:
			stock[item] = Basket.count(item)
	return stock
