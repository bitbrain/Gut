extends GutTest

class BaseTest:
	extends GutTest

	const DOUBLE_ME_PATH = 'res://test/resources/doubler_test_objects/double_me.gd'
	const DOUBLE_ME_SCENE_PATH = 'res://test/resources/doubler_test_objects/double_me_scene.tscn'
	const DOUBLE_EXTENDS_NODE2D = 'res://test/resources/doubler_test_objects/double_extends_node2d.gd'
	const DOUBLE_EXTENDS_WINDOW_DIALOG = 'res://test/resources/doubler_test_objects/double_extends_window_dialog.gd'
	const DOUBLE_WITH_STATIC = 'res://test/resources/doubler_test_objects/has_static_method.gd'
	const INNER_CLASSES_PATH = 'res://test/resources/doubler_test_objects/inner_classes.gd'

	var DoubleMe = load(DOUBLE_ME_PATH)
	var DoubleExtendsNode2D = load(DOUBLE_EXTENDS_NODE2D)
	var DoubleExtendsWindowDialog = load(DOUBLE_EXTENDS_WINDOW_DIALOG)
	var DoubleWithStatic = load(DOUBLE_WITH_STATIC)
	var DoubleMeScene = load(DOUBLE_ME_SCENE_PATH)
	var InnerClasses = load(INNER_CLASSES_PATH)

	var Doubler = load('res://addons/gut/doubler.gd')
	var print_source_when_failing = true

	func get_source(thing):
		var to_return = null
		if(_utils.is_instance(thing)):
			to_return = thing.get_script().get_source_code()
		else:
			to_return = thing.source_code
		return to_return


	func assert_source_contains(thing, look_for, text=''):
		var source = get_source(thing)
		var msg = str('Expected source for ', _strutils.type2str(thing), ' to contain "', look_for, '":  ', text)
		if(source == null || source.find(look_for) == -1):
			fail_test(msg)
			if(print_source_when_failing):
				var header = str('------ Source for ', _strutils.type2str(thing), ' ------')
				gut.p(header)
				gut.p(_utils.add_line_numbers(source))
		else:
			pass_test(msg)

	func assert_source_not_contains(thing, look_for, text=''):
		var source = get_source(thing)
		var msg = str('Expected source for ', _strutils.type2str(thing), ' to not contain "', look_for, '":  ', text)
		if(source == null || source.find(look_for) == -1):
			pass_test(msg)
		else:
			fail_test(msg)
			if(print_source_when_failing):
				var header = str('------ Source for ', _strutils.type2str(thing), ' ------')
				gut.p(header)
				gut.p(_utils.add_line_numbers(source))

	func print_source(thing):
		var source = get_source(thing)
		gut.p(_utils.add_line_numbers(source))



class TestTheBasics:
	extends BaseTest

	var _doubler = null

	var stubber = _utils.Stubber.new()
	func before_each():
		stubber.clear()
		_doubler = Doubler.new()
		_doubler.set_stubber(stubber)
		_doubler.set_gut(gut)
		_doubler.print_source = false

	func test_get_set_stubber():
		var dblr = Doubler.new()
		var default_stubber = dblr.get_stubber()
		assert_accessors(dblr, 'stubber', default_stubber, GDScript.new())

	func test_can_get_set_spy():
		assert_accessors(Doubler.new(), 'spy', null, GDScript.new())

	func test_get_set_gut():
		assert_accessors(Doubler.new(), 'gut', null, GDScript.new())

	func test_get_set_logger():
		assert_ne(_doubler.get_logger(), null)
		var l = load('res://addons/gut/logger.gd').new()
		_doubler.set_logger(l)
		assert_eq(_doubler.get_logger(), l)

	func test_doubler_sets_logger_of_method_maker():
		assert_eq(_doubler.get_logger(), _doubler._method_maker.get_logger())

	func test_setting_logger_sets_it_on_method_maker():
		var l = load('res://addons/gut/logger.gd').new()
		_doubler.set_logger(l)
		assert_eq(_doubler.get_logger(), _doubler._method_maker.get_logger())

	func test_get_set_strategy():
		assert_accessors(_doubler, 'strategy', _utils.DOUBLE_STRATEGY.SCRIPT_ONLY,  _utils.DOUBLE_STRATEGY.INCLUDE_SUPER)

	func test_can_set_strategy_in_constructor():
		var d = Doubler.new(_utils.DOUBLE_STRATEGY.INCLUDE_SUPER)
		assert_eq(d.get_strategy(), _utils.DOUBLE_STRATEGY.INCLUDE_SUPER)


