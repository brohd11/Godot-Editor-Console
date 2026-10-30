extends SceneTree
## Headless: python3 addons/editor_console/_export_ignore/test/run_headless.py
## Editor console: `test editor_console` runs the same checks, including prompt completion.
const Suite = preload("res://addons/editor_console/_export_ignore/test/runtime_suite.gd")


func _initialize():
	_run.call_deferred()


func _run():
	var res = await run_tests()
	print("\n".join(res.output))
	quit(1 if res.result else 0)


## Entry for the editor console `test` command, which awaits the frame-dependent checks.
static func run_tests() -> Dictionary:
	var suite = Suite.new()
	suite.run_sync()
	await suite.run_frames()
	return {"result": suite.failures, "output": suite.finish()}
