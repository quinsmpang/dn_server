local skynet = require "skynet"
local cmd = require "cmd"

local port, max_agent, buffer, ptype, service_name = ...
local command = {}
local agent_all = {}
local event = {}
local gate
--local print = function(...) end

function command:open(parm)
	local fd,addr = string.match(parm,"(%d+) ([^%s]+)")
	fd = tonumber(fd)
	print("agent open", self, string.format("%d %d %s", self, fd, addr))
	agent_all[self] = {[1] = nil, [2] = nil, fd = fd, addr = addr, state = 1}
--	local client = skynet.launch("client", fd, gate, self)
--	local agent = skynet.launch("snlua", "agent", skynet.address(client), self, addr, ptype)
--	if agent then
--		agent_all[self] = {agent, client}
--		skynet.send(gate, "text", "forward", self, skynet.address(agent), skynet.address(client))
--	end
--	local log = string.format("recv connect from %s", addr)
--	skynet.send("CPLog", "lua", cmd.DAY_LOG, log)
end 

function command:close()
	--print("agent close%%%%%%%%%%%%%%%%%", self, string.format("close %d", self))
	local agent = agent_all[self]
--	agent_all[self] = nil
--	if agent then
	if agent and agent[1] then
		skynet.send(agent[1], "text", "CLOSE")
	else
		agent_all[self] = nil
	end
	--skynet.kill(agent[1])
	--skynet.kill(agent[2])
end

function command:data(data, session)
--	local agent = agent_all[self]
--	print("recv data", data)
--	if agent then
--		skynet.redirect(agent[1], agent[2], "client", 0, data)
--	else
--	--	skynet.error(string.format("agent data drop %d size=%d", self, #data))
--	end

	local agent_client = agent_all[self]
	if agent_client then
		if not agent_client[1] and agent_client.state == 1 then
			agent_client.state = 2
			local client = skynet.launch("client", agent_client.fd, gate, self)
			local agent = skynet.newservice("agent", skynet.address(client), self, agent_client.addr, ptype)
			if agent and agent_all[self] then
				agent_client.state = 3
				agent_all[self][1] = agent
				agent_all[self][2] = client
				skynet.send(gate, "text", "forward", self, skynet.address(agent), skynet.address(client)) --将 agent与 client关联起来
			end
		end
		if agent_client[1] then
			skynet.redirect(agent_client[1], agent_client[2], "client", 0, data)
		else
			skynet.error(string.format("agent data drop %d size=%d", self, #data))
		end
	end
end

event[cmd.EVENT_REDIRECT] = function(body)
	local _, newsid, oldsid = unpack(body)
	newid = tonumber(newsid)
	oldid = tonumber(oldsid)
	local oldagent = agent_all[oldid][1]
	local newagent = agent_all[newid][1]
	agent_all[oldid][1] = newagent
	agent_all[newid][1] = oldagent
	skynet.send(gate, "text", "forward", newsid, skynet.address(agent_all[newid][1]), skynet.address(agent_all[newid][2]))
	skynet.send(gate, "text", "forward", oldsid, skynet.address(agent_all[oldid][1]), skynet.address(agent_all[oldid][2]))
	skynet.ret(skynet.pack(true, skynet.address(agent_all[oldid][2]), skynet.address(agent_all[newid][2])))
end

event[cmd.EVENT_CHANGE_AGENT] = function(body)
	local _, sid, newagent = unpack(body)
	sid = tonumber(sid)
	local oldagent = agent_all[sid][1]
	if newagent then
		agent_all[sid][1] = newagent
		skynet.send(gate, "text", "forward", sid, skynet.address(agent_all[sid][1]), skynet.address(agent_all[sid][2]))
	end
	skynet.ret(skynet.pack(skynet.address(agent_all[sid][2]), oldagent))
end

event[cmd.EVENT_AGENT_CLOSE] = function(body)
	local _, sessionid = unpack(body)
	sessionid = tonumber(sessionid)
	skynet.send(gate, "text", "kick", sessionid)
	agent_all[sessionid] = nil
end

skynet.register_protocol{
	name = "client",
	id = 3,
}

skynet.start(function()
	skynet.dispatch("text", function(session, from, message)
		local id, cmd, parm = string.match(message, "(%d+) (%w+) ?(.*)")
		print("watchdog recv:", cmd, " msg:", parm)
		id = tonumber(id)
		local f = command[cmd]
		if f then
			f(id, parm, session)
		else
			error(string.format("[watchdog] Unknown command : %s",message))
		end
	end)
	skynet.dispatch("lua", function(session, address, ...)
		local body = {...}
		local type = body[1]
		body[1] = address
		local f = event[type]
		if f then
			f(body)
		else 
			print("unknow message", cmd)
		end
	end)

	gate = skynet.launch("gate", ptype, skynet.address(skynet.self()), port, 0, max_agent, buffer)
--	gate = skynet.launch("gate", "S", skynet.address(skynet.self()), port, 0, max_agent, buffer)
	skynet.send(gate, "text", "start")
	skynet.register(service_name)
end)