class TestDoublingScripts:
	extends BaseTest

	var _doubler = null

	var stubber = _utils.Stubber.new()
	func before_each():
		stubber.clear()
		_doubler = Doubler.new()
		_doubler.set_stubber(stubber)
		_doubler.set_gut(gut)
		_doubler.print_source = false


	func test_doubling_object_includes_methods():
		var inst = _doubler.double(DoubleMe).new()
		assert_source_contains(inst, 'func get_value(')
		assert_source_contains(inst, 'func set_value(')

	func test_doubling_methods_have_parameters_1():
		var inst = _doubler.double(DoubleMe).new()
		assert_source_contains(inst, 'has_one_param(p_one=', 'first parameter for one param method is defined')

	# Don't see a way to see which have defaults and which do not, so we default
	# everything.
	func test_all_parameters_are_defaulted_to_null():
		var inst = _doubler.double(DoubleMe).new()
		assert_source_contains(inst,
			'has_two_params_one_default(' +
			'p_one=__gutdbl.default_val("has_two_params_one_default",0), '+
			'p_two=__gutdbl.default_val("has_two_params_one_default",1))')
		# assert_true(text.match('*has_two_params_one_default(p_arg0=__gut_default_val("has_two_params_one_default",0), p_arg1=__gut_default_val("has_two_params_one_default",1))*'))

	func test_doubled_thing_includes_stubber_metadata():
		var doubled = _doubler.double(DoubleMe).new()
		assert_ne(doubled.get('__gutdbl'), null)

	func test_doubled_thing_has_original_path_in_metadata():
		var doubled = _doubler.double(DoubleMe).new()
		assert_eq(doubled.__gutdbl.thepath, DOUBLE_ME_PATH)

	func test_doublecd_thing_has_gut_metadata():
		var doubled = _doubler.double(DoubleMe).new()
		assert_eq(doubled.__gutdbl.gut, gut)

	func test_keeps_extends():
		pending('Crashes hard in 4.0 a16 on assert_is')
		var doubled = _doubler.double(DoubleExtendsNode2D).new()
		# assert_is(doubled, Node2D)

	func test_does_not_add_duplicate_methods():
		var TheClass = load('res://test/resources/parsing_and_loading_samples/extends_another_thing.gd')
		_doubler.double(TheClass)
		assert_true(true, 'If we get here then the duplicates were removed.')


	func test_returns_class_that_can_be_instanced():
		var Doubled = _doubler.double(DoubleMe)
		var doubled = Doubled.new()
		assert_ne(doubled, null)

	func test_doubles_retain_signals():
		var d = _doubler.double(DOUBLE_ME_PATH).new()
		assert_has_signal(d, 'signal_signal')


class TestAddingIgnoredMethods:
	extends BaseTest
	var _doubler = null

	var stubber = _utils.Stubber.new()
	func before_each():
		stubber.clear()
		_doubler = Doubler.new()
		_doubler.set_stubber(stubber)
		_doubler.set_gut(gut)
		_doubler.print_source = false

	func test_can_add_to_ignore_list():
		assert_eq(_doubler.get_ignored_methods().size(), 0, 'initial size')
		_doubler.add_ignored_method(DoubleWithStatic, 'some_method')
		assert_eq(_doubler.get_ignored_methods().size(), 1, 'after add')

	func test_when_ignored_methods_are_a_local_method_mthey_are_not_present_in_double_code():
		_doubler.add_ignored_method(DoubleMe, 'has_one_param')
		var c = _doubler.double(DoubleMe)
		assert_source_not_contains(c.new(), 'has_one_param')

	func test_when_ignored_methods_are_a_super_method_they_are_not_present_in_double_code():
		_doubler.add_ignored_method(DoubleMe, 'is_connected')
		var c = _doubler.double(DoubleMe, _utils.DOUBLE_STRATEGY.INCLUDE_SUPER)
		assert_source_not_contains(c.new(), 'is_connected')

	func test_can_double_classes_with_static_methods():
		_doubler.add_ignored_method(DoubleWithStatic, 'this_is_a_static_method')
		var d = _doubler.double(DoubleWithStatic).new()
		assert_null(d.this_is_not_static())


