--[[
     LibSavedVars protected members.
  ]]--

local LIBNAME      = "LibSavedVars"
local CLASSNAME    = "Protected"
local CLASSVERSION = 1.0
local libSavedVars = LibStub(LIBNAME)

-- If a newer version of this class is already loaded, exit
local protected = libSavedVars:NewClass(CLASSNAME, CLASSVERSION)
if not protected then return end

-- When set to true, enables verbose log messages in the chat window.  Enable/disable with libSavedVars:SetDebugMode().
local debugMode = false

protected.debugMode = debugMode

function protected.CreatePath(t, ...)
    protected.Debug("CreatePath for table "..tostring(t).." "..table.concat({...}, " > "))
    
    local current = t
    
    local container
    local containerKey
    for i=1, select("#", ...) do
        local key = select(i, ...)
        if key ~= nil then
            if current == nil then
                protected.Debug("Current is nil for key "..tostring(containerKey)..". How could this happen, since we just initialized?")
                break
            end
            if not current[key] then
                current[key] = {}
                protected.Debug("Initialized new empty table " .. tostring(current[key]).." at " 
                                .. tostring(current) .. " key " .. tostring(key))
            end
            container = current
            containerKey = key
            current = current[key]
        end
    end

    return current, container, containerKey
end

function protected.Debug(message, force, ...)
    if not force and not debugMode then 
       return
    end
    if select("#", ...) > 0 then
        message = zo_strformat(message, ...)
    end
    message = zo_strformat("|c99CCEF<<1>>|r|cFFFFFF: <<2>>|r", LIBNAME, message)
    d(message)
end

function protected.GetSavedVarsPath(savedVariableTableName, namespace, profile, displayName, characterName, characterId, characterKeyType)
    
    local savedVariableTable = protected.ValidateSavedVarsTable(savedVariableTableName)
    
    profile = profile or "Default"
    if type(profile) ~= "string" then
        error("Profile must be a string or nil", 3)
    end

    local playerName
    if characterName == nil then
        playerName = "$AccountWide"
    else
        playerName = characterKeyType == ZO_SAVED_VARS_CHARACTER_NAME_KEY and characterName or characterId
    end    

    protected.Debug("GetSavedVarsPath returning ".. table.concat({tostring(savedVariableTable), profile,displayName,playerName,namespace}, " > "))

    return savedVariableTable, profile, displayName, playerName, namespace
end

function protected.GetSavedVarsTable(savedVariableTableName, namespace, profile, displayName, characterName, characterId, characterKeyType)
    
    local savedVariableTable, path1, path2, path3, path4 = 
        protected.GetSavedVarsPath(savedVariableTableName, namespace, profile, displayName, characterName, characterId, characterKeyType)
    
    local rawSavedVarsTable, parent, key = protected.SearchPath(savedVariableTable, path1, path2, path3, path4)
    return rawSavedVarsTable, parent, key, savedVariableTable, { path1, path2, path3, path4 }
end

--[[
     Assuming the given value can be coerced to a boolean, returns the inverse of that value.
  ]]--
function protected.Invert(value) 
    return not value
end

function protected.NilPack(...) 
    return {n=select('#', ...), ...}
end
function protected.NilUnpack(t) 
    return unpack(t, 1, t.n)
end

--[[
     Variation of zo_savedvars.lua => SearchPath().
     Expands deeply nested tables within the given table by a list of keys, and returns the table for the final key,
     as well as its parent and the final key.
     If any of the keys does not exist, returns nil instead.
  ]]--
function protected.SearchPath(t, ...)
    local current = t
    local parent
    local lastKey
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if key ~= nil then
            lastKey = key
            parent = current
            if current == nil then
                return
            end
            current = current[key]
        end
    end
    return current, parent, lastKey
end

function protected.MaybeSetPath(t, value, ...)
    protected.Debug("MaybeSetPath " .. table.concat({...}, " > ") .. " to " .. tostring(value))
    local current, parent, lastKey = protected.SearchPath(t, ...)
    if parent ~= nil then
        parent[lastKey] = value
        protected.Debug(tostring(parent) .. "[" .. tostring(lastKey) .. "] = " .. tostring(value))
    end
    return parent
end

