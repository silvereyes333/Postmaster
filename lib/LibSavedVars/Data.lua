--[[
     LibSavedVars data storage class.
     
     libSavedVars:GetClass("Data"):New()
  ]]--

local LIBNAME      = "LibSavedVars"
local CLASSNAME    = "Data"
local CLASSVERSION = 1.0
local libSavedVars = LibStub(LIBNAME)

-- If a newer version of this class is already loaded, exit
local libSavedVars_Data = libSavedVars:NewClass(CLASSNAME, CLASSVERSION)
if not libSavedVars_Data then return end

-- Server/world name registry
local WORLDS = {
    ["live"] = {
        ["EU Megaserver"] = true,
        ["NA Megaserver"] = true,
    },
    ["pts"] = {
        ["PTS"] = true
    },
}

-- Used for readability
local DO_NOT_OVERWRITE = true



---------------------------------------
--
--          Public Methods
-- 
---------------------------------------

--[[ 
     Returns true when both character-specific and account-wide saved vars are defined, and the account-wide vars
     are active for the currently logged in character; otherwise, returns nil
  ]]--
function libSavedVars_Data:GetAccountSavedVarsActive()
    if not self or not self.dataSource then return end
    if not self.dataSource.characterSavedVars or self.dataSource.characterSavedVars[LIBNAME].accountSavedVarsActive then
        return true
    end
end

--[[ 
     Returns the internal ZO_SavedVars instance that is active for the currently logged in character.
  ]]--
function libSavedVars_Data:GetActiveSavedVars()
    if not self or not self.dataSource then return end
    if libSavedVars_Data.GetAccountSavedVarsActive(self) then
        return self.dataSource.accountSavedVars
    else
        return self.dataSource.characterSavedVars
    end
end

--[[
     Returns a next-like function used to iterate over the active ZO_SavedVar isntance for the currently logged in 
     character.  Appends "__dataSource" as the last key/value pair, to provide access to the internal table containing
     configuration info and references to accountSavedVar and characterSavedVar.
  ]]--
function libSavedVars_Data:GetIterator()
    return function(tableToIterate, key)
        if key == "__dataSource" then
            return
        end
        local value
        key, value = next(tableToIterate, key)
        if value == nil and self.dataSource then
            return "__dataSource", self.dataSource
        end
        return key, value
    end
end

--[[
     Works like the # operator.  Gets the number of saved vars stored in the active internal ZO_SavedVars instance for 
     the currently logged in character.  The same caveats as # apply, i.e. it is not reliable except for tables 
     stored as a numerically indexed array beginning with index 1 and having no gaps.
     Provided as a separate method, because overriding the # operator is not supported in Lua 5.1.
  ]]--
function libSavedVars_Data:GetLength()
    if not self then return 0 end
    
    local savedVars = libSavedVars_Data.GetActiveSavedVars(self)
    if not savedVars then return 0 end
    
    local rawDataTable = libSavedVars:GetRawDataTable(savedVars)
    return #rawDataTable
end

--[[
     When both character-specific and account-wide saved vars are defined, sets whether or not the account-wide
     saved vars are active for the currently logged in character.
     
     accountActive:                  true to user account-wide settings for the current character; 
                                     false to use character-specific settings
     initializeCharacterWithAccount: if set to true and accountActive is false, copy any account-wide settings that are 
                                     not defined in the character-specific saved vars from the account saved vars
  ]]--
function libSavedVars_Data:SetAccountSavedVarsActive(accountActive, initializeCharacterWithAccount)
    
    if not self or not self.dataSource or not self.dataSource.characterSavedVars then return end
        
    self.dataSource.characterSavedVars[LIBNAME].accountSavedVarsActive = accountActive
    
    initializeCharacterWithAccount = initializeCharacterWithAccount or self.dataSource.defaultAccountSavedVarsActive
    
    if accountActive then return end
    
    if initializeCharacterWithAccount then
        libSavedVars:DeepSavedVarsCopy(self.dataSource.accountSavedVars, self.dataSource.characterSavedVars, DO_NOT_OVERWRITE)
    else
        libSavedVars:DeepSavedVarsCopy(self.dataSource.characterDefaults, self.dataSource.characterSavedVars, DO_NOT_OVERWRITE)
    end
end

