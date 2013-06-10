local log = dofile("log.lua")
local reactor = dofile("reactor.lua")

local logger = log.Logger.new("node")
local pycowfarm_node = {}

function pycowfarm_node.open()
	rs.setOutput("top", false)
end

function pycowfarm_node.close()
	rs.setOutput("top", true)
end

local REQUEST_HANDLERS = {
	['STATUS']=function(from_id, payload, distance)
		return {
			['is_open']=not rs.getOutput("top"),
			['id']=os.getComputerID(),
			['name']=os.getComputerLabel(),
		}
	end,
	['OPEN']=function(from_id, payload, distance)
		pycowfarm_node.open()
	end,
	['CLOSE']=function(from_id, payload, distance)
		pycowfarm_node.close()
	end,
}

function pycowfarm_node.start()
	logger:info("Starting node")
	pycowfarm_node.open()
	reactor.start(true, nil, REQUEST_HANDLERS)
end

return pycowfarm_node