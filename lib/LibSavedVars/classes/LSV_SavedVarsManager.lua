--[[
     LibSavedVars saved vars manager class.
     
     LSV_SavedVarsManager:New()
  ]]--

local LIBNAME      = "LibSavedVars"
local CLASSNAME    = "SavedVarsManager"
local CLASSVERSION = 1.0
local libSavedVars = LibStub(LIBNAME)

-- If a newer version of this class is already loaded, exit
local class, protected = libSavedVars:NewClass(CLASSNAME, CLASSVERSION)
if not class then return end

LSV_SavedVarsManager = class

local debugMode = false
local nextId = 1
local extraLazyLoadParams = {}
local extraMigrateParams  = {}
local versionUpdateQueue       = {}


local LIBSAVEDVARS_MIGRATE_START_CALLBACK_NAME = LIBNAME.."MigrateStart"
local LIBSAVEDVARS_LAZY_LOAD_CALLBACK_NAME = LIBNAME.."LazyLoad"

-- Local methods
local fireLazyLoadCallbacks, unregisterAllLazyLoadCallbacks, unregisterAllMigrateStartCallbacks, updatePendingVersionsOnLogout


---------------------------------------
--
--       Public Methods
-- 
---------------------------------------

function LSV_SavedVarsManager:IsProfileWorldName()
    local isProfileWorldName = ZO_IsElementInNumericallyIndexedTable(libSavedVars:GetWorldNames(), self.profile)
    protected.Debug("LSV_SavedVarsManager:IsProfileWorldName() == " .. tostring(isProfileWorldName) 
      .. " (self.profile==" .. tostring(self.profile) .. ")", debugMode)
    return isProfileWorldName
end

function LSV_SavedVarsManager:FireMigrateStartCallbacks()
    local scope = LIBSAVEDVARS_MIGRATE_START_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:FireMigrateStartCallbacks() scope=" .. scope)
    local params = extraMigrateParams[self.id]
    local rawSavedVarsTable = self:LoadRawTableData()
    CALLBACK_MANAGER:FireCallbacks(scope, rawSavedVarsTable, params and protected.NilUnpack(params))
    unregisterAllMigrateStartCallbacks(self)
end

function LSV_SavedVarsManager:LoadRawTableData()
    protected.Debug("LSV_SavedVarsManager:LoadRawTableData()", debugMode)
    
    if self.rawSavedVarsTable and self.rawSavedVarsTableParent and self.rawSavedVarsTableKey 
       and self.rawSavedVarsTablePath
    then
        return self.rawSavedVarsTable, self.rawSavedVarsTableParent, self.rawSavedVarsTableKey, self.rawSavedVarsTablePath
    end
    
    if not self.table then
        self:Validate()
    end
    
    if self.keyType == LIBSAVEDVARS_ACCOUNT_KEY then
        self.rawSavedVarsTable, self.rawSavedVarsTableParent, self.rawSavedVarsTableKey, _, self.rawSavedVarsTablePath =
            protected.GetSavedVarsTable(self.name, self.namespace, self.profile, self.displayName)
    else
        self.rawSavedVarsTable, self.rawSavedVarsTableParent, self.rawSavedVarsTableKey, _, self.rawSavedVarsTablePath =
            protected.GetSavedVarsTable(self.name, self.namespace, self.profile, self.displayName, self.characterName, self.characterId, self.keyType)
    end
    
    return self.rawSavedVarsTable, self.rawSavedVarsTableParent, self.rawSavedVarsTableKey, self.rawSavedVarsTablePath
end

--[[
    Registers a callback function to be called whenever a ZO_SavedVars instance is lazy loaded by accessing the 
    savedVars property.
    
    callback:              The callback function to call.  It should have the signature function(savedVarsManager), 
                           where savedVarsManager is the LSV_SavedVarsManager instance doing the lazy loading.
              
    param1:                (optional) if provided and not nil, this will be sent as the first parameter to your 
                                      callback, e.g. function(param1, savedVarsManager).
                                      If you want to call a "self" method, pass in the object instance for the method.
                                      
    ...:                   (optional) Any additional parameters you provide will be passed to the callback after the
                                      savedVarsManager parameter when the lazy load event fires.
                                      e.g. function(param1, savedVarsManager, param2, param3, param4).
  ]]--
