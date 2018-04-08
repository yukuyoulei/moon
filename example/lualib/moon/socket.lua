--协程socket封装

local moon  = require("moon")

local csrv          = moon
local co_yield      = coroutine.yield
local make_response = moon.make_response

local read_delim = {
    '\r\n',
    '\r\n\r\n',
    '\n'
}

local session       = {}

session.__index = session

function session.new(sock,connid,ip,host)
    local tb = {}
    tb.sock = sock
    tb.connid = connid
    tb.ip = ip
    tb.host = host
    return setmetatable(tb,session)
end

function session:co_read(n)
    local delim = 0
    if type(n) == 'string' then
        delim = -1
        for k,v in pairs(read_delim) do
            if v == n then
                delim = k
                break
            end
        end

        if delim == -1 then
            return nil,"unsupported read delim "..tostring(n)
        end
        n = 0
    end
    local respid = make_response()
    self.sock:read(self.connid,n,delim,respid)
    return co_yield()
end

function session:send(data)
    assert(self.connid,"attemp send an invalid session")
    return self.sock:send(self.connid,data,false)
end

function session:close()
    assert(self.connid,"attemp close an invalid session")
    local ret = self.sock:close(self.connid)
    self.connid = nil
    return ret
end

----------------------------------------------

local socket = {}

socket.__index = socket

local n = 0;
function socket.new()
    n=n+1
    local tb = {}
    tb.sock = csrv.add_component_tcp("component_tcp"..(tostring(n)))
    tb.sock:setprotocol(1)
    return setmetatable(tb,socket)
end

function socket:listen(ip,port)
    assert(self.sock:listen(ip,tostring(port)))
end

function socket:settimeout(t)
    self.sock:settimeout(t)
end

function socket:co_accept()
    local respid = make_response()
    self.sock:async_accept(respid)
    local connid,err = co_yield()
    if not connid then
        return nil,err
    end
    return session.new(self.sock,tonumber(connid))
end

function socket:connect(ip,port)
    local connid = self.sock:connect(ip,port)
    if connid == 0 then
        return nil,"connect failed"
    end
    return session.new(self.sock,tonumber(connid),ip,port)
end

function socket:co_connect(ip,port)
    local respid = make_response()
    self.sock:async_connect(ip,port,respid)
    local connid,err = co_yield()
    if not connid then
        return nil,err
    end
    print("connect success", connid)
    return session.new(self.sock,tonumber(connid),ip,port)
end

return socket
