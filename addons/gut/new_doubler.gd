# ##############################################################################
#(G)odot (U)nit (T)est class
#
# ##############################################################################
# The MIT License (MIT)
# =====================
#
# Copyright (c) 2020 Tom "Butch" Wesley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# ##############################################################################
# Description
# -----------
# ##############################################################################


# ------------------------------------------------------------------------------
# This is what is left of stripping out the old "write a file" method of
# creating doubles.  It's now just a string with the load_it function.
# It seemed like there could be some utility in maintaining this little
# class.
# ------------------------------------------------------------------------------
class DoubledScript:
	extends File

	var _contents  = ''

	func add_source(s):
		_contents += s

	func get_contents():
		return _contents

	func load_it():
		if(_contents != ''):
			var script = GDScript.new()
			script.source_code = _contents
			# this is causing an error in 4.0 (does not halt execution, just prints it)
			# ERROR: Attempt to open script '' resulted in error 'File not found'.
			# Everyting seems to work.  I suspect that the path is empty and it
			# is throwing an erro that should not be thrown.  An issue has been
			# created and marked as bug.
			var result = script.reload()
			return script


# ------------------------------------------------------------------------------
# A stroke of genius if I do say so.  This allows for doubling a scene without
# having  to write any files.  By overloading the "instantiate" method  we can
# make whatever we want.
# ------------------------------------------------------------------------------
class PackedSceneDouble:
	extends PackedScene
	var _script =  null
	var _scene = null

	func set_script_obj(obj):
		_script = obj

	func instantiate(edit_state=0):
		var inst = _scene.instantiate(edit_state)
		if(_script !=  null):
			inst.set_script(_script)
		return inst

	func load_scene(path):
		_scene = load(path)




# ------------------------------------------------------------------------------
# START Doubler
# ------------------------------------------------------------------------------
var _utils = load('res://addons/gut/utils.gd').get_instance()
var _base_script_text = _utils.get_file_as_text('res://addons/gut/double_templates/script_template.txt')
var _script_collector = _utils.ScriptCollector.new()
# used by tests for debugging purposes.
var print_source = false


# ###############
# Properties
# ###############
var _stubber = _utils.Stubber.new()
func get_stubber():
	return _stubber
func set_stubber(stubber):
	_stubber = stubber

var _lgr = _utils.get_logger()
func get_logger():
	return _lgr
func set_logger(logger):
	_lgr = logger
	_method_maker.set_logger(logger)

var _spy = null
func get_spy():
	return _spy
func set_spy(spy):
	_spy = spy

var _gut = null
func get_gut():
	return _gut
func set_gut(gut):
	_gut = gut

var _strategy = null
func get_strategy():
	return _strategy
func set_strategy(strategy):
	_strategy = strategy


var _method_maker = _utils.MethodMaker.new()
func get_method_maker():
	return _method_maker

var _ignored_methods = _utils.OneToMany.new()
func get_ignored_methods():
	return _ignored_methods

# ###############
# Private
# ###############
func _init(strategy=_utils.DOUBLE_STRATEGY.SCRIPT_ONLY):
	set_logger(_utils.get_logger())
	_strategy = strategy


func _get_indented_line(indents, text):
	var to_return = ''
	for _i in range(indents):
		to_return += "\t"
	return str(to_return, text, "\n")


func _stub_to_call_super(parsed, method_name):
	if(_utils.non_super_methods.has(method_name)):
		return

	var path = parsed.script_path
	# if(obj_info.is_singleton()):
	# 	path = obj_info.get_singleton_name()
	# elif(obj_info.scene_path != null):
	# 	path = obj_info.scene_path

	var params = _utils.StubParams.new(path, method_name, parsed.subpath)
	params.to_call_super()
	_stubber.add_stub(params)


func _get_base_script_text(parsed, override_path, partial):
	var path = parsed.script_path
	if(override_path != null):
		path = override_path

	var stubber_id = -1
	if(_stubber != null):
		stubber_id = _stubber.get_instance_id()

	var spy_id = -1
	if(_spy != null):
		spy_id = _spy.get_instance_id()

	var gut_id = -1
	if(_gut != null):
		gut_id = _gut.get_instance_id()

	var values = {
		# Top  sections
		"extends":parsed.get_extends_text(),
		"constants":'',#obj_info.get_constants_text(),
		"properties":'',#obj_info.get_properties_text(),

		# metadata values
		"path":path,
		"subpath":_utils.nvl(parsed.subpath, ''),
		"stubber_id":stubber_id,
		"spy_id":spy_id,
		"gut_id":gut_id,
		"singleton_name":'',#_utils.nvl(obj_info.get_singleton_name(), ''),
		"is_partial":partial,#str(obj_info.make_partial_double).to_lower()
	}

	return _base_script_text.format(values)



