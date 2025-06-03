extends CanvasLayer

func _ready():
	await get_tree().process_frame  # Wait for scene tree to initialize
	if TurnManager:
		$EndTurnButton.pressed.connect(TurnManager._on_EndTurnButton_pressed)
	else:
		print("Error: TurnManager not loaded.")
