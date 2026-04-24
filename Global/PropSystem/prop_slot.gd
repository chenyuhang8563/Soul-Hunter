# Global/PropSystem/prop_slot.gd
## 背包中的一个物品堆叠槽位
class_name PropSlot
extends Resource

## 物品配置 ID（对应 PropItem.id）
@export var item_id: int = 0
## 当前数量
@export var count: int = 1
