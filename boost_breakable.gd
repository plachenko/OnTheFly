extends Node3D

@export var enabled: bool = true
@export var visual_root: NodePath = NodePath("..")
@export var minimum_impact_speed: float = 8.0
var broken: bool = false

func object_size() -> float:
    var target = get_node(visual_root) as Node3D
    var meshes = target.find_children("*","MeshInstance3D",true,false)
    if target is MeshInstance3D:
        meshes.append(target)
    var bounds = AABB()
    var first = true
    for mesh in meshes:
        var local_box: AABB = (target.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
        bounds = local_box if first else bounds.merge(local_box)
        first = false
    var dimensions = bounds.size*target.global_transform.basis.get_scale().abs()
    return maxf(dimensions.x,maxf(dimensions.y,dimensions.z))

func smash(size_limit: float, impact_speed: float, direction: Vector3) -> bool:
    if broken or not enabled or impact_speed<minimum_impact_speed or object_size()>size_limit:
        return false
    broken=true
    var body = get_parent() as CollisionObject3D
    body.set_deferred("collision_layer",0)
    body.set_deferred("collision_mask",0)
    if body is RigidBody3D:
        body.set_deferred("freeze",true)
    var target = get_node(visual_root)
    var meshes = target.find_children("*","MeshInstance3D",true,false)
    if target is MeshInstance3D:
        meshes.append(target)
    for mesh in meshes:
        mesh.layers=0
    $Debris.direction=global_basis.inverse()*(direction+Vector3.UP*.5).normalized()
    $Debris.emitting=true
    return true
