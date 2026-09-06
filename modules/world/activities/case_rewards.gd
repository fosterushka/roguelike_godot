extends RefCounted
## Reward authority for support cases. Presentation only reveals this receipt.

static func award(player: Dictionary, catalog: Dictionary, vehicle: Node3D, source: String, case_id: String, random: RefCounted, guaranteed: Dictionary) -> Dictionary:
	var pool := available(player, catalog, vehicle, source)
	var selected: Dictionary = pool[random.integer(0, pool.size() - 1)].duplicate(true)
	match str(selected.kind):
		"blueprint":
			if not player.has("unlocked_weapons"):
				player.unlocked_weapons = []
			player.unlocked_weapons.append(str(selected.type))
		"salvage":
			player.coins += int(selected.amount)
		"xp":
			player.xp += int(selected.amount)
		"fuel":
			vehicle.fuel += float(selected.amount)
			player.fuel = vehicle.fuel
	return {"id": case_id, "source": source, "pool": pool, "selected": selected, "guaranteed": guaranteed.duplicate(true), "awarded": true}

static func available(player: Dictionary, catalog: Dictionary, vehicle: Node3D, source: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	# Airdrops retain their guaranteed blueprint until every weapon is unlocked.
	if source == "airdrop":
		var types: Array = catalog.keys()
		types.sort()
		for type: String in types:
			if catalog[type].has("projectile") and not player.get("unlocked_weapons", []).has(type):
				pool.append({"id": "blueprint:" + type, "kind": "blueprint", "type": type, "name": str(catalog[type].get("name", type)), "amount": 1})
	if not pool.is_empty():
		return pool
	var amount := 16 + int(player.get("level", 1)) * 2
	pool.append({"id": "salvage", "kind": "salvage", "amount": amount})
	pool.append({"id": "xp", "kind": "xp", "amount": amount})
	var fuel := minf(24.0, maxf(0.0, vehicle.max_fuel - vehicle.fuel))
	if fuel > 0.01:
		pool.append({"id": "fuel", "kind": "fuel", "amount": fuel})
	return pool
