# Global/PropSystem/prop_item.gd
## 物品静态配置数据
class_name PropItem
extends Resource

# ============================================================
#  枚举定义
# ============================================================

## 物品类型枚举
enum PropType {
	CONSUMABLE,  # 消耗品（药水、卷轴等）
	EQUIPMENT,   # 装备（武器、防具等）
	MATERIAL,    # 材料（合成/升级材料）
	QUEST        # 任务道具
}

## 物品稀有度枚举
enum PropRarity {
	COMMON,      # 普通
	UNCOMMON,    # 精良
	RARE,        # 稀有
	EPIC,        # 史诗
	LEGENDARY    # 传说
}

# ============================================================
#  导出属性
# ============================================================

## 物品唯一ID
@export var id: int = 0
## 物品名称
@export var name: String = ""
## 物品类型
@export var type: PropType = PropType.MATERIAL
## 物品稀有度
@export var rarity: PropRarity = PropRarity.COMMON
## 物品描述
@export var description: String = ""
## 图标资源路径
@export var icon_path: String = ""
## 最大堆叠数量（0 表示不可堆叠，内部会当作 1 处理）
@export var max_stack: int = 99
## 物品购买价格
@export var buy_price: int = 0
## 物品出售价格
@export var sell_price: int = 0