function protected.Migrate(defaultKeyType, fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    local toSavedVarsInfoList = { ... }
    
    protected.Debug("protected.Migrate()")
    
    -- defaultKeyType is optional
    if type(defaultKeyType) == "table" then
        protected.Debug("defaultKeyType is a table. shift params")
        if toSavedVarsInfoList ~= nil then
            table.insert(toSavedVarsInfoList, 1, toSavedVarsInfo1)
        end
        toSavedVarsInfo1 = fromSavedVarsInfo
        fromSavedVarsInfo = defaultKeyType
        defaultKeyType = nil
        protected.Debug("defaultKeyType is now nil")
    end
    
    assert(fromSavedVarsInfo ~= nil, "Missing required parameter 'fromSavedVarsInfo'")
    assert(toSavedVarsInfo1 ~= nil, "Missing required parameter 'toSavedVarsInfo1'.")
    
    defaultKeyType = defaultKeyType or LIBSAVEDVARS_CHARACTER_NAME_KEY
    
    protected.Debug("defaultKeyType: "
      .. (defaultKeyType == LIBSAVEDVARS_ACCOUNT_KEY and "Account-wide" 
          or defaultKeyType == LIBSAVEDVARS_CHARACTER_ID_KEY and "Character-ID-specific" 
          or "Character-Name-specific"))
    
    if fromSavedVarsInfo.keyType == nil then
        fromSavedVarsInfo.keyType = defaultKeyType
        protected.Debug("From saved vars keyType blank. Setting to default key type.")
    end
    
    -- Find the raw data table for the source saved vars
    local from = (getmetatable(fromSavedVarsInfo) == LSV_SavedVarsManager and fromSavedVarsInfo) 
                  or LSV_SavedVarsManager:New(fromSavedVarsInfo)
    from:LoadRawTableData()
    
    -- Don't bother migrating something that isn't there
    if not from.rawSavedVarsTable then
        protected.Debug("From raw saved vars table does not exist.  Halt migration.")
        return nil, from
    end
    
    -- Validate destination parameters 
    table.insert(toSavedVarsInfoList, 1, toSavedVarsInfo1)
    
    protected.Debug("#savedVarsInfoList: "..tostring(#toSavedVarsInfoList))
    
    local toParams = { }
    for i, toSavedVarsInfo in ipairs(toSavedVarsInfoList) do
        if toSavedVarsInfo.name == nil then
            toSavedVarsInfo.name = from.name
        end
        if not toSavedVarsInfo.keyType then
            toSavedVarsInfo.keyType = defaultKeyType
            protected.Debug("To saved vars "..tostring(i).." keyType is blank. Setting to default key type.")
        end
        local to = (getmetatable(toSavedVarsInfo) == LSV_SavedVarsManager and toSavedVarsInfo) 
                   or LSV_SavedVarsManager:New(toSavedVarsInfo)
        to:Validate()
        protected.Debug("To saved vars "..tostring(i).." validated successfully.")
        table.insert(toParams, to)
    end
    
    -- Check to make sure the data wasn't already migrated in a previous version
    if not from.rawSavedVarsTable.libSavedVarsMigrated 
       and not (from.rawSavedVarsTable[LIBNAME] and from.rawSavedVarsTable[LIBNAME].migrated)
    then
        
        protected.Debug("Raw saved vars table was not previously migrated by LibSavedVars v2 or v3.")
        
        -- Fire any registered callbacks for migration start
        from:FireMigrateStartCallbacks()
        
        protected.Debug("Migrate start callbacks fired.")
        
        -- Copy the source table to each destination
        for i, to in ipairs(toParams) do
          
            protected.Debug("to (" .. tostring(to) .. ").table = " .. tostring(to.table))
            
            -- Lookup path information
            to:LoadRawTableData()
            protected.Debug("To saved vars manager "..tostring(i).." raw table data loaded.")
            
            if not to.table then
                protected.Debug("To table is nil. How can this be, since we called Validate on it already?")
            end
            
            -- Create the destination table, if it doesn't exist
            if not to.rawSavedVarsTable then
                _, to.rawSavedVarsTableParent, to.rawSavedVarsTableKey = 
                    protected.CreatePath(to.table, unpack(to.rawSavedVarsTablePath))
                protected.Debug("To saved vars manager "..tostring(i).." raw table data did not exist.  Created.")
            end
            
            -- Copy the source table to the destination path
            if to.rawSavedVarsTableParent == nil then
                protected.Debug("Raw saved vars parent table does not exist.  CreatePath must have failed.")
            else
                protected.Debug("Setting to raw saved vars parent table "..tostring(i) 
                    .." (" .. tostring(to.rawSavedVarsTableParent) .. ") key "..tostring(to.rawSavedVarsTableKey)
                    .." to the from raw saved vars table (" .. tostring(from.rawSavedVarsTable) .. ")")
                libSavedVars:DeepSavedVarsCopy(from.rawSavedVarsTable, to.rawSavedVarsTableParent[to.rawSavedVarsTableKey])
                to.rawSavedVarsTableParent[to.rawSavedVarsTableKey].version = from.rawSavedVarsTable.version
            end
        end
    end
    
    return toParams, from
end

function protected.MigrateToMegaserverProfiles(defaultKeyType, fromSavedVarsInfo, copyToAllServers, toSavedVarsInfo)
    
    if defaultKeyType == nil then
        if fromSavedVarsInfo.keyType == nil then
            defaultKeyType            = LIBSAVEDVARS_CHARACTER_NAME_KEY
            fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_NAME_KEY
        else
            defaultKeyType = fromSavedVarsInfo.keyType
        end
    end
    
    if toSavedVarsInfo then
        if toSavedVarsInfo.keyType == nil then
            toSavedVarsInfo.keyType = defaultKeyType
        end
    else
        toSavedVarsInfo = ZO_DeepTableCopy(fromSavedVarsInfo)
        toSavedVarsInfo.keyType = defaultKeyType
    end
    
    local isAccountWide = toSavedVarsInfo.keyType == LIBSAVEDVARS_ACCOUNT_KEY
    
    protected.Debug("MigrateToMegaserverProfiles performing migration to "
      .. (isAccountWide and "account-wide" 
          or toSavedVarsInfo.keyType == LIBSAVEDVARS_CHARACTER_ID_KEY and "character-ID-specific" 
          or "character-name-specific")
      .. " settings.")
    
    local profiles
    if isAccountWide and (copyToAllServers == nil or copyToAllServers)  then
        profiles = libSavedVars:GetWorldNames()
    else
        profiles = { GetWorldName() }
    end
    if not toSavedVarsInfo.profile then
        toSavedVarsInfo.profile = GetWorldName()
    elseif not ZO_IsElementInNumericallyIndexedTable(profiles, toSavedVarsInfo.profile) then
        table.insert(profiles, 1, toSavedVarsInfo.profile)
    end
    
    protected.Debug("#profiles: "..tostring(#profiles))
    
    local toSavedVarsInfoList = { }
    for _, profile in ipairs(profiles) do
        protected.Debug("profile: "..tostring(profile))
        local toProfileSavedVarsInfo = { }
        ZO_ShallowTableCopy(toSavedVarsInfo, toProfileSavedVarsInfo)
        setmetatable (toProfileSavedVarsInfo, getmetatable(toSavedVarsInfo))
        toProfileSavedVarsInfo.profile = profile
        table.insert(toSavedVarsInfoList, toProfileSavedVarsInfo)
    end
    
    protected.Debug("#toSavedVarsInfoList: "..tostring(#toSavedVarsInfoList))
    
    local toSavedVarsManagers, from = protected.Migrate(defaultKeyType, fromSavedVarsInfo, unpack(toSavedVarsInfoList))
    
    if not toSavedVarsManagers then
        protected.Debug("toSavedVarsManagers is nil. Exiting MegaServer profiles migration.")
        return nil, from
    end
    local toSavedVarsManagersByProfile = { }
    for i, to in ipairs(toSavedVarsManagers) do
        local profile = toSavedVarsInfoList[i].profile
        toSavedVarsManagersByProfile[profile] = to
        
        protected.Debug("Saved vars manager detected for " .. tostring(to.name) .. " (" .. tostring(_G[to.name]) .. ") profile "..tostring(profile)..": path "
                        .. (to.rawSavedVarsTablePath and table.concat(to.rawSavedVarsTablePath, " > ") or "") 
                        .. " at index " .. tostring(i))
    end
    return toSavedVarsManagersByProfile, from
end

function protected.UnsetPath(t, ...)
    local params = { ... }
    local paramCount = #params
    for i = paramCount, 1, -1 do
        local parent = protected.MaybeSetPath(t, nil, unpack(params))
        if parent ~= nil and next(parent) ~= nil then
            return
        end
        table.remove(params)
    end
end

function protected.ValidateSavedVarsTable(savedVariableTable)
    protected.Debug("ValidateSavedVarsTable("..tostring(savedVariableTable)..")")
    if type(savedVariableTable) ~= "table" then
        if _G[savedVariableTable] == nil then
            protected.Debug("No global of that name exists. Creating.")
            _G[savedVariableTable] = {}
        end
        savedVariableTable = _G[savedVariableTable]
    end

    if type(savedVariableTable) ~= "table" then
        error("Can only apply saved variables to a table", 3)
    end
    protected.Debug("ValidateSavedVarsTable returning " .. tostring(savedVariableTable))
    return savedVariableTable
end