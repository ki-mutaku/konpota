class_name CustomerDropTarget
extends DirectDropTarget


func accepts(item: DirectDraggableItem) -> bool:
	if item == null or not is_instance_valid(item) or not super.accepts(item):
		return false
	var customer: Customer = get_parent() as Customer
	return (
		customer != null
		and customer.is_node_ready()
		and customer.can_receive_soup(item.get_interaction_payload())
	)
