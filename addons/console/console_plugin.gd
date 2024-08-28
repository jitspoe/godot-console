@tool
extends EditorPlugin


func _enter_tree():
	print("Console plugin activated.")
	add_autoload_singleton("Console", "res://addons/console/console.gd")


func _exit_tree():
	remove_autoload_singleton("Console")
