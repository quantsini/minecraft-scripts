local log = {}
local Logger = {}

Logger.__index = Logger

local function construct_log_string(msg_type, name, msg)
	return ": "..msg_type.." : "..name.." : "..msg
end

function Logger.new(name, monitor, write_func)
	write_func = write_func or print	
	return setmetatable({name=name, monitor=monitor, write_func=write_func, should_log=false}, Logger)
end

function Logger:info(msg)
	local log_content = construct_log_string("INFO ", self.name, msg)	
	if self.should_log then
		self.write_func(log_content)
	end
end

function Logger:debug(msg)
	local log_content = construct_log_string("DEBUG", self.name, msg)	
	if self.should_log then
		self.write_func(log_content)
	end
end

function Logger:error(msg)
	local log_content = construct_log_string("ERROR", self.name, msg)	
	if self.should_log then
		self.write_func(log_content)
	end 
end

function Logger:toggle(should_log)
	self.should_log = should_log
end

log.Logger = Logger

return log
