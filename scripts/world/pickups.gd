@tool
class_name Pickups
extends RefCounted
## What each pickup is: its name, colour, how long its boost lasts, how soon it comes back,
## and its model (simple shapes, readable from across the map).
## - health: +50 HP. health_big: +100 HP. (Never above 100.)
## - speed: run 40% faster. super ("Super Yeet"): throws, punts and launches 1.8x stronger.
## - feather: low gravity, high jumps. iron ("Iron Yeet"): can't be grabbed or knocked
##   about, half damage.

const INFO := {
	"health": {"name": "First aid", "color": Color(1.0, 0.25, 0.3), "heal": 50.0, "respawn": 20.0},
	"health_big": {"name": "Big first aid", "color": Color(1.0, 0.25, 0.3), "heal": 100.0, "respawn": 40.0},
	"speed": {"name": "SPEED", "color": Color(0.3, 0.7, 1.0), "time": 12.0, "respawn": 35.0},
	"super": {"name": "SUPER YEET", "color": Color(1.0, 0.55, 0.12), "time": 15.0, "respawn": 40.0},
	"feather": {"name": "FEATHER", "color": Color(0.55, 1.0, 0.95), "time": 12.0, "respawn": 35.0},
	"iron": {"name": "IRON YEET", "color": Color(0.72, 0.75, 0.82), "time": 12.0, "respawn": 40.0},
}
const POWERUPS := ["speed", "super", "feather", "iron"]
const RANDOM_PREVIEW := "super" # what a random pickup shows in the editor

## Boost strengths.
const SPEED_MULT := 1.4
const SUPER_MULT := 1.8
const FEATHER_GRAVITY := 0.45
const FEATHER_JUMP := 1.35
const IRON_DAMAGE := 0.5
const IRON_KNOCKBACK := 0.2


static func is_powerup(kind: String) -> bool:
	return kind in POWERUPS


static func color_of(kind: String) -> Color:
	return INFO.get(kind, INFO.health).color


static func name_of(kind: String) -> String:
	return INFO.get(kind, INFO.health).name


static func duration(kind: String) -> float:
	return INFO.get(kind, {}).get("time", 0.0)


static func respawn_time(kind: String) -> float:
	return INFO.get(kind, INFO.health).respawn


## The floating item for a kind (spun and bobbed by its PickupSpawn).
static func build_model(kind: String) -> Node3D:
	var root := Node3D.new()
	var col := color_of(kind)
	match kind:
		"health", "health_big":
			var s := 1.3 if kind == "health" else 1.7
			_box(root, Vector3(0.42, 0.34, 0.42) * s, Color(0.96, 0.96, 0.97), Vector3.ZERO)
			_box(root, Vector3(0.16, 0.06, 0.1) * s, Color(0.3, 0.3, 0.35), Vector3(0, 0.2, 0) * s) # handle
			for side in 4: # a red cross on every side
				var face := Node3D.new()
				face.rotation.y = side * PI * 0.5
				root.add_child(face)
				_box(face, Vector3(0.24, 0.07, 0.02) * s, col, Vector3(0, 0, 0.215) * s, true)
				_box(face, Vector3(0.07, 0.24, 0.02) * s, col, Vector3(0, 0, 0.215) * s, true)
		"speed":
			for i in 2: # two chevrons: >>
				for side in [-1, 1]:
					var b := _box(root, Vector3(0.32, 0.09, 0.1), col, Vector3(-0.08 + i * 0.2, side * 0.1, 0), true)
					b.rotation.z = side * -0.75
		"super":
			_sphere(root, 0.16, col, Vector3.ZERO, true)
			for i in 8: # a star burst
				var a := i * TAU / 8.0
				var spike := _cone(root, 0.07, 0.3, col, Vector3(cos(a), sin(a), 0) * 0.22)
				spike.rotation.z = a - PI * 0.5
		"feather":
			var vane := _sphere(root, 0.3, col.lightened(0.3), Vector3(0, 0.05, 0), true)
			vane.scale = Vector3(0.38, 1.0, 0.08)
			vane.rotation.z = 0.35
			var quill := _cone(root, 0.02, 0.62, Color(0.95, 0.95, 1.0), Vector3(0.02, -0.02, 0))
			quill.rotation.z = 0.35
		"iron":
			var steel := StandardMaterial3D.new()
			steel.albedo_color = col
			steel.metallic = 0.9
			steel.roughness = 0.25
			var block := _box(root, Vector3(0.42, 0.3, 0.3), col, Vector3.ZERO)
			block.material_override = steel
			var top := _box(root, Vector3(0.56, 0.08, 0.34), col, Vector3(0, 0.19, 0))
			top.material_override = steel
			_box(root, Vector3(0.44, 0.05, 0.32), Color(0.35, 0.38, 0.45), Vector3(0, -0.02, 0))
	if is_powerup(kind):
		# A faint glowing shell and a light, so it reads as special from afar.
		var shell := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.42
		sm.height = 0.84
		sm.radial_segments = 20
		sm.rings = 10
		shell.mesh = sm
		var g := Color(col.r, col.g, col.b, 0.18)
		shell.material_override = Mats.glow(g, 0.6, true)
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shell)
	var light := OmniLight3D.new()
	light.light_color = col
	light.omni_range = 2.5
	light.light_energy = 0.9
	root.add_child(light)
	return root


static func _mat(color: Color, glow: bool) -> Material:
	return Mats.plastic(color, 0.3, 0.8) if glow else Mats.plastic(color, 0.35)


static func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color, glow)
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, color: Color, pos: Vector3, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color, glow)
	parent.add_child(mi)
	return mi


static func _cone(parent: Node3D, r: float, h: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 0
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color, true)
	parent.add_child(mi)
	return mi
