const TEST_PATH = "res://.addons/editor_console/test/test.yml"



static func read_file(path:String=TEST_PATH):
	if not FileAccess.file_exists(path):
		return {}
	var parser = YAMLParser.new()
	var err = parser.parse_file(path)
	if err != Error.OK:
		print("Error getting config file: ", err)
		return
	return parser.data

static func write_file(data:Dictionary, path:String=TEST_PATH):
	YAMLParser.dump_to_file(data, path)
