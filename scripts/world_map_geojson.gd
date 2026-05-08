extends Node2D

@export var geojson_path: String = "res://assets/data/ne_110m_admin_0_countries.geojson"
@export var map_size: Vector2 = Vector2(3840.0, 1920.0) # equirectangular canvas

@export var camera_path: NodePath
@export var focus_duration: float = 0.25
@export var click_zoom_multiplier: float = 1.7

@export var ocean_color: Color = Color("1f2e3a")
@export var grid_color: Color = Color("2f4657")
@export var grid_step: float = 160.0
@export var border_color: Color = Color("67839a")
@export var border_width: float = 6.0

@export var country_border_color: Color = Color("0b1117")
@export var country_border_width: float = 2.0

@export_range(0.0, 1.0, 0.01) var hover_lighten: float = 0.18

@export var saturation: float = 0.55
@export var value: float = 0.90

@export var label_color: Color = Color(1, 1, 1, 0.88)
@export var label_shadow_color: Color = Color(0, 0, 0, 0.55)
@export var label_shadow_offset: Vector2 = Vector2(2, 2)

@export var label_size_min: int = 12
@export var label_size_max: int = 40
@export var label_min_zoom: float = 0.55 # below this, show only biggest countries
@export var label_detail_zoom: float = 1.60 # above this, show much more
@export var label_max_count_zoomed_out: int = 40
@export var label_max_count_zoomed_in: int = 140
@export var label_min_distance: float = 70.0 # simple anti-overlap in map units

var _polys: Array[PackedVector2Array] = []
var _colors: Array[Color] = []
var _base_colors: Array[Color] = []
var _hovered: Array[bool] = []
var _poly_country: Array[String] = []

var _label_countries: Array[String] = []
var _label_pos: Array[Vector2] = []
var _label_area: Array[float] = []

var _hit_root: Node2D
var _camera: Camera2D
var _focus_tween: Tween
var _font: Font


func _ready() -> void:
	_camera = _resolve_camera()
	_font = _resolve_font()
	_load_countries()
	queue_redraw()


func _draw() -> void:
	_draw_ocean()
	_draw_grid()
	_draw_countries()
	_draw_labels()
	_draw_border()


func _draw_ocean() -> void:
	draw_rect(Rect2(-map_size * 0.5, map_size), ocean_color, true)


func _draw_grid() -> void:
	var half: Vector2 = map_size * 0.5
	var x: float = -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), grid_color, 1.0)
		x += grid_step

	var y: float = -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), grid_color, 1.0)
		y += grid_step


func _draw_countries() -> void:
	var n: int = _polys.size()
	for i in range(n):
		var pts: PackedVector2Array = _polys[i]
		if pts.size() < 3:
			continue
		draw_colored_polygon(pts, _colors[i])
		if country_border_width > 0.0:
			draw_polyline(pts, country_border_color, country_border_width, true)


func _draw_border() -> void:
	var rect := Rect2(-map_size * 0.5, map_size)
	draw_rect(rect, border_color, false, border_width)


func _load_countries() -> void:
	_polys.clear()
	_colors.clear()
	_base_colors.clear()
	_hovered.clear()
	_poly_country.clear()
	_label_countries.clear()
	_label_pos.clear()
	_label_area.clear()

	if _hit_root == null:
		_hit_root = Node2D.new()
		_hit_root.name = "CountryButtons"
		add_child(_hit_root)
	else:
		for c in _hit_root.get_children():
			c.queue_free()

	if not FileAccess.file_exists(geojson_path):
		push_error("GeoJSON not found: %s" % geojson_path)
		return

	var json_text: String = FileAccess.get_file_as_string(geojson_path)
	var parsed_variant: Variant = JSON.parse_string(json_text)
	if parsed_variant == null or typeof(parsed_variant) != TYPE_DICTIONARY:
		push_error("Failed to parse GeoJSON: %s" % geojson_path)
		return

	var root: Dictionary = parsed_variant as Dictionary
	var features: Array = root.get("features", [])
	for f in features:
		if typeof(f) != TYPE_DICTIONARY:
			continue

		var feat: Dictionary = f
		var props: Dictionary = feat.get("properties", {})
		var name: String = str(props.get("NAME", props.get("ADMIN", "Country")))
		var color: Color = _color_for_name(name)

		var geom: Dictionary = feat.get("geometry", {})
		var gtype: String = str(geom.get("type", ""))
		var coords: Variant = geom.get("coordinates", null)

		if gtype == "Polygon":
			_add_polygon(name, coords, color)
		elif gtype == "MultiPolygon":
			_add_multipolygon(name, coords, color)

	_build_country_buttons()
	_build_country_labels()


