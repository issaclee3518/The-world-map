extends Node2D

@export var camera_path: NodePath
@export var overdraw_factor: float = 1.8 # bigger = fewer redraw artifacts at edges

var _camera: Camera2D


func _ready() -> void:
	_camera = _resolve_camera()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	# Redraw as camera moves/zooms so the rect always covers the screen.
	queue_redraw()


func _draw() -> void:
	if _camera == null:
		_camera = _resolve_camera()
	var vp: Viewport = get_viewport()
	if vp == null:
		return

	var screen: Vector2 = vp.get_visible_rect().size
	var z: float = 1.0
	var center: Vector2 = Vector2.ZERO
	if _camera != null:
		z = _camera.zoom.x
		center = _camera.global_position

	var half: Vector2 = (screen * 0.5) / max(z, 0.001) * overdraw_factor
	draw_rect(Rect2(center - half, half * 2.0), Color.WHITE, true)


func _resolve_camera() -> Camera2D:
	if camera_path != NodePath() and has_node(camera_path):
		var n: Node = get_node(camera_path)
		if n is Camera2D:
			return n as Camera2D
	var v: Viewport = get_viewport()
	return v.get_camera_2d() if v != null else null

