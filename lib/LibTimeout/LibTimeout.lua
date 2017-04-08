-- LibTimeout & its files © silvereyes                          --
-- Distributed under the MIT license (see LICENSE.txt)          --
------------------------------------------------------------------

--Register LTO with LibStub
local MAJOR, MINOR = "LibTimeout", 1
local lto, minorVersion = LibStub:NewLibrary(MAJOR, MINOR)
if not lto then return end --the same or newer version of this lib is already loaded into memory

local callbacks = {}
local retryCounts = {}
function pack(...)
    return {...}
end
local function scopeCallback(id)

    -- Find the callback options for the given zo_callLater id
    local scopeIndex
    for callbackScopeIndex, options in pairs(callbacks) do
        if id == options.id then
            scopeIndex = callbackScopeIndex
            break
        end
    end
    -- No callback with the given zo_callLater id exists. It must have been canceled, so do nothing.
    if not scopeIndex then return end
    
    local options = callbacks[scopeIndex]
    local retryCount = retryCounts[scopeIndex]
    
    -- If the retry limit is met, then raise the optional "done" callback
    if lto:IsDone(scopeIndex, options) then
        if options.doneCallback and type(options.doneCallback) == "function" then
            options.doneCallback(options)
        end
        return
    end
    
    -- Otherwise, raise the retry callback
    options.callback(unpack(options.parameters))
end

function lto:CancelTimeout(name)
    local scopeIndex = tostring(name)
    callbacks[scopeIndex] = nil
    retryCounts[scopeIndex] = nil
end
function lto:GetScopeIndex(options, callback)
    if options.name then
        return options.name
    end
    return tostring(callback)
end
function lto:IsDone(scopeIndex, options)
    if retryCounts[scopeIndex] and options.maxRetries and type(options.maxRetries) == "number" 
       and options.maxRetries > 0 and retryCounts[scopeIndex] >= options.maxRetries
    then
        return true
    end
end
function lto:StartTimeout(options, timeoutMs, callback, ...)
    local parameters = pack(...)
    
    -- Make the options parameter optional. If a table isn't supplied as the first argument
    local optionsParamType = type(options)
    if optionsParamType ~= "table" then
        if optionsParamType == "number" then
            if callback then
                table.insert(parameters, 1, callback)
            end
            callback = timeoutMs
            timeoutMs = options
            options = {}
        else
            d(MAJOR .. " error. Invalid parameter type " .. optionsParamType
              .. " given as first argument to StartTimeout(). Table or number expected.")
        end
    end
    
    if type(timeoutMs) ~= "number" then
        d(MAJOR .. " error. Invalid timeout parameter type " .. tostring(type(timeoutMs))
          ..". Expected number.")
    end
    
    if type(callback) ~= "function" then
        d(MAJOR .. " error. Invalid callback parameter type " .. tostring(type(callback))
          ..". Expected function.")
    end
    local scopeIndex = self:GetScopeIndex(options, callback)
    
    -- If the retry limit has already been met, then do nothing
    if self:IsDone(scopeIndex, options) then 
        return

    -- If the retry limit doesn't exist or hasn't been met, increment the retry count
    elseif retryCounts[scopeIndex] then
        retryCounts[scopeIndex] = retryCounts[scopeIndex] + 1
    
    -- Record the first retry attempt
    else
        retryCounts[scopeIndex] = 1
        
    end
    
    -- Set up the timed callback
    options.callback = callback
    if not options.parameters then
        options.parameters = parameters
    end
    options.id = zo_callLater(scopeCallback, timeoutMs)
    callbacks[scopeIndex] = options
end