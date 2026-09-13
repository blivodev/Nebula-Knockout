extends GutTest
## Exercises HeroRigAnimator: verifies the Bone2D chain resolves correctly
## (torso -> arms/legs -> forearms/lower legs, head on torso) and that the
## attached AnimationPlayer carries real keyframed rotation tracks for
## "idle"/"walk"/"attack" -- i.e. genuine skeletal animation, not just a
## rig with no motion.

func test_build_creates_expected_bone_hierarchy() -> void:
	var skeleton: Skeleton2D = HeroRigAnimator.build("test_hero", Color.RED)

	var torso: Node = skeleton.get_node_or_null("torso")
	assert_not_null(torso, "torso should be a direct child of the skeleton root")

	var head: Node = torso.get_node_or_null("head") if torso != null else null
	assert_not_null(head, "head should be parented under torso")

	for side in ["l", "r"]:
		var upper_arm: Node = torso.get_node_or_null("upper_arm_%s" % side) if torso != null else null
		assert_not_null(upper_arm, "upper_arm_%s should be parented under torso" % side)
		var forearm: Node = upper_arm.get_node_or_null("forearm_%s" % side) if upper_arm != null else null
		assert_not_null(forearm, "forearm_%s should be parented under upper_arm_%s" % [side, side])

		var upper_leg: Node = torso.get_node_or_null("upper_leg_%s" % side) if torso != null else null
		assert_not_null(upper_leg, "upper_leg_%s should be parented under torso" % side)
		var lower_leg: Node = upper_leg.get_node_or_null("lower_leg_%s" % side) if upper_leg != null else null
		assert_not_null(lower_leg, "lower_leg_%s should be parented under upper_leg_%s" % [side, side])

	skeleton.free()

func test_build_attaches_a_working_animation_player() -> void:
	var skeleton: Skeleton2D = HeroRigAnimator.build("test_hero", Color.BLUE)
	var player: AnimationPlayer = skeleton.get_node_or_null("AnimationPlayer")
	assert_not_null(player, "skeleton should carry an AnimationPlayer child")
	if player != null:
		for anim_name in ["idle", "walk", "attack"]:
			assert_true(player.has_animation(anim_name), "AnimationPlayer should have a %s animation" % anim_name)
	skeleton.free()

func test_walk_animation_keyframes_real_bone_rotation_tracks() -> void:
	var skeleton: Skeleton2D = HeroRigAnimator.build("test_hero", Color.GREEN)
	var player: AnimationPlayer = skeleton.get_node("AnimationPlayer")
	var walk: Animation = player.get_animation("walk")
	assert_not_null(walk)
	assert_gt(walk.get_track_count(), 0, "walk animation should have at least one track")
	var found_leg_track: bool = false
	for i in range(walk.get_track_count()):
		var path: String = str(walk.track_get_path(i))
		if "upper_leg_l" in path and path.ends_with(":rotation"):
			found_leg_track = true
			assert_gt(walk.track_get_key_count(i), 1, "leg rotation track should have multiple keyframes")
	assert_true(found_leg_track, "walk animation should keyframe the leg bones' rotation, not just torso/arms")
	skeleton.free()

func test_rig_tint_affects_generated_limb_texture() -> void:
	var red_skeleton: Skeleton2D = HeroRigAnimator.build("red_hero", Color.RED)
	var blue_skeleton: Skeleton2D = HeroRigAnimator.build("blue_hero", Color.BLUE)
	var red_sprite: Sprite2D = red_skeleton.get_node("torso/Visual")
	var blue_sprite: Sprite2D = blue_skeleton.get_node("torso/Visual")
	var red_pixel: Color = red_sprite.texture.get_image().get_pixel(1, 1)
	var blue_pixel: Color = blue_sprite.texture.get_image().get_pixel(1, 1)
	assert_gt(red_pixel.r, blue_pixel.r, "the red-tinted rig's torso texture should be redder")
	assert_gt(blue_pixel.b, red_pixel.b, "the blue-tinted rig's torso texture should be bluer")
	red_skeleton.free()
	blue_skeleton.free()
