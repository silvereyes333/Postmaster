--[[ LibSavedVars and its files © silvereyes
     Distributed under MIT license (see LICENSE) ]]

-- copy language strings locally, then destroy
local libSavedVarsStrings = LIBSAVEDVARS_STRINGS
LIBSAVEDVARS_STRINGS = nil

--Register LibSavedVars with LibStub
local LIBNAME, LIBVERSION = "LibSavedVars", 3.0
local libSavedVars, oldminor = LibStub:NewLibrary(LIBNAME, LIBVERSION)
if not libSavedVars then return end --the same or newer version of this lib is already loaded into memory

local deepSavedVarsCopy

-- Create localized strings
for stringId, value in pairs(libSavedVarsStrings) do
    ZO_CreateStringId(stringId, value)
end

---------------------------------------
--
--       Public methods
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
     Gets the underlying data table for a ZO_SavedVars instance, since ZO_SavedVars don't support many common table
     operations directly (e.g. pairs/ipairs/next/#).
  ]]--
function libSavedVars:GetRawDataTable(savedVars)
    local meta = getmetatable(savedVars)
    return meta and meta.__index or savedVars
end

--[[
     Creates ZO_SavedVar instances for account-wide and/or character-specific saved vars, per-server, and returns a 
     new data object (See Data.lua) that can be used just like a normal ZO_SavedVars object, but can toggle between
     account-wide and character-specific settings on-the-fly.  
     
     The data object can also be used for migrating old ZO_SavedVar instances to the server-specific structure using the
     data:Migrate() method.  See the Data.lua file for full documentation.
     
     accountSavedVarsName:          Name of the account-wide saved var to create, or nil.
                                    If nil, then characterSavedVarsName should not be nil.
                                    
                                    Should match a name specified with ## SavedVariables in your manifest.
     characterSavedVarsName:        Name of the character-specific saved var to create, or nil.
                                    If nil, then accountSavedVarsName should not be nil.
                                    Should match a name specified with ## SavedVariables in your manifest.
                                    
     defaults:                      (optional) Table containing default values for your saved vars.
     
     defaultAccountSavedVarsActive: True if account-wide saved vars should be enabled by default the first time settings
                                    are loaded for a character; false if character-specific settings should be enabled
                                    by default.
                                    If you plan to use the libSavedVars_Data:Migrate() feature, you should pass in true
                                    only if your legacy saved vars were created with ZO_SavedVars:NewAccountWide().
                                    If your legacy saved vars were created with ZO_SavedVars:New() or 
                                    ZO_SavedVars:NewCharacterIdSettings(), then you should pass in false.
  ]]--
function libSavedVars:New(accountSavedVarsName, characterSavedVarsName, defaults, useAccountSettingsDefault)
    return self:GetClass("Data"):New(accountSavedVarsName, characterSavedVarsName, defaults, useAccountSettingsDefault)
end

--[[
     Stand-in replacement for ZO_SavedVars:NewAccountWide()
     Returns a LibSavedVars data object just like libSavedVars:New(), but with no character-specific settings.  
     Mainly used to get a quick data file instance for legacy saved vars migration.
  ]]--
function libSavedVars:NewAccountWide(accountSavedVarsName, defaults)    
    return self:GetClass("Data"):New(accountSavedVarsName, nil, defaults, true)
end

--[[
     Stand-in replacement for ZO_SavedVars:NewCharacterIdSettings()
     Returns a LibSavedVars data object just like libSavedVars:New(), but with no account-wide settings.  
     Mainly used to get a quick data file instance for legacy saved vars migration.
  ]]--
function libSavedVars:NewCharacterIdSettings(characterSavedVarsName, defaults)
    return self:GetClass("Data"):New(nil, characterSavedVarsName, defaults, false)
end



-------------------------------------------------------
--
--       Stubbed library class helper functions
-- 
-------------------------------------------------------

-- Library class registry tables
local classes       = { }
local classVersions = { }

--[[
     Gets the active version of the given LibSavedVars class by name. 
     Returns the class definition table and version number
  ]]--
function libSavedVars:GetClass(name)
    return classes[name], classVersions[name]
end

--[[
     Similar to LibStub:NewLibrary(), but used to break out LibSavedVars classes into separate files without version 
     conflicts.
  ]]--
function libSavedVars:NewClass(name, version)
    if not classVersions[name] or classVersions[name] < version then
        classVersions[name] = version
        classes[name] = ZO_Object:Subclass()
        return classes[name]
    end
end



----------------------------------------------------------------------------
--
--       Deprecated methods
--
--       The following methods will be removed in a future version.
--       Please migrate to the new methods above and those in Data.lua
-- 
----------------------------------------------------------------------------

-- Registry of data instances by addon for v2 backwards compatibility
local addonInstances = { }

--[[
     DEPRECATED
     See Data.lua => libSavedVars_Data:__index(key)
  ]]--
function libSavedVars:Get(addon, key)
    if not addonInstances[addon] then return end
    return addonInstances[addon][key]
end

--[[ 
     DEPRECATED
     See Data.lua => libSavedVars_Data:GetLibAddonMenuSetting(default)
  ]]--
function libSavedVars:GetLibAddonMenuSetting(addon, default)
    if not addonInstances[addon] then return end
    return addonInstances[addon]:GetLibAddonMenuAccountCheckbox(default)
end

--[[ 
     DEPRECATED
     See libSavedVars:New()
     See Data.lua => libSavedVars_Data:Migrate(legacySavedVars, beforeCallback, addon, ...)
  ]]--
function libSavedVars:Init(addon, accountSavedVarsName, characterSavedVarsName, defaults, useAccountSettingsDefault,
        legacySavedVars, legacyIsAccountWide, legacyMigrationCallback, ...)
    
    local data = self:New(accountSavedVarsName, characterSavedVarsName, defaults, useAccountSettingsDefault)
    
    addon.accountSettings   = data.dataSource.accountSavedVars
    addon.characterSettings = data.dataSource.characterSavedVars
    addonInstances[addon]   = data
    
    if legacySavedVars then
        data:Migrate(legacySavedVars, legacyMigrationCallback, addon, ...)
    end
end

--[[ 
     DEPRECATED
     See Data.lua => libSavedVars_Data:__newindex(key, value)
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

--[[
     Helper method for libSavedVars:DeepSavedVarsCopy()
  ]]--
deepSavedVarsCopy = function(source, dest, doNotOverwrite)
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
