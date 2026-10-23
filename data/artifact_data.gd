extends Resource
## Static description of one artifact. What it does lives in `effect_script`; the texts are
## translation keys built from the id (ARTIFACT_<ID>_NAME / _DESC / _HINT).

enum Kind { ACTIVE, PASSIVE, CONSUMABLE, CURSED }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, CURSED }

@export var id: StringName
@export var game_id: StringName = &"blackjack"
@export var kind: Kind = Kind.PASSIVE
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export var effect_script: GDScript
## True when the player triggers it with a button; false when it reacts on its own.
@export var button: bool = false
@export var uses_per_hand: int = 0
## Consumables: charges per run, gone for good once spent.
@export var charges: int = 0
## Empty stat means open from the first launch.
@export var unlock_stat: StringName
@export var unlock_value: int = 0

func key(part: String) -> String:
	return "ARTIFACT_%s_%s" % [String(id).to_upper(), part]

func title() -> String:
	return tr(key("NAME"))

func description() -> String:
	return tr(key("DESC"))

func unlock_hint() -> String:
	return tr(key("HINT"))

## Why it opened, in the player's terms: "Won 5 hands". The key is built from the unlock counter.
func unlock_reason() -> String:
	var text := tr("REASON_%s" % String(unlock_stat).to_upper())
	return text % unlock_value if "%d" in text else text

func is_open_from_start() -> bool:
	return unlock_stat == &""