function LSV_SavedVarsManager:RegisterLazyLoadCallback(callback, param1, ...)
    local scope = LIBSAVEDVARS_LAZY_LOAD_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:RegisterLazyLoadCallback() scope=" .. scope, debugMode)
    if select('#', ...) > 0 then
        extraLazyLoadParams[self.id] = protected.NilPack(...)
    end
    CALLBACK_MANAGER:RegisterCallback(scope, callback, param1)
    return scope
end


--[[
    Registers a callback function to be called whenever a migration is started.
    
    callback:              The callback function to call.  It should have the signature function(rawSavedVarsTable), 
                           where rawSavedVarsTable is the Lua table used to store the saved vars being migrated.
              
    param1:                (optional) if provided and not nil, this will be sent as the first parameter to your 
                                      callback, e.g. function(param1, rawSavedVarsTable).
                                      If you want to call a "self" method, pass in the object instance for the method.
                                      
    ...:                   (optional) Any additional parameters you provide will be passed to the callback after the
                                      rawSavedVarsTable parameter when the migrate start event fires.
                                      e.g. function(param1, rawSavedVarsTable, param2, param3, param4).
  ]]--
function LSV_SavedVarsManager:RegisterMigrateStartCallback(callback, param1, ...)
    local scope = LIBSAVEDVARS_MIGRATE_START_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:RegisterMigrateStartCallback() scope=" .. scope, debugMode)
    if select('#', ...) > 0 then
        extraMigrateParams[self.id] = protected.NilPack(...)
    end
    CALLBACK_MANAGER:RegisterCallback(scope, callback, param1)
end

function LSV_SavedVarsManager:SetDebugMode(enable)
    protected.SetDebugMode(enable)
end