class TestDoubleScene:
	extends BaseTest
	var _doubler = null

	var stubber = _utils.Stubber.new()
	func before_each():
		stubber.clear()
		_doubler = Doubler.new()
		_doubler.set_stubber(stubber)
		_doubler.set_gut(gut)
		_doubler.print_source = false

	func test_can_double_scene():
		var obj = _doubler.double_scene(DoubleMeScene)
		var inst = obj.instantiate()
		assert_eq(inst.return_hello(), null)

	func test_can_add_doubled_scene_to_tree():
		var inst = _doubler.double_scene(DoubleMeScene).instantiate()
		add_child(inst)
		assert_ne(inst.label, null)
		remove_child(inst)

	func test_metadata_for_scenes_script_points_to_scene_not_script():
		var inst = _doubler.double_scene(DoubleMeScene).instantiate()
		assert_eq(inst.__gutdbl.thepath, DOUBLE_ME_SCENE_PATH)

	func test_can_override_strategy_when_doubling_scene():
		_doubler.set_strategy(_utils.DOUBLE_STRATEGY.SCRIPT_ONLY)
		var inst = autofree(_doubler.double_scene(DoubleMeScene, _utils.DOUBLE_STRATEGY.INCLUDE_SUPER).instantiate())
		assert_source_contains(inst, 'func is_blocking_signals')

	func test_full_start_has_block_signals():
		_doubler.set_strategy(_utils.DOUBLE_STRATEGY.INCLUDE_SUPER)
		var inst = autofree(_doubler.double_scene(DoubleMeScene).instantiate())
		assert_source_contains(inst, 'func is_blocking_signals')


class TestDoubleStrategyIncludeSuper:
	extends BaseTest

	func _hide_call_back():
		pass

	var doubler = null
	var stubber = _utils.Stubber.new()

	func before_all():
		var d = Doubler.new(_utils.DOUBLE_STRATEGY.INCLUDE_SUPER)


	func before_each():
		stubber.clear()
		doubler = Doubler.new(_utils.DOUBLE_STRATEGY.INCLUDE_SUPER)
		doubler.set_stubber(stubber)


	func test_built_in_overloading_ony_happens_on_full_strategy():
		doubler.set_strategy(_utils.DOUBLE_STRATEGY.SCRIPT_ONLY)
		var inst = doubler.double(DoubleMe).new()
		var txt = get_source(inst)
		assert_false(txt == '', "text is not empty")
		assert_source_not_contains(inst, 'func is_blocking_signals', 'does not have non-overloaded methods')

	func test_can_override_strategy_when_doubling_script():
		doubler.set_strategy(_utils.DOUBLE_STRATEGY.SCRIPT_ONLY)
		var inst = doubler.double(DoubleMe, _utils.DOUBLE_STRATEGY.INCLUDE_SUPER).new()
		assert_source_contains(inst, 'func is_blocking_signals')

	func test_when_everything_included_you_can_still_make_an_a_new_object():
		var inst = doubler.double(DoubleMe).new()
		assert_ne(inst, null)

	func test_when_everything_included_you_can_still_make_a_new_node2d():
		var inst = autofree(doubler.double(DoubleExtendsNode2D).new())
		assert_ne(inst, null)

	func test_when_everything_included_you_can_still_double_a_scene():
		pending('YIELD')
		return

		var inst = autofree(doubler.double_scene(DOUBLE_ME_SCENE_PATH).instantiate())
		add_child(inst)
		assert_ne(inst, null, "instantiate is not null")
		assert_ne(inst.label, null, "Can get to a label on the instantiate")
		# pause so _process gets called
		await yield_for(3).YIELD

	func test_double_includes_methods_in_super():
		var inst = doubler.double(DoubleExtendsWindowDialog).new()
		assert_source_contains(inst, 'connect(')

	func test_can_call_a_built_in_that_has_default_parameters():
		pending('have to rework defaults')
		return

		var inst = autofree(doubler.double(DoubleExtendsWindowDialog).new())
		inst.connect('hide', self._hide_call_back)
		pass_test("if we got here, it worked")


	func test_doubled_builtins_call_super():
		var inst = autofree(doubler.double(DoubleExtendsWindowDialog).new())
		# Make sure the function is in the doubled class definition
		assert_source_contains(inst, 'func add_user_signal(p_signal')
		# Make sure that when called it retains old functionality.
		inst.add_user_signal('new_one', [])
		inst.add_user_signal('new_two', ['a', 'b'])
		assert_has_signal(inst, 'new_one')
		assert_has_signal(inst, 'new_two')

	func test_doubled_builtins_are_added_as_stubs_to_call_super():
		var inst = autofree(doubler.double(DoubleExtendsWindowDialog).new())
		assert_true(doubler.get_stubber().should_call_super(inst, 'add_user_signal'))

