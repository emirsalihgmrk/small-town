class_name ShopItems
extends RefCounted
## Dükkânın rafındaki ürünler ve fiyatları (kaç bozuk para). Aksesuarlar kızın şapkasının yerine takılır,
## süsler ana ekranda kendi yerlerinde belirir. Kimlikler kayıtta da bu adlarla tutulacak; değiştirmek eski
## kayıtları bozar.

enum Kind { ACCESSORY, DECOR }

const FLOWER_CROWN: StringName = &"flower_crown"
const BOW: StringName = &"bow"
const BUNNY_EARS: StringName = &"bunny_ears"
const CROWN: StringName = &"crown"
const BIRDHOUSE: StringName = &"birdhouse"
const KITE: StringName = &"kite"
const SWING: StringName = &"swing"
const POND: StringName = &"pond"

const ACCESSORIES: Array[StringName] = [FLOWER_CROWN, BOW, BUNNY_EARS, CROWN]
const DECORS: Array[StringName] = [BIRDHOUSE, KITE, SWING, POND]

const PRICES: Dictionary[StringName, int] = {
	FLOWER_CROWN: 2,
	BOW: 3,
	BUNNY_EARS: 4,
	CROWN: 5,
	BIRDHOUSE: 2,
	KITE: 3,
	SWING: 4,
	POND: 5,
}


static func price(item: StringName) -> int:
	return PRICES.get(item, 0)


static func kind(item: StringName) -> Kind:
	return Kind.ACCESSORY if ACCESSORIES.has(item) else Kind.DECOR


## Verilen ürünlerin en ucuzunun fiyatı; liste boşsa -1.
static func cheapest(items: Array[StringName]) -> int:
	var result: int = -1
	for item: StringName in items:
		if result < 0 or price(item) < result:
			result = price(item)
	return result
