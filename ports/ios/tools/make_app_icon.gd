extends SceneTree
## Renders the App Store icon for the iOS project from res://icon.svg:
## a full 1024x1024 square (iOS rounds the corners itself) saved as RGB PNG without alpha.
## Usage: godot --headless --path ports/ios/project -s ports/ios/tools/make_app_icon.gd

const SOURCE := "res://icon.svg"
const TARGET := "res://assets/ios/app_icon_1024.png"
const SIZE := 1024


func _init() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	if svg.is_empty():
		printerr("Cannot read ", SOURCE)
		quit(1)
		return
	# drop the rounded corners — transparent corners are what makes the icon invalid
	svg = svg.replace(' rx="16"', "")
	# move the cyan dot off the edge: in icon.svg it sticks out of the 128 px canvas, and iOS
	# masks the corners (corner radius ≈ 22% of the size). At (104, 24) it is fully inside that
	# mask and keeps a ~4.6 px gap from the red ring (outer radius 38 around 64, 64).
	svg = svg.replace('cx="116" cy="20"', 'cx="104" cy="24"')
	var image := Image.new()
	var err := image.load_svg_from_string(svg, SIZE / 128.0)
	if err != OK or image.get_width() != SIZE or image.get_height() != SIZE:
		printerr("SVG render failed (error %d, size %dx%d)" % [err, image.get_width(), image.get_height()])
		quit(1)
		return
	image.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET.get_base_dir()))
	err = image.save_png(TARGET)
	if err != OK:
		printerr("Cannot save ", TARGET, " (error ", err, ")")
		quit(1)
		return
	print("Saved ", TARGET)
	quit(0)