func _create_double(parsed, strategy, override_path, partial):
	var base_script = _get_base_script_text(parsed, override_path, partial)
	var super_name = ""
	var path = ""

	path = parsed.script_path
	var dbl = DoubledScript.new()
	dbl.add_source(base_script)

	for method in parsed.get_local_methods():
		if(!method.is_black_listed() && !_ignored_methods.has(parsed.resource, method.meta.name)):
			var mthd = parsed.get_local_method(method.meta.name)
			dbl.add_source(_get_func_text(method.meta, path, super_name))

	if(strategy == _utils.DOUBLE_STRATEGY.INCLUDE_SUPER):
		for method in parsed.get_super_methods():
			if(!method.is_black_listed() && !_ignored_methods.has(parsed.resource, method.meta.name)):
				_stub_to_call_super(parsed, method.meta.name)
				dbl.add_source(_get_func_text(method.meta, path, super_name))

	if(print_source):
		print(_utils.add_line_numbers(dbl.get_contents()))

	return dbl


func _get_scene_script_object(scene):
	var state = scene.get_state()
	var to_return = null
	var root_node_path = NodePath(".")
	var node_idx = 0

	while(node_idx < state.get_node_count() and to_return == null):
		# Assumes that the first node we encounter that has a root node path, one
		# property, and that property is named 'script' is the GDScript for the
		# scene.  This could be flawed.
		if(state.get_node_path(node_idx) == root_node_path and state.get_node_property_count(node_idx) == 1):
			if(state.get_node_property_name(node_idx, 0) == 'script'):
				to_return = state.get_node_property_value(node_idx, 0)

		node_idx += 1

	return to_return


func _double_scene_and_script(scene, strategy, partial):
	var to_return = PackedSceneDouble.new()
	to_return.load_scene(scene.get_path())

	var script_obj = _get_scene_script_object(scene)
	if(script_obj != null):
		var script_dbl = null
		if(partial):
			script_dbl = _partial_double(script_obj, strategy, scene.get_path())
		else:
			script_dbl = _double(script_obj, strategy, scene.get_path())
		to_return.set_script_obj(script_dbl)

	return to_return


func _get_inst_id_ref_str(inst):
	var ref_str = 'null'
	if(inst):
		ref_str = str('instance_from_id(', inst.get_instance_id(),')')
	return ref_str


func _get_func_text(method_hash, path, super_=""):
	var override_count = null;
	if(_stubber != null):
		override_count = _stubber.get_parameter_count(path, method_hash.name)

	var text = _method_maker.get_function_text(method_hash, path, override_count, super_) + "\n"

	return text


# Override path is used with scenes.
func _double(obj, strategy, override_path=null):
	var parsed = _script_collector.parse(obj)
	var result = _create_double(parsed, strategy, override_path, false)
	return result.load_it()


func _partial_double(obj, strategy, override_path=null):
	var parsed = _script_collector.parse(obj)
	var result = _create_double(parsed, strategy, override_path, true)
	return result.load_it()


# -------------------------
# Public
# -------------------------

# double a script/object
func double(obj, strategy=_strategy):
	return _double(obj, strategy)

func partial_double(obj, strategy=_strategy):
	return _partial_double(obj, strategy)


# double a scene
func double_scene(scene, strategy=_strategy):
	return _double_scene_and_script(scene, strategy, false)

func partial_double_scene(scene, strategy=_strategy):
	return _double_scene_and_script(scene, strategy, true)


func double_gdnative(which):
	return _double(which, _utils.DOUBLE_STRATEGY.INCLUDE_SUPER, false)

func partial_double_gdnative(which):
	return _double(which, _utils.DOUBLE_STRATEGY.INCLUDE_SUPER, true)


func double_inner(path, subpath, strategy=_strategy):
	_lgr.error('Cannot double inner classes due to Godot bug.')
	return null

func partial_double_inner(path, subpath, strategy=_strategy):
	_lgr.error('Cannot double inner classes due to Godot bug.')
	return null


func add_ignored_method(obj, method_name):
	_ignored_methods.add(obj, method_name)
