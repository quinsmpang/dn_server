local skynet = require "skynet"
local log = require "log"

skynet.start(function()
	log.config{level = log.INFO}
	log.Debug("hello world.")
	log.Info("hello world")
	skynet.exit()
end)

