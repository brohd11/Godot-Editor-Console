The console has some built in commands:

## config

```text
config
	└── scope
		└── reg # register a command
		└── dereg # deregister a command
		└── reload # reload all top level commands
```

## script

```text
script # current script
	└── call # call a static function
	└── args # prints args of function
	└── list # list members of script
	└── infer # attempts to insert static type hints for untyped vars
```

## global

```text
global
	└── registry # add or remove classes from autocomplete
	└── print_list # print global class list with search flags
	└── GlobalClass
		└── call # call a static function
		└── args # prints args of function
		└── list # list members of script

'GlobalClass' evaluates to a script and gives the same commands as 'script'. This can also be used without the global command, but will not have autocompletion for registered classes
```

## Other
### os
Switches to a mock terminal that can be used to run non interactive commands

### help
Print all top level commands

### clear
Clears the output log and/or prompt history