--[[
     Moves saved var values from an old legacy saved vars instance into appropriate character-specific or 
     account-wide saved vars in this instance.
     
     Once migrated, the old legacy saved vars are cleared, and a new var called libSavedVarsMigrated is set to true.
     Successived calls to this method will not migrate again if legacySavedVars.libSavedVarsMigrated is true.
     
     If self.dataSource.defaultAccountSavedVarsActive is true, then the values are copied to account-wide saved vars for both 
     NA and EU if on live, or just PTS if on PTS, and then cleared.
     
     If self.dataSource.defaultAccountSavedVarsActive is NOT true, then the values are copied to character-specific settings on
     only the current server, and then cleared for the currently logged in user.
     
     legacySavedVars: The ZO_SavedVars instance to migrate to the new savedvars structure in this instance.
     
     beforeCallback:  (optional) If specified, raised right before data is copied, so that any transformations can be
                                 run on the old saved vars table before its values are moved.
                                 Valid signatures include function(addon, legacySavedVars, ...), if addon is not nil,
                                 or function(legacySavedVars, ...) if addon is nil.
                                 
     addon:           (optional) If not nil, will be passed as the first parameter to beforeCallback. 
                                 Helpful when using callbacks defined on your addon itself, so you can access "self".
                                 
     ...:             (optional) Any additional parameters passed will be sent along to beforeCallback(), 
                                 after the legacySavedVars parameter.
  ]]--
function libSavedVars_Data:Migrate(legacySavedVars, beforeCallback, addon, ...)
    if not self or not self.dataSource then return end
    
    self.dataSource.legacySavedVars = legacySavedVars
    if not legacySavedVars or legacySavedVars.libSavedVarsMigrated then
        return
    end
    
    -- Migrate old settings to new world-specific settings
    if beforeCallback and type(beforeCallback) == "function" then
        beforeCallback(unpack({ addon, legacySavedVars, ... }))
    end
    
    local worldName = GetWorldName()
    local worlds = WORLDS["live"][worldName] and WORLDS["live"] or WORLDS["pts"]
    
    for copyToWorldName, _ in pairs(worlds) do
        local settings
        if copyToWorldName == worldName then
            settings = self.dataSource.defaultAccountSavedVarsActive and self.dataSource.accountSavedVars or self.dataSource.characterSavedVars
        elseif self.dataSource.defaultAccountSavedVarsActive then
            settings = ZO_SavedVars:NewAccountWide(self.dataSource.accountSavedVarsName, 1, nil, self.dataSource.accountDefaults, copyToWorldName)
        end
        if settings then
            libSavedVars:DeepSavedVarsCopy(legacySavedVars, settings)
        end
    end
    libSavedVars:ClearSavedVars(legacySavedVars)
    legacySavedVars.libSavedVarsMigrated = true
end

--[[ 
     Returns an "Account-wide Settings" checkbox control configuration table for a LibAddonMenu-2 panel, 
     localized for English, French, German, Japanese and Russian.
     
     Defaults to the value of self.dataSource.defaultAccountSavedVarsActive.
     
     initializeCharacterWithAccount: if set to true, whenever character-specific settings are toggled on (i.e. the 
                                     account-wide checkbox is toggled off), copy any account-wide settings that are not 
                                     defined in the character-specific saved vars from the account saved vars.
                                     If set to false, toggling to character-specific settings inializes any undefined 
                                     saved vars with default values.
                                     (default: true)
     
     EXAMPLE:
     
     local LibSavedVars = LibStub("LibSavedVars")
     local LAM2         = LibStub("LibAddonMenu-2.0")
     
     addon.settings = LibSavedVars:New(addon.name .. "_Account", addon.name .. "_Character", addon.defaults, false)
     
     -- Setup options panel
     local panelData = {
         type = "panel",
         name = addon.title,
         displayName = addon.title,
         author = addon.author,
         version = addon.version,
         registerForRefresh = true,  -- IMPORTANT! registerForRefresh must be set to true!
         registerForDefaults = true,
     }
     LAM2:RegisterAddonPanel(addon.name .. "Options", panelData)
 
     local optionsTable = { 
     
         -- Account-wide settings
         addon.settings:GetLibAddonMenuAccountCheckbox(),
        
         -- other LAM2 setting options....
        
     }
 
     LAM2:RegisterOptionControls(addon.name .. "Options", optionsTable)
  ]]--

