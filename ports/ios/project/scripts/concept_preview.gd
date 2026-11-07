extends Node3D

func _ready() -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://assets/sprites/concepts/concept_board.png")
	print("CONCEPT_CAPTURE: %s" % error_string(error))
	get_tree().quit(0 if error == OK else 1)
