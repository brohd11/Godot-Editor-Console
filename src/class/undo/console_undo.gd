# Console-local undo helper.
#
# Buffers do/undo operations and commits them either to the editor's native undo
# stack (EditorUndoRedoManager) or directly, based on the global
# EditorConsoleSingleton.undo_tracking toggle. One create_action/commit_action per
# Action => one undo entry per command. Exposed as UtilsLocal.ConsoleUndo.
#
# Usage:
#   var a = ConsoleUndo.action("Rename node: %s" % old_name)
#   a.do_property(node, &"name", new_name)
#   a.undo_property(node, &"name", old_name)
#   a.commit()
#
# Commands must NOT also apply the mutation themselves: when tracking,
# commit_action() executes the do-ops; when not tracking, commit() applies them.

static func action(name:String) -> Action:
	return Action.new(name, _is_tracking())


static func _is_tracking() -> bool:
	var inst = EditorConsoleSingleton.get_instance()
	if inst != null and is_instance_valid(inst):
		return inst.undo_tracking
	return true


class Action:
	enum {
		_DO_PROPERTY,
		_UNDO_PROPERTY,
		_DO_METHOD,
		_UNDO_METHOD,
		_DO_REFERENCE,
		_UNDO_REFERENCE,
	}

	var _name:String
	var _track:bool
	var _ops:Array = []

	func _init(name:String, track:bool) -> void:
		_name = name
		_track = track

	func do_property(obj, property:StringName, value) -> Action:
		_ops.append([_DO_PROPERTY, obj, property, value])
		return self

	func undo_property(obj, property:StringName, value) -> Action:
		_ops.append([_UNDO_PROPERTY, obj, property, value])
		return self

	func do_method(obj, method:StringName, args:Array = []) -> Action:
		_ops.append([_DO_METHOD, obj, method, args])
		return self

	func undo_method(obj, method:StringName, args:Array = []) -> Action:
		_ops.append([_UNDO_METHOD, obj, method, args])
		return self

	# Object is OUT of the tree on the DO side (e.g. a freshly created node before
	# add_child): keep it referenced by the undo stack so an undo can restore it.
	func do_reference(obj) -> Action:
		_ops.append([_DO_REFERENCE, obj])
		return self

	# Object is OUT of the tree on the UNDO side (e.g. a node removed by delete):
	# the undo stack holds it. When NOT tracking there is no undo stack, so commit()
	# frees it to avoid a leak.
	func undo_reference(obj) -> Action:
		_ops.append([_UNDO_REFERENCE, obj])
		return self

	func commit() -> void:
		if _ops.is_empty():
			return
		if _track:
			_commit_tracked()
		else:
			_commit_direct()

	func _commit_tracked() -> void:
		var ur := EditorInterface.get_editor_undo_redo()
		# Default MERGE_DISABLE => one discrete undo entry per command.
		ur.create_action(_name)
		for op in _ops:
			match op[0]:
				_DO_PROPERTY:
					ur.add_do_property(op[1], op[2], op[3])
				_UNDO_PROPERTY:
					ur.add_undo_property(op[1], op[2], op[3])
				_DO_METHOD:
					ur.callv("add_do_method", [op[1], op[2]] + op[3])
				_UNDO_METHOD:
					ur.callv("add_undo_method", [op[1], op[2]] + op[3])
				_DO_REFERENCE:
					ur.add_do_reference(op[1])
				_UNDO_REFERENCE:
					ur.add_undo_reference(op[1])
		# commit_action(execute=true) runs the do-ops now.
		ur.commit_action()

	func _commit_direct() -> void:
		var orphaned:Array = []
		for op in _ops:
			match op[0]:
				_DO_PROPERTY:
					op[1].set(op[2], op[3])
				_DO_METHOD:
					op[1].callv(op[2], op[3])
				_UNDO_REFERENCE:
					orphaned.append(op[1])
				# undo-side and do_reference ops are no-ops when not tracking.
		for obj in orphaned:
			if not is_instance_valid(obj):
				continue
			if obj is Node:
				obj.queue_free()
			elif obj is Object and not obj is RefCounted:
				obj.free()
