--[[ LibSavedVars and its files © silvereyes
     Distributed under MIT license (see LICENSE) ]]

-- copy language strings locally, then destroy
local libSavedVarsStrings = LIBSAVEDVARS_STRINGS
LIBSAVEDVARS_STRINGS = nil

--Register LibSavedVars with LibStub
local LIBNAME, LIBVERSION = "LibSavedVars", 40001
local libSavedVars, oldminor = LibStub:NewLibrary(LIBNAME, LIBVERSION)
if not libSavedVars then return end --the same or newer version of this lib is already loaded into memory

-- Constants
LIBSAVEDVARS_CHARACTER_NAME_KEY = ZO_SAVED_VARS_CHARACTER_NAME_KEY
LIBSAVEDVARS_CHARACTER_ID_KEY   = ZO_SAVED_VARS_CHARACTER_ID_KEY
LIBSAVEDVARS_ACCOUNT_KEY        = 3
LIBSAVEDVARS_SCOPE_CHARACTER    = 1
LIBSAVEDVARS_SCOPE_ACCOUNT      = 2
LIBSAVEDVARS_SCOPE_MIN          = LIBSAVEDVARS_SCOPE_CHARACTER
LIBSAVEDVARS_SCOPE_MAX          = LIBSAVEDVARS_SCOPE_ACCOUNT

-- Protected methods accessible to LibSavedVars and all classes created with :NewClass() (see below)
local protected

-- Server/world name registry
local WORLDS

-- Registry of extra parameters to pass to "LibSavedVarsMigrateStart" callbacks
local extraMigrateParams = { }

-- Registry of saved var table names and paths by saved var instances
local savedVarRegistry = { }

-- Addon name most recently loaded
local currentAddonName

-- Local functions
local codeFormat, debug, deepSavedVarsCopy, registerSavedVars, toCode

-- Create localized strings
for stringId, value in pairs(libSavedVarsStrings) do
    ZO_CreateStringId(stringId, value)
end

---------------------------------------
--
--       Public Members
-- 
---------------------------------------

--[[
     Clears all saved vars values from the given ZO_SavedVars instance. Leaves the built-in "version" var, and all
     function definitions.
     
     savedVars: the ZO_SavedVars table to clear
  ]]--
function libSavedVars:ClearSavedVars(savedVars)
    local dataTable = self:GetRawDataTable(savedVars)
    for key, value in pairs(dataTable) do
        if key ~= "version" and type(value) ~= "function" then
            savedVars[key] = nil
        end
    end
end

--[[
     Copies saved var values from one ZO_SavedVars instance to another, optionally ignoring vars that already exist in
     the destination.
     
     source:         The ZO_SavedVars instance to copy values from
     destination:    The ZO_SavedVars instance to copy values to
     doNotOverwrite: (optional) If true, only vars that equal nil in the destination will be copied. default: false.
  ]]--
function libSavedVars:DeepSavedVarsCopy(source, destination, doNotOverwrite)
    
    -- Get rid of the annoying ZO_SavedVars interface crap to deal with the data directly
    source      = self:GetRawDataTable(source)
    destination = self:GetRawDataTable(destination)
    
    -- Copy keys from source to destination
    for key, value in pairs(source) do
        
        -- Copy nested tables
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            self:DeepSavedVarsCopy(value, destination[key], doNotOverwrite)
            
        -- Copy scalar values
        elseif key ~= "version" and type(value) ~= "function" then
        
            -- Make sure we don't overwrite destination values, if requested
            if not doNotOverwrite or destination[key] == nil then
                destination[key] = value
            end
        end
    end
end


--[[
     Gets a list of tables of the form { account = "@displayName", profile = "NA Megaserver" } for all accounts within
     the given saved var table.
     
     savedVarName: The name of the saved var table to extract account names from.
  ]]--
