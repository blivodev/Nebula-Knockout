class_name ItemDefinition
extends Resource
## Data-driven shop item (see docs/ARCHITECTURE.md, Item Shop & Economy).
## Categories exist for shop UI organization ONLY -- any class can buy any
## item; there is no hard gating by hero_class anywhere in this resource.

enum Category { DAMAGE, TANK, UTILITY, MAGIC }

@export var item_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.UTILITY
@export var gold_cost: int = 0
@export var sell_value_ratio: float = 0.5

@export_group("Stat Bonuses")
@export var bonus_max_hp: float = 0.0
@export var bonus_move_speed: float = 0.0
@export var bonus_dash_speed: float = 0.0
@export var bonus_attack_damage: float = 0.0
@export var bonus_ability_power: float = 0.0
@export var bonus_armor: float = 0.0
@export var bonus_cooldown_reduction: float = 0.0

@export_group("Unique Passive")
## Looked up by ItemPassiveRegistry (future work) to trigger bespoke
## behavior, e.g. "cloud_architects_cloak" -> one-charge spell shield.
@export var passive_id: StringName = &""
@export_multiline var passive_description: String = ""

func sell_value() -> int:
	return int(round(gold_cost * sell_value_ratio))
