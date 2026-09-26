class_name CostConfig
extends Resource

@export var lane_rate: float = 20.0        # per meter per lane
@export var elev_rate: float = 30.0        # per meter per meter above ground
@export var sunk_rate: float = 50.0        # per meter per meter below ground
@export var junction_base: float = 500.0
@export var light_base: float = 1500.0
@export var bulldoze_refund: float = 0.6
@export var prop_remove_cost: float = 200.0
