class_name Recipes
extends RefCounted
## Fırındaki tarifler ve malzemeleri. Tarifin kimliği pişen ürünün (Items) kimliğidir: ekmek tarifi
## sepete ekmek olarak girer. Kimlikler ileride kayıtta da tutulacak; değiştirmek eski kayıtları bozar.

const BREAD: StringName = Items.BREAD
const COOKIE: StringName = Items.COOKIE
const CARROT_CAKE: StringName = Items.CARROT_CAKE
const BIRTHDAY_CAKE: StringName = Items.BIRTHDAY_CAKE

## Tarif -> malzemeler. Aynı ürün birden çok kez geçebilir (her biri kasede ayrı bir yuva).
const INGREDIENTS: Dictionary[StringName, Array] = {
	BREAD: [Items.WHEAT, Items.WHEAT],
	COOKIE: [Items.WHEAT, Items.EGG],
	CARROT_CAKE: [Items.WHEAT, Items.EGG, Items.CARROT],
	BIRTHDAY_CAKE: [Items.WHEAT, Items.EGG, Items.MILK],
}


static func ingredients(recipe: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(INGREDIENTS.get(recipe, []))
	return result