func _draw_labels() -> void:
	if _font == null:
		return

	if _camera == null:
		_camera = _resolve_camera()

	var zoom: float = 1.0
	if _camera != null:
		zoom = _camera.zoom.x

	var max_count: int = label_max_count_zoomed_out
	if zoom >= label_detail_zoom:
		max_count = label_max_count_zoomed_in
	elif zoom >= label_min_zoom:
		# blend between out/in counts
		var t: float = inverse_lerp(label_min_zoom, label_detail_zoom, zoom)
		max_count = int(lerp(float(label_max_count_zoomed_out), float(label_max_count_zoomed_in), t))

	# Draw biggest first to reduce clutter. We pre-sorted label entries by area desc.
	var placed: Array[Vector2] = []
	var drawn: int = 0
	var n: int = _label_countries.size()
	for i in range(n):
		if drawn >= max_count:
			break

		var area: float = _label_area[i]
		# For small countries, require more zoom to show.
		if zoom < label_detail_zoom and area < 12000.0:
			continue
		if zoom < label_min_zoom and area < 65000.0:
			continue

		var p: Vector2 = _label_pos[i]
		var ok: bool = true
		for q in placed:
			if p.distance_to(q) < label_min_distance:
				ok = false
				break
		if not ok:
			continue

		var size: int = _label_font_size(area)
		var text: String = _label_countries[i]
		# Center align: approximate by measuring string and offsetting half width.
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var pos: Vector2 = p - Vector2(w * 0.5, 0.0)

		draw_string(_font, pos + label_shadow_offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, label_shadow_color)
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, label_color)

		placed.append(p)
		drawn += 1


func _label_font_size(area: float) -> int:
	# Smooth size scaling with diminishing returns.
	var t: float = clamp((log(area + 1.0) - log(8000.0)) / (log(900000.0) - log(8000.0)), 0.0, 1.0)
	return int(round(lerp(float(label_size_min), float(label_size_max), t)))


func _build_country_labels() -> void:
	# Pick one representative polygon per country: largest area polygon.
	var best_area: Dictionary = {}
	var best_idx: Dictionary = {}

	var n: int = _polys.size()
	for i in range(n):
		var name: String = _poly_country[i]
		var a: float = absf(_polygon_area(_polys[i]))
		if not best_area.has(name) or a > float(best_area[name]):
			best_area[name] = a
			best_idx[name] = i

	var entries: Array[Dictionary] = []
	for k in best_idx.keys():
		var idx: int = int(best_idx[k])
		var a2: float = float(best_area[k])
		var c: Vector2 = _polygon_centroid(_polys[idx])
		entries.append({"name": str(k), "pos": c, "area": a2})

	# Sort by area desc for stable “big first” rendering.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["area"]) > float(b["area"])
	)

	for e in entries:
		_label_countries.append(str(e["name"]))
		_label_pos.append(e["pos"])
		_label_area.append(float(e["area"]))


func _polygon_area(pts: PackedVector2Array) -> float:
	var n: int = pts.size()
	if n < 3:
		return 0.0
	var a: float = 0.0
	for i in range(n):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		a += p0.x * p1.y - p1.x * p0.y
	return a * 0.5


func _resolve_font() -> Font:
	# Use the engine fallback font so we don't ship a font file.
	# Works in Godot 4.x.
	if Engine.has_singleton("ThemeDB"):
		var tdb = Engine.get_singleton("ThemeDB")
		if tdb != null and "fallback_font" in tdb:
			var f = tdb.fallback_font
			if f is Font:
				return f as Font
	# Last resort: no font (labels won't draw).
	return null


func _build_country_buttons() -> void:
	var n: int = _polys.size()
	_hovered.resize(n)
	for i in range(n):
		_hovered[i] = false

	# One "button" (Area2D) per polygon for precise hover via collision polygon.
	for i in range(n):
		var pts: PackedVector2Array = _polys[i]
		if pts.size() < 3:
			continue

		var area: Area2D = Area2D.new()
		area.name = "CountryButton_%d" % i
		area.input_pickable = true
		_hit_root.add_child(area)

		var col: CollisionPolygon2D = CollisionPolygon2D.new()
		col.polygon = pts
		area.add_child(col)

		area.mouse_entered.connect(func() -> void:
			_set_hover(i, true)
		)
		area.mouse_exited.connect(func() -> void:
			_set_hover(i, false)
		)
		area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					_focus_country(i)
		)


