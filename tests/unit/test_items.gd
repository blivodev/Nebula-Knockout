extends GutTest
## Covers ItemDatabase + PlayerInventory (docs/ARCHITECTURE.md, Item Shop &
## Economy). Verifies the four required sample items exist, every shop
## category is populated, and item stat bonuses aggregate correctly.

const REQUIRED_SAMPLE_ITEMS: Array[StringName] = [
	&"hunters_hardtack",
	&"cloud_architects_cloak",
	&"glycerin_treads",
	&"liquid_mesh_network",
]

func before_each() -> void:
	ItemDatabase.reload()
	PlayerInventory.clear_all()

func test_item_database_loads_all_items() -> void:
	assert_eq(ItemDatabase.count(), 8, "8 items should be authored")

func test_required_sample_items_exist() -> void:
	for item_id in REQUIRED_SAMPLE_ITEMS:
		assert_not_null(ItemDatabase.get_item(item_id), "missing required item: %s" % item_id)

func test_all_four_categories_are_populated() -> void:
	var present: Dictionary = {}
	for item in ItemDatabase.get_all_items():
		present[item.category] = true
	for category in [
		ItemDefinition.Category.DAMAGE,
		ItemDefinition.Category.TANK,
		ItemDefinition.Category.UTILITY,
		ItemDefinition.Category.MAGIC,
	]:
		assert_true(present.has(category), "no items in category %d" % category)

func test_items_by_category_filters_correctly() -> void:
	var damage_items: Array[ItemDefinition] = ItemDatabase.get_items_by_category(
		ItemDefinition.Category.DAMAGE
	)
	assert_true(damage_items.size() >= 1, "expected at least one Damage item")
	for item in damage_items:
		assert_eq(item.category, ItemDefinition.Category.DAMAGE)

func test_inventory_sums_stat_bonuses_across_items() -> void:
	PlayerInventory.add_item(0, ItemDatabase.get_item(&"glycerin_treads"))  # +40 move, +120 dash
	PlayerInventory.add_item(0, ItemDatabase.get_item(&"hunters_hardtack")) # +150 hp
	var totals: Dictionary = PlayerInventory.get_total_stats(0)
	assert_almost_eq(totals["move_speed"], 40.0, 0.01)
	assert_almost_eq(totals["dash_speed"], 120.0, 0.01)
	assert_almost_eq(totals["max_hp"], 150.0, 0.01)

func test_inventory_owns_then_removes() -> void:
	var item: ItemDefinition = ItemDatabase.get_item(&"glycerin_treads")
	PlayerInventory.add_item(0, item)
	assert_true(PlayerInventory.owns(0, &"glycerin_treads"))
	PlayerInventory.remove_item(0, item)
	assert_false(PlayerInventory.owns(0, &"glycerin_treads"))

func test_any_class_can_own_any_item_no_gating() -> void:
	# Explicitly guards the cross-class-purchase design rule: nothing in the
	# data or inventory layer may reject an item based on hero class.
	PlayerInventory.add_item(0, ItemDatabase.get_item(&"arcanists_codex"))
	assert_true(PlayerInventory.owns(0, &"arcanists_codex"))
