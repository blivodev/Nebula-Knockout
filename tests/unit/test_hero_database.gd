extends GutTest
## Verifies the four proof-of-concept heroes (one per class) load through
## the HeroDatabase autoload and each has a complete kit.

const EXPECTED_HERO_IDS: Array[StringName] = [&"kael", &"bastion", &"monk", &"machinist", &"pyra"]

func test_hero_database_loads_all_authored_heroes() -> void:
	HeroDatabase.reload()
	assert_eq(HeroDatabase.count(), 5, "Kael, Bastion, Monk, Machinist, Pyra should all load")

func test_each_expected_hero_is_present() -> void:
	HeroDatabase.reload()
	for hero_id in EXPECTED_HERO_IDS:
		assert_not_null(HeroDatabase.get_hero(hero_id), "missing hero: %s" % hero_id)

func test_each_hero_has_a_complete_kit() -> void:
	HeroDatabase.reload()
	for hero in HeroDatabase.get_all_heroes():
		assert_not_null(hero.skill_1, "%s missing skill_1" % hero.hero_id)
		assert_not_null(hero.skill_2, "%s missing skill_2" % hero.hero_id)
		assert_not_null(hero.skill_3, "%s missing skill_3" % hero.hero_id)
		assert_not_null(hero.ultimate, "%s missing ultimate" % hero.hero_id)

func test_all_four_classes_are_covered() -> void:
	HeroDatabase.reload()
	var classes_present: Dictionary = {}
	for hero in HeroDatabase.get_all_heroes():
		classes_present[hero.hero_class] = true
	assert_true(classes_present.has(HeroDefinition.HeroClass.DAMAGE), "no DAMAGE hero")
	assert_true(classes_present.has(HeroDefinition.HeroClass.TANK), "no TANK hero")
	assert_true(classes_present.has(HeroDefinition.HeroClass.SUPPORT), "no SUPPORT hero")
	assert_true(classes_present.has(HeroDefinition.HeroClass.ENGINEER), "no ENGINEER hero")
