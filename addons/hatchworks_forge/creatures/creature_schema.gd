@tool
class_name ForgeCreatureSchema
extends RefCounted

const LABELS := {
	"id":"ID", "display_name":"Nazwa", "description":"Opis", "scene":"Scena", "icon":"Portret", "ai_graph":"Reguły wyboru działań",
	"hold_height":"Wysokość podnoszenia", "follow_speed":"Podążanie za dłonią", "rotation_speed":"Szybkość obracania", "maximum_tilt":"Przechylenie podczas przenoszenia",
	"walk_speed":"Bazowa prędkość szarży", "swim_speed":"Prędkość pływania", "minimum_swim_depth":"Głębokość rozpoczęcia pływania", "bathing_seconds":"Czas kąpieli",
	"shaking_seconds":"Czas otrząsania", "resting_seconds":"Przerwa przed ponowieniem próby", "grass_per_cycle":"Kępy trawy na jedną pracę", "grass_radius":"Promień tworzenia trawy",
	"food_resource":"Pokarm", "food_per_feeding":"Pokarm na posiłek", "feeding_seconds":"Czas jedzenia", "breeding_seconds":"Czas rozrodu",
	"breeding_cooldown":"Przerwa pomiędzy rozrodami", "breeding_min_satiety":"Najedzenie potrzebne do rozrodu", "breeding_satiety_cost":"Koszt najedzenia każdego rodzica",
	"satiety_seconds":"Czas spadku najedzenia ze 100 do 0", "feeding_threshold":"Najedzenie rozpoczynające szukanie pokarmu", "satiety_per_meal":"Najedzenie przywracane przez posiłek",
	"leisure_seconds_min":"Najkrótszy odpoczynek", "leisure_seconds_max":"Najdłuższy odpoczynek",
	"unhappy_threshold":"Granica nieszczęśliwego nastroju", "happy_threshold":"Granica szczęśliwego nastroju", "happiness_response_seconds":"Czas zmiany zadowolenia o 100 punktów",
	"terrain_happiness_penalty":"Maksymalna kara za brak podłoża", "preferred_area":"Sucha powierzchnia na stworka", "company_radius":"Zasięg towarzystwa", "noise_sensitivity":"Wrażliwość na hałas",
	"crowding_sensitivity":"Wrażliwość na tłok", "species_aversions":"Niechęć do innych gatunków", "breeding_call_seconds":"Czas nawoływania",
	"requires_water":"Rozród wymaga dostępu do wody", "habitat_ground":"Podłoże wymagane do rozrodu", "production":"Rola podstawowa", "female_production":"Rola samicy",
	"production_seconds":"Czas jednej pracy", "impact_time":"Moment efektu w cyklu pracy", "production_radius":"Zasięg szukania lokalnej pracy",
	"terrain_minimums":"Podstawowy profil podłoża", "female_terrain_minimums":"Profil podłoża samicy",
	"production_limit":"Lokalny limit obiektów", "impact_radius":"Promień przekształcania podłoża", "impact_strength":"Siła deformacji gruntu", "impact_damage":"Obrażenia jednego trafienia", "aggression_cooldown":"Odpoczynek po ataku"
}
const GROUPS := {
	"identity":"Tożsamość", "wellbeing":"Zadowolenie", "feeding":"Jedzenie", "landscape":"Krajobraz regionu", "work":"Praca", "rest":"Odpoczynek", "breeding":"Rozmnażanie", "movement":"Ruch", "aggression":"Agresja", "handling":"Podnoszenie", "advanced":"Zaawansowane"
}
const ENUMS := {"None":"Dziedzicz rolę podstawową", "Gardener":"Sadzenie drzew", "Quarry":"Produkcja kamienia", "Herbalist":"Produkcja ziół", "Sand Maker":"Produkcja piasku"}
const SECTIONS := {
	"identity":["display_name","description"],
	"wellbeing":["terrain_happiness_penalty","preferred_area","company_radius","noise_sensitivity","crowding_sensitivity","species_aversions","unhappy_threshold","happy_threshold","happiness_response_seconds"],
	"feeding":["food_per_feeding","feeding_seconds","satiety_seconds","feeding_threshold","satiety_per_meal"],
	"landscape":["terrain_minimums","female_terrain_minimums"],
	"work":["bathing_seconds","shaking_seconds","grass_per_cycle","grass_radius","production_seconds","impact_time","production_radius","production_limit","impact_radius","impact_strength"],
	"rest":["leisure_seconds_min","leisure_seconds_max","resting_seconds"],
	"breeding":["breeding_call_seconds","breeding_seconds","breeding_cooldown","breeding_min_satiety","breeding_satiety_cost","requires_water","habitat_ground"],
	"movement":["swim_speed","minimum_swim_depth","rotation_speed"],
	"aggression":["impact_damage","aggression_cooldown","walk_speed"],
	"handling":["hold_height","follow_speed","maximum_tilt"],
	"advanced":["ai_graph"]
}
const DESCRIPTIONS := {
	"identity":"Teksty używane w grze. Model i portret są przypisane do gatunku poza tym formularzem.",
	"wellbeing":"Warunki życia i reakcja nastroju. Wrażliwość 0 oznacza brak wpływu, 1 pełny wpływ.",
	"feeding":"Wszystkie obecne karmniki podają włókno roślinne. Parametry dotyczą obu płci.",
	"landscape":"Minimum podłoża liczone z suchego lądu regionu. Cel jest wspólny dla mieszkańców, nie mnoży się przez ich liczbę.",
	"work":"Jedna udana praca zwiększa licznik serii. Nastrój wybiera 1, 2 albo 3 prace przed odpoczynkiem.",
	"rest":"Długość zwykłej przerwy i ponawianie pracy, kiedy brakuje warunków. Gatunek nie ma statystyki energii.",
	"breeding":"Warunki po wybraniu rozrodu przez gracza. Podłoże i dostęp do wody w tej sekcji dotyczą rozrodu.",
	"movement":"Pływanie i obracanie. Zwykły chód jest dopasowany do kroku aktualnego modelu.",
	"aggression":"Obie płcie Pebblita mogą atakować, kiedy są nieszczęśliwe. Po każdym trafieniu odpoczywają.",
	"handling":"Reakcja na podniesienie i przesuwanie przez gracza.",
	"advanced":"Zaawansowane reguły grafu AI. Puste ustawienie korzysta z domyślnych priorytetów gatunku."
}
const HELP := {
	"terrain_happiness_penalty":"Brak preferowanego podłoża odejmuje tyle punktów zadowolenia. Kara maleje proporcjonalnie do spełnienia wspólnego minimum regionu i znika przy jego osiągnięciu.",
	"preferred_area":"Kara za tłok zanika, gdy na mieszkańca przypada co najmniej tyle suchego terenu. Liczą się wszystkie gatunki w regionie.",
	"company_radius":"Towarzyszem jest inny osobnik tego samego gatunku w tym samym regionie i w tym zasięgu.",
	"species_aversions":"Niechęć działa na cały wspólny region. Więcej osobników obcego gatunku nie zwiększa jej siły.",
	"unhappy_threshold":"Poniżej tej wartości seria ma jedną pracę. Pebblit może wtedy zaatakować konstrukcję.",
	"happy_threshold":"Od tej wartości seria ma trzy prace. Pomiędzy progami seria ma dwie prace.",
	"happiness_response_seconds":"Określa szybkość dążenia do warunków życia, a nie opóźnienie przed ich odczytaniem.",
	"terrain_minimums":"Wspólne minimum preferowanego podłoża w regionie. Tuftling tworzy trawę, samiec Pebblita skałę; Rootle i Bloomlet sadzą wyłącznie rośliny.",
	"female_terrain_minimums":"Samica Pebblita tworzy piasek. Pozostałe samice mogą mieć inne minimum trawy. Pusty profil dziedziczy podstawowy.",
	"impact_time":"Po tylu sekundach od początku pracy powstaje jej efekt. Wartość musi zmieścić się w czasie całego cyklu.",
	"production_limit":"Łączna liczba właściwych roślin, złóż albo kamyków w zasięgu pracy. Limit obiektów nie blokuje tworzenia brakującego podłoża.",
	"impact_radius":"Zasięg zmiany podłoża Pebblita. W przypadku ogrodników określa odstęp od budynków powiększany o 0,25 m.",
	"impact_strength":"Wysokość fałd gruntu tworzonych przez samca Pebblita przy zmianie podłoża na skalne.",
	"walk_speed":"Samiec szarżuje z 2,5-krotnością tej wartości. Zwykły chód pozostaje ograniczony krokiem modelu.",
	"habitat_ground":"Wystarczy obecność tego podłoża w regionie. To odrębny warunek od procentowego minimum krajobrazu.",
	"breeding_call_seconds":"Minimalny czas nawoływania. Partner musi jeszcze podejść do nawołującego osobnika.",
	"minimum_swim_depth":"Pływanie kończy się przy głębokości mniejszej o 0,1 m, co ogranicza przełączanie na brzegu.",
	"resting_seconds":"Czas przed ponowieniem próby, gdy brakuje wody, miejsca lub poprawnego zadania.",
	"grass_per_cycle":"Maksymalna liczba kęp w jednej pracy. Wolne miejsce może ograniczyć rzeczywisty wynik."
}
const SECONDS := ["bathing_seconds","shaking_seconds","resting_seconds","feeding_seconds","breeding_seconds","breeding_cooldown","satiety_seconds","leisure_seconds_min","leisure_seconds_max","happiness_response_seconds","breeding_call_seconds","production_seconds","impact_time","aggression_cooldown"]
const METRES := ["hold_height","company_radius","grass_radius","production_radius","impact_radius","minimum_swim_depth"]
const PERCENT := ["feeding_threshold","satiety_per_meal","unhappy_threshold","happy_threshold","breeding_min_satiety","breeding_satiety_cost"]
const TUFTLING_ONLY := ["bathing_seconds","shaking_seconds","grass_per_cycle","grass_radius"]
const ECOSYSTEM_ONLY := ["production_seconds","impact_time","production_radius","production_limit","impact_radius"]
const PEBBLIT_ONLY := ["impact_strength","impact_damage","aggression_cooldown","walk_speed"]

