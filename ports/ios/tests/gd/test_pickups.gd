extends RefCounted
# Zbieranie kulek (życie / przyspieszenie strzelania): na iOS promień zbierania kulki rośnie
# z 0.45 do PICKUP_COLLECT_RADIUS = 0.9 (main.gd), bez zmiany scripts/pickup.gd.
# Gracz to kapsuła o promieniu 0.55 → kontakt w poziomie: dawniej 1.0, teraz 1.45 j.

const RADIUS := 0.9


func _shape(p: Node) -> SphereShape3D:
	for c in p.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is SphereShape3D:
			return (c as CollisionShape3D).shape
	return null


func _game(t) -> Node:
	var main: Node = await t.spawn_main()
	main._start_run()
	await t.frames(2)
	main.player.global_position = Vector3.ZERO
	await t.frames(2)
	return main


## Drops a pickup `dist` units right of the player and reports whether it was collected.
func _collected_at(t, main: Node, kind: String, dist: float) -> bool:
	var p: Node = main.pickup_pool[0]
	p.setup(kind, Vector3(dist, 0.0, 0.0))
	for i in 10:
		await t.physics_frame  # Area3D overlap is detected on physics ticks
	return not p.visible


func test_collect_radius_constant(t) -> void:
	var script: Script = load("res://scripts/main.gd")
	t.approx(RADIUS, float(script.get_script_constant_map().get("PICKUP_COLLECT_RADIUS", -1.0)), "main.gd: PICKUP_COLLECT_RADIUS = 0.9")


func test_pool_pickups_use_collect_radius(t) -> void:
	var main: Node = await _game(t)
	t.ok(main.pickup_pool.size() > 0, "pickup pool not empty")
	for p in main.pickup_pool:
		var s := _shape(p)
		t.ok(s != null, "pickup has a sphere collision shape")
		if s != null:
			t.approx(RADIUS, s.radius, "pickup collision radius 0.9")


func test_pickup_collected_at_close_range(t) -> void:
	var main: Node = await _game(t)
	t.eq(true, await _collected_at(t, main, "overdrive", 0.8), "0.8 j. from the player → collected (as before)")


func test_pickup_collected_within_new_radius(t) -> void:
	var main: Node = await _game(t)
	t.eq(true, await _collected_at(t, main, "overdrive", 1.35), "1.35 j. (beyond old 1.0 and 1.3 contact) → collected")


func test_heal_collected_within_new_radius(t) -> void:
	var main: Node = await _game(t)
	main.player.hp = 50.0
	var before: float = main.player.hp
	t.eq(true, await _collected_at(t, main, "heal", 1.35), "heal 1.35 j. away → collected")
	t.ok(main.player.hp > before, "heal restores HP (%.1f → %.1f)" % [before, main.player.hp])


func test_pickup_not_collected_beyond_radius(t) -> void:
	var main: Node = await _game(t)
	t.eq(false, await _collected_at(t, main, "overdrive", 1.6), "1.6 j. (beyond new 1.45 contact) → stays on the floor")
