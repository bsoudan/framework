extends Node

class Multiwaiter extends RefCounted:
	signal any(sig, args)
	signal all(signals)

	var results: Dictionary = {} # signal: {has_emitted: bool, data: any}

	func _init(signals: Array) -> void:
		for s in signals:
			var signal_func = func(arg1 = NullSignal, arg2 = NullSignal, arg3 = NullSignal, arg4 = NullSignal, arg5 = NullSignal, arg6 = NullSignal, arg7 = NullSignal, arg8 = NullSignal, arg9 = NullSignal):
				on_signal(s, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
			s.connect(signal_func)

	var NullSignal: Signal = Signal()

	func exclude_nulls(a: Array[Signal]):
		return a.filter(func(s: Signal):
			return s != NullSignal
		)

	func on_signal(sig: Signal, arg1 = NullSignal, arg2 = NullSignal, arg3 = NullSignal, arg4 = NullSignal, arg5 = NullSignal, arg6 = NullSignal, arg7 = NullSignal, arg8 = NullSignal, arg9 = NullSignal) -> void:
		var args = exclude_nulls([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9])
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

var NullSignal: Signal = Signal()

func exclude_nulls(a: Array[Signal]):
	return a.filter(func(s: Signal):
		return s != NullSignal
	)

func multiwait(arg1: Signal, arg2: Signal, arg3: Signal = NullSignal, arg4: Signal = NullSignal, arg5: Signal = NullSignal, arg6: Signal = NullSignal, arg7: Signal = NullSignal, arg8: Signal = NullSignal, arg9: Signal = NullSignal):
	var args = exclude_nulls([arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9])
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

	var NullCallable = func():
		pass

	func _init(path, progress_func: Callable = NullCallable):
		if progress_func != NullCallable:
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

var NullCallable = func():
	pass

func load_threaded(path, progress_func: Callable = NullCallable):
	if ResourceLoader.has_cached(path):
		if progress_func != NullCallable:
			progress_func.call(1.0)
		return ResourceLoader.load(path)

	return ThreadedResourceLoader.new(path, progress_func)
