class_name CharacterPreview
extends SubViewportContainer
## A character on a little turntable, for the menu's character page. Rebuild with show_look().

var _vp: SubViewport
var _pivot: Node3D
var _model: CharacterModel
var _time := 0.0


func _ready() -> void:
	stretch = true
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.85)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 2.2
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 1.2
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.35, 4.6)
	cam.rotation_degrees.x = -7
	cam.fov = 30
	_vp.add_child(cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)


func show_look(shirt: Color, hat: int, face: int, skin: int, seed_value: int, outfit := 0, character := 0) -> void:
	if _model:
		_model.queue_free()
	_model = CharacterModel.new()
	_model.expressive = Game.expressive_faces
	_pivot.add_child(_model)
	_model.setup(shirt, hat, seed_value, face, skin, outfit, character)
	_model.squash(0.25) # a little hop of joy on every change


func _process(delta: float) -> void:
	_time += delta
	if _model:
		# Mostly facing the camera, swaying side to side to show the hat.
		var yaw := PI + sin(_time * 0.6) * 0.45
		_model.animate(delta, Vector3.ZERO, Player.F_GROUNDED, yaw, false)
		# Show the face off now and then.
		if fmod(_time, 6.0) < delta:
			_model.react(["happy", "grin", "scared", "angry"][int(_time / 6.0) % 4], 1.4)
