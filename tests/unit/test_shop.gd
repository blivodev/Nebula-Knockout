extends GutTest
## Covers the Item Shop UI (docs/ARCHITECTURE.md, Item Shop & Economy):
## category filtering, the purchase path, and gold/inventory side effects.

const ItemShopScene: PackedScene = preload("res://ui/shop/ItemShop.tscn")

func before_each() -> void:
	ItemDatabase.reload()
	PlayerInventory.clear_all()
	MatchEconomy._gold.clear()
	MatchEconomy._kill_streak.clear()
	MatchEconomy._passive_accum.clear()

func _make_shop(gold: int) -> ItemShop:
	MatchEconomy.register_player(0, gold)
	var shop: ItemShop = ItemShopScene.instantiate() as ItemShop
	shop.player_id = 0
	add_child_autofree(shop)
	return shop

func test_shop_builds_rows_for_default_category() -> void:
	var shop: ItemShop = _make_shop(1000)
	# Default category is DAMAGE, which has exactly one authored item
	# (siegebreaker_gauntlets).
	assert_eq(shop.get_visible_item_count(), 1)

func test_switching_category_rebuilds_the_list() -> void:
	var shop: ItemShop = _make_shop(1000)
	shop.select_category(ItemDefinition.Category.UTILITY)
	# hunters_hardtack, cloud_architects_cloak, glycerin_treads,
	# liquid_mesh_network, wayfarers_compass = 5
	assert_eq(shop.get_visible_item_count(), 5)

func test_purchase_deducts_gold_and_adds_item() -> void:
	var shop: ItemShop = _make_shop(1000)
	var item: ItemDefinition = ItemDatabase.get_item(&"siegebreaker_gauntlets") # 450g
	assert_true(shop.try_purchase(item), "purchase should succeed with enough gold")
	assert_eq(MatchEconomy.get_gold(0), 550, "450 should have been deducted from 1000")
	assert_true(PlayerInventory.owns(0, &"siegebreaker_gauntlets"))

func test_purchase_fails_without_enough_gold() -> void:
	var shop: ItemShop = _make_shop(100)
	var item: ItemDefinition = ItemDatabase.get_item(&"siegebreaker_gauntlets") # 450g
	assert_false(shop.try_purchase(item), "purchase should fail with insufficient gold")
	assert_eq(MatchEconomy.get_gold(0), 100, "gold must be unchanged on a failed purchase")
	assert_false(PlayerInventory.owns(0, &"siegebreaker_gauntlets"))

func test_purchase_emits_success_signal() -> void:
	var shop: ItemShop = _make_shop(1000)
	var item: ItemDefinition = ItemDatabase.get_item(&"siegebreaker_gauntlets")
	watch_signals(shop)
	shop.try_purchase(item)
	assert_signal_emitted_with_parameters(shop, "purchase_succeeded", [0, item])

func test_purchase_failure_emits_signal() -> void:
	var shop: ItemShop = _make_shop(0)
	var item: ItemDefinition = ItemDatabase.get_item(&"siegebreaker_gauntlets")
	watch_signals(shop)
	shop.try_purchase(item)
	assert_signal_emitted(shop, "purchase_failed")
