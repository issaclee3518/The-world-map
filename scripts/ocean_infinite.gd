extends Node2D

@export var camera_path: NodePath
@export var map_node_path: NodePath = NodePath("../MapRoot/WorldMap")
@export var overdraw_x_factor: float = 1.2 # extra width to hide seam at edges

var _camera: Camera2D
var _map_w: float = 0.0
var _map_h: float = 0.0


func _ready() -> void:
	_camera = _resolve_camera()
	_read_map_size()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	# Redraw as camera moves/zooms so the rect always covers the screen.
	queue_redraw()


func _draw() -> void:
	if _camera == null:
		_camera = _resolve_camera()
	_read_map_size()
	var vp: Viewport = get_viewport()
	if vp == null:
		return

	var z: float = 1.0
	if _camera != null:
		z = _camera.zoom.x
	if _map_w <= 0.0 or _map_h <= 0.0:
		return

	# Draw only within map height (no vertical infinite background),
	# and repeat horizontally alongside the wrapped map.
	var screen_w: float = vp.get_visible_rect().size.x
	var half_w: float = (screen_w * 0.5) / max(z, 0.001) * overdraw_x_factor

	var cam_x: float = _camera.global_position.x if _camera != null else 0.0
	var base: float = round(cam_x / _map_w) * _map_w

	var rect_h: float = _map_h
	var rect_y: float = -_map_h * 0.5

	# Center tile (clipped to visible width via limited overdraw)
	draw_rect(Rect2(Vector2(base - half_w, rect_y), Vector2(half_w * 2.0, rect_h)), Color.WHITE, true)
	# Left / Right tiles to cover across wrap boundary
	draw_rect(Rect2(Vector2(base - _map_w - half_w, rect_y), Vector2(half_w * 2.0, rect_h)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(base + _map_w - half_w, rect_y), Vector2(half_w * 2.0, rect_h)), Color.WHITE, true)


func _resolve_camera() -> Camera2D:
	if camera_path != NodePath() and has_node(camera_path):
		var n: Node = get_node(camera_path)
		if n is Camera2D:
			return n as Camera2D
	var v: Viewport = get_viewport()
	return v.get_camera_2d() if v != null else null


func _read_map_size() -> void:
	var map_node: Node = get_node_or_null(map_node_path)
	if map_node == null:
		return
	var v: Variant = map_node.get("map_size")
	if typeof(v) == TYPE_VECTOR2:
		_map_w = float(v.x)
		_map_h = float(v.y)

