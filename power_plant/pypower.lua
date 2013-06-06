local reactor = dofile("reactor.lua")
local pypower = {}

function pypower.activate_node(node_id)
	reactor.transmit(node_id, "ACTIVATE_NODE", '')
end

function pypower.deactivate_node(node_id)
	reactor.transmit(node_id, "DEACTIVATE_NODE", '')
end

function pypower.deactivate_all()
	reactor.transmit(nil, "DEACTIVATE_NODE", '')
end

function pypower.node_status(node_id)
	return reactor.transmit(node_id, "STATUS", '')().is_running
end

return pypower