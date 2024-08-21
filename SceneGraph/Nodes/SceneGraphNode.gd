extends Control
class_name SceneGraphNode

signal scene_complete(params)

func complete(params = {}):
	scene_complete.emit(params)
