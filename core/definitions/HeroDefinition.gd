class_name HeroDefinition
extends Resource
## Data-driven hero definition. One .tres per hero under res://heroes/,
## loaded automatically by the HeroDatabase autoload -- adding hero #31
## never requires touching engine/GDScript code, only authoring a new
## resource (see docs/ARCHITECTURE.md).

enum HeroClass { DAMAGE, TANK, SUPPORT, ENGINEER }
enum AttackType { MELEE, RANGED, MAGIC }
enum RoleTag { ENGAGE, PEEL, POKE, SPLIT_PUSH, OBJECTIVE }

@export var hero_id: StringName
@export var display_name: String = ""
@export var hero_class: HeroClass = HeroClass.DAMAGE
@export var attack_type: AttackType = AttackType.MELEE
@export var role_tag: RoleTag = RoleTag.ENGAGE

@export_group("Base Stats")
@export var base_max_hp: float = 600.0
@export var base_move_speed: float = 300.0
@export var base_dash_speed: float = 900.0
@export var base_armor: float = 0.0
@export var base_attack_damage: float = 50.0

@export_group("Kit")
@export var skill_1: AbilityDefinition
@export var skill_2: AbilityDefinition
@export var skill_3: AbilityDefinition
@export var ultimate: AbilityDefinition

@export_group("Flavor")
## Which other classes this hero's kit pairs well with -- surfaced in the
## Draft Screen UI as a pick-suggestion hint.
@export var synergy_note: String = ""
@export_multiline var lore_hook: String = ""

@export_group("Art / Animation")
## Populated by the MCP asset pipeline (docs/ARCHITECTURE.md Section 1):
## portrait for draft/shop UI, sprite_frames for in-match flipbook combat
## animation. Skeleton2D/Polygon2D rigs are reserved for menu showcases
## only and are not referenced here.
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames
## The playable scene for this hero (entities/heroes/<id>/<Name>.tscn). The
## match flow loads this to spawn whoever was drafted.
@export_file("*.tscn") var scene_path: String = ""