function LSV_SavedVarsManager:RemoveSettings(version, settingsToRemove, ...)
    assert(type(version) == "number", 
           "Invalid type for argument 'version'. Expected 'number'. Got '" .. type(version) .. "' instead.")
    local params = { ... }
    if type(settingsToRemove) == "string" then
        table.insert(params, 1, settingsToRemove)
        settingsToRemove = params
    end
    protected.Debug("LSV_Data:RemoveSettings(<<1>>, <<2>> (<<3>>))", debugMode, 
                    version, tostring(settingsToRemove), settingsToRemove and #settingsToRemove or nil)
                
    if not self.version or self.version < version then
        self.version = version
    end
                
    local rawDataTable = self:LoadRawTableData()
    if not rawDataTable then
        protected.Debug("Saved vars don't exist. Skipping " .. table.concat({self.rawSavedVarsTablePath}, " > "), debugMode)
        return self
    elseif rawDataTable.version and rawDataTable.version >= version then
        protected.Debug("Version check passed. Skipping " .. table.concat({self.rawSavedVarsTablePath}, " > "), debugMode)
        return self
    end
    protected.Debug("Raw data table at " .. table.concat({self.rawSavedVarsTablePath}, " > ") 
        .. " has ".. NonContiguousCount(rawDataTable) .. " items.", debugMode)
    for _, settingToRemove in ipairs(settingsToRemove) do
        protected.Debug("Setting rawDataTable['" .. tostring(settingToRemove) .. "'] = nil", debugMode)
        rawDataTable[settingToRemove] = nil
    end
    protected.Debug("Raw data table at " .. table.concat({self.rawSavedVarsTablePath}, " > ") 
        .. " has ".. NonContiguousCount(rawDataTable) .. " items.", debugMode)
    protected.Debug(tostring(#settingsToRemove) .. " settings removed.", debugMode)
    
    if not self.pendingVersion or self.pendingVersion < version then
        self.pendingVersion = version
        versionUpdateQueue[self.id] = self
    end
    
    return self
end

function LSV_SavedVarsManager:RenameSettings(version, renameMap, callback)
    if type(version) == "table" then
        renameMap = version
        version = nil
    end
    protected.Debug("LSV_SavedVarsManager:RenameSettings(<<1>>, <<2>>, <<3>>)", debugMode, version, renameMap, callback)
                
    if not self.version or self.version < version then
        self.version = version
    end
    
    local rawDataTable = self:LoadRawTableData()
    if not rawDataTable then
        protected.Debug("Saved vars don't exist. Skipping " .. table.concat({self.rawSavedVarsTablePath}, " > "), debugMode)
        return self
    elseif version and rawDataTable.version and rawDataTable.version >= version then
        protected.Debug("Version check passed. Skipping " .. table.concat({self.rawSavedVarsTablePath}, " > "), debugMode)
        return self
    end
    local count = 0
    for oldSetting, newSetting in pairs(renameMap) do
        if rawDataTable[oldSetting] ~= nil then
            local value = rawDataTable[oldSetting]
            if callback then
                value = callback(value)
            end
            rawDataTable[newSetting] = value
            rawDataTable[oldSetting] = nil
            count = count + 1
        end
    end
    protected.Debug(tostring(count) .. " settings renamed.", debugMode)
    
    if not self.pendingVersion or self.pendingVersion < version then
        self.pendingVersion = version
        versionUpdateQueue[self.id] = self
    end
    
    return self
end


function LSV_SavedVarsManager:RenameSettingsAndInvert(version, renameMap)
    protected.Debug("LSV_SavedVarsManager:RenameSettingsAndInvert(<<1>>, <<2>>)", debugMode, version, renameMap)
    return self:RenameSettings(version, renameMap, protected.Invert)
end

--[[
    Removes a callback registration for when a ZO_SavedVars instance is lazy loaded by accessing the savedVars property.
    
    callback: The callback function to unregister.
  ]]--
function LSV_SavedVarsManager:UnregisterLazyLoadCallback(callback)
    local scope = LIBSAVEDVARS_LAZY_LOAD_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:UnregisterLazyLoadCallback() scope=" .. scope, debugMode)
    CALLBACK_MANAGER:UnregisterCallback(scope, callback)
    extraLazyLoadParams[self.id] = nil
end

--[[
    Removes a callback registration for when a migration is started on the given raw saved vars data table.
    
    callback:              The callback function to unregister.
  ]]--
function LSV_SavedVarsManager:UnregisterMigrateStartCallback(callback)
    local scope = LIBSAVEDVARS_MIGRATE_START_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:UnregisterMigrateStartCallback() scope=" .. scope, debugMode)
    CALLBACK_MANAGER:UnregisterCallback(scope, callback)
    extraMigrateParams[self.id] = nil
end

function LSV_SavedVarsManager:Validate()
    protected.Debug("LSV_SavedVarsManager:Validate()", debugMode)
    
    if rawget(self, "table") then
        return true, self
    end
    
    local tableValid, savedVarsTable = pcall(protected.ValidateSavedVarsTable, rawget(self, "name"))
    
    assert(tableValid, "Invalid saved vars table specified in field 'name'.")
    
    
    protected.Debug("Setting 'table' field of LSV_SavedVarsManager " .. tostring(self) 
                    .. " to " .. tostring(savedVarsTable), debugMode)
    rawset(self, "table", savedVarsTable)
    
    return true, self
end

--[[
     Upgrades the saved vars tracked by this loader to the given version number.  
     Has no effect on saved vars at or above the given version.
     
     version:         Settings are only upgraded on saved vars below this version number.
     
     onVersionUpdate: Upgrade script function with the signature function(rawDataTable) end to be run before updating
                      saved vars version.  You can run any settings transforms in here.
  ]]--
function LSV_SavedVarsManager:Version(version, onVersionUpdate)
    
    protected.Debug("LSV_SavedVarsManager:Version(<<1>>, <<2>>)", debugMode, version, onVersionUpdate)
                
    if not self.version or self.version < version then
        self.version = version
    end
    
    local rawDataTable = self:LoadRawTableData()
    if not rawDataTable then
        protected.Debug("Saved vars don't exist. Skipping " .. table.concat({self.rawSavedVarsTablePath}, " > "), debugMode)
        return self
    elseif rawDataTable.version and rawDataTable.version >= version then
        protected.Debug("Version check failed. Skipping.", debugMode)
        return self
    end
    
    onVersionUpdate(rawDataTable)

    if not self.pendingVersion or self.pendingVersion < version then
        self.pendingVersion = version
        versionUpdateQueue[self.id] = self
    end
    
    return self
end



---------------------------------------
--
--       Meta methods
-- 
---------------------------------------

--[[
     Lazy-load "savedVars" key.
  ]]--
function LSV_SavedVarsManager.__index(manager, key)    
    
    if not manager or key == nil then
        return
    end
    
    if key ~= "savedVars" then
        return LSV_SavedVarsManager[key]
    end
    
    if not rawget(manager, "table") then
        manager:Validate()
    end
    
    local pendingVersion = rawget(manager, "pendingVersion")
    if pendingVersion then
        local rawDataTable = LSV_SavedVarsManager.LoadRawTableData(manager)
        if rawDataTable then
            rawDataTable.version = pendingVersion
        end
        rawset(manager, "pendingVersion", nil)
        versionUpdateQueue[manager.id] = nil
    end
    
    local savedVars
    if rawget(manager, "keyType") == LIBSAVEDVARS_ACCOUNT_KEY then
        protected.Debug("Lazy loading new account wide saved vars.", debugMode)
        savedVars = ZO_SavedVars:NewAccountWide(rawget(manager, "name"), rawget(manager, "version"), 
                                                rawget(manager, "namespace"), rawget(manager, "defaults"), 
                                                rawget(manager, "profile"), rawget(manager, "displayName"))
    else
        protected.Debug("Lazy loading new character-specific saved vars.", debugMode)
        savedVars = ZO_SavedVars:New(rawget(manager, "name"), rawget(manager, "version"), rawget(manager, "namespace"), 
                                     rawget(manager, "defaults"), rawget(manager, "profile"), rawget(manager, "displayName"), 
                                     rawget(manager, "characterName"), rawget(manager, "characterId"), 
                                     rawget(manager, "keyType"))
    end
    
    rawset(manager, "savedVars", savedVars)
    
    fireLazyLoadCallbacks(manager)
    
    return savedVars
end


---------------------------------------
--
--       Constructors
-- 
---------------------------------------
function LSV_SavedVarsManager:New(data)
    
    local manager = {
        id                      = nextId,
        name                    = data.name,
        keyType                 = data.keyType or LIBSAVEDVARS_CHARACTER_NAME_KEY,
        version                 = data.version or 1,
        defaults                = data.defaults or { },
        namespace               = data.namespace,
        profile                 = data.profile,
        displayName             = data.displayName or GetDisplayName(),
        table                   = data.table,
        rawSavedVarsTable       = data.rawSavedVarsTable,
        rawSavedVarsTableParent = data.rawSavedVarsTableParent,
        rawSavedVarsTableKey    = data.rawSavedVarsTableKey,
        rawSavedVarsTablePath   = data.rawSavedVarsTablePath,
    }
    if manager.keyType ~= LIBSAVEDVARS_ACCOUNT_KEY then
        manager.characterName = data.characterName or GetUnitName("player")
        manager.characterId   = data.characterId or GetCurrentCharacterId()
    end
    
    setmetatable(manager, self)
    
    protected.Debug("LSV_SavedVarsManager:New() returning " .. tostring(manager) .. " with [table] field = " .. tostring(manager.table))
    
    nextId = nextId + 1

    return manager
end



---------------------------------------
--
--       Private Methods
-- 
---------------------------------------

function fireLazyLoadCallbacks(self)
    local scope = LIBSAVEDVARS_LAZY_LOAD_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:fireLazyLoadCallbacks() scope=" .. scope, debugMode)
    local params = extraLazyLoadParams[self.id]
    CALLBACK_MANAGER:FireCallbacks(scope, params and protected.NilUnpack(params))
    unregisterAllLazyLoadCallbacks(self)
end

function unregisterAllLazyLoadCallbacks(self)
    local scope = LIBSAVEDVARS_LAZY_LOAD_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:unregisterAllLazyLoadCallbacks() scope=" .. scope, debugMode)
    CALLBACK_MANAGER:UnregisterAllCallbacks(scope)
    extraLazyLoadParams[self.id] = nil
end

function updatePendingVersionsOnLogout()
    for id, savedVarsManager in pairs(versionUpdateQueue) do
        local pendingVersion = rawget(savedVarsManager, "pendingVersion")
        if pendingVersion then
            local rawDataTable = LSV_SavedVarsManager.LoadRawTableData(savedVarsManager)
            if rawDataTable then
                rawDataTable.version = pendingVersion
            end
            rawset(savedVarsManager, "pendingVersion", nil)
        end
    end
    versionUpdateQueue = {}
end

function unregisterAllMigrateStartCallbacks(self)
    local scope = LIBSAVEDVARS_MIGRATE_START_CALLBACK_NAME .. tostring(self.id)
    protected.Debug("LSV_SavedVarsManager:unregisterAllMigrateStartCallbacks() scope=" .. scope, debugMode)
    CALLBACK_MANAGER:UnregisterAllCallbacks(scope)
    extraMigrateParams[self.id] = nil
end

EVENT_MANAGER:RegisterForEvent(CLASSNAME, EVENT_PLAYER_DEACTIVATED, updatePendingVersionsOnLogout)