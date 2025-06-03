extends Control


func _on_retry_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
