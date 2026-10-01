extends RigidBody3D
@export var knockdown_impulse: float = 12.0
var fallen: bool = false
func knock_down(direction: Vector3,impact_speed: float) -> bool:
    if fallen:
        return false
    fallen=true
    freeze=false
    sleeping=false
    apply_impulse(direction*impact_speed*knockdown_impulse+Vector3.UP*10.0,Vector3(0,2.0,0))
    return true
