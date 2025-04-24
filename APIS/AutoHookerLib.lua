-- AutoHookerLib.lua v7.0
-- note: this api currently testing.
-- Load with:
-- local Hooker = loadstring(game:HttpGet("https://your.url/AutoHookerLib.lua"))()

-- Global export with version tracking
local Hooker = {
    VERSION = "7.0",
    BUILD_DATE = os.date("%Y-%m-%d")
}
_G.AutoHooker = Hooker

do
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local HealInterval = 5
    local DebugMode = false

    -- Enhanced filtering system with metadata
    Hooker.Whitelist = Hooker.Whitelist or {
        Patterns = {},
        Metadata = {
            LastUpdated = 0,
            Source = "local"
        }
    }
    
    Hooker.Blacklist = Hooker.Blacklist or {
        Patterns = {},
        Metadata = {
            LastUpdated = 0,
            Source = "local"
        }
    }

    -- Internal state with improved tracking
    local ActiveHooks = {}      -- [uid] = { original = fn, api = tbl, instance = obj, method = string }
    local HookErrors = 0
    local OnHookCbs = {}        -- subscribers for new hooks with priority support
    local CustomFns = {}        -- custom hook functions with metadata
    local HookRegistry = {}     -- registry for tracking all hook attempts
    local PerformanceStats = {
        TotalHooks = 0,
        FailedHooks = 0,
        HookTime = 0
    }

    -- UTILITIES ------------------------------------------------
    local function debugPrint(...)
        if DebugMode then
            print("[AutoHooker Debug]", ...)
        end
    end

    local function generateUID(instance, methodName)
        return HttpService:GenerateGUID(false):sub(1, 8) .. ":" .. tostring(instance) .. ":" .. methodName
    end

    local function matches(list, name)
        if not name then return false end
        for _, pat in ipairs(list.Patterns) do
            if name:match(pat) then return true end
        end
        return false
    end

    local function shouldHookRemote(remote)
        if #Hooker.Whitelist.Patterns > 0 and not matches(Hooker.Whitelist, remote.Name) then 
            debugPrint("Skipping (not in whitelist):", remote.Name)
            return false 
        end
        if matches(Hooker.Blacklist, remote.Name) then 
            debugPrint("Skipping (blacklisted):", remote.Name)
            return false 
        end
        return true
    end

    local function isRemote(obj)
        return obj and (obj.ClassName == "RemoteEvent" or obj.ClassName == "RemoteFunction")
    end

    local function getMethodName(instance)
        if instance.ClassName == "RemoteEvent" then
            return "FireServer"
        elseif instance.ClassName == "RemoteFunction" then
            return "InvokeServer"
        end
        return nil
    end

    -- CORE: Enhanced hooking with performance tracking and safety
    local function hookInstanceMethod(instance, methodName)
        if not instance or type(methodName) ~= "string" then return nil end
        
        local startTime = os.clock()
        local uid = generateUID(instance, methodName)
        
        if ActiveHooks[uid] then 
            debugPrint("Hook already exists:", uid)
            return ActiveHooks[uid].api 
        end
        
        if typeof(instance[methodName]) ~= "function" then 
            debugPrint("Not a function:", uid)
            return nil 
        end

        -- prepare hook environment
        local original = instance[methodName]
        local preHooks = {}
        local postHooks = {}
        local hookMeta = {
            CreatedAt = os.time(),
            LastCalled = 0,
            CallCount = 0
        }

        -- enhanced unhook with validation
        local function unhook()
            if instance and instance.Parent and instance[methodName] ~= original then
                instance[methodName] = original
                debugPrint("Unhooked:", uid)
            end
            ActiveHooks[uid] = nil
            return true
        end

        -- hook validation function
        local function validateHook()
            return instance and instance.Parent and instance[methodName] ~= original
        end

        -- override with enhanced error handling and argument inspection
        instance[methodName] = function(self, ...)
            hookMeta.LastCalled = os.time()
            hookMeta.CallCount += 1
            
            local args = {...}
            local argsInfo = {
                Count = select("#", ...),
                Types = {}
            }
            
            -- Pre-hook processing
            for i, cb in ipairs(preHooks) do
                local ok, res = pcall(cb, self, table.unpack(args))
                if not ok then
                    HookErrors += 1
                    warn("[AutoHooker] Pre-hook error on " .. uid .. ": ", res)
                elseif ok and res == false then 
                    debugPrint("Pre-hook blocked execution:", uid)
                    return nil 
                end
            end
            
            -- Original call with protected execution
            local ok, ret = pcall(original, self, table.unpack(args))
            
            -- Post-hook processing
            if ok then
                for i, cb in ipairs(postHooks) do 
                    pcall(cb, self, ret) 
                end
            else
                HookErrors += 1
                warn("[AutoHooker] Execution error on " .. uid .. ": ", ret)
            end
            
            return ret
        end

        -- Enhanced API with hook metadata
        local api = {
            registerPre = function(cb, priority)
                if type(cb) == "function" then 
                    table.insert(preHooks, {
                        func = cb,
                        priority = priority or 50
                    })
                    table.sort(preHooks, function(a, b) return a.priority < b.priority end)
                end
            end,
            
            registerPost = function(cb, priority)
                if type(cb) == "function" then 
                    table.insert(postHooks, {
                        func = cb,
                        priority = priority or 50
                    })
                    table.sort(postHooks, function(a, b) return a.priority < b.priority end)
                end
            end,
            
            unhook = unhook,
            validate = validateHook,
            getMetadata = function() return hookMeta end,
            getUID = function() return uid end
        }

        ActiveHooks[uid] = { 
            original = original, 
            api = api, 
            instance = instance, 
            method = methodName 
        }
        
        -- Notify subscribers with protection
        for _, cb in ipairs(OnHookCbs) do 
            pcall(cb, instance, methodName, api) 
        end
        
        PerformanceStats.TotalHooks += 1
        PerformanceStats.HookTime += (os.clock() - startTime)
        
        debugPrint("Successfully hooked:", uid)
        return api
    end

    -- PUBLIC API IMPROVEMENTS ----------------------------------

    function Hooker.SetDebugMode(enabled)
        DebugMode = enabled == true
    end

    -- Enhanced remote hooking with automatic method detection
    function Hooker.HookRemote(remote)
        if not isRemote(remote) then return nil end
        if not shouldHookRemote(remote) then return nil end
        
        local methodName = getMethodName(remote)
        if not methodName then return nil end
        
        return hookInstanceMethod(remote, methodName)
    end

    -- Enhanced method hooking with validation
    function Hooker.HookMethod(instance, methodName)
        if not instance or not methodName then return nil end
        if typeof(instance[methodName]) ~= "function" then return nil end
        return hookInstanceMethod(instance, methodName)
    end

    -- Class hooking with namespace support
    function Hooker.HookClass(className, methodName, options)
        options = options or {}
        local namespace = options.namespace or game
        
        -- Hook existing instances
        for _, inst in ipairs(namespace:GetDescendants()) do
            if inst.ClassName == className then
                Hooker.HookMethod(inst, methodName)
            end
        end
        
        -- Hook future instances
        local conn
        conn = namespace.DescendantAdded:Connect(function(inst)
            if inst.ClassName == className then
                Hooker.HookMethod(inst, methodName)
                
                -- Optional: disconnect after first match if requested
                if options.once then
                    conn:Disconnect()
                end
            end
        end)
        
        return conn
    end

    -- Folder hooking with recursion control
    function Hooker.HookFolder(folder, options)
        options = options or {}
        local recursive = options.recursive ~= false
        
        local function process(obj)
            if isRemote(obj) then 
                Hooker.HookRemote(obj) 
            end
        end
        
        if recursive then
            for _, obj in ipairs(folder:GetDescendants()) do
                process(obj)
            end
        else
            for _, obj in ipairs(folder:GetChildren()) do
                process(obj)
            end
        end
    end

    -- Filter management with remote updates
    function Hooker.UpdateFilters(listType, patterns, source)
        if listType == "whitelist" then
            Hooker.Whitelist.Patterns = patterns or {}
            Hooker.Whitelist.Metadata = {
                LastUpdated = os.time(),
                Source = source or "manual"
            }
        elseif listType == "blacklist" then
            Hooker.Blacklist.Patterns = patterns or {}
            Hooker.Blacklist.Metadata = {
                LastUpdated = os.time(),
                Source = source or "manual"
            }
        end
        Hooker.RefreshFilters()
    end

    function Hooker.RefreshFilters()
        -- Unhook remotes not matching current filters
        for uid, info in pairs(ActiveHooks) do
            if isRemote(info.instance) then
                if not shouldHookRemote(info.instance) then
                    info.api.unhook()
                end
            end
        end
        
        -- Re-hook valid remotes
        for _, obj in ipairs(game:GetDescendants()) do
            if isRemote(obj) and not ActiveHooks[generateUID(obj, getMethodName(obj))] then
                Hooker.HookRemote(obj)
            end
        end
    end

    -- Enhanced statistics with performance data
    function Hooker.GetStats()
        local activeCount = 0
        for _ in pairs(ActiveHooks) do activeCount += 1 end
        
        return {
            version = Hooker.VERSION,
            activeHooks = activeCount,
            totalHooks = PerformanceStats.TotalHooks,
            failedHooks = PerformanceStats.FailedHooks,
            hookErrors = HookErrors,
            avgHookTime = PerformanceStats.TotalHooks > 0 
                and PerformanceStats.HookTime / PerformanceStats.TotalHooks 
                or 0,
            lastUpdated = os.time()
        }
    end

    -- Event subscription with priority
    function Hooker.OnHook(cb, priority)
        if type(cb) == "function" then 
            table.insert(OnHookCbs, {
                func = cb,
                priority = priority or 50
            })
            table.sort(OnHookCbs, function(a, b) return a.priority < b.priority end)
        end
    end

    -- Custom function registration with metadata
    function Hooker.RegisterCustom(fn, meta)
        if type(fn) == "function" then 
            table.insert(CustomFns, {
                func = fn,
                meta = meta or {}
            })
        end
    end

    -- Self-healing with validation and backup
    spawn(function()
        while true do
            wait(HealInterval)
            
            for uid, info in pairs(ActiveHooks) do
                if not info.api.validate() then
                    debugPrint("Hook invalidated, attempting repair:", uid)
                    info.api.unhook()
                    
                    -- Recreate hook if instance still exists
                    if info.instance and info.instance.Parent then
                        Hooker.HookMethod(info.instance, info.method)
                    end
                end
            end
            
            -- Process custom functions
            for _, custom in ipairs(CustomFns) do
                pcall(custom.func, Hooker)
            end
        end
    end)
end

return Hooker