class TestPartialDoubles:
	extends BaseTest

	var doubler = null
	var stubber = _utils.Stubber.new()

	func before_each():
		stubber.clear()
		doubler = Doubler.new()
		doubler.set_stubber(stubber)

	func test_can_make_partial_of_script():
		var inst = doubler.partial_double(DoubleMe).new()
		inst.set_value(10)
		assert_eq(inst.get_value(), 10)

	func test_double_script_does_not_make_partials():
		var inst = doubler.double(DoubleMe).new()
		assert_eq(inst.get_value(), null)

	func test_can_make_partial_of_inner_script():
		pending('Broke in 4.0 see TestDoubleInnerClasses');
		return

		var inst = doubler.partial_double_inner(InnerClasses, 'InnerA').new()
		assert_eq(inst.get_a(), 'a')

	func test_can_make_partial_of_scene():
		var inst = autofree(doubler.partial_double_scene(DoubleMeScene).instantiate())
		assert_eq(inst.return_hello(), 'hello')

	func test_double_scene_does_not_call_supers():
		var inst = autofree(doubler.double_scene(DoubleMeScene).instantiate())
		assert_eq(inst.return_hello(), null)

	func test_init_is_not_stubbed_to_call_super():
		var inst = doubler.partial_double(DoubleMe).new()
		var text = get_source(inst)
		assert_false(text.match("*__gutdbl.should_call_super('_init'*"), 'should not call super _init')

	func test_can_partial_and_normal_double_in_same_test():
		var double = doubler.double(DoubleMe).new()
		var p_double = doubler.partial_double(DoubleMe).new()

		assert_null(double.get_value(), 'double get_value')
		assert_eq(p_double.get_value(), 0, 'partial get_value')
		if(is_failing()):
			print(doubler.get_stubber().to_s())



class TestDoubleGDNaviteClasses:
	extends BaseTest

	var _doubler = null
	var _stubber = _utils.Stubber.new()

	func before_each():
		_stubber.clear()
		_doubler = Doubler.new()
		_doubler.set_stubber(_stubber)

	func test_can_double_Node2D():
		var d_node_2d = _doubler.double_gdnative(Node2D)
		assert_not_null(d_node_2d)

	func test_can_partial_double_Node2D():
		var pd_node_2d  = _doubler.partial_double_gdnative(Node2D)
		assert_not_null(pd_node_2d)

	func test_can_make_instances_of_native_doubles():
		var crect_double_inst = _doubler.double_gdnative(ColorRect).new()
		assert_not_null(crect_double_inst)


