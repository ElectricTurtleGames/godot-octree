## An extension of OctreeLeaf that acts as a container for a node instead of the node needing to extend OctreeLeaf
extends OctreeLeaf
class_name OctreeLeafContainer

var leaf_item: Variant

func set_item(item: Variant):
    leaf_item = item
    add_child(leaf_item)
