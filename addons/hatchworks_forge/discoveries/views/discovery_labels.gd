@tool
class_name ForgeDiscoveryLabels
extends RefCounted

const CATEGORIES := ["Natura","Materiały","Rośliny","Pojęcia","Jaja","Stworki","Budowle"]

static func categories() -> PackedStringArray:
	return PackedStringArray(CATEGORIES)

static func category_name(category: int) -> String:
	return CATEGORIES[category] if category >= 0 and category < CATEGORIES.size() else "Nieznany typ"

static func title(index: ForgeDiscoveryIndex, id: String) -> String:
	if id.is_empty():
		return "—"
	var entry := index.discovery(id)
	return str(entry.display_name) if not entry.is_empty() else "Brak: "+id

static func equation(index: ForgeDiscoveryIndex, recipe: Dictionary) -> String:
	return "%s + %s → %s" % [title(index,str(recipe.get("first",""))),title(index,str(recipe.get("second",""))),title(index,str(recipe.get("result","")))]

static func icon(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path,"Texture2D"):
		return null
	return load(path) as Texture2D

static func problem_message(index: ForgeDiscoveryIndex, problem: Dictionary) -> String:
	match str(problem.code):
		"duplicate_pair":
			var ids: Array = problem.get("discovery_ids",[])
			if ids.size() == 2:
				return "Powielona para: %s + %s. Występuje w %d recepturach." % [title(index,str(ids[0])),title(index,str(ids[1])),problem.recipe_ids.size()]
		"missing_name":
			return "Nadaj kaflowi nazwę."
		"invalid_icon":
			return "Wybierz istniejący obraz z projektu jako ikonę kafla."
		"invalid_category":
			return "Wybierz poprawny typ kafla."
		"missing_reference":
			return "Wybierz istniejący kafel w każdym polu receptury."
		"invalid_science":
			return "Punkty nauki muszą być liczbą całkowitą od 0 do 1000."
		"invalid_reward":
			return "Liczba przedmiotów w nagrodzie musi wynosić od 0 do 100."
		"missing_reward":
			return "Nagroda wymaga wskazania przedmiotu."
		"invalid_id":
			return "Każdy wpis musi mieć unikalny, niepusty identyfikator."
	return str(problem.message)
