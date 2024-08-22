extends SceneGraphNode
class_name MenuScene

func _ready():
	for b in Util.find_nodes_by_class(self, "Button", true):
		b.pressed.connect(complete.bind(b.name))
