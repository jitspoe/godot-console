# godot-console
Dev console addon for Godot engine.

Simply drop the addons directory into your godot project, go to the project settings, plugins, and enable "Console".

After you've done that, you can add console commands from any class.

Example:

```gdscript
func _ready():
  Console.add_command("hello", my_hello_function)

func my_hello_function():
  Console.print_line("Hello, world!")
```

You can also specify up to 3 parameters, which will be passed in as strings:

```gdscript
  Console.add_command("param_test", param_test_function, 1) # 1 specifies 1 parameter

func param_test_function(param1 : String):
  Console.print_line("Param passed in: %s" % param1)
```

The "quit"/"exit" command is implemented by default.

By default the console does not pause the tree. If this is undesirable behaviour to you, you can change that behaviour by setting the `pause_enabled` variable accordingly.

```gdscript
func _ready_():
  Console.pause_enabled = true
  # Console will now pause the tree when being opened
```

If you prefer to use C#, you might want to check out the C# console by Moliko here: https://github.com/MolikoDeveloper/Csharp-Console-Godot
