local log = dofile("log.lua")
local reactor = dofile("reactor.lua")

local pypower_node = {}
local logger = log.Logger.new("node")

pypower_node.is_running = false
function pypower_node.activate()
	logger:info("Activating node")
	pypower_node.is_running = true
	rs.setOutput("top", true)
	rs.setOutput("back", true)
end

function pypower_node.deactivate()
	logger:info("Deactivating node")
	pypower_node.is_running = false
	rs.setOutput("top", false)
	rs.setOutput("back", false)
end

local REQUEST_HANDLERS = {
	['STATUS']=function(from_id, payload, distance) 
		-- Responds with status information
		return {
			['is_running']=pypower_node.is_running,
			['capacity']=false,
			['output']=false,
		}
	end,
	['ACTIVATE_NODE']=function(from_id, payload, distance)
		-- Activates this node
		pypower_node.activate()
	end,
	['DEACTIVATE_NODE']=function(from_id, payload, distance)
		-- Deactivates this node
		pypower_node.deactivate()
	end,
}

reactor.register_request_handlers(REQUEST_HANDLERS)

function pypower_node.start()
	logger:info("Starting node")
	rednet.open("front")
	pypower_node.deactivate()
	reactor.start(true, nil)
end

return pypower_node