static func describe(fields: Array, resource: CreatureSpecies, database: GameDatabase) -> Array:
	for field: Dictionary in fields:
		var name := str(field.name)
		field.label = LABELS.get(name,name)
		field.description = HELP.get(name,"")
		field.unit = "s" if name in SECONDS else ("m" if name in METRES else ("%" if name in PERCENT else ""))
		if name == "preferred_area":
			field.unit = "m²"
		elif name == "terrain_happiness_penalty":
			field.unit = "pkt"
		elif name in ["walk_speed","swim_speed"]:
			field.unit = "m/s"
		elif name == "maximum_tilt":
			field.unit = "rad"
		for section: String in SECTIONS:
			if name in SECTIONS[section]:
				field.group = section
				field.group_label = GROUPS[section]
				field.group_description = DESCRIPTIONS[section]
				break
		if name == "impact_radius" and resource.id in [&"rootle",&"bloomlet"]:
			field.label = "Odstęp miejsca pracy od budynków"
		if name == "terrain_minimums":
			field.description = "Minimum skalnego podłoża tworzonego przez samce. Po osiągnięciu celu nadal powstają złoża." if resource.id == &"pebblit" else ("Minimum trawy wspólne dla Tuftlingów w regionie. Po osiągnięciu celu nadal powstają kępy." if resource.id == &"tuftling" else "Minimum trawy wpływające na zadowolenie. Gatunek sadzi wyłącznie rośliny i sam nie przekształca podłoża.")
		elif name == "female_terrain_minimums":
			field.description = "Minimum piasku tworzonego przez samice. Wyłączenie osobnego profilu włącza wspólny profil skały, której samica sama nie tworzy." if resource.id == &"pebblit" else "Samica domyślnie dziedziczy minimum trawy. Włącz osobny profil, aby ustawić dla niej inną wartość."
		if name == "habitat_ground":
			field.options = [{"value":-1,"label":"Dowolne podłoże"},{"value":0,"label":"Trawa"},{"value":1,"label":"Gleba"},{"value":3,"label":"Piasek"},{"value":4,"label":"Skała"}]
		if name in ["terrain_minimums","female_terrain_minimums"]:
			var kind := ("sand" if name == "female_terrain_minimums" else "rock") if resource.id == &"pebblit" else "grass"
			field.mapping_options = [{"key":kind,"label":{"grass":"Trawa","rock":"Skała","sand":"Piasek"}[kind]}]
			field.mapping_known_options = [{"key":"grass","label":"Trawa"},{"key":"soil","label":"Gleba"},{"key":"sand","label":"Piasek"},{"key":"rock","label":"Skała"}]
			field.mapping_scale = 1.0
			field.inherited_value = resource.terrain_minimums
		elif name == "species_aversions":
			field.mapping_options = []
			for other: CreatureSpecies in database.creatures:
				if other != null:
					field.mapping_options.append({"key":str(other.id),"label":other.display_name})
			field.mapping_scale = 100.0
			field.mapping_known_options = field.mapping_options.duplicate(true)
	return fields

