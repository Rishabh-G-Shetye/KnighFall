# GameSettings.gd
extends Node

enum Difficulty { EASY, HARD }
var current_difficulty: Difficulty = Difficulty.EASY  # Default to EASY
