extends SceneGraphNode
class_name SplashScene

signal skip()

func _ready():
	var sig = await Util.multiwait(Util.timeout(5.0), skip).any
	var result = {}
	if sig[0] == skip:
		result = {'skip_splash' : true}
	complete(result)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed:
		skip.emit()
	if event is InputEventKey and event.is_pressed:
		skip.emit()
