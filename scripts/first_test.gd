@tool
extends Node2D

@export var run = false:
	set(value):
		run = value
		
		if run:
			geometrize()

@export var use_evolution = false
@export var use_random_colors = false
@export var use_transparent_background = true

@export var texture : Texture2D
var image : Image

var image_pixels = []
var geometrize_pixels = []

#background color
var average_color : Color = Color.WEB_GRAY

#images to draw
var rects : Array = []

var width = 10
var height = 10

var rect_min_size = 20
var rects_per_generation = 50
var evolution_randomness = .9
var evolution_rects_per_generation = 15
var rect_count = 50

#save locations for generated images
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

#this is probably the same as:
#return image.get_pixel(x, y)
#but I wanted to try a different approach and see if it was faster
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
	#my version of performance checking
	var start_time = Time.get_unix_time_from_system()
	
	#resetting all pixel_buffers
	image_pixels.clear()
	geometrize_pixels.clear()
	rects.clear()
	
	image = texture.get_image()
	
	width = image.get_width()
	height = image.get_height()
	
	#this will be used for the background color
	average_color = Color(0, 0, 0)
	
	for x in width:
		var line = []
		
		for y in height:
			var color = image.get_pixel(x, y)
			line.append(color)
			
			average_color += color
		
		image_pixels.append(line)
	
	average_color /= width * height
	
	#optionally dectivate any background color
	if use_transparent_background:
		average_color = Color(0, 0, 0, 0)
	
	#initialize the drawn pixels, these are used later to compare the change a new rectangle adds
	for x in width:
		var line = []
		
		for y in height:
			line.append(average_color)
		
		geometrize_pixels.append(line)
	
	#generate new rects
	for i in rect_count:
		var new_rect = generate_rect()
		
		#apply the selected rectangle to geometrize_pixels and the new_rect list
		apply_rect(new_rect)
		
		#visual update of the progress (this does not really effect performance)
		await get_tree().create_timer(.001).timeout
		
		print("Progress: ", i, "/", rect_count)
	
	#end of my performance checker
	var time = Time.get_unix_time_from_system() - start_time
	
	print("Done, took: ", time, " seconds")
	
	#saving the genrated image to disk
	var new_image = image.duplicate() as Image
	
	for x in width:
		for y in height:
			new_image.set_pixel(x, y, get_geometrize_pixel(x, y))
	
	new_image.save_png(folder_path + "/" + prefix + "_" + str(get_existing_images_count()) + suffix)
	
	run = false

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
	
	var rect_count = rects_per_generation
	
	if original_rect:
		rect_count = evolution_rects_per_generation
	
	for x in rect_count:
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
			
			#make sure the rectangle is within bounds of the original image
			if rect.end.x > width:
				rect.size.x -= rect.end.x - width
			if rect.end.y > height:
				rect.size.y -= rect.end.y - height
			
		else:
			rect.position = Vector2(randi_range(0, width - rect_min_size), randi_range(0, height - rect_min_size))
			rect.size = Vector2(randi_range(rect_min_size, width - rect.position.x), randi_range(rect_min_size, height - rect.position.y))
			
			if use_random_colors:
				rect.color = Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1), randf_range(0, 1))
			else:
				rect.color = get_image_pixelv(rect.position + rect.size / 2)
				rect.color.a = randf_range(.25, 1)
		
		new_rects.append(rect)
	
	#this is just a placeholder value which gets replaced immediatly
	var lowest_difference = 100000
	var best_rect = new_rects[0]
	
	#compare rects
	for rect in new_rects:
		rect.difference = compare_rect(rect)
		
		if rect.difference < lowest_difference:
			lowest_difference = rect.difference
			best_rect = rect
	
	if use_evolution:
		#prevent an infinite loop generating more and more evolutions of a rect
		if !original_rect:
			best_rect = generate_rect(best_rect)
	
	return best_rect

#this function is causing most of the lag
func compare_rect(rect: DrawRect) -> float:
	var total_difference = 0
	
	for loc_x in rect.size.x - 1:
		for loc_y in rect.size.y - 1:
			var x = int(loc_x + rect.position.x)
			var y = int(loc_y + rect.position.y)
			
			#just check every 4th pixel, this increases performance quite a lot and could be increased further at the cost of performance
			if !(x % 2 == 0 and y % 2 == 0):
				continue
			
			#calculate the difference of the original image and the generated old pixels (before applying the new rect)
			var image_color = get_image_pixel(x, y)
			var old_color = get_geometrize_pixel(x, y)
			var old_color_difference = old_color - image_color
			
			var old_difference = Vector4(old_color_difference.r, old_color_difference.g, old_color_difference.b, old_color_difference.a).length()
			
			
			#calculate the difference of the original image and the change the rect does to the old pixels
			var new_color = old_color * (1 - rect.color.a) + rect.color * rect.color.a
			new_color.r = clamp(new_color.r, 0, 1)
			new_color.g = clamp(new_color.g, 0, 1)
			new_color.b = clamp(new_color.b, 0, 1)
			new_color.a = 1
			var new_color_difference = new_color - image_color
			
			var new_difference = Vector4(new_color_difference.r, new_color_difference.g, new_color_difference.b, new_color_difference.a).length()
			
			total_difference += new_difference - old_difference
	
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