function libSavedVars_Data:GetLibAddonMenuAccountCheckbox(initializeCharacterWithAccount)
    
    if not self or not self.dataSource then return end
    
    if initializeCharacterWithAccount == nil then
        initializeCharacterWithAccount = true
    end
    
    -- Account-wide settings
    return {
        type    = "checkbox",
        name    = GetString(SI_LSV_ACCOUNT_WIDE),
        tooltip = GetString(SI_LSV_ACCOUNT_WIDE_TT),
        getFunc = function() return self:GetAccountSavedVarsActive() end,
        setFunc = function(value) self:SetAccountSavedVarsActive(value, initializeCharacterWithAccount) end,
        default = self.dataSource.defaultAccountSavedVarsActive,
    }
end



---------------------------------------
--
--       Constructor
-- 
---------------------------------------

--[[
     See LibSavedVars.lua => libSavedVars:New() for constructor documentation
  ]]--
local initialize
function libSavedVars_Data:New(...)
    
    -- Create a table with an empty dataSource
    local data = { dataSource = {} }
    
    -- See the Meta Methods section at the bottom for behavior definitions
     setmetatable (data, self )
     
    -- Initialize the object with parameters and return
    initialize(data, ...)

    return data
end
initialize = function(self, accountSavedVarsName, characterSavedVarsName, defaults, defaultAccountSavedVarsActive)
    if not self then return end
    
    if accountSavedVarsName == nil and characterSavedVarsName == nil then
        error("Missing required parameter accountSavedVarsName or characterSavedVarsName.", 2)
    elseif accountSavedVarsName ~= nil and type(accountSavedVarsName) ~= "string" then
        error("Expected data type 'string' for parameter accountSavedVarsName. '"..type(accountSavedVarsName).."' given.", 2)
    elseif characterSavedVarsName ~= nil and type(characterSavedVarsName) ~= "string" then
        error("Expected data type 'string' for parameter characterSavedVarsName. '"..type(characterSavedVarsName).."' given.", 2)
    elseif defaults ~= nil and type(defaults) ~= "table" then
        error("Expected data type 'table' for parameter defaults. '"..type(defaults).."' given.", 2)
    elseif defaultAccountSavedVarsActive ~= nil and type(defaultAccountSavedVarsActive) ~= "boolean" then
        error("Expected data type 'boolean' for parameter defaultAccountSavedVarsActive. '"..type(defaultAccountSavedVarsActive).."' given.", 2)
    end
    defaults = defaults or { }
    
    local worldName = GetWorldName()
    
    if accountSavedVarsName == nil then
        defaultAccountSavedVarsActive = true
    elseif defaultAccountSavedVarsActive == nil then
        --v2 backwards compatibility
        if defaults.useAccountSettings ~= nil then
            defaultAccountSavedVarsActive = defaults.useAccountSettings
        else
            defaultAccountSavedVarsActive = true
        end
    end        
        
    defaults.useAccountSettings = nil -- clear old v2 default
    
    -- Initialize shared dataSource properties
    self.dataSource.accountSavedVarsName          = accountSavedVarsName
    self.dataSource.characterSavedVarsName        = characterSavedVarsName
    self.dataSource.defaultAccountSavedVarsActive = defaultAccountSavedVarsActive
    
    -- Initialize account-wide dataSource properties
    if accountSavedVarsName then
        
        -- Always initialize account-wide saved vars with defaults
        self.dataSource.accountDefaults = defaults
        
        -- Create account-wide saved vars for this server
        self.dataSource.accountSavedVars = ZO_SavedVars:NewAccountWide(
            accountSavedVarsName, 1, nil, self.dataSource.accountDefaults, worldName)
    end
    
    -- Initialize character-specifid dataSource properties
    if characterSavedVarsName then
        
        -- Leave character-specific saved vars empty until enabled if account-wide saved vars are the default
        self.dataSource.characterDefaults = defaultAccountSavedVarsActive and { } or defaults
        
        -- Create character-specific saved vars for the current server and logged in character
        self.dataSource.characterSavedVars = ZO_SavedVars:NewCharacterIdSettings(
            characterSavedVarsName, 1, nil, self.dataSource.characterDefaults, worldName)
        
        -- Library character-specific settings
        if self.dataSource.characterSavedVars[LIBNAME] == nil then
            local libSettings = { }
            
            -- Upgrade from v2 settings
            if self.dataSource.characterSavedVars.useAccountSettings ~= nil then
                libSettings.accountSavedVarsActive = self.dataSource.characterSavedVars.useAccountSettings
                self.dataSource.characterSavedVars.useAccountSettings = nil
            
            -- If no v2 settings exist, use defaultAccountSavedVarsActive
            else
                libSettings.accountSavedVarsActive = defaultAccountSavedVarsActive
            end
            
            self.dataSource.characterSavedVars[LIBNAME] = libSettings
        end
    end
