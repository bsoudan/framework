extends Node

var NullCallable = func():
	assert(false, "null callable invoked")

var NullSignal = Signal(self, "null signal")

func filter_null_signals(a: Array[Signal]):
	return a.filter(func(s: Signal):
		return s != Const.NullSignal
	)

func _init():
	assert(Callable() == Callable(), "empty callables are the same")

	assert(NullCallable != Callable(), "null callable should be different than empty callable")
	
	var EmptyCallable = func():
		pass
		
	assert(NullCallable != EmptyCallable, "null callable should not equal empty callable")
	
	var OtherEmptyCallable = func():
		pass
		
	assert(EmptyCallable != OtherEmptyCallable, "different empty lambdas do not equal each other")


	
