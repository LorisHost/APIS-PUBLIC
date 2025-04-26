local function getgenv()
    if not _g.__genv then
        _g.__genv = {
            -- Core
            _version = _version,
            
            
            getscript = function() return debug.info(2, "s") or "unknown" end,
            getcaller = function() return debug.info(2, "f") end,
            
            
            getinfo = function()
                return {
                    luau = _version,
                    client = not not (shared and shared.getrawmetatable),
                    server = not not (script and script:isa("luasourcecontainer")),
                    modules = getloadedmodules and getloadedmodules() or {}
                }
            end,
            
          
            require = function(mod)
                local s, r = pcall(require, mod)
                return s and r or nil
            end,
            
          
            readonly = function(t)
                return setmetatable({}, {
                    __index = t,
                    __newindex = function() error("readonly table", 2) end,
                    __metatable = false
                })
            end,
            
            clone = function(t)
                local c = {}
                for k, v in pairs(t) do
                    c[k] = type(v) == "table" and getgenv().clone(v) or v
                end
                return c
            end,
            
            merge = function(t1, t2)
                local m = getgenv().clone(t1)
                for k, v in pairs(t2) do m[k] = v end
                return m
            end,
            
        
            watch = function(t, callback)
                return setmetatable({}, {
                    __index = t,
                    __newindex = function(_, k, v)
                        if callback then callback(k, t[k], v) end
                        rawset(t, k, v)
                    end,
                    __metatable = false
                })
            end,
            
            -- Memory Tools
            clearmemory = function()
                collectgarbage("collect")
                if gcinfo then gcinfo() end
            end,
            
            -- Debugging
            trace = function(msg)
                print(`[{getgenv().getscript()}] {msg}`)
            end,
            
        
            random = {
                int = function(min, max)
                    return math.random(min or 1, max or 100)
                end,
                str = function(len)
                    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
                    local res = ""
                    for _ = 1, len or 10 do
                        res = res .. chars:sub(math.random(1, #chars), 1)
                    end
                    return res
                end,
                choice = function(t)
                    return t[math.random(1, #t)]
                end
            },
            
          
            json = {
                encode = function(t)
                    return game:GetService("HttpService"):JSONEncode(t)
                end,
                decode = function(s)
                    return game:GetService("HttpService"):JSONDecode(s)
                end
            },
            
            
            http = {
                get = function(url)
                    return game:GetService("HttpService"):GetAsync(url, true)
                end,
                post = function(url, data)
                    return game:GetService("HttpService"):PostAsync(url, data)
                end
            },
            delay = function(sec, callback)
                task.delay(sec, callback)
            end,
            hook = {
                -- Override a function
                func = function(original, new)
                    return function(...)
                        return new(original, ...)
                    end
                end,
                replace = function(obj, funcname, newfunc)
                    local old = obj[funcname]
                    obj[funcname] = newfunc
                    return old
                end
            },
          
            signal = {
                new = function()
                    local listeners = {}
                    return {
                        connect = function(callback)
                            table.insert(listeners, callback)
                            return {
                                disconnect = function()
                                    for i, v in pairs(listeners) do
                                        if v == callback then
                                            table.remove(listeners, i)
                                            break
                                        end
                                    end
                                end
                            }
                        end,
                        fire = function(...)
                            for _, cb in pairs(listeners) do
                                task.spawn(cb, ...)
                            end
                        end
                    }
                end
            }
        }
        
    
        for k, v in pairs(_g) do
            if not k:find("^__") and k ~= "script" and k ~= "shared" then
                _g.__genv[k] = v
            end
        end
        
        
        setmetatable(_g.__genv, {
            __index = _g,
            __newindex = function(_, k, v) rawset(_g, k, v) end
        })
    end
    return _g.__genv
end

-- Globalize
getgenv = getgenv
