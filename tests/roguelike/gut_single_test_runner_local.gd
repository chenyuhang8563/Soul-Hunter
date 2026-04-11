extends Node

const GutConfigScript := preload("res://addons/gut/gut_config.gd")
const GutRunnerScene := preload("res://addons/gut/gui/GutRunner.tscn")
const ResultExporterScript := preload("res://addons/gut/result_exporter.gd")

const RESULT_JSON_PATH := "user://gut_single_test.json"
const RESULT_BBCODE_PATH := "user://gut_single_test.bbcode"

@export var selected_script := "test_arena_flow.gd"
@export var unit_test_name := ""

func _ready() -> void:
	var config = GutConfigScript.new()
	config.load_options("res://.gutconfig.json")
	config.options.selected = selected_script
	config.options.unit_test_name = unit_test_name
	config.options.should_exit = true
	config.options.should_exit_on_success = false
	config.options.failure_error_types = ["gut", "push_error"]

	var runner = GutRunnerScene.instantiate()
	runner.result_json_path = RESULT_JSON_PATH
	runner.result_bbcode_path = RESULT_BBCODE_PATH
	runner._ran_from_editor = true
	runner.set_gut_config(config)
	runner.gut.end_run.connect(func() -> void:
		var exporter = ResultExporterScript.new()
		exporter.write_json_file(runner.gut, RESULT_JSON_PATH)
	, CONNECT_ONE_SHOT)
	add_child(runner)
	runner.run_tests()
