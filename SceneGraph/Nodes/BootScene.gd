extends SceneGraphNode
class_name BootScene

func _ready():
	Director.on_new_scene(self)
	complete()
