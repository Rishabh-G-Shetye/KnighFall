extends CanvasModulate
class_name DayNightCycle

signal changeDayTime(dayTime: DAY_STATE)

@onready var animation_player: AnimationPlayer = $AnimationPlayer

enum DAY_STATE{NOON, EVENING}

var dayTime : DAY_STATE = DAY_STATE.NOON

func _ready() -> void:
	add_to_group("DayNightCycle") 

func _process(delta: float) -> void:
	var animationPos = animation_player.current_animation_position
	var animationLength = animation_player.current_animation_length / 2
	
	if animationPos > animationLength && dayTime != DAY_STATE.EVENING:
		dayTime = DAY_STATE.EVENING
		changeDayTime.emit(dayTime)
	elif  animationPos < animationLength && dayTime != DAY_STATE.NOON:
		dayTime = DAY_STATE.NOON
		changeDayTime.emit(dayTime)
