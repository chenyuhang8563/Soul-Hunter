class_name TileMapUtils
extends RefCounted

## 从场景中查找 TileMapLayer
## 查找顺序: Environment/TileMapLayer -> TileMapLayer
## @param scene 场景节点
## @return TileMapLayer 实例，未找到则返回 null
static func get_tilemap_from_scene(scene: Node) -> TileMapLayer:
	if not scene:
		return null
	
	var tilemap: TileMapLayer = scene.get_node_or_null("Environment/TileMapLayer")
	if not tilemap:
		tilemap = scene.get_node_or_null("TileMapLayer")
	
	return tilemap