class TestDoubleInnerClasses:
	extends BaseTest
	var skip_script = 'Cannot extend inner classes godotengine #65666'

	var doubler = null

	func before_each():
		doubler = Doubler.new()
		doubler.set_stubber(_utils.Stubber.new())

	func test_can_instantiate_inner_double():
		var Doubled = doubler.double_inner(InnerClasses, InnerClasses.InnerB.InnerB1)
		assert_has_method(Doubled.new(), 'get_b1')

	func test_doubled_instance_returns_null_for_get_b1():
		var dbld = doubler.double_inner(InnerClasses, InnerClasses.InnerB.InnerB1).new()
		assert_null(dbld.get_b1())

	func test_doubled_instances_extend_the_inner_class():
		var inst = doubler.double_inner(InnerClasses, InnerClasses.InnerA).new()
		assert_true(inst is InnerClasses.InnerA, 'instance should be an InnerA')
		if(is_failing()):
			print_source(inst)

	func test_doubled_inners_that_extend_inners_get_full_inheritance():
		var inst = doubler.double_inner(InnerClasses, InnerClasses.InnerCA).new()
		assert_has_method(inst, 'get_a')
		assert_has_method(inst, 'get_ca')

	func test_doubled_inners_have_subpath_set_in_metadata():
		var inst = doubler.double_inner(InnerClasses, InnerClasses.InnerCA).new()
		assert_eq(inst.__gutdbl.subpath, 'InnerCA')

	func test_non_inners_have_empty_subpath():
		var inst = doubler.double(InnerClasses).new()
		assert_eq(inst.__gutdbl.subpath, '')

	func test_can_override_strategy_when_doubling():
		#doubler.set_strategy(DOUBLE_STRATEGY.FULL)
		var d = doubler.double_inner(InnerClasses, InnerClasses.InnerA, DOUBLE_STRATEGY.FULL)
		# make sure it has something from Object that isn't implemented
		assert_source_contains(d.new() , 'func disconnect(p_signal')
		assert_eq(doubler.get_strategy(), DOUBLE_STRATEGY.SCRIPT_ONLY, 'strategy should have been reset')

	func test_doubled_inners_retain_signals():
		var inst = doubler.double_inner(InnerClasses, InnerClasses.InnerWithSignals).new()
		assert_has_signal(inst, 'signal_signal')

	func test_double_inner_does_not_call_supers():
		var inst = doubler.double_inner(InnerClasses, InnerClasses.InnerA).new()
		assert_eq(inst.get_a(), null)


class TestAutofree:
	extends BaseTest

	class InitHasDefaultParams:
		var a = 'b'

		func _init(value='asdf'):
			a = value

	func test_doubles_are_autofreed():
		var doubled = double(DoubleExtendsNode2D).new()
		gut.get_autofree().free_all()
		assert_no_new_orphans()

	func test_partial_doubles_are_autofreed():
		var doubled = partial_double(DoubleExtendsNode2D).new()
		gut.get_autofree().free_all()
		assert_no_new_orphans()


class TestInitParameters:
	extends BaseTest
	var skip_script = 'Cannot extend inner classes, and this depends on inners for the object under test.  it could be moved instead.'

	class InitDefaultParameters:
		var value = 'start_value'

		func _init(p_arg0='default_value'):
			value = p_arg0

	var _doubler = null


	var DoubledClass = null
	var PartialDoubledClass = null
	var TestDoubler = load('res://tests_4_0/test_new_doubler.gd')

	func before_each():
		print('path = ', self.get_script().get_path())
		print('resource_path = ', self.get_script().resource_path)
		_doubler = Doubler.new()
		_doubler.set_gut(gut)
		_doubler.print_source = false

		DoubledClass = _doubler.double_inner(
			TestDoubler,
			TestDoubler.TestInitParameters.InitDefaultParameters)
		PartialDoubledClass = _doubler.partial_double_inner(
			TestDoubler,
			TestDoubler.TestInitParameters.InitDefaultParameters)

	# This is due to the gut defaulting mechanism since the
	# default value cannot be known
	func test_double_gets_null_for_default_value():
		var doubled = DoubledClass.new()
		assert_null(doubled.value)

	func test_double_gets_passed_value():
		var doubled = DoubledClass.new('test')
		assert_eq(doubled.value, 'test')

	func test_partial_double_gets_passed_value():
		var doubled = PartialDoubledClass.new('test')
		assert_eq(doubled.value, 'test')

	func test_partial_double_gets_null_for_default_value():
		var doubled = PartialDoubledClass.new()
		assert_null(doubled.value)


















# class TestDoubleSingleton:
# 	extends BaseTest

# 	var _doubler = null
# 	var _stubber = _utils.Stubber.new()

# 	func before_each():
# 		_stubber.clear()
# 		_doubler = Doubler.new()
# 		_doubler.set_output_dir(TEMP_FILES)
# 		_doubler.set_stubber(_stubber)
# 		_doubler._print_source = false

# 	func test_can_make_double_of_input():
# 		var Doubled = _doubler.double_singleton("Input")
# 		assert_not_null(Doubled)

# 	func test_can_make_instance_of_double():
# 		var doubled = _doubler.double_singleton("Input").new()
# 		assert_not_null(doubled)