func _set_hover(i: int, is_on: bool) -> void:
	if i < 0 or i >= _hovered.size():
		return
	if _hovered[i] == is_on:
		return
	_hovered[i] = is_on

	var base: Color = _base_colors[i]
	_colors[i] = base.lerp(Color.WHITE, hover_lighten) if is_on else base
	queue_redraw()


func _focus_country(i: int) -> void:
	if _camera == null:
		_camera = _resolve_camera()
		if _camera == null:
			return

	if i < 0 or i >= _polys.size():
		return

	var local_center: Vector2 = _polygon_centroid(_polys[i])
	var target_pos: Vector2 = to_global(local_center)

	var current_zoom: float = _camera.zoom.x
	var target_zoom: float = clamp(current_zoom * click_zoom_multiplier, 0.15, 12.0)

	if _focus_tween != null and _focus_tween.is_running():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_SINE)
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(_camera, "global_position", target_pos, focus_duration)
	_focus_tween.parallel().tween_property(_camera, "zoom", Vector2.ONE * target_zoom, focus_duration)


func _resolve_camera() -> Camera2D:
	if camera_path != NodePath() and has_node(camera_path):
		var n: Node = get_node(camera_path)
		if n is Camera2D:
			return n as Camera2D

	var v: Viewport = get_viewport()
	if v != null:
		var c: Camera2D = v.get_camera_2d()
		if c != null:
			return c
	return null


func _polygon_centroid(pts: PackedVector2Array) -> Vector2:
	# Area-weighted centroid. Falls back to average if degenerate.
	var n: int = pts.size()
	if n == 0:
		return Vector2.ZERO

	var a: float = 0.0
	var cx: float = 0.0
	var cy: float = 0.0
	for i in range(n):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		var cross: float = p0.x * p1.y - p1.x * p0.y
		a += cross
		cx += (p0.x + p1.x) * cross
		cy += (p0.y + p1.y) * cross

	if is_zero_approx(a):
		var sum: Vector2 = Vector2.ZERO
		for p in pts:
			sum += p
		return sum / float(n)

	a *= 0.5
	return Vector2(cx / (6.0 * a), cy / (6.0 * a))


func _add_polygon(name: String, coords: Variant, color: Color) -> void:
	# GeoJSON Polygon: [ [outer], [hole1], ... ]
	if coords == null or typeof(coords) != TYPE_ARRAY:
		return
	var rings: Array = coords
	if rings.is_empty():
		return

	# MVP: draw outer ring only (ignore holes).
	var outer: Variant = rings[0]
	var pts: PackedVector2Array = _ring_to_points(outer)
	_store_poly(name, pts, color)


func _add_multipolygon(name: String, coords: Variant, color: Color) -> void:
	# GeoJSON MultiPolygon: [ Polygon, Polygon, ... ]
	if coords == null or typeof(coords) != TYPE_ARRAY:
		return
	var polys: Array = coords
	for poly in polys:
		_add_polygon(name, poly, color)


func _ring_to_points(ring: Variant) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	if ring == null or typeof(ring) != TYPE_ARRAY:
		return pts

	var arr: Array = ring
	for ll in arr:
		if typeof(ll) != TYPE_ARRAY:
			continue
		var pair: Array = ll
		if pair.size() < 2:
			continue
		var lon: float = float(pair[0])
		var lat: float = float(pair[1])
		pts.append(_lonlat_to_xy(lon, lat))

	# Drop duplicated last vertex if present
	if pts.size() >= 2 and pts[0].is_equal_approx(pts[pts.size() - 1]):
		pts.remove_at(pts.size() - 1)
	return pts


func _store_poly(name: String, pts: PackedVector2Array, color: Color) -> void:
	if pts.size() < 3:
		return
	_polys.append(pts)
	_base_colors.append(color)
	_colors.append(color)
	_poly_country.append(name)


func _lonlat_to_xy(lon: float, lat: float) -> Vector2:
	# Equirectangular: lon [-180,180] -> x, lat [90,-90] -> y
	var x: float = (lon / 180.0) * (map_size.x * 0.5)
	var y: float = (-lat / 90.0) * (map_size.y * 0.5)
	return Vector2(x, y)


func _color_for_name(name: String) -> Color:
	var h: int = name.hash()
	var hue: float = fposmod(float(h), 360.0) / 360.0
	return Color.from_hsv(hue, clamp(saturation, 0.0, 1.0), clamp(value, 0.0, 1.0))
