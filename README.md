# Godot Editor Console

This plugin adds a console button next to the filter for the Output bottom panel.

## Using it in your Plugin
The plugin is "portable", meaning you can include the plugin as a subplugin for any plugin that may need it. This is made easy using [Plugin Exporter](https://github.com/brohd11/Godot-Plugin-Exporter). The console plugin will be packaged in your plugin package, class_names will be stripped from all the files, instead using preload to reference the classes.

After export, using the EditorConsole.get_instance() static function allows all the different plugins that use the console to interact with the proper instance of the console. This allows any plugin to have a copy of the plugin and add the console if it has not been added yet, but not clash with global class names, or require the user to download an extra plugin as a dependency.

## How to Use
When clicked, the console will be shown next to the filter. Right clicking will give some options such as hiding the filter when the console is open.

The default "scopes", a script that has associated commands:
 - script - call static methods or list members of the current script in script editor
 - global - same as script, except can be called on any global class in project. Can also skip the global keyword and just type the global class name
 - config - used to add or remove scopes
 - misc - misc functions
 - clear - clear output log and/or command history
 - help - print registered scopes
 - os - switch to os mode, see below

Pressing ctrl + space will call for a completion on the console line. Built-in scopes will display context appropriate suggestions like valid commands or arguments. You can add logic to your scripts that will allow you to add suggestions to the autocomplete.

## OS mode
You can switch to OS mode with the 'os' command, that will allow you to run non-interactive commands in the shell, using bash.

For a full terminal experience, I have added support for the [GDTerm Plugin](https://github.com/markeel/gdterm) by markeel. There are a few files included in a hidden 'gdterm' folder of this plugin. Merge and replace the files in the GDTerm plugin and you can then change the layout mode of GDTerm to 'editor console'. This will allow you to call up a full terminal instance in front of the Output log by entering the command 'term'. Enter it again and it will hide the terminal.

## Adding Scopes
The easiest way to interact with the console is to just call functions in global classes. The commands would look like:

`global MyClass call -- my_function arg1 arg2`

also valid:

`MyClass call -- my_function arg1 arg2`

The function could be anything as long as it is a static function.

if you register the class with the console, it will be displayed in the auto-complete popup when 'global' is in the console line.

`config global-class reg -- MyClass`


For more advanced usage or less verbose calling, you can create a custom scope and register it with the console.

You can register a script by using: `config scope reg-scope -- MyScope path/to/script.gd`

Once it has been registered, you can call it by name: `MyScope my-command -- arg`
When the command is sent, the console will attempt to call:

`static func parse(commands:Array, args:Array, editor_console_instance)`

From here you can read the commands and args and determine what to do. The EditorConsole instance is passed for access to utils.

For further customisation, you can instead add a script that will return data for the console. The three methods below will be called when the console loads it's scopes.

``` gdscript
static func register_scopes():
	return {
		"MyScope":{
			"callable": some_callable
		},
		"MyOtherScope":{
			"script": MyOtherScope
		}

static func register_hidden_scopes():
	return {
		"MyHiddenScope":{
			"callable": some_callable
		},

static func register_variables():
	return {
		"$my-var": "my var",
		"$dynamic-var": func(): return Class.get_some_var

```

register_scopes returns a dictionary with the scope data. You can either assign a script or a callable for the console to call when the scope is called. Using a script will allow you to define an auto-completion function in the script. Callable is good for a simpler commands.

register_hidden_scopes is the exact same, except the entries will not appear in the auto-complete menu. Good for simple commands that you don't want to be cluttering the popup. They will still be highlighted in the command line when typed.

register_variables can be used to create variable that will be converted when the command is entered. You can use an anonymous function to make this more useful. For example, a default variable is "$script-cur-path" which will sub the current script editor path for the variable.
This could be used in the register function. Navigate to the script to register, then enter:

`config scope reg-scope -- MyScope $script-cur-path`

Then you don't need to copy and paste the script's path. Currently I only have a couple variables registered, but I will be looking to add more that make sense.
