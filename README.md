# Godot Editor Console

This plugin adds a console button next to the filter in the Output bottom panel. You can also instance a console from the tool menu.

Basic nested commands can be achieved by just following the recommended directory structure. This introduces a bit of boiler plate file management, but simplifies command flow and auto completion. See the 'Scripting' section below for advanced usage notes.

```text
📁 top_command
 ├── 📄 top_command.gd
 ├── 📁 sub_command
 │   └── 📄 sub_command.gd 
 └── 📁 sub_command2
     └── 📄 sub_command2.gd
```

Create your top most command that will be registered with the console in a "plugin.gd". When the plugin enters the tree, you can register the command with `EditorConsoleSingleton.register_temp_scope("my_cmd", ConsoleCommand)`. `my_cmd` is how you will call your command in the console. `ConsoleCommand` is a refrence to the command script, typically a preload. 

Commands can also be registered via the console without a plugin using the `config scope reg` command. This is written to either the project or global config file, and will be loaded everytime you load the editor until you deregister it.

Sub commands should be in a folder, and should have the same file name as the folder. Files not in a folder are ignored, these could be shared utilities, notes, etc.

Once your top level command is registered, all subcommands will automatically be routed to and be suggested in autocomplete.

By default the console will parse the input text and each command will consume tokens and select the next command until there are no more tokens, or an unrecognized token. At this point the command will attempt to execute. See [command example](export_ignore/doc/command_base.md) for a deeper explanation as well as a list of functions that can be overidden to customize behaviour.

Base commands can be found [here](export_ignore/doc/commands.md). Adding `--help` after any token will print help for that token if defined.

## Scripting
While simple commands are great for triggering small tasks, commands can be combined using their stdin and stdout, as well as exit codes.


I'm calling this GDShell(gdsh), because the format is pretty similar to bash. [Example File](export_ignore/doc/example.gdsh)
You can define functions and variables, use conditions and loops, even run or source other scripts.

The composble nature of the commands means you can get alot of use out of simple tools.

## MCP
There is an optional Go MCP server that you can use to connect agents to the console. Because of the similar nature to bash, and having help text readily available through "token --help", they seem to be able to figure out the commands fairly quickly.

[MCP Server](https://github.com/brohd11/Godot-Editor-Console-MCP)



## Using it with your Plugin
The plugin is "portable", meaning you can include it as a sub-plugin easily. Due to the duck typed singleton design, multiple plugins can have their own copy of the source and interact with a shared instance. This is made easy using [Plugin Exporter](https://github.com/brohd11/Godot-Plugin-Exporter). The console plugin will be packaged in with your plugin package, class_names will be stripped from all the files, instead using preload to reference the classes. There will be no name clashes between plugins.