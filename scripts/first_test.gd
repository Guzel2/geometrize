@tool
extends Node2D

@export var run = false:
	set(value):
		run = value
		
		if run:
			geometrize()

@export var texture : Texture2D
var image : Image

var image_pixels = []
var geometrize_pixels = []

var average_color : Color = Color.WEB_GRAY

var rects : Array = []

var width = 10
var height = 10

var rect_min_size = 20
var rects_per_generation = 100
var evolution_randomness = .8
var rect_count = 250

var folder_path = "res://generated_images"
var prefix = "mt_fuji"
var suffix = ".png"

func _process(delta):
	if run:
		queue_redraw()

func _draw():
	if !run:
		return
	
	draw_rect(Rect2(0, 0, width, height), average_color)
	
	for draw_rect in rects:
		draw_rect = draw_rect as DrawRect
		
		var rect = draw_rect.rect
		var color = draw_rect.color
		
		draw_rect(rect, color)

func get_image_pixel(x: int, y: int) -> Color:
	return image_pixels[x][y]

func get_image_pixelv(vec: Vector2) -> Color:
	return image_pixels[vec.x][vec.y]

func get_geometrize_pixel(x: int, y: int) -> Color:
	return geometrize_pixels[x][y]

func set_geometrize_pixel(x: int, y: int, color : Color):
	geometrize_pixels[x][y] = color

func get_evolution_random_float() -> float:
	return randf_range(evolution_randomness, 1 / evolution_randomness)

func geometrize():
	var start_time = Time.get_unix_time_from_system()
	
	image_pixels.clear()
	geometrize_pixels.clear()
	rects.clear()
	
	image = texture.get_image()
	
	width = image.get_width()
	height = image.get_height()
	
	average_color = Color(0, 0, 0)
	
	for x in width:
		var line = []
		
		for y in height:
			var color = image.get_pixel(x, y)
			line.append(color)
			
			average_color += color
		
		image_pixels.append(line)
	
	average_color /= width * height
	
	#average_color = Color(0, 0, 0, 0)
	
	for x in width:
		var line = []
		
		for y in height:
			line.append(average_color)
		
		geometrize_pixels.append(line)
	
	for i in rect_count:
		var new_rect = generate_rect()
		
		apply_rect(new_rect)
		
		await get_tree().create_timer(.001).timeout
		
		print("Progress: ", i, "/", rect_count)
	
	print("done")
	
	var time = Time.get_unix_time_from_system() - start_time
	
	print(time)
	
	var new_image = image.duplicate() as Image
	
	for x in width:
		for y in height:
			new_image.set_pixel(x, y, get_geometrize_pixel(x, y))
	
	
	new_image.save_png(folder_path + "/" + prefix + "_" + str(get_existing_images_count()) + suffix)

func get_existing_images_count() -> int:
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var count = 0
		while file_name != "":
			if file_name.begins_with(prefix) and file_name.ends_with(suffix):
				count += 1
			file_name = dir.get_next()
		dir.list_dir_end()
		return count
	return 0

func generate_rect(original_rect : DrawRect = null) -> DrawRect:
	var new_rects  = []
	
	for x in rects_per_generation:
		var rect = DrawRect.new()
	
		var pos = Vector2(0, 0)
		var size = Vector2(0, 0)
		
		if original_rect:
			rect.position = Vector2(
				original_rect.position.x * get_evolution_random_float(),
				original_rect.position.y * get_evolution_random_float()
				)
			
			rect.size = Vector2(
				original_rect.size.x * get_evolution_random_float(),
				original_rect.size.y * get_evolution_random_float()
				)
			
			rect.color = Color(
				original_rect.color.r * get_evolution_random_float(),
				original_rect.color.g * get_evolution_random_float(),
				original_rect.color.b * get_evolution_random_float(),
				original_rect.color.a * get_evolution_random_float()
				)
			
			if rect.end.x > width:
				rect.size.x -= rect.end.x - width
			if rect.end.y > height:
				rect.size.y -= rect.end.y - height
			
		else:
			rect.position = Vector2(randi_range(0, width - rect_min_size), randi_range(0, height - rect_min_size))
			rect.size = Vector2(randi_range(rect_min_size, width - rect.position.x), randi_range(rect_min_size, height - rect.position.y))
			
			#rect.color = Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1), randf_range(0, 1))
			
			rect.color = get_image_pixelv(rect.position + rect.size / 2)
			rect.color.a = randf_range(.25, 1)
		
		new_rects.append(rect)
	
	var lowest_difference = 100000
	var best_rect = new_rects[0]
	
	#compare rects
	for rect in new_rects:
		rect.difference = compare_rect(rect)
		
		if rect.difference < lowest_difference:
			lowest_difference = rect.difference
			best_rect = rect
	
	return best_rect

func compare_rect(rect: DrawRect) -> float:
	var total_old_difference = 0
	var total_new_difference = 0
	
	var total_difference = 0
	
	for loc_x in rect.size.x - 1:
		for loc_y in rect.size.y - 1:
			var x = int(loc_x + rect.position.x)
			var y = int(loc_y + rect.position.y)
			
			if x % 2 == 1 or y % 2 == 1:
				continue
			
			var image_color = get_image_pixel(x, y)
			var old_color = get_geometrize_pixel(x, y)
			var old_color_difference = old_color - image_color
			
			var old_difference = Vector4(old_color_difference.r, old_color_difference.g, old_color_difference.b, old_color_difference.a).length()
			
			var new_color = old_color * (1 - rect.color.a) + rect.color * rect.color.a
			new_color.r = clamp(new_color.r, 0, 1)
			new_color.g = clamp(new_color.g, 0, 1)
			new_color.b = clamp(new_color.b, 0, 1)
			new_color.a = 1
			var new_color_difference = new_color - image_color
			
			var new_difference = Vector4(new_color_difference.r, new_color_difference.g, new_color_difference.b, new_color_difference.a).length()
			
			#total_old_difference += old_difference
			#total_new_difference += new_difference
			
			var difference = new_difference - old_difference
			total_difference += difference
			#if difference < 0:
			#	total_difference += difference
			#else:
			#	total_difference += difference * 1
	
	return total_difference

func apply_rect(rect : DrawRect):
	for loc_x in rect.size.x - 1:
		for loc_y in rect.size.y - 1:
			var x = int(loc_x + rect.position.x)
			var y = int(loc_y + rect.position.y)
			
			var new_color = get_geometrize_pixel(x, y) * (1 - rect.color.a) + rect.color * rect.color.a
			new_color.r = clamp(new_color.r, 0, 1)
			new_color.g = clamp(new_color.g, 0, 1)
			new_color.b = clamp(new_color.b, 0, 1)
			new_color.a = 1
			
			set_geometrize_pixel(x, y, new_color)
	
	rects.append(rect)
