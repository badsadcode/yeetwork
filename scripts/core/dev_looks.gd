extends Node
## Developer tool: every hat and every head attachment in a line-up, front and three-quarter.
## Usage: godot -- --host --map prime --bots 0 --tour <dir> --tour-mode looks

var world: Node
var out_dir := ""


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var pl: Player = world.local_player
	pl.is_bot = true
	pl.bot_brain = null
	pl.set_physics_process(false)
	pl.model.visible = false
	world.hud.visible = false
	Game.fov = 34.0 # close-up lens (not saved)
	# Floating in the sky above the map: nothing in the way, sky behind.
	var moods: Array = CharacterModel.MOODS.keys()
	var rows := [CharacterModel.HAT_COUNT, CharacterModel.FACE_NAMES.size(), moods.size() + 1, 5]
	var noor_moods := ["", "grin", "scared", "angry", "dizzy"]
	var groups := []
	for row in 4:
		var models: Array[CharacterModel] = []
		for i in rows[row]:
			var m := CharacterModel.new()
			world.add_child(m)
			var col: Color = Game.FFA_COLORS[i % Game.FFA_COLORS.size()]
			if row == 0:
				m.setup(col, i, i + 3)
			elif row == 1:
				m.setup(col, 0, i + 3, i, i % CharacterModel.SKINS.size())
			elif row == 2 and i < moods.size():
				m.setup(col, 0, i + 3, 0, 0)
				m.react(moods[i], 1000.0)
			elif row == 2: # the tribute captain
				m.setup(Color(0.75, 0.12, 0.15), CharacterModel.HAT_CAPTAIN, 7, 0, 0, 1)
			else: # Noor Yeet in a few moods, scarves in different colours
				m.setup(col, 0, i + 3, 0, -1, 0, CharacterModel.NOOR)
				if noor_moods[i] != "":
					m.react(noor_moods[i], 1000.0)
			m.global_position = Vector3(0, 120, row * 40.0 + i * 1.4)
			models.append(m)
		for g in range(0, models.size(), 5):
			groups.append([["hats", "extras", "moods", "noor"][row] + str(g / 5), models.slice(g, g + 5)])
	for group in groups:
		var ms: Array = group[1]
		var center := Vector3.ZERO
		for m in ms:
			center += m.global_position
		center /= ms.size()
		for yaw_name in [["front", -PI * 0.5], ["side", -PI * 0.5 + 0.7]]:
			for m in ms:
				for k in 30:
					m.animate(0.05, Vector3.ZERO, Player.F_GROUNDED, yaw_name[1], false)
			var target := center + Vector3(0, 1.15, 0)
			var eye := target + Vector3(5.2, 0.5, 0)
			var to := target - eye
			pl.global_position = eye - Vector3(0, Player.EYE_STAND, 0)
			pl.yaw = atan2(-to.x, -to.z)
			pl.pitch = atan2(to.y, Vector2(to.x, to.z).length())
			await get_tree().create_timer(0.4).timeout
			if pl.gun:
				pl.gun.set_viewmodel_visible(false)
				pl.gun._world_model.visible = false
			await get_tree().process_frame
			var path := "%s/looks_%s_%s.png" % [out_dir, group[0], yaw_name[0]]
			get_viewport().get_texture().get_image().save_png(path)
			print("Saved ", path.get_file())
	get_tree().quit()