static func visible_fields(entry: Dictionary, changes: Dictionary) -> Array:
	var result: Array = []
	var id := str(entry.get("id",""))
	for section: String in SECTIONS:
		for name: String in SECTIONS[section]:
			if name in TUFTLING_ONLY and id != "tuftling":
				continue
			if name in ECOSYSTEM_ONLY and id == "tuftling":
				continue
			if name in PEBBLIT_ONLY and id != "pebblit":
				continue
			for original: Dictionary in entry.get("fields",[]):
				if original.name != name or not original.editable:
					continue
				var field := original.duplicate(true)
				if name == "female_terrain_minimums":
					field.inherited_value = changes.get("terrain_minimums",_value(entry,{},"terrain_minimums"))
				if name == "species_aversions":
					field.mapping_options = field.mapping_options.filter(func(option: Dictionary): return str(option.key) != id)
				result.append(field)
	return result

static func validation_error(entry: Dictionary, changes: Dictionary) -> String:
	var fields := {}
	var known_ids: Array = []
	for field: Dictionary in entry.get("fields",[]):
		fields[str(field.name)] = field
		if field.name == "species_aversions":
			for option: Dictionary in field.get("mapping_options",[]):
				known_ids.append(str(option.key))
	var errors := PackedStringArray()
	for name: Variant in changes:
		if not fields.has(str(name)) or not fields[str(name)].editable:
			errors.append("Pole nie jest edytowalne: "+str(name))
			continue
		var field: Dictionary = fields[str(name)]
		var issue := field_error(field,changes[name],known_ids)
		if not issue.is_empty():
			errors.append(str(field.label)+": "+issue)
	for pair: Array in [["unhappy_threshold","happy_threshold"],["leisure_seconds_min","leisure_seconds_max"],["impact_time","production_seconds"]]:
		var first: Variant = _value(entry,changes,pair[0])
		var last: Variant = _value(entry,changes,pair[1])
		if (first is int or first is float) and (last is int or last is float):
			if float(first) > float(last) or (pair[0] == "unhappy_threshold" and is_equal_approx(float(first),float(last))):
				errors.append(str(LABELS[pair[0]])+" musi być "+("mniejsze od " if pair[0] == "unhappy_threshold" else "nie większe niż ")+str(LABELS[pair[1]]).to_lower()+".")
	return "\n".join(errors)

