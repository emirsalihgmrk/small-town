class_name Oscillation
extends RefCounted
## Bileşenlerin ortak kullandığı yardımcı: bir özelliği iki değer arasında sonsuz,
## sinüs yumuşatmalı gidip-gelme hareketiyle oynatan Tween kurar.


## Tween, owner düğümüne bağlıdır; owner işlemezken (gizli sahne, arka plan) kendiliğinden durur.
## period: tam bir gidiş-dönüş süresi. period_randomness: süreye eklenen ±oran (senkron görünmesin diye).
static func ping_pong(owner: Node, target: Object, property: NodePath, from: Variant, to: Variant,
		period: float, period_randomness: float = 0.0, random_phase: bool = true) -> Tween:
	var half: float = period * (1.0 + randf_range(-period_randomness, period_randomness)) * 0.5
	target.set_indexed(property, from)
	var tween: Tween = owner.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, property, to, half)
	tween.tween_property(target, property, from, half)
	if random_phase:
		tween.custom_step(randf() * half * 2.0)
	return tween