function libSavedVars:GetAccountsAndProfiles(savedVarName)
    local savedVariableTable = _G[savedVarName]
    if type(savedVariableTable) ~= "table" then
        error("Can only apply saved variables to a table")
    end
    local accountsAndProfiles = { }
    for key1, value1 in pairs(savedVariableTable) do
        if type(value1) == "table" then
            if key1:sub(1, 1) == "@" then
                table.insert(accountsAndProfiles, { account = key1 })
            else
                for key2, value2 in pairs(value1) do
                    if type(value2) == "table" and key1:sub(1, 1) == "@" then
                        table.insert(accountsAndProfiles, { account = key2, profile = key1 } )
                    end
                end
            end
        end
    end
    return accountsAndProfiles
end

--[[
     Gets table containing the following information about a ZO_SavedVars interface instance.  Can be passed directly
     to LSV_SavedVarsManager:New().
     
     addonName:     The name of the addon that created the saved vars.
     
     name:          The name of the top-level global table containing the saved vars.  
                    Matches the name in ## SavedVariables: in the manifest text file.
                    
     table:         Reference to the top-level global table containing the saved vars.
     
     keyType:       One of the following, depending on the type of constructor used for ZO_SavedVars:
                    LIBSAVEDVARS_CHARACTER_ID_KEY:   For ZO_SavedVars:NewCharacterIdSettings()
                    LIBSAVEDVARS_CHARACTER_NAME_KEY: For ZO_SavedVars:New() and ZO_SavedVars:NewCharacterNameSettings()
                    LIBSAVEDVARS_ACCOUNT_KEY:        For ZO_SavedVars:NewAccountWide()
                    
     defaults:      Table of default values provided to the ZO_SavedVars constructor.
     
     version:       Saved vars version passed to the ZO_SavedVars constructor.
     
     namespace:     An optional string namespace to separate other variables using the same table.
     
     profile:       An optional string used to group several saved vars tables together as a unit.  
                    Usually either nil, "Default" or the megaserver name (i.e. "NA Megaserver", "EU Megaserver", "PTS")
                    
     displayName:   The account name the saved vars belong to.  Defaults to the current account name.
     
     characterName: The character name the saved vars belong to.  For account-wide vars, should be nil.
     
     characterId:   The character id the saved vars belong to, if ZO_SavedVars:NewCharacterIdSettings() was used.
     
     rawSavedVarsTable:       The child table within *table* that actually stores the ZO_SavedVars data.
     
     rawSavedVarsTablePath:   A list of nested keys used to lookup the raw saved vars table within *table*.
     
     rawSavedVarsTableParent: The table containing the raw saved vars table.
     
     rawSavedVarsTableKey:    The key within *rawSavedVarsTableParent* that can be used to lookup rawSavedVarsTable.
                              Usually equals either *namespace*, *characterId*, *characterName* or "$AccountWide"
  ]]--
function libSavedVars:GetInfo(savedVars)
    if savedVars == nil then return end
    return savedVarRegistry[savedVars]
end

