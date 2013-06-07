-- RPC implemented using the Reactor Design Pattern.
-- This seems overly engineered, it is :)

local log = dofile("log.lua")

local reactor = {}
local logger = log.Logger.new("reactor")
local __callback_identifier = 0

reactor.EVENT_NAME_SENTINEL = '_reactor_event'
reactor.request_handlers = nil
reactor.futures = {}

function get_callback_identifier()
	-- Used in tagging each callback so the caller knows what event to wait on
	__callback_identifier = __callback_identifier + 1
	return reactor.EVENT_NAME_SENTINEL..__callback_identifier
end

function reactor._send_table(recipient, table)
	if recipient == nil then
		return rednet.broadcast(table)
	end
	return rednet.send(tonumber(recipient), table, true)
end


local Defer = {}
Defer.__index = Defer
function Defer:__call(timeout_sec)
	return self.block(timeout_sec)
end

function Defer.new(callback_identifier, is_single_shot)
	local function defer_function(timeout_sec)
		if timeout_sec == nil then
			timeout_sec = 5
		end
		local return_value = {}	
		local function gather()
			while true do
				local event, return_val = os.pullEvent(callback_identifier)
				table.insert(return_value, return_val)
				if is_single_shot then
					break
				end
			end
		end
		local function timeout()
			local herp_derp = nil
			local timer_id = os.startTimer(timeout_sec)
			while true do
				local event, herp_derp = os.pullEvent('timer')
				if timer_id == herp_derp then
					break
				end
			end
		end
		parallel.waitForAny(gather, timeout)
		if is_single_shot then
			return_value = return_value[1]
		end
		return return_value
	end
	return setmetatable({['block']=defer_function}, Defer)
end

function reactor.transmit(recipient, event_name, payload)
	-- Invokes an RPC to a recipient. Returns a promise object
	-- similar to jQuery's Defer object. When you call the promise
	-- object, it'll block until the RPC is done and returns
	-- The promise object will return what the RPC returns.
	logger:info("Transmitting "..event_name)
	local callback_identifier = get_callback_identifier()
	local is_single_shot = recipient ~= nil
	local blob = {
		['event_name']=event_name,
		['payload']=payload,
		['callback_identifier']=callback_identifier,
	}
	local is_sent = reactor._send_table(recipient, blob)
	if not is_sent then
		logger:error("Failed to send table")
	end
	return Defer.new(callback_identifier, is_single_shot)
end

function handle_callback_return(from_id, payload, distance)
	logger:info("Handling callback for "..from_id)
	local callback_identifier = payload.callback_identifier
	local return_value = payload.return_value
	os.queueEvent(callback_identifier, return_value)
end

function reactor.register_request_handlers(request_handlers)
	reactor.request_handlers = request_handlers
	reactor.request_handlers[reactor.EVENT_NAME_SENTINEL.."_CALLBACK"] = handle_callback_return
end

function reactor.listen_on_rednet()
	while true do
		reactor.capture_rednet()
	end
end

function reactor.capture_rednet()
	logger:info("Capturing rednet")
	local event, from_id, message, distance = os.pullEvent("rednet_message")	
	if message ~= nil then
		logger:info("Got rednet_message from "..tostring(from_id).." for "..message.event_name)
		local parameters = {
			['from_id']=from_id,
			['distance']=distance,
			['payload']=message.payload,
			['event_name']=message.event_name,
			['callback_identifier']=message.callback_identifier,
		}
		logger:info("Dispatching "..message.event_name.." for "..from_id)
		os.queueEvent(reactor.EVENT_NAME_SENTINEL, parameters)
	else
		logger:info("message was nil")
		logger:info(tostring(from_id))
	end
end

function reactor.capture_dispatch()
	logger:info("Capturing Dispatch")
	local event, parameters = os.pullEvent(reactor.EVENT_NAME_SENTINEL)
	local callback_func = reactor.request_handlers[parameters.event_name]
	if callback_func ~= nil then
		local return_value = callback_func(parameters.from_id, parameters.payload, parameters.distance)
		
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

function reactor.listen_on_dispatch()
	while true do
		reactor.capture_dispatch()
	end
end

function reactor.listen_on_rednet_and_dispatch()
	parallel.waitForAll(reactor.listen_on_rednet, reactor.listen_on_dispatch)
end

function reactor.start(logging_enabled, main_func)
	logger:toggle(logging_enabled)
	logger:info("Starting reactor")

	if reactor.request_handlers == nil then
		reactor.register_request_handlers({})
	end

	if main_func == nil then
		-- Runs in daemon mode
		reactor.listen_on_rednet_and_dispatch()
	else
		-- Run until the end of main_func
		parallel.waitForAny(reactor.listen_on_rednet_and_dispatch, main_func)
	end
end

return reactor
