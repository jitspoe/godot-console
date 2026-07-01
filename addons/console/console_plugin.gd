@tool
extends EditorPlugin


const SINGLETON_NAME: = "Console"
const CONSOLE_SCRIPT: = "res://addons/console/console.gd"


func _enter_tree() -> void:
	# Initialize project settings when plugin is started
	# Ensures that we see all the settings in the editor
	preload(CONSOLE_SCRIPT).setup_project_settings()


func _enable_plugin() -> void:
	add_autoload_singleton(SINGLETON_NAME, CONSOLE_SCRIPT)
	print("Console plugin enabled.")


func _disable_plugin() -> void:
	remove_autoload_singleton(SINGLETON_NAME)
	print("Console plugin disabled.")
