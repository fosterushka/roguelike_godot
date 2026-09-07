extends RefCounted

const RANGE := 12.0
const PREFERRED := {"mechanic": "repair", "shooter": "weapon", "loader": "weapon", "looter": "cargo", "fuel": "fuel", "anti_tank": "anti_tank", "anti_air": "anti_air", "civilian": "cargo"}
const NAMES := [["Мира", "Mira"], ["Роман", "Roman"], ["Ника", "Nika"], ["Лев", "Lev"], ["Ася", "Asya"], ["Борис", "Boris"], ["Тая", "Taya"], ["Марк", "Mark"]]
const STORIES := [
	["Мой караван попал в засаду у соляных вышек. Мне удалось выбраться, но вода и транспорт пропали.", "My convoy was ambushed near the salt towers. I escaped, but lost my water and transport."],
	["Мой дом был у старой насосной станции. Налётчики сожгли наш лагерь. Назад дороги нет.", "I lived by the old pumping station. Raiders burned our camp. There is no going back."],
	["Мы искали пропавший груз в пустоши. Буря разлучила меня с остальными.", "We were looking for a missing shipment. A storm hit and I lost the others."],
	["Пришлось уйти из гарнизона: там начали отбирать еду у беженцев. Теперь ищу новый дом.", "I left the garrison when they started taking food from refugees. Now I need a new home."]
]
const CALLS := [
	["Спасите! Я здесь!", "Help! Over here!"],
	["Эй, странник! Подъедь сюда!", "Hey, traveller! Come over here!"],
	["Помогите! Не оставляйте меня!", "Please help! Don't leave me!"],
	["В караване найдётся место?", "Got room in your convoy?"]
]

static func identity(id: String) -> int:
	return posmod(id.hash(), NAMES.size())

static func distance(person: Dictionary, player: Dictionary, wagons: Array) -> float:
	var best := flat_distance(person.position, player.get("position", Vector3.ZERO))
	for wagon: Dictionary in wagons:
		if not wagon.get("dead", false) and wagon.get("attached", true):
			best = minf(best, flat_distance(person.position, wagon.position))
	return best

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func seat(roster: RefCounted, role: String) -> Dictionary:
	for wagon: Dictionary in roster.wagons:
		if wagon.type == PREFERRED.get(role, ""):
			var found: Dictionary = roster.free_seat(wagon.id)
			if not found.is_empty():
				return found
	return {} if role == "civilian" else roster.free_seat()

static func refusal(roll: float) -> String:
	return "fleeing" if roll < 0.5 else "joining_enemy" if roll < 0.8 else "hostile"
