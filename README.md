# Godot Editor Console

This plugin adds a console button next to the filter in the Output bottom panel.

In 0.6.0 I have completely redesigned how commands are created and used. Now each command is split into it's own script, so expanding a set of commands is far more scalable. It is also much simpler to handle flags and positional arguments.

Basic nested commands can be achieved by just following the recommended directory structure. This introduces a bit of boiler plate file management, but hugely simplifies command flow and auto completion.

```text
📁 top_command
 ├── 📄 top_command.gd
 ├── 📁 sub_command
 │   └── 📄 sub_command.gd 
 └── 📁 sub_command2
     └── 📄 sub_command2.gd
```

Create your top most command that will be registered with the console in a "plugin.gd". They can also be registered via the console without a plugin.

Sub commands should be in a folder, and should have the same file name as the folder. Files not in a folder are ignored, these could be shared utilities, notes, etc.

By default the console will parse the input text and each command will consume tokens and select the next command until there are no more tokens, or an unrecognized token. At this point the command will attempt to execute. See [command example](export_ignore/doc/command_base.md) for a deeper explanation as well as a list of functions that can be overidden to customize behaviour.

Base commands can be found [here](export_ignore/commands.md). Adding `--help` after any token will print help for that token if defined.

## Using it with your Plugin
The plugin is "portable", meaning you can include it as a sub-plugin easily. Due to the duck typed singleton design, multiple plugins can have their own copy of the source and interact with a shared instance. This is made easy using [Plugin Exporter](https://github.com/brohd11/Godot-Plugin-Exporter). The console plugin will be packaged in with your plugin package, class_names will be stripped from all the files, instead using preload to reference the classes. There will be no name clashes between plugins.