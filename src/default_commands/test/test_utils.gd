const TEST_PATH = "res://.addons/editor_console/test/test.yml"



static func read_file(path:String=TEST_PATH):
	if not FileAccess.file_exists(path):
		return {}
	var file_str = FileAccess.get_file_as_string(path)
	var parser = YAMLParser.new()
	return parser.parse(file_str)
	

static func write_file(data:Dictionary, path:String=TEST_PATH):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	
	var yaml_str = YAMLParser.dump(data)
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(yaml_str)
	
