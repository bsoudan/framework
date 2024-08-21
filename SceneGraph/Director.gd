extends Node

func scene_transition(scene, result):
	match [scene.name, result]:
		["Boot", _]:
			return "res://Scenes/Splash.tscn"
		#[_, { 'skip_splash' : true, ..}]:
			#return ""
		["Splash", _]:
			return "res://Scenes/Splash2.tscn"
		["Splash2", _]:
			return "res://Scenes/Splash.tscn"

var jobs = Util.job_queue()

func on_scene_complete(params, scene):
	jobs.add_job(func(): return await scene_complete_job(scene, params))
	
func scene_complete_job(scene, result):
	var ctx = Util.context("Director::scene_complete_job", "scene", scene.name)
	var is_current_scene = scene == get_tree().current_scene
	var parent = scene.get_parent()

	ctx.info("result=%s%s" % [result, ", is_current_scene" if is_current_scene else ""])
	
	scene.queue_free()
	await scene.tree_exited  # wait for the scene to be fully removed
	if is_current_scene:
		get_tree().unload_current_scene()
	
	ctx.info("scene removed from parent (%s)" % parent)

	var next_scene = scene_transition(scene, result)

	if not next_scene:
		push_warning(ctx.info("no scene transition defined"))
		if parent == get_parent():
			%ErrorLabel.visible = true
			%ErrorLabel.text = "Director: no scene transition defined for scene %s" % scene.name
		return
		
	ctx.info("next scene is %s" % next_scene)

	var progress = func(percent):
		push_warning(ctx.info("progress: %s" % percent))
		
	var load_result = await Util.load_threaded(next_scene, progress).done
	push_warning(ctx.info("load result is %s" % [load_result]))
	
	var new_scene = load_result[0]
	var err = load_result[1]
	if err != null:
		ctx.info(err)
		if parent == get_parent():
			%ErrorLabel.visible = true
			%ErrorLabel.text = "Director: %s" % err
		return

	%LoadProgress.visible = true
	var i = 1.0
	while i < 100.0:
		%LoadProgress.value = i
		await Util.next_process_frame()
		i = i + 0.1
	%LoadProgress.visible = false
	
	new_scene = new_scene.instantiate()	
	on_new_scene(new_scene)
	parent.add_child(new_scene)
	if is_current_scene:
		get_tree().current_scene = new_scene
	
	ctx.info("scene change complete.")

func on_new_scene(scene : SceneGraphNode):
	var err = scene.connect("scene_complete", on_scene_complete.bind(scene))
	assert(err == 0)

## detect boot scene	
#
#func _enter_tree():
	#print('director enter tree')
	#print(get_tree().connect("tree_changed", on_scenetree_tree_changed))
#
#func on_scenetree_tree_changed():
	#print('tree changed')
	#var current_scene = get_tree().current_scene
	#if not current_scene:
		#return
		#
	#get_tree().disconnect("tree_changed", on_scenetree_tree_changed)
	#
	#info("boot scene is %s" % current_scene)
#
	#on_new_scene(current_scene)
