-- RPC implemented using the Reactor Design Pattern.
-- This seems overly engineered, it is :)

local log = dofile("log.lua")

local reactor = {}
local logger = log.Logger.new("reactor")
local callback_identifier = 0

reactor.EVENT_NAME_SENTINEL = '_reactor_event'
reactor.request_handlers = nil
reactor.futures = {}

function get_callback_identifier()
	-- Used in tagging each callback so the caller knows what event to wait on
	callback_identifier = callback_identifier + 1
	return reactor.EVENT_NAME_SENTINEL..callback_identifier
end

function reactor._send_table(recipient, table)
	if recipient == nil then
		return rednet.broadcast(table)
	end
	return rednet.send(tonumber(recipient), table)
end

function reactor.transmit(recipient, event_name, payload)
	-- Invokes an RPC to a recipient. Returns a promise object
	-- similar to jQuery's Defer object. When you call the promise
	-- object, it'll block until the RPC is done and returns
	-- The promise object will return what the RPC returns.
	logger:info("Transmitting "..event_name)
	local defer_function = nil
	local callback_identifier = nil
	if recipient ~= nil then
		callback_identifier = get_callback_identifier()
		defer_function = function()
			local event, return_value = os.pullEvent(callback_identifier)
			return return_value
		end
	end
	local blob = {
		['event_name']=event_name,
		['payload']=payload,
		['callback_identifier']=callback_identifier,
	}
	local is_sent = reactor._send_table(recipient, blob)
	return defer_function
end

function handle_callback_return(from_id, payload, distance)
	logger:info("Handling callback from "..from_id)
	local callback_identifier = payload.callback_identifier
	if callback_identifier ~= nil then
		local return_value = payload.return_value
		os.queueEvent(callback_identifier, return_value)
	end
end

function reactor.register_request_handlers(request_handlers)
	reactor.request_handlers = request_handlers
	reactor.request_handlers[reactor.EVENT_NAME_SENTINEL.."_CALLBACK"] = handle_callback_return
end

function reactor._rednet_capture()
	while true do
		reactor.capture_rednet()
	end
end

function reactor.capture_rednet()
	logger:info("Capturing rednet")
	local event, from_id, message, distance = os.pullEvent("rednet_message")	
	logger:info("Got rednet_message from "..from_id.." for "..message.event_name)
	local parameters = {
		['from_id']=from_id,
		['distance']=distance,
		['payload']=message.payload,
		['event_name']=message.event_name,
		['callback_identifier']=message.callback_identifier,
	}
	logger:info("Dispatching "..message.event_name.." for "..from_id)
	os.queueEvent(reactor.EVENT_NAME_SENTINEL, parameters)
end

function reactor.dispatch()
	logger:info("Capturing Dispatch")
	local event, parameters = os.pullEvent(reactor.EVENT_NAME_SENTINEL)
	local callback_func = reactor.request_handlers[parameters.event_name]
	if callback_func ~= nil then
		local return_value = callback_func(parameters.from_id, parameters.payload, parameters.distance)

		-- TODO: Clean this up
		if callback_func ~= handle_callback_return then
			logger:info("Sending return value")
			local response = {
				['callback_identifier']=parameters.callback_identifier,
				['return_value']=return_value,
			}
			reactor.transmit(parameters.from_id, reactor.EVENT_NAME_SENTINEL.."_CALLBACK", response)
		end
	else
		logger:error("No callback function found for "..parameters.event_name)
	end
end

function reactor._dispatcher()
	while true do
		reactor.dispatch()
	end
end

function reactor.start_rednet_capture_and_dispatcher()
	parallel.waitForAll(reactor._rednet_capture, reactor._dispatcher)
end

function reactor.start(logging_enabled, main_func)
	logging_enabled = logging_enabled or false
	logger:toggle(logging_enabled)
	logger:info("Starting reactor")

	if reactor.request_handlers == nil then
		logger:error("You must register request handlers")
	end

	if main_func == nil then
		-- Runs in daemon mode
		reactor.start_rednet_capture_and_dispatcher()
	else
		-- Run until the end of main_func
		parallel.waitForAny(reactor.start_rednet_capture_and_dispatcher, main_func)
	end
end

return reactor
