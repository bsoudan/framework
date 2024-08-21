extends Node

func _ready():
	
	var NullCallable = func():
		pass
		
	assert(NullCallable != Callable(), "empty lambda does not equal empty callable")
	
	var OtherNullCallable = func():
		pass
		
	assert(NullCallable != OtherNullCallable, "different lambdas do not equal each other")

	assert(Callable() == Callable(), "empty callables are the same")

	
