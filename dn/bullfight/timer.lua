local skynet = require "skynet"
local timer = {}
local command = {}

-- 启动定时器
 function command:start(ti, f, ...)
    self.param = {...}
    self.cb = f 
    local session = self.session
    skynet.timeout(ti, function()
      if session == self.session then
         self.cb(unpack(self.param or {}))
      else
         print("timer removed")
      end
   end)
 end

 -- 移除定时器
 function command:remove()
    self.session = self.session + 1 
 end

 function timer.new()
    return setmetatable({session = 0}, {__index = command})
 end

 return timer
