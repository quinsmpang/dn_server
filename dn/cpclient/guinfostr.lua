local guinfostr = {}

guinfostr.titleform = function(name)
	assert(type(name) == "string")
	name = "\""..name.."\""..":"
	return name
end

guinfostr.contentform = function(content, last)
	if not last then
		if content ~= nil and type(content) == "number" then
			content = content..","
	    elseif type(content) == "string" then
		    content = "\""..content.."\""..","
		else
		    content = "\"".."\""..","
		end
	end
	return content
end

--"avatar":"111212121211",
----"pfid":1,
----"sex":0,
----"puid":"220743842",
----"name":"flyten1121223",
----"tencentLv":0,
----"tencentYear":false,
----"homePage":"js://toFriendHome,220743842"
guinfostr.GetUserinfoString = function(content)
	local userinfo = ""
	local num = 7
	local title = {"puid", "sex", "name", "tencentLv", "avatar", "tencentYear", "pfid"}
	for i = 1, num do
		local v = title[i]
		title[i] = guinfostr.titleform(v)
	end
	for j = 1, num do
		local last = false
		local v = content[j]
		if j == num then last = true end
		content[j] = guinfostr.contentform(v, last)
	end
	for i = 1, num do
		userinfo = userinfo..title[i]..content[i]
	end
	userinfo = "{"..userinfo.."}"
	return userinfo
end

return guinfostr
