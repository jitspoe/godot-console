@tool
extends EditorPlugin


func _enter_tree():
	print("Console plugin activated.")
	add_autoload_singleton("Console", "res://addons/console/Console.gd")
