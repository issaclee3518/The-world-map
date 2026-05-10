extends Node2D

@export var camera_path: NodePath
@export var center_map_path: NodePath = NodePath("WorldMap")
@export var left_map_path: NodePath = NodePath("WorldMapLeft")
@export var right_map_path: NodePath = NodePath("WorldMapRight")

@export var clamp_vertical: bool = true

var _camera: Camera2D
var _center: Node2D
var _left: Node2D
var _right: Node2D
var _map_w: float = 0.0
var _map_h: float = 0.0


func _ready() -> void:
	_camera = _resolve_camera()
	_center = get_node_or_null(center_map_path) as Node2D
	_left = get_node_or_null(left_map_path) as Node2D
	_right = get_node_or_null(right_map_path) as Node2D

	_map_w = _read_map_size_x(_center)
	_map_h = _read_map_size_y(_center)

	set_process(true)
	_apply_wrap()


func _process(_delta: float) -> void:
	_apply_wrap()


func _apply_wrap() -> void:
	if _camera == null:
		_camera = _resolve_camera()
	if _center == null:
		_center = get_node_or_null(center_map_path) as Node2D
		if _center != null:
			_map_w = _read_map_size_x(_center)
			_map_h = _read_map_size_y(_center)

	if _camera == null or _center == null:
		return
	if _map_w <= 0.0:
		return

	var cx: float = _camera.global_position.x
	var base: float = round(cx / _map_w) * _map_w

	_center.global_position.x = base
	_center.global_position.y = 0.0

	if _left != null:
		_left.global_position.x = base - _map_w
		_left.global_position.y = 0.0
	if _right != null:
		_right.global_position.x = base + _map_w
		_right.global_position.y = 0.0

	if clamp_vertical and _map_h > 0.0:
		_clamp_camera_y()


func _clamp_camera_y() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var screen_h: float = vp.get_visible_rect().size.y
	var z: float = max(_camera.zoom.y, 0.001)
	var half_visible: float = (screen_h * 0.5) / z

	var half_map: float = _map_h * 0.5
	var min_y: float = -half_map + half_visible
	var max_y: float = half_map - half_visible

	# If zoomed out so far the screen is taller than the map, pin to center.
	if min_y > max_y:
		_camera.global_position.y = 0.0
	else:
		_camera.global_position.y = clamp(_camera.global_position.y, min_y, max_y)


func _resolve_camera() -> Camera2D:
	if camera_path != NodePath() and has_node(camera_path):
		var n: Node = get_node(camera_path)
		if n is Camera2D:
			return n as Camera2D
	var v: Viewport = get_viewport()
	return v.get_camera_2d() if v != null else null


func _read_map_size_x(map_node: Node) -> float:
	if map_node == null:
		return 0.0
	var v: Variant = map_node.get("map_size")
	return float(v.x) if typeof(v) == TYPE_VECTOR2 else 0.0


func _read_map_size_y(map_node: Node) -> float:
	if map_node == null:
		return 0.0
	var v: Variant = map_node.get("map_size")
	return float(v.y) if typeof(v) == TYPE_VECTOR2 else 0.0

