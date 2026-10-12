class_name ShopItems
extends RefCounted
## Dükkânın rafındaki ürünler ve fiyatları (kaç bozuk para). Aksesuarlar kızın şapkasının yerine takılır,
## süsler ana ekranda kendi yerlerinde belirir. Duvar rafındaki tohum paketleri tarlada yeni bir ürünü,
## tarif kartları fırında yeni bir tarifi açar; bir ürünün tarif kartı, o ürünün tohumu alınmadan rafta
## görünmez (çocuk yapamayacağı tarifi almasın). Kimlikler kayıtta da bu adlarla tutulacak; değiştirmek eski
## kayıtları bozar.

enum Kind { ACCESSORY, DECOR, SEED, RECIPE }

const FLOWER_CROWN: StringName = &"flower_crown"
const BOW: StringName = &"bow"
const BUNNY_EARS: StringName = &"bunny_ears"
const CROWN: StringName = &"crown"
const BIRDHOUSE: StringName = &"birdhouse"
const KITE: StringName = &"kite"
const SWING: StringName = &"swing"
const POND: StringName = &"pond"
const STRAWBERRY_SEEDS: StringName = &"strawberry_seeds"
const PUMPKIN_SEEDS: StringName = &"pumpkin_seeds"
const SIMIT_RECIPE: StringName = &"simit_recipe"
const STRAWBERRY_CAKE_RECIPE: StringName = &"strawberry_cake_recipe"
const PUMPKIN_PIE_RECIPE: StringName = &"pumpkin_pie_recipe"

const ACCESSORIES: Array[StringName] = [FLOWER_CROWN, BOW, BUNNY_EARS, CROWN]
const DECORS: Array[StringName] = [BIRDHOUSE, KITE, SWING, POND]
const SEEDS: Array[StringName] = [STRAWBERRY_SEEDS, PUMPKIN_SEEDS]
const RECIPES: Array[StringName] = [SIMIT_RECIPE, STRAWBERRY_CAKE_RECIPE, PUMPKIN_PIE_RECIPE]

const PRICES: Dictionary[StringName, int] = {
	FLOWER_CROWN: 2,
	BOW: 3,
	BUNNY_EARS: 4,
	CROWN: 5,
	BIRDHOUSE: 2,
	KITE: 3,
	SWING: 4,
	POND: 5,
	SIMIT_RECIPE: 2,
	STRAWBERRY_SEEDS: 3,
	STRAWBERRY_CAKE_RECIPE: 4,
	PUMPKIN_SEEDS: 4,
	PUMPKIN_PIE_RECIPE: 5,
}

## Tarlada ancak tohumu alınınca ekilebilen ürünler (Items kimliği -> tohum paketi).
const SEEDS_FOR: Dictionary[StringName, StringName] = {
	Items.STRAWBERRY: STRAWBERRY_SEEDS,
	Items.PUMPKIN: PUMPKIN_SEEDS,
}
## Fırında ancak kartı alınınca görünen tarifler (Recipes kimliği -> tarif kartı).
const RECIPE_CARDS: Dictionary[StringName, StringName] = {
	Recipes.SIMIT: SIMIT_RECIPE,
	Recipes.STRAWBERRY_CAKE: STRAWBERRY_CAKE_RECIPE,
	Recipes.PUMPKIN_PIE: PUMPKIN_PIE_RECIPE,
}
## Rafta ancak bir başka ürün alınınca beliren ürünler (ürün -> önce alınması gereken).
const NEEDS: Dictionary[StringName, StringName] = {
	STRAWBERRY_CAKE_RECIPE: STRAWBERRY_SEEDS,
	PUMPKIN_PIE_RECIPE: PUMPKIN_SEEDS,
}


static func price(item: StringName) -> int:
	return PRICES.get(item, 0)


static func kind(item: StringName) -> Kind:
	if ACCESSORIES.has(item):
		return Kind.ACCESSORY
	if SEEDS.has(item):
		return Kind.SEED
	if RECIPES.has(item):
		return Kind.RECIPE
	return Kind.DECOR


## Verilen ürünlerin en ucuzunun fiyatı; liste boşsa -1.
static func cheapest(items: Array[StringName]) -> int:
	var result: int = -1
	for item: StringName in items:
		if result < 0 or price(item) < result:
			result = price(item)
	return result
