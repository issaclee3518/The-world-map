extends Node2D

@export var map_size: Vector2 = Vector2(3840.0, 1920.0) # world map working canvas
@export var ocean_color: Color = Color("1f2e3a")
@export var grid_color: Color = Color("2f4657")
@export var grid_step: float = 160.0
@export var border_color: Color = Color("67839a")
@export var border_width: float = 6.0

# Simple stylized continents inspired by the reference image (not a direct copy).
# Coordinates are normalized (0..1) in map space.
const _CONTINENTS: Array[Dictionary] = [
	{
		"name": "NorthAmerica",
		"color": Color("c85b55"),
		"pts": [
			Vector2(0.06, 0.18), Vector2(0.10, 0.12), Vector2(0.17, 0.11), Vector2(0.23, 0.15),
			Vector2(0.27, 0.20), Vector2(0.27, 0.27), Vector2(0.24, 0.33), Vector2(0.20, 0.37),
			Vector2(0.15, 0.39), Vector2(0.10, 0.34), Vector2(0.07, 0.28)
		]
	},
	{
		"name": "Greenland",
		"color": Color("a7d8da"),
		"pts": [
			Vector2(0.28, 0.11), Vector2(0.33, 0.08), Vector2(0.37, 0.11), Vector2(0.35, 0.18),
			Vector2(0.30, 0.17)
		]
	},
	{
		"name": "SouthAmerica",
		"color": Color("65b07a"),
		"pts": [
			Vector2(0.23, 0.42), Vector2(0.28, 0.46), Vector2(0.30, 0.54), Vector2(0.29, 0.66),
			Vector2(0.26, 0.82), Vector2(0.23, 0.92), Vector2(0.19, 0.84), Vector2(0.20, 0.70),
			Vector2(0.20, 0.58), Vector2(0.19, 0.49)
		]
	},
	{
		"name": "Europe",
		"color": Color("7f78c8"),
		"pts": [
			Vector2(0.49, 0.20), Vector2(0.54, 0.18), Vector2(0.58, 0.21), Vector2(0.56, 0.27),
			Vector2(0.51, 0.28), Vector2(0.48, 0.25)
		]
	},
	{
		"name": "Africa",
		"color": Color("caa14f"),
		"pts": [
			Vector2(0.50, 0.32), Vector2(0.58, 0.33), Vector2(0.61, 0.45), Vector2(0.59, 0.62),
			Vector2(0.55, 0.75), Vector2(0.51, 0.82), Vector2(0.47, 0.72), Vector2(0.46, 0.56),
			Vector2(0.47, 0.41)
		]
	},
	{
		"name": "Asia",
		"color": Color("6da66e"),
		"pts": [
			Vector2(0.59, 0.18), Vector2(0.74, 0.14), Vector2(0.89, 0.20), Vector2(0.90, 0.32),
			Vector2(0.81, 0.36), Vector2(0.73, 0.34), Vector2(0.66, 0.29), Vector2(0.60, 0.25)
		]
	},
	{
		"name": "India",
		"color": Color("e0923f"),
		"pts": [
			Vector2(0.70, 0.36), Vector2(0.73, 0.41), Vector2(0.72, 0.50), Vector2(0.68, 0.49),
			Vector2(0.67, 0.42)
		]
	},
	{
		"name": "Australia",
		"color": Color("7aa7b9"),
		"pts": [
			Vector2(0.79, 0.68), Vector2(0.89, 0.70), Vector2(0.92, 0.78), Vector2(0.87, 0.86),
			Vector2(0.80, 0.84), Vector2(0.77, 0.76)
		]
	},
]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_ocean()
	_draw_grid()
	_draw_continents()
	_draw_border()


func _draw_ocean() -> void:
	draw_rect(Rect2(-map_size * 0.5, map_size), ocean_color, true)


func _draw_grid() -> void:
	var half := map_size * 0.5
	var x: float = -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), grid_color, 1.0)
		x += grid_step

	var y: float = -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), grid_color, 1.0)
		y += grid_step


func _draw_continents() -> void:
	for c in _CONTINENTS:
		var pts: PackedVector2Array = PackedVector2Array()
		var uv: PackedVector2Array = PackedVector2Array()
		for p in c["pts"]:
			var px: float = (float(p.x) - 0.5) * map_size.x
			var py: float = (float(p.y) - 0.5) * map_size.y
			var v: Vector2 = Vector2(px, py)
			pts.append(v)
			uv.append(Vector2.ZERO)
		draw_colored_polygon(pts, c["color"])


func _draw_border() -> void:
	var rect := Rect2(-map_size * 0.5, map_size)
	draw_rect(rect, border_color, false, border_width)