static func field_error(field: Dictionary, value: Variant, known_ids: Array) -> String:
	match int(field.type):
		TYPE_STRING, TYPE_STRING_NAME:
			if not (value is String or value is StringName) or str(value).length() > 16000:
				return "Wymagany tekst do 16000 znaków."
		TYPE_BOOL:
			if not value is bool:
				return "Wymagana wartość logiczna."
		TYPE_INT, TYPE_FLOAT:
			if not (value is int or value is float) or not is_finite(float(value)):
				return "Wymagana skończona liczba."
			if int(field.type) == TYPE_INT and float(value) != floorf(float(value)):
				return "Wymagana liczba całkowita."
			if int(field.hint) == PROPERTY_HINT_RANGE:
				var limits: PackedStringArray = str(field.hint_string).split(",")
				if float(value) < float(limits[0]) or float(value) > float(limits[1]):
					return "Wartość poza zakresem %s–%s." % [limits[0],limits[1]]
			if not field.options.is_empty() and not field.options.any(func(option: Dictionary): return float(option.value) == float(value)):
				return "Nieznana opcja."
		TYPE_DICTIONARY:
			if not value is Dictionary:
				return "Wymagany poprawny obiekt JSON."
	if field.name in ["terrain_minimums","female_terrain_minimums"]:
		return GameDatabaseValidator.terrain_minimums_error(value)
	if field.name == "species_aversions" and value is Dictionary:
		for key: Variant in value:
			if str(key) not in known_ids or not (value[key] is int or value[key] is float) or not is_finite(float(value[key])) or float(value[key]) < 0.0 or float(value[key]) > 1.0:
				return "Wybierz gatunek i siłę niechęci od 0 do 100%."
	if field.name == "ai_graph":
		return CreatureAiGraph.validate(value)
	return ""

static func _value(entry: Dictionary, changes: Dictionary, name: String) -> Variant:
	if changes.has(name):
		return changes[name]
	for field: Dictionary in entry.get("fields",[]):
		if field.name == name:
			return field.value
	return null