# 	func test_double_gets_methods_from_input():
# 		var doubled = _doubler.double_singleton("Input").new()
# 		assert_true(doubled.has_method("action_press"))

# 	func test_normal_double_of_input_does_not_have_implementations():
# 		var doubled = _doubler.double_singleton("Input").new()
# 		assert_null(doubled.is_action_just_pressed())

# 	func test_partial_double_gets_implementation():
# 		var doubled = _doubler.partial_double_singleton("Input").new()
# 		assert_false(doubled.is_action_just_pressed("foobar"))

# 	func test_double_gets_constants():
# 		var doubled = _doubler.double_singleton("Input").new()
# 		assert_eq(doubled.CURSOR_VSPLIT, Input.CURSOR_VSPLIT)

# 	func test_partial_double_gets_wired_properties():
# 		var doubled = _doubler.partial_double_singleton("XRServer").new()
# 		assert_eq(doubled.world_scale, 1.0, "property")
# 		assert_eq(doubled.get_world_scale(), 1.0, "accessor")

# 	func test_partial_double_setters_are_wired_to_set_source_property():
# 		var doubled = _doubler.partial_double_singleton("XRServer").new()
# 		doubled.world_scale = 0.5
# 		assert_eq(XRServer.get_world_scale(), 0.5, "accessor")
# 		# make sure to put it back to what it was, who knows what it does.
# 		XRServer.world_scale = 1.0

# 	func test_double_gets_unwired_properties_by_default():
# 		var doubled = _doubler.double_singleton("XRServer").new()
# 		assert_null(doubled.world_scale)

# 	# These singletons were found using print_instanced_ClassDB_classes in
# 	# scratch/get_info.gd and are most likely the only singletons that
# 	# should be doubled as of now.
# 	var eligible_singletons = [
# 		"XRServer", "AudioServer", "CameraServer",
# 		"Engine", "Geometry2D", "Input",
# 		"InputMap", "IP", "JavaClassWrapper",
# 		"JavaScript", "JSON", "Marshalls",
# 		"OS", "Performance", "PhysicsServer2D",
# 		"PhysicsServer3D",
# 		"ProjectSettings", "ResourceLoader",
# 		"ResourceSaver", "TranslationServer", "VisualScriptEditor",
# 		"RenderingServer",
# 		# these two were missed by print_instanced_ClassDB_classes but were in
# 		# the global scope list.
# 		"ClassDB", "NavigationMeshGenerator"
# 	]
# 	func test_can_make_doubles_of_eligible_singletons(singleton = use_parameters(eligible_singletons)):
# 		# !! Keep eligible singletons in line with eligible_singletons in test_test_stubber_doubler
# 		assert_not_null(_doubler.double_singleton(singleton), singleton)

# 	# Note that setters aren't tested b/c picking valid values automatically is
# 	# an unreasonable approach and I didn't want to maintain a list.  If a setter
# 	# or getter method is not found when trying to make the double then an
# 	# error should be printed.  It seems safe to assume if the getters are wired
# 	# and there aren't any error messages when this test runs then the setters
# 	# are also wired.  A specific setter is tested in a previous test, just
# 	# not on all properties of all the eligible singletons.
# 	func test_property_getters_wired_for_partials_of_eligible_singletons(singleton = use_parameters(eligible_singletons)):
# 		var props = ClassDB.class_get_property_list(singleton)
# 		for prop in props:
# 			var double = partial_double_singleton(singleton).new()
# 			var parent_inst = _utils.get_singleton_by_name(singleton)
# 			assert_eq(double.get(prop["name"]), parent_inst.get(prop["name"]),
# 				str(singleton, ".", prop["name"]))

# 	var os_method_names = ['get_processor_count']
# 	func test_OS_methods(method_name = use_parameters(os_method_names)):
# 		var dbl_os = _doubler.partial_double_singleton('OS').new()
# 		assert_eq(dbl_os.has_method(method_name), OS.has_method(method_name), 'has ' + method_name)

# 	var input_method_names = ['something']
# 	func test_Input_methods(method_name = use_parameters(input_method_names)):
# 		var dbl_input = _doubler.partial_double_singleton('Input')
# 		assert_eq(dbl_input.has_method(method_name), Input.has_method(method_name), 'has ' + method_name)