end



-----------------------------------------------------------------------------------
--
--          Meta Methods
--
--          This is where the magic awesomesauce happens that allows 
--          libSavedVars_Data instances to be used with all the same 
--          operators/syntax as the internal ZO_SavedVars instances themselves.
--          
--          Full support included for:
--
--            data[key]          -- Get
--            data.key           -- Get
--            data[key] = value  -- Set
--            data.key = value   -- Set
--            ipairs(data)       -- Looping by numerical index
--            next(data, key)    -- Iterating by key.  Note: will include functions 
--                                  and the dataSource property.
--            pairs(data)        -- Looping by key.  Note: will include functions 
--                                  and the dataSource property.
--
--          Unsupported syntax:
--
--            #data              -- Length/count. There is no support for the
--                                  __len metamethod on tables in Lua 5.1, and no 
--                                  way to rewrite the # operator with a custom one 
--                                  like I do below with next(), pairs() and 
--                                  ipairs() global functions.
--                                  See: http://lua-users.org/wiki/LuaVirtualization
--                                  
--                                  Use data:Count() instead if you need a count
--                                  of how many saved vars are stored.
--
-----------------------------------------------------------------------------------

--[[
     Allows data[key] and data.key to grab their values from the active internal ZO_SavedVars instance for the 
     currently logged in character
  ]]--
function libSavedVars_Data.__index(data, key)
    if not data then return end
    
    -- Get values from saved vars
    local savedVars = libSavedVars_Data.GetActiveSavedVars(data)
    if savedVars then
        local value = savedVars[key]
        if value ~= nil then
            return value
        end
    end
    
    -- Enable metatable fallback
    local meta = getmetatable(data)
    return meta and meta[key]
end

--[[
     Allows iterating through the active internal ZO_SavedVars instance for the currently logged in character with the
     ipairs() table iterator method.
  ]]--
function libSavedVars_Data.__ipairs(data)
    if not data then return end
    
    local savedVars = libSavedVars_Data.GetActiveSavedVars(data)
    if savedVars then
        local rawDataTable = libSavedVars:GetRawDataTable(savedVars)
        return ipairs(rawDataTable)
    end
end

--[[
     Allows data[key] = value and data.key = value to set values on the active internal ZO_SavedVars instance for the 
     currently logged in character
  ]]--
function libSavedVars_Data.__newindex(data, key, value)
    if not data then return end
    
    local savedVars = libSavedVars_Data.GetActiveSavedVars(data)
    if savedVars then
        savedVars[key] = value
    end
end

--[[
     Allows iterating through the active internal ZO_SavedVars instance for the currently logged in character with the
     pairs() table iterator method.
  ]]--
function libSavedVars_Data.__pairs(data)
    if not data then return end
    local savedVars = libSavedVars_Data.GetActiveSavedVars(data)
    if not savedVars then return end
    local rawDataTable = libSavedVars:GetRawDataTable(savedVars)
    return libSavedVars_Data.GetIterator(data), rawDataTable, nil
end



---------------------------------------
--
--       Global Overrides
-- 
---------------------------------------

--[[
     Override the lua ipairs() function to look for an __ipairs meta method for iteration, just like Lua 5.2.
  ]]--
local rawipairs = ipairs
function ipairs(tableToIterate)
    local meta = getmetatable(tableToIterate)
    local iterator = meta and meta.__ipairs or rawipairs
    return iterator(tableToIterate)
end

--[[
     Override the lua pairs() function to look for a __pairs meta method for iteration, just like Lua 5.2.
  ]]--
local rawpairs = pairs
function pairs(tableToIterate)
    local meta = getmetatable(tableToIterate)
    local iterator = meta and meta.__pairs or rawpairs
    return iterator(tableToIterate)
end

--[[
     Override the lua next() function to look for a __pairs meta method for iteration, just like Lua 5.2.
  ]]--
function next(tableToIterate, key)
    local handler, modifiedTable = pairs(tableToIterate)
    if handler ~= nil and modifiedTable ~= nil then
        return handler(modifiedTable, key)
    end
end