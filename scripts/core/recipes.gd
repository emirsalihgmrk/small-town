class_name Recipes
extends RefCounted
## Fırındaki tarifler ve malzemeleri. Kimlikler ileride kayıtta da tutulacak; değiştirmek eski kayıtları bozar.

const BREAD: StringName = &"bread"
const COOKIE: StringName = &"cookie"
const CARROT_CAKE: StringName = &"carrot_cake"

## Tarif -> malzemeler. Aynı ürün birden çok kez geçebilir (her biri kasede ayrı bir yuva).
const INGREDIENTS: Dictionary[StringName, Array] = {
	BREAD: [Items.WHEAT, Items.WHEAT],
	COOKIE: [Items.WHEAT, Items.EGG],
	CARROT_CAKE: [Items.WHEAT, Items.EGG, Items.CARROT],
}


static func ingredients(recipe: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(INGREDIENTS.get(recipe, []))
	return result
