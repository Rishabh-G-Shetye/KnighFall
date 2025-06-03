# Unit.gd (attach this to all characters, both player and enemy)
extends CharacterBody2D

class_name Unit

@export var faction: String = "player"  # or "enemy"
@export var max_health: int = 10
@export var current_health: int = 10
@export var damage: int = 3
@export var movement: int = 3

var has_moved: bool = false
var has_attacked: bool = false

func take_damage(amount: int):
	current_health -= amount
	print(name, "takes", amount, "damage. HP now:", current_health)

	if current_health <= 0:
		die()

func die():
	print(name, "has died.")
	queue_free()
