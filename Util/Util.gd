extends Node

class Multiwaiter extends RefCounted:
	signal any(sig, args)
	signal all(signals)

	var results: Dictionary = {} # signal: {has_emitted: bool, data: any}

	func _init(signals: Array) -> void:
		for s in signals:
			var signal_func = func(arg1 = Const.NullSignal, arg2 = Const.NullSignal, arg3 = Const.NullSignal, arg4 = Const.NullSignal, arg5 = Const.NullSignal, arg6 = Const.NullSignal, arg7 = Const.NullSignal, arg8 = Const.NullSignal, arg9 = Const.NullSignal):
				on_signal(s, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
			s.connect(signal_func)

	func on_signal(sig: Signal, arg1 = Const.NullSignal, arg2 = Const.NullSignal, arg3 = Const.NullSignal, arg4 = Const.NullSignal, arg5 = Const.NullSignal, arg6 = Const.NullSignal, arg7 = Const.NullSignal, arg8 = Const.NullSignal, arg9 = Const.NullSignal) -> void:
		var args = Const.filter_null_signals([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9])
		any.emit(sig, args)

		if len(any.get_connections()):
			push_warning("stopping cause any")
			stop()
			
		results[sig] = {'signal' : sig, 'args' : args}

		all.emit(results)
		
		if len(results) == len(get_incoming_connections()):
			push_warning("stopping cause all")
			stop()

	func stop():
		for c in get_incoming_connections():
			self.disconnect(c['signal'], c['callable'])

func multiwait(arg1: Signal, arg2: Signal, arg3: Signal = Const.NullSignal, arg4: Signal = Const.NullSignal, arg5: Signal = Const.NullSignal, arg6: Signal = Const.NullSignal, arg7: Signal = Const.NullSignal, arg8: Signal = Const.NullSignal, arg9: Signal = Const.NullSignal):
	var args = Const.filter_null_signals([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9])
	return Multiwaiter.new(args)

func timeout(duration: float):
	return get_tree().create_timer(duration).timeout

func next_process_frame():
	return await wait_process_frames(1)

func wait_process_frames(count: int):
	var initial = Engine.get_process_frames()
	
	while Engine.get_process_frames() < initial + count:
		await get_tree().process_frame
		
	return Engine.get_frames_drawn() - initial

class JobQueue extends Object:
	var jobs: Array[Callable] = []

	func add_job(method: Callable):
		jobs.append(method)

		if len(jobs) > 1:
			return

		while len(jobs) > 0:
			await jobs[0].call()
			jobs.remove_at(0)

func job_queue():
	return JobQueue.new()

class Tag:
	var tag: String
	var value: Variant
	
	func _init(tag_: String, value_: Variant):
		tag = tag_
		value = value_

class Context:
	var source
	var static_tags: Array[Tag] = []

	func _init(source_, tags: Array[Tag]):
		source = source_
		if tags != null:
			self.static_tags = tags
	
	func with_tags(name1: String, value1, name2: String = "", value2 = null, name3: String = "", value3 = null, name4: String = "", value4 = null):
		var result = static_tags.duplicate()
		if name1: result.append(Tag.new(name1, value1))
		if name2: result.append(Tag.new(name2, value2))
		if name3: result.append(Tag.new(name3, value3))
		if name4: result.append(Tag.new(name4, value4))
		
		return Context.new(source, result)
		
	func info(line: String):
		var tags = static_tags.duplicate()
		
		tags.append(Tag.new("cur_frame", Engine.get_process_frames()))
		
		var tag_text = tags.reduce(func(result: String, tag: Tag):
			if result == "":
				return "%s=%s" % [tag.tag, tag.value]
			else:
				return "%s, %s=%s" % [result, tag.tag, tag.value]
		, "")
		
		var output = "%s: [%s] %s" % [source, tag_text, line]
		print(output)
		return output

func context(source: String, name1: String, value1, name2: String = "", value2 = null, name3: String = "", value3 = null, name4: String = "", value4 = null):
	var result: Array[Tag] = [Tag.new("orig_frame", Engine.get_process_frames())]

	if name1: result.append(Tag.new(name1, value1))
	if name2: result.append(Tag.new(name2, value2))
	if name3: result.append(Tag.new(name3, value3))
	if name4: result.append(Tag.new(name4, value4))
	
	return Context.new(source, result)
	

class ThreadedResourceLoader extends RefCounted:
	signal progress(percent)
	signal done(resource, err)
	
	static var jobs = JobQueue.new()

	func _init(path, progress_func: Callable = Const.NullCallable):
		if progress_func != Const.NullCallable:
			progress.connect(progress_func)
		jobs.add_job(func(): load_job(path))
		
	func load_job(path):
		var err = ResourceLoader.load_threaded_request(path)
		if err != OK:
			done.emit(null, "ResourceLoader.load_threaded_request for %s failed: %s" % [path, error_string(err)])
			return
		
		var resource = null	
		var progress_arr = []
		
		while true:
			await Util.timeout(0.10)

			var loading_status = ResourceLoader.load_threaded_get_status(path, progress_arr)
			progress.emit(progress_arr[0])

			match loading_status:
				ResourceLoader.THREAD_LOAD_LOADED:
					resource = ResourceLoader.load_threaded_get(path)
					err = null
					break					
				ResourceLoader.THREAD_LOAD_FAILED:
					err = "ResourceLoader.load_threaded_request failed for %s" % path
					break
				ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					err = 'ResourceLoader.load_threaded_request deected invalid resource for %s' % path
					break
					
		done.emit(resource, err)

func load_threaded(path, progress_func: Callable = Const.NullCallable):
	if ResourceLoader.has_cached(path):
		if progress_func != Const.NullCallable:
			progress_func.call(1.0)
		return ResourceLoader.load(path)

	return ThreadedResourceLoader.new(path, progress_func)

func find_nodes_by_class(node: Node, className: String, recursive: bool) -> Array[Node]:
	var result: Array[Node]
	find_nodes_by_class_(node, className, recursive, result)
	return result

func find_nodes_by_class_(node: Node, className: String, recursive: bool, result: Array[Node]) -> void:
	for child in node.get_children():
		if child.is_class(className) :
			result.push_back(child)
		if recursive:
			find_nodes_by_class_(child, className, recursive, result)

class Error extends Object:
	var message: String

	func _init(message_: String):
		message = message_

	func _to_string() -> String:
		return "error: %s" % message

func is_error(object):
	return object is Util.Error

func error(msg):
	return Error.new(msg)


	