--[[
     Gets the underlying data table for a ZO_SavedVars instance, since ZO_SavedVars don't support many common table
     operations directly (e.g. pairs/ipairs/next/#).
  ]]--
function libSavedVars:GetRawDataTable(savedVars)
    local meta = getmetatable(savedVars)
    return meta and meta.__index or savedVars
end

--[[
     Returns an array of world (i.e. server) names for the given environment.
     
     environment: "live", "pts", "*" for all, or empty/nil to autodetect
  ]]--
function libSavedVars:GetWorldNames(environment)
    if environment == "*" then
        return { unpack(WORLDS["live"]), unpack(WORLDS["pts"]) }
    end
    if not environment then
        environment = GetWorldName() == "PTS" and "pts" or "live"
    end
    return WORLDS[environment]
end

--[[
     Returns true if the given input is a ZO_SavedVars interface instance; otherwise nil.
  ]]--
function libSavedVars:IsZOSavedVars(input)
    return type(input) == "table" and type(input.GetInterfaceForCharacter) == "function"
end

--[[
     Moves a legacy saved var with the specified info to one or more new saved vars with their own specified info.
     
     Returns an array of migrated saved vars loader instances that can optionally be used to create 
     ZO_SavedVars instances.
     
     defaultKeyType:    (optional) If specified, selects the general type of saved vars to be copied.
                                   Should be one of the following values:
                                
                                   LIBSAVEDVARS_CHARACTER_NAME_KEY - for saved vars created with ZO_SavedVars:New() 
                                                                     or ZO_SavedVars:NewCharacterNameSettings().
                                                                     This is the default.
                                                                  
                                   LIBSAVEDVARS_CHARACTER_ID_KEY   - for saved vars created with 
                                                                     ZO_SavedVars:NewCharacterIdSettings().
                                
                                   LIBSAVEDVARS_ACCOUNT_KEY        - for saved vars created with 
                                                                     ZO_SavedVars:NewAccountWideSettings().
                                                                  
     fromSavedVarsInfo: details describing the parameters to ZO_SavedVars used for the source saved var to migrate.
                        See below for details.
                        
     toSavedVarsInfo1,
                   ...: details describing the parameters to ZO_SavedVars used for one or more destination saved vars.
                   
     Each info parameter (fromSavedVarsInfo, toSavedVarsInfo1, ...) should be a table of the following format:
     
     {
       name          = The string name of the saved variable table. Required.
       keyType       = (optional) The general type of saved vars involved.  Same parameters as defaultKeyType above.  
                                  Takes precedence over defaultKeyType.
       version       = (optional) The numeric current saved vars version. Defaults to 1. Only used for toSavedVarsInfo params.
       namespace     = (optional) String namespace to separate other variables using the same table
       defaults      = (optional) A table describing the default saved variables.  Only used for toSavedVarsInfo params.
       profile       = (optional) String to describe a top-level grouping for related account-wide and 
                                  character-specific saved vars. Most often used to separate out settings by 
                                  megaserver name (e.g. GetWorldName())
       displayName   = (optional) The account name the saved vars are for. Defaults to the current account name.
       characterName = (optional) The name of the character the saved vars are for, if keyType is 
                                  LIBSAVEDVARS_CHARACTER_NAME_KEY.  Defaults to the current character name.
       characterId   = (optional) The numeric id of the character the saved vars are for, if keyType is 
                                  LIBSAVEDVARS_CHARACTER_ID_KEY.  Defaults to the current character id.
     }
  ]]--
function libSavedVars:Migrate(defaultKeyType, fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    local toParams, from = protected.Migrate(defaultKeyType, fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    -- Remove the source saved var and any empty parent containers
    protected.UnsetPath(from.table, unpack(from.rawSavedVarsTablePath))
    
    return toParams
end

--[[
     Same as Migrate, with the assumption that all saved vars involved are account-wide.
  ]]--
function libSavedVars:MigrateAccountWide(fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    return self:Migrate(LIBSAVEDVARS_ACCOUNT_KEY, fromSavedVarsInfo, toSavedVarsInfo1, ...)
end

--[[
     Same as Migrate, with the assumption that all saved vars involved are character-id-specific.
  ]]--
function libSavedVars:MigrateCharacterId(fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    return self:Migrate(LIBSAVEDVARS_CHARACTER_ID_KEY, fromSavedVarsInfo, toSavedVarsInfo1, ...)
end

--[[
     Same as Migrate, with the assumption that all saved vars involved are character-name-specific.
  ]]--
function libSavedVars:MigrateCharacterName(fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    return self:Migrate(LIBSAVEDVARS_CHARACTER_NAME_KEY, fromSavedVarsInfo, toSavedVarsInfo1, ...)
end

--[[
     Same as Migrate, but for migrating character name saved vars to character id ones.
  ]]--
function libSavedVars:MigrateCharacterNameToId(fromSavedVarsInfo, toSavedVarsInfo1, ...)
    
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_NAME_KEY
    return self:Migrate(LIBSAVEDVARS_CHARACTER_ID_KEY, fromSavedVarsInfo, toSavedVarsInfo1, ...)
end

--[[
     Same as Migrate, but simply moves all of the given saved vars to megaserver-specific copies.
     
     defaultkeyType:    (optional) Same as Migrate()
     fromSavedVarsInfo: Same as Migrate(). Required.
     copyToAllServers:  (optional) When set to true and fromSavedVarsInfo.keyType or defaultKeyType is set to 
                                   LIBSAVEDVARS_ACCOUNT_KEY, then the settings are migrated to both NA and EU 
                                   megaservers.  Set to false to only copy to the first megaserver this method is called
                                   on.  Defaults to true.  
                                   Character settings are only copied to the current megaserver for each character.
     toSavedVarsInfo:   (optional) If set, details describing the parameters to ZO_SavedVars used for all destination
                                   megaserver saved vars.  If nil or omitted, then it's assumed the destination
                                   saved vars will be the same as fromSavedVarsInfo, except with megaserver name as the
                                   profile name.
  ]]--
function libSavedVars:MigrateToMegaserverProfiles(defaultKeyType, fromSavedVarsInfo, copyToAllServers, toSavedVarsInfo)
    
    local toParams, from = protected.MigrateToMegaserverProfiles(defaultKeyType, fromSavedVarsInfo, copyToAllServers, toSavedVarsInfo)
    
    -- Remove the source saved var and any empty parent containers
    protected.UnsetPath(from.table, unpack(from.rawSavedVarsTablePath))
    
    return toParams
end

--[[
     Stand-in replacement for ZO_SavedVars:NewAccountWide() that defaults to server-specific profiles.
     Returns an LSV_Data object
     
     To add a character-specific scope for the same settings that can be toggled, call :AddCharacterSettingsToggle() on the 
     object that is returned by this function.
     
     See classes/LSV_Data.lua => LSV_Data:AddCharacterSettingsToggle()
  ]]--
function libSavedVars:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName)
    return LSV_Data:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName)
end

--[[
     Stand-in replacement for ZO_SavedVars:New() that defaults to server-specific profiles and character id settings 
     instead of character name.
     Returns an LSV_Data object.
     
     To add an account-wide scope for the same settings that can be toggled, call :AddAccountWideToggle() on the 
     object that is returned by this function.
     
     See classes/LSV_Data.lua => LSV_Data:AddAccountWideToggle()
  ]]--
function libSavedVars:NewCharacterSettings(savedVariableTable, version, namespace, defaults, profile, displayName, 
                                           characterName, characterId, characterKeyType)
    return LSV_Data:NewCharacterSettings(savedVariableTable, version, namespace, defaults, profile, displayName, 
                                         characterName, characterId, characterKeyType)
end

--[[
     Alias of libSavedVars:NewCharacterSettings()
     For backwards compatibility with v3
  ]]--
libSavedVars.NewCharacterIdSettings = libSavedVars.NewCharacterSettings

function libSavedVars:SetDebugMode(enable)
    protected.SetDebugMode(enable)
end



-------------------------------------------------------
--
--       Stubbed library class helper functions
-- 
-------------------------------------------------------

-- Library class registry tables
local classVersions = { }

--[[
     Similar to LibStub:NewLibrary(), but used to break out LibSavedVars classes into separate files without version 
     conflicts.  Not necessary if people include the LibSavedVars.txt manifest - the ## AddonVersion should take 
     care of versioning - but I can't assume people won't try to bundle this library without the manifest.
  ]]--
function libSavedVars:NewClass(name, version)
    if not classVersions[name] or classVersions[name] < version then
        classVersions[name] = version
        
        local newClass = { }
        if name == "Protected" then
            protected = newClass
        end
        return newClass, protected
    end
end



-------------------------------------------------------
--
--             Global Overrides
-- 
-------------------------------------------------------

--[[
     Override ZO_SavedVars:New() so that the parameters for the resulting saved var can be registered.
  ]]--
local origSavedVarsNew = ZO_SavedVars.New
function ZO_SavedVars:New(savedVariableTable, version, namespace, defaults, profile, displayName, characterName, characterId, characterKeyType)
    local savedVars = origSavedVarsNew(self, savedVariableTable, version, namespace, defaults, profile, displayName, characterName, characterId, characterKeyType)
    registerSavedVars(savedVars, savedVariableTable, version, namespace, defaults, profile, displayName, characterName, characterId, characterKeyType)
    return savedVars
end

--[[
     Override ZO_SavedVars:NewCharacterNameSettings() so that the parameters for the resulting saved var can be registered.
  ]]--
function ZO_SavedVars:NewCharacterNameSettings(savedVariableTable, version, namespace, defaults, profile)
    return self:New(savedVariableTable, version, namespace, defaults, profile, GetDisplayName(), GetUnitName("player"), GetCurrentCharacterId(), ZO_SAVED_VARS_CHARACTER_NAME_KEY)
end

--[[
     Override ZO_SavedVars:NewCharacterIdSettings() so that the parameters for the resulting saved var can be registered.
  ]]--
function ZO_SavedVars:NewCharacterIdSettings(savedVariableTable, version, namespace, defaults, profile)
    return self:New(savedVariableTable, version, namespace, defaults, profile, GetDisplayName(), GetUnitName("player"), GetCurrentCharacterId(), ZO_SAVED_VARS_CHARACTER_ID_KEY)
end

--[[
     Override ZO_SavedVars:NewAccountWide() so that the parameters for the resulting saved var can be registered.
  ]]--
local origSavedVarsNewAccountWide = ZO_SavedVars.NewAccountWide
function ZO_SavedVars:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName)
    local savedVars = origSavedVarsNewAccountWide(self, savedVariableTable, version, namespace, defaults, profile, displayName)
    registerSavedVars(savedVars, savedVariableTable, version, namespace, defaults, profile, displayName)
    return savedVars
end



----------------------------------------------------------------------------
--
--       Deprecated methods
--
--       The following methods will be removed in a future version.
--       Please migrate to the new methods above and those in 
--       classes/LSV_Data.lua
-- 
----------------------------------------------------------------------------

-- Registry of data instances by addon for v2 backwards compatibility
local addonInstances = { }

--[[
     **DEPRECATED**
     See classes/LSV_Data.lua => LSV_Data:__index(key)
  ]]--
function libSavedVars:Get(addon, key)
    if not addonInstances[addon] then return end
    return addonInstances[addon][key]
end

--[[ 
     **DEPRECATED**
     See classes/LSV_Data.lua => LSV_Data:GetLibAddonMenuSetting(default)
  ]]--
function libSavedVars:GetLibAddonMenuSetting(addon, default)
    if not addonInstances[addon] then return end
    return addonInstances[addon]:GetLibAddonMenuAccountCheckbox(default)
end

--[[
     **DEPRECATED**
     See libSavedVars:NewCharacterSettings()
     See libSavedVars:NewAccountWide()
     See libSavedVars:AddCharacterSettingsToggle()
     See libSavedVars:AddAccountWideToggle()
  ]]--
function libSavedVars:New(accountSavedVarsName, characterSavedVarsName, version, namespace, defaults, useAccountSettingsDefault)
    return LSV_Data:New(accountSavedVarsName, characterSavedVarsName, version, namespace, defaults, useAccountSettingsDefault)
end

--[[ 
     **DEPRECATED**
     See libSavedVars:New()
     See libSavedVars:Migrate()
  ]]--
function libSavedVars:Init(addon, accountSavedVarsName, characterSavedVarsName, defaults, useAccountSettingsDefault,
        legacySavedVars, legacyIsAccountWide, legacyMigrationCallback, ...)
    
    local data = self:New(accountSavedVarsName, characterSavedVarsName, defaults, useAccountSettingsDefault)
    
    addonInstances[addon]   = data
    
    if legacySavedVars then
        data:Migrate(legacySavedVars, legacyMigrationCallback, addon, ...)
    end
    
    addon.accountSettings   = data.__dataSource.account.savedVars
    addon.characterSettings = data.__dataSource.character.savedVars
end

--[[ 
     **DEPRECATED**
     See classes/LSV_Data.lua => LSV_Data:__newindex(key, value)
  ]]--
function libSavedVars:Set(addon, key, value)
    if not addonInstances[addon] then return end
    addonInstances[addon][key] = value
end



---------------------------------------
--
--       Private functions
-- 
---------------------------------------

function codeFormat(format, ...)
    local params = {}
    for i = 1, select("#", ...) do
        local value = toCode(select(i, ...))
        table.insert(params, value)
    end
    return zo_strformat(format, unpack(params))
end

--[[
     Helper method for libSavedVars:DeepSavedVarsCopy()
  ]]--
function deepSavedVarsCopy(source, dest, doNotOverwrite)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(dest[key]) ~= "table" then
                dest[key] = {}
            end
            deepSavedVarsCopy(value, dest[key], doNotOverwrite)
        elseif key ~= "version" and type(value) ~= "function" then
            if not doNotOverwrite or dest[key] == nil then
                dest[key] = value
            end
        end
    end
end

--[[
     Adds the given ZO_SavedVars instance and its creation parameters, data table, and lookup path to savedVarRegistry
     to be able to get detailed metadata about the var after the fact.
     
     See libSavedVars:GetInfo()
  ]]--
function registerSavedVars(savedVars, savedVariableTableName, version, namespace, defaults, profile, displayName, characterName, characterId, characterKeyType)
    
    local rawSavedVarsTable, parent, key, savedVariableTable, path = 
        protected.GetSavedVarsTable(savedVariableTableName, namespace, profile, displayName, 
                                    characterName, characterId, characterKeyType)
    
    local info = { 
        addonName = currentAddonName,
        name = savedVariableTableName,
        table = savedVariableTable,
        keyType = characterName == nil and LIBSAVEDVARS_ACCOUNT_KEY 
                  or characterKeyType ~= nil and characterKeyType
                  or LIBSAVEDVARS_CHARACTER_NAME_KEY,
        defaults = defaults,
        version = version,
        namespace = namespace,
        profile = profile,
        displayName = displayName,
        characterName = characterName,
        characterId = characterId,
        rawSavedVarsTable = rawSavedVarsTable,
        rawSavedVarsTablePath = path,
        rawSavedVarsTableParent = parent,
        rawSavedVarsTableKey = key,
    }
    
    if protected.debugMode then
    
        local format
        if key == LIBSAVEDVARS_ACCOUNT_KEY then
            format = "ZO_SavedVars:New(<<1>>,<<2>>,<<3>>,<<4>>,<<5>>,<<6>>,<<7>>,<<8>>,<<9>>)"
        else
            format = "ZO_SavedVars:NewAccountWide(<<1>>,<<2>>,<<3>>,<<4>>,<<5>>,<<6>>)"
        end
        local message = codeFormat(format, savedVariableTableName, version, namespace, defaults, profile, displayName, 
                                   characterName, characterId, characterKeyType)
        protected.Debug(message)
    end
    
    savedVarRegistry[savedVars] = info
end

function toCode(input)
    local t = type(input)
    if t == "string" then
        return "'" .. input .. "'"
    end
    return tostring(input)
end

local function onAddonLoaded(event, name)
    currentAddonName = name
end

EVENT_MANAGER:RegisterForEvent(LIBNAME, EVENT_ADD_ON_LOADED, onAddonLoaded)

WORLDS = {
    ["live"] = { "NA Megaserver", "EU Megaserver" },
    ["pts"]  = { "PTS" },
}
