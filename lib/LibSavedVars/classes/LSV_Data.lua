--[[
     LibSavedVars data storage class.
     
     LSV_Data:NewAccountWide()
     LSV_Data:NewCharacterSettings()
  ]]--

local LIBNAME      = "LibSavedVars"
local CLASSNAME    = "Data"
local CLASSVERSION = 1.2
local libSavedVars = LibStub(LIBNAME)

-- If a newer version of this class is already loaded, exit
local class, protected = libSavedVars:NewClass(CLASSNAME, CLASSVERSION)
if not class then return end

LSV_Data = class

-- Used for readability
local DO_NOT_OVERWRITE = true

-- Toggle on to only print debug messages for this class
local debugMode = false

-- Private member declarations.  Definitions are at the end of the file.
local defaultIterator, initAccountWide, initCharacterSettings, initToggle, onToggleLazyLoaded, shiftOptionalParams, 
      tableDiffKeys, tableFilterKeys, tableMerge, validateScope

-- Lua 5.1 versions of next() and ipairs()
local rawnext = LibLua52 and LibLua52.rawnext or next
local rawipairs = LibLua52 and LibLua52.rawipairs or ipairs



---------------------------------------
--
--       Constructors
-- 
---------------------------------------

--[[
     Creates a new data object with account-wide saved vars as the default.  You can add a character-specific saved vars
     toggle by chaining :AddCharacterSettingsToggle() below.  
     
     You can also chain with several other methods, such as :Migrate(), :RemoveSettings(), :RenameSettings() and 
     :Version(). See the Public Methods section below for details.
     
     savedVariableTableName:  The name of the top-level global table containing the saved vars. Required. 
                              Matches the name in ## SavedVariables: in the manifest text file.
     
     version:                 (optional) The numeric current saved vars version. Defaults to 1.
                                         WARNING! Incrementing this value without adding a chained :Version() call after
                                         for the new version number will cause all settings to be reset to defaults.
     
     namespace:               (optional) An string namespace to separate other variables using the same table.
     
     defaults:                (optional) A table describing the default saved variables.
     
     profile:                 (optional) String used to group several saved vars tables together as a unit.  
                                         Usually either nil, "Default" or the megaserver name 
                                         (i.e. "NA Megaserver", "EU Megaserver", "PTS"). Defaults to megaserver name.
                                         
     displayName:             (optional) The account name the saved vars are for. Defaults to the current account name.
  ]]--
function LSV_Data:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName)
    
    local _
    version, namespace, defaults, _, profile, displayName = 
        shiftOptionalParams(version, namespace, defaults, nil, profile, displayName)
    
    protected.Debug("LSV_Data:NewAccountWide(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>)", debugMode, 
        savedVariableTable, version, namespace, defaults, profile, displayName)
    
    local data = { 
        __dataSource = { defaultToAccount = true }
    }
    setmetatable(data, self)
    
    initAccountWide(data, savedVariableTable, version, namespace, defaults, profile, displayName)

    return data
end

--[[
     Creates a new data object with character-specific saved vars as the default.  You can add an account-wide saved 
     vars toggle by chaining :AddAccountWideToggle() below.  
     
     You can also chain with several other methods, such as :Migrate(), :RemoveSettings(), :RenameSettings() and 
     :Version(). See the Public Methods section below for details.
     
     savedVariableTableName:  The name of the top-level global table containing the saved vars. Required. 
                              Matches the name in ## SavedVariables: in the manifest text file.
     
     version:                 (optional) The numeric current saved vars version. Defaults to 1.
                                         WARNING! Incrementing this value without adding a chained :Version() call after
                                         for the new version number will cause all settings to be reset to defaults.
     
     namespace:               (optional) An string namespace to separate other variables using the same table.
     
     defaults:                (optional) A table describing the default saved variables.
     
     profile:                 (optional) String used to group several saved vars tables together as a unit.  
                                         Usually either nil, "Default" or the megaserver name 
                                         (i.e. "NA Megaserver", "EU Megaserver", "PTS"). Defaults to megaserver name.
                                         
     displayName:             (optional) The account name the saved vars are for. Defaults to the current account name.
     
     
     characterName:           (optional) The character name the saved vars belong to.  Defaults to the current character.
     
     characterId:             (optional) The character id the saved vars belong to.  Defaults to the current character id.
  ]]--
function LSV_Data:NewCharacterSettings(savedVariableTable, version, namespace, defaults, profile, displayName, 
                                       characterName, characterId, characterKeyType)
    
    local _
    version, namespace, defaults, _, profile, displayName, characterName, characterId, characterKeyType = 
        shiftOptionalParams(version, namespace, defaults, nil, profile, displayName, characterName, characterId, characterKeyType)
    
    protected.Debug("LSV_Data:NewCharacterSettings(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>, <<7>>, <<8>>, <<9>>)", 
        debugMode, savedVariableTable, version, namespace, defaults, profile, displayName, 
        characterName, characterId, characterKeyType)
    
    local data = { 
        __dataSource = { defaultToAccount = false } 
    }
    setmetatable(data, self)
    
    initCharacterSettings(data, savedVariableTable, version, namespace, defaults, profile, displayName, 
                          characterName, characterId, characterKeyType)

    return data
end



---------------------------------------
--
--          Public Methods
-- 
---------------------------------------

--[[
     Used to add an account-wide saved vars scope to an existing character-specific scope that can then be toggled
     back and forth at runtime, automatically switching the behavior of reading and writing settings on this instance.
     
     See the NewAccountWide() constructor above for parameter descriptions.
  ]]--
function LSV_Data:AddAccountWideToggle(savedVariableTableName, version, namespace, defaults, profile, displayName)
    if not self then
        return
    end
    
    protected.Debug("LSV_Data:AddAccountWideToggle(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>)", debugMode, 
        savedVariableTableName, version, namespace, defaults, profile, displayName)
    
    local _
    version, namespace, defaults, _, profile, displayName = 
        shiftOptionalParams(version, namespace, defaults, nil, profile, displayName)
    
    local ds = self.__dataSource
    
    if savedVariableTableName == nil then
        savedVariableTableName = ds.character.name
    end
    
    if defaults == nil then
        defaults = ds.character.defaults
    else
        ds.pinnedAccountKeys = tableDiffKeys(defaults, ds.character.defaults)
        defaults             = tableMerge(defaults, ds.character.defaults)
    end
    
    if profile == nil then
        profile = ds.character.profile
    end
    
    if displayName == nil then
        displayName = ds.character.displayName
    end
    
    initAccountWide(self, savedVariableTableName, version, namespace, defaults, profile, displayName)
    initToggle(self)
    
    return self
end

--[[
     Used to add an character-specific saved vars scope to an existing account-wide scope that can then be toggled
     back and forth at runtime, automatically switching the behavior of reading and writing settings on this instance.
     
     See the NewCharacterSettings() constructor above for parameter descriptions.
  ]]--
function LSV_Data:AddCharacterSettingsToggle(savedVariableTableName, version, namespace, defaults, profile, 
                                             displayName, characterName, characterId, characterKeyType)
    if not self then
        return
    end
    
    local _
    version, namespace, defaults, _, profile, displayName, characterName, characterId, characterKeyType = 
        shiftOptionalParams(version, namespace, defaults, nil, profile, displayName, characterName, characterId, characterKeyType)
    
    protected.Debug("LSV_Data:AddCharacterSettingsToggle(<<1>>, <<2>>, <<3>>, <<4>>, <<5>>, <<6>>, <<7>>, <<8>>, <<9>>)", 
        debugMode, savedVariableTableName, version, namespace, defaults, profile, displayName, 
        characterName, characterId, characterKeyType)
    
    local ds = self.__dataSource
    
    if savedVariableTableName == nil then
        savedVariableTableName = ds.account.name
    end
    
    if defaults == nil then
        defaults = { }
    else
        ds.pinnedAccountKeys = tableDiffKeys(ds.account.defaults, defaults)
        local defaultsNotOnAccount = tableDiffKeys(defaults, ds.account.defaults)
        if next(defaultsNotOnAccount) ~= nil then
            ds.account.defaults = tableMerge(ds.account.defaults, defaultsNotOnAccount)
        end
    end
    
    if profile == nil then
        profile = ds.account.profile
    end
    
    if displayName == nil then
        displayName = ds.account.displayName
    end
    
    initCharacterSettings(self, savedVariableTableName, version, namespace, defaults, profile, displayName, 
                          characterName, characterId, characterKeyType)
    initToggle(self)
    
    return self
end

--[[ 
     Returns true if account-wide saved vars are currently toggled on.  When no character-specific settings have been
     specified, always returns true.
  ]]--
function LSV_Data:GetAccountSavedVarsActive()
    if not self then return end
    protected.Debug("LSV_Data:GetAccountSavedVarsActive()", debugMode)
    local ds = rawget(self, "__dataSource")
    
    if ds.active then
        return ds.active == ds.account
    else
        return ds.account ~= nil
    end
end

--[[ 
     Returns the internal ZO_SavedVars instance that is active for the currently logged in character.
     
     Usage note: if no settings have yet been accessed with getters or setters, calling this method will cause an 
     underlying call to ZO_SavedVars:NewCharacterIdSettings() or ZO_SavedVars:NewAccountWide().
  ]]--
function LSV_Data:GetActiveSavedVars(key)
    if not self then return end
    protected.Debug("LSV_Data:GetActiveSavedVars(<<1>>)", debugMode, key)
    
    local ds = rawget(self, "__dataSource")
    
    -- Get account pinned vars
    if key ~= nil and ds.account and ds.pinnedAccountKeys and ds.pinnedAccountKeys[key] ~= nil then
        return ds.account.savedVars
    end
    
    return ds.active and ds.active.savedVars or nil
end

--[[
     Returns a function like next() used to iterate over the active ZO_SavedVar instance for the currently logged in 
     character.  If account-wide vars are not active, then any pinned account-wide vars are prepended.
     Appends "__dataSource" as the last key/value pair, to provide access to the internal table containing
     configuration info and references to account and character saved vars managers.
  ]]--
local emptyObject = setmetatable({ __dataSource = {} }, LSV_Data)
function LSV_Data:GetIterator()
    protected.Debug("LSV_Data:GetIterator()", debugMode)
    if not self then return rawnext, emptyObject end
    local ds = rawget(self, "__dataSource")
    if not ds then return rawnext, emptyObject end
    
    if ds.iterator then return ds.iterator, self end
    
    local subTables = {}
    local pinnedKeys = ds.pinnedAccountKeys
    if pinnedKeys and rawnext(pinnedKeys) == nil or LSV_Data.GetAccountSavedVarsActive(self) then
        pinnedKeys = nil
    end
    if pinnedKeys then
        local accountRawDataTable = ds.account and ds.account:LoadRawTableData()
        if accountRawDataTable then
            local pinnedSettings = tableFilterKeys(accountRawDataTable, pinnedKeys)
            table.insert(subTables, pinnedSettings)
        end
    end
    
    local savedVars = LSV_Data.GetActiveSavedVars(self)
    local rawDataTable = savedVars and libSavedVars:GetRawDataTable(savedVars)
    if rawDataTable then
        table.insert(subTables, rawDataTable)
    end
    
    table.insert(subTables, { __dataSource = ds })
    protected.Debug("subTables: <<1>>, #subTables: <<2>>", debugMode, tostring(subTables), #subTables)
    
    local subTableIndex, subTable = 1, subTables[1]
    return
        function(_, key)
            if key == nil then
                subTableIndex, subTable = 1, subTables[1]
            end
            local value
            repeat
                protected.Debug("subtableIndex: <<1>>, subTable: <<2>>, key: <<3>>", debugMode, 
                                subTableIndex, tostring(subTable), key)
                key, value = rawnext(subTable, key)
                if key == nil then
                    subTableIndex, subTable = subTableIndex + 1, subTables[subTableIndex + 1]
                end
            until key ~= nil or not subTable
            protected.Debug("key: <<1>>, value: <<2>>", debugMode, key, value)
            if not subTable then
                ds.iterator = nil
            end
            return key, value
        end, 
        self
end

--[[
     Works like the # operator.  Gets the number of saved vars stored in the active internal ZO_SavedVars instance for 
     the currently logged in character.  The same caveats as # apply, i.e. it is not reliable except for tables 
     stored as a numerically indexed array beginning with index 1 and having no gaps.
     Provided as a separate method, because overriding the # operator is not supported in Lua 5.1.
  ]]--
function LSV_Data:GetLength()
    if not self then return 0 end
    protected.Debug("LSV_Data:GetLength()", debugMode)
    
    local accountActive = LSV_Data:GetAccountSavedVarsActive()
    if accountActive then
        if not self.account then return 0 end
        return #self.account:LoadRawTableData()
    end
    
    local rawCharacterDataTable = self.character:LoadRawTableData()
    if not self.pinnedAccountKeys then
        return #rawCharacterDataTable
    end
    
    -- Length is only valid on contiguous numeric keys.
    -- If the pinned keys and nonpinned keys form such a sequence, then the # operator is not trustworthy for the 
    -- individual pieces.  We calculate length directly here.
    
    local i = 1
    while self.pinnedAccountKeys[i] ~= nil 
          or rawCharacterDataTable[i] ~= nil
    do
        i = i + 1
    end
    return i - 1
end


--[[ 
     Returns an "Account-wide Settings" checkbox control configuration table for a LibAddonMenu-2 panel, 
     localized for English, French, German, Japanese and Russian.
     
     Defaults to the value of self.__dataSource.defaultToAccount.
     
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

function LSV_Data:GetLibAddonMenuAccountCheckbox(initializeCharacterWithAccount)
    
    if not self then return end
    protected.Debug("LSV_Data:GetLibAddonMenuAccountCheckbox(<<1>>)", debugMode, initializeCharacterWithAccount)
    
    if initializeCharacterWithAccount == nil then
        initializeCharacterWithAccount = true
    end
    
    -- Account-wide settings
    return {
        type    = "checkbox",
        name    = GetString(SI_LSV_ACCOUNT_WIDE),
        tooltip = GetString(SI_LSV_ACCOUNT_WIDE_TT),
        getFunc = function() 
                      self:LoadAllSavedVars()
                      return self:GetAccountSavedVarsActive()
                  end,
        setFunc = function(value) 
                      self:LoadAllSavedVars()
                      self:SetAccountSavedVarsActive(value, initializeCharacterWithAccount)
                  end,
        default = self.__dataSource.defaultToAccount,
    }
end

--[[
     Gets a table containing all underlying LSV_SavedVarsManager instances for the given scope.
     
     scope: LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. Defaults to '*'.
  ]]--
function LSV_Data:GetSavedVarsManagers(scope)
    protected.Debug("LSV_Data:GetSavedVarsManagers(<<1>>)", debugMode, scope)
    local wildcard = not scope or scope == "*"
    validateScope(scope)
    local ds = self.__dataSource
    local savedVarManagers = { 
        (wildcard or scope == "character") and ds.character or nil,
        (wildcard or scope == "account") and ds.account or nil
    }
    protected.Debug("<<1>> saved var managers found", debugMode, #savedVarManagers)
    return savedVarManagers
end

--[[
     Forces the loading of all underlying ZO_SavedVars instances instead of waiting for them to be lazy-loaded.
  ]]--
function LSV_Data:LoadAllSavedVars()
    if not self then return end
    protected.Debug("LSV_Data:LoadAllSavedVars()", debugMode)
    local ds = self.__dataSource
    -- Lazy load character saved vars
    if ds.character and ds.character.savedVars then end
    -- Lazy load account saved vars
    if ds.account and ds.account.savedVars then end
    
    return self
end

--[[
     Moves a legacy saved var with the specified info to one or more new saved vars with their own specified info.
     
     Can be chained with other transformations like :Version(), :RemoveSettings() and :RenameSettings().
     
     See LibSavedVars.lua => libSavedVars:Migrate() for full documentation, since this method works the same, just 
     without the toSavedVarsInfo parameters.
  ]]--
function LSV_Data:MigrateFrom(fromSavedVarsInfo, copyToAllServers)

    if not fromSavedVarsInfo.keyType then
        fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_NAME_KEY
    end
    
    protected.Debug("LSV_Data:MigrateFrom(<<1>> (<<2>>), <<3>>)", debugMode, 
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    
    local from
    local ds = self.__dataSource
    if ds.account then
        protected.Debug("ds.account block entered")
        if copyToAllServers == nil then
            copyToAllServers = ds.account:IsProfileWorldName()
        end
        local profile = ds.account.profile
        local to
        to, from = 
            protected.MigrateToMegaserverProfiles(
                nil,
                fromSavedVarsInfo, 
                copyToAllServers,
                ds.account
            )
        if to then
            protected.Debug("Saving account saved var manager for profile " .. tostring(profile) .. " as " 
                            .. tostring(to[profile]), debugMode)
            ds.account = to[profile]
        else
            protected.Debug("toSavedVars was nil", debugMode)
        end
    end
    
    if ds.character 
       and (fromSavedVarsInfo.keyType ~= LIBSAVEDVARS_ACCOUNT_KEY
            or not ds.defaultToAccount)
    then
        protected.Debug("ds.character block entered")
        local profile = ds.character.profile
        local to
        to, from = 
            protected.MigrateToMegaserverProfiles(
                nil,
                fromSavedVarsInfo, 
                nil,
                ds.character
            )
        if to then
            protected.Debug("Saving character saved var manager as "..tostring(to[profile]), debugMode)
            ds.character = to[profile]
        else
            protected.Debug("toSavedVars was nil", debugMode)
        end
    end
    
    protected.Debug("Unsetting from raw saved vars path", debugMode)
    
    -- Remove the source saved var and any empty parent containers
    protected.UnsetPath(from.table, unpack(from.rawSavedVarsTablePath))
    
    protected.Debug("Migration complete.", debugMode)
    
    return self
end

--[[ 
     Same as MigrateFrom, but with a default keyType set to LIBSAVEDVARS_ACCOUNT_KEY.
  ]]--
function LSV_Data:MigrateFromAccountWide(fromSavedVarsInfo, copyToAllServers)
    protected.Debug("LSV_Data:MigrateFromAccountWide(<<1>> (<<2>>), <<3>>)", debugMode, 
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_ACCOUNT_KEY
    return self:MigrateFrom(fromSavedVarsInfo, copyToAllServers)
end

--[[ 
     Same as MigrateFrom, but with a default keyType set to LIBSAVEDVARS_CHARACTER_ID_KEY.
  ]]--
function LSV_Data:MigrateFromCharacterId(fromSavedVarsInfo, copyToAllServers)
    protected.Debug("LSV_Data:MigrateFromCharacterId(<<1>> (<<2>>), <<3>>)", debugMode, 
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_ID_KEY
    return self:MigrateFrom(fromSavedVarsInfo, copyToAllServers)
end

--[[ 
     Same as MigrateFrom, but with a default keyType set to LIBSAVEDVARS_CHARACTER_ID_NAME.
  ]]--
function LSV_Data:MigrateFromCharacterName(fromSavedVarsInfo, copyToAllServers)
    protected.Debug("LSV_Data:MigrateFromCharacterName(<<1>> (<<2>>), <<3>>)", debugMode, 
                    fromSavedVarsInfo, fromSavedVarsInfo and #fromSavedVarsInfo or nil, copyToAllServers)
    fromSavedVarsInfo.keyType = LIBSAVEDVARS_CHARACTER_NAME_KEY
    return self:MigrateFrom(fromSavedVarsInfo, copyToAllServers)
end

--[[
     Removes a list of settings from all saved vars tracked by this data instance of a given scope
     when upgrading to the given version number.  Has no effect on saved vars at or above the given version.
     
     version:          Settings are only removed from saved vars below this version number.
     
     scope:            (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                                  Defaults to '*'.
     
     settingsToRemove: Either a table containing a list of string setting names to remove, or a single string 
                       setting name.  If a string is given, then additional strings can be provided as extra parameters.
  ]]--
function LSV_Data:RemoveSettings(version, scope, settingsToRemove, ...)
    
    assert(type(version) == "number", 
           "Invalid type for argument 'version'. Expected 'number'. Got '" .. type(version) .. "' instead.")
    local params = {...}
    if scope ~= nil and type(scope) ~= "number" then
        table.insert(params, 1, settingsToRemove)
        settingsToRemove = scope
        scope = nil
    end
    if type(settingsToRemove) == "string" then
        table.insert(params, 1, settingsToRemove)
        settingsToRemove = params
    end
        
    protected.Debug("LSV_Data:RemoveSettings(<<1>>, <<2>>, <<3>> (<<4>>))", debugMode, 
                    version, scope, tostring(settingsToRemove), settingsToRemove and #settingsToRemove or nil)
    validateScope(scope)
    local svManagers = self:GetSavedVarsManagers(scope)
    for _, svManager in rawipairs(svManagers) do
        svManager:RemoveSettings(version, settingsToRemove)
    end
    
    return self
end

--[[
     Changes the names of a list of settings in all saved vars tracked by this data instance of a given scope
     when upgrading to the given version number.  Has no effect on saved vars at or above the given version.
     
     version:   Settings are only renamed on saved vars below this version number.
     
     scope:     (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                           Defaults to '*'.
     
     renameMap: A key-value table containing a mapping of old setting names (keys) to new setting names (values).
     
     callback:   (optional) A function to be called on saved vars values right before they are renamed. 
                           Used by RenameSettingsAndInvert().
  ]]--
function LSV_Data:RenameSettings(version, scope, renameMap, callback)
    
    if scope ~= nil and type(scope) ~= "number" then
        callback = renameMap
        renameMap = scope
        scope = nil
    end
    protected.Debug("LSV_Data:RenameSettings(<<1>>, <<2>>, <<3>>, <<4>>)", debugMode, 
                    version, scope, tostring(renameMap), tostring(callback))
    validateScope(scope)
    local svManagers = self:GetSavedVarsManagers(scope)
    for _, svManager in rawipairs(svManagers) do
        svManager:RenameSettings(version, renameMap, callback)
    end
    
    return self
end

--[[
     Changes the names of a list of boolean settings and inverts them in all saved vars tracked by this data instance of 
     a given scope when upgrading to the given version number.  Has no effect on saved vars at or above the given version.
     
     version:   Settings are only renamed on saved vars below this version number.
     
     scope:     (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                           Defaults to '*'.
     
     renameMap: A key-value table containing a mapping of old setting names (keys) to new setting names (values).
  ]]--
function LSV_Data:RenameSettingsAndInvert(version, scope, renameMap)
    protected.Debug("LSV_Data:RenameSettingsAndInvert(<<1>>, <<2>>, <<3>>)", debugMode, 
                    version, scope, tostring(renameMap))
    return self:RenameSettings(version, scope, renameMap, protected.Invert)
end

--[[
     Toggles whether account-wide settings or character-specific settings are active.
     
     accountActive:                  True to user account-wide settings for the current character; 
                                     false to use character-specific settings
                                     
     initializeCharacterWithAccount: If set to true and accountActive is false, copy any account-wide settings that are 
                                     not defined in the character-specific saved vars from the account saved vars
  ]]--
function LSV_Data:SetAccountSavedVarsActive(accountActive, initializeCharacterWithAccount)
    
    if not self then return end
    protected.Debug("LSV_Data:SetAccountSavedVarsActive(<<1>>, <<2>>)", debugMode, 
                    accountActive, initializeCharacterWithAccount)
    
    local ds = self.__dataSource
    
    if not ds.character 
       or not ds.account
       or not ds.character.savedVars[LIBNAME] 
    then 
        return self
    end
        
    ds.character.savedVars[LIBNAME].accountSavedVarsActive = accountActive
    
    initializeCharacterWithAccount = initializeCharacterWithAccount or ds.defaultToAccount
    
    if accountActive then
        ds.active = ds.account
        return self
    end
    
    ds.active = ds.character
    
    local characterRawDataTable = ds.character:LoadRawTableData()
    
    if initializeCharacterWithAccount and ds.account.savedVars then
        
        local accountVars = ds.account:LoadRawTableData()
        if ds.pinnedAccountKeys then
            accountVars = tableDiffKeys(accountVars, ds.pinnedAccountKeys)
        end
        
        protected.Debug("Copying the following settings from account-wide scope to character settings:", debugMode)
        for key, value in pairs(accountVars) do
            protected.Debug("<<1>>: <<2>>", debugMode, key, tostring(value))
        end
        
        libSavedVars:DeepSavedVarsCopy(accountVars, characterRawDataTable, DO_NOT_OVERWRITE)
    else
        libSavedVars:DeepSavedVarsCopy(ds.character.defaults, characterRawDataTable, DO_NOT_OVERWRITE)
    end
    
    return self
end

--[[
     Toggles whether to output LSV_Data debug messages to chat at runtime.
     
     enable: True enables debug messages for LSV_Data.  False disables them.
  ]]--
function LSV_Data:SetDebugMode(enable)
    debugMode = enable
end

--[[
     Upgrades all saved vars tracked by this data instance of a given scope to the given version number.  
     Has no effect on saved vars at or above the given version.
     
     version:         Settings are only upgraded on saved vars below this version number.
     
     scope:           (optional) LIBSAVEDVARS_SCOPE_CHARACTER, LIBSAVEDVARS_SCOPE_ACCOUNT or '*' for all scopes. 
                                 Defaults to '*'.
     
     onVersionUpdate: Upgrade script function with the signature function(rawDataTable) end to be run before updating
                      saved vars version.  You can run any settings transforms in here.
  ]]--
function LSV_Data:Version(version, scope, onVersionUpdate)
    
    if type(scope) == "function" then
        onVersionUpdate = scope
        scope = nil
    end
    protected.Debug("LSV_Data:Version(<<1>>, <<2>>, <<3>>)", debugMode, version, scope, onVersionUpdate)
    validateScope(scope)
    local svManagers = self:GetSavedVarsManagers(scope)
    for _, svManager in rawipairs(svManagers) do
        svManager:Version(version, onVersionUpdate)
    end
    
    return self
end



-----------------------------------------------------------------------------------
--
--          Meta Methods
--
--          This is where the magic awesomesauce happens that allows 
--          LSV_Data instances to be used with all the same 
--          operators/syntax as the internal ZO_SavedVars instances themselves.
--          
--          Full support included for:
--
--            data[key]          -- Get
--            data.key           -- Get
--            data[key] = value  -- Set
--            data.key = value   -- Set
--           
--          The following require LibLua5.2:
--            ipairs(data)       -- Looping by numerical index.

--            next(data, key)    -- Iterating by key.  Note: will include functions 
--                                  and the __dataSource property.
--            pairs(data)        -- Looping by key.  Note: will include functions 
--                                  and the __dataSource property.
--
--          Unsupported syntax:
--
--            #data              -- Length/count. There is no support for the
--                                  __len metamethod on tables in Lua 5.1, and no 
--                                  way to rewrite the # operator with a custom one 
--                                  like is done with __ipairs and __pairs in LibLua5.2.
--                                  See: http://lua-users.org/wiki/LuaVirtualization
--                                  
--                                  Use data:GetLength() instead if you need a count
--                                  of how many saved vars are stored.
--
-----------------------------------------------------------------------------------

--[[
     Allows data[key] and data.key to grab their values from the active internal ZO_SavedVars instance for the 
     currently logged in character
  ]]--
function LSV_Data.__index(data, key)
    
    protected.Debug("LSV_Data.__index(<<1>>, <<2>>)", debugMode, data, key)
    
    if not data then return end
    
    -- Always use metatable for function lookups, to avoid lazy loading saved vars earlier than needed
    local meta = getmetatable(data)
    if meta and type(meta[key]) == "function" then
        return meta[key]
    end
    
    -- Get toggleable values from active saved vars
    local savedVars = LSV_Data.GetActiveSavedVars(data, key)
    if savedVars then
        local value = savedVars[key]
        if value ~= nil then
            return value
        end
    end
    
    -- Metatable fallback for non-function values
    if meta then
        return meta[key]
    end
end

--[[
     Allows iterating through the active internal ZO_SavedVars instance for the currently logged in character with the
     ipairs() table iterator method.
     Requires LibLua5.2 to work.
  ]]--
if LibLua52 then
    function LSV_Data.__ipairs(data)
        
        protected.Debug("LSV_Data.__ipairs(<<1>>, <<2>>)", debugMode, data)
        
        if not data then return end
        
        local savedVars = LSV_Data.GetActiveSavedVars(data)
        if savedVars then
            local rawDataTable = libSavedVars:GetRawDataTable(savedVars)
            return ipairs(rawDataTable)
        end
    end
end

--[[
     Allows data[key] = value and data.key = value to set values on the active internal ZO_SavedVars instance for the 
     currently logged in character
  ]]--
function LSV_Data.__newindex(data, key, value)
    
    protected.Debug("LSV_Data.__newindex(<<1>>, <<2>>, <<3>>)", debugMode, data, key, value)
    
    if not data then return end
    
    local savedVars = LSV_Data.GetActiveSavedVars(data, key)
    if savedVars then
        savedVars[key] = value
    end
end

--[[
     Allows iterating through the active internal ZO_SavedVars instance for the currently logged in character with the
     pairs() table iterator method.
     Requires LibLua5.2 to work.
  ]]--
if LibLua52 then
    function LSV_Data.__pairs(data)
        
        protected.Debug("LSV_Data.__pairs(<<1>>)", debugMode, data)
        
        local iterator
        iterator, data = LSV_Data.GetIterator(data)
        return iterator, data, nil
    end
end



----------------------------------------------------------------------------
--
--       Deprecated methods
--
--       The following methods will be removed in a future version.
--       Please migrate to the new methods above and those in LibSavedVars.lua
-- 
----------------------------------------------------------------------------

--[[
     v3 style all-in-one constructor.  
     Replaced with NewAccountWide(), NewCharacterSettings(), AddAccountWideToggle() and AddCharacterSettingsToggle().
  ]]--
function LSV_Data:New(accountSavedVarsName, characterSavedVarsName, version, namespace, defaults, 
                      defaultToAccount, profile, displayName, characterName, characterId, characterKeyType)
    
    if accountSavedVarsName == nil and characterSavedVarsName == nil then
        error("Missing required parameter accountSavedVarsName or characterSavedVarsName.", 2)
    elseif accountSavedVarsName ~= nil and type(accountSavedVarsName) ~= "string" then
        error("Expected data type 'string' for parameter accountSavedVarsName. '"..type(accountSavedVarsName).."' given.", 2)
    elseif characterSavedVarsName ~= nil and type(characterSavedVarsName) ~= "string" then
        error("Expected data type 'string' for parameter characterSavedVarsName. '"..type(characterSavedVarsName).."' given.", 2)
    end
    
    version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId, characterKeyType = 
        shiftOptionalParams(version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId, characterKeyType)
    
    if accountSavedVarsName == nil then
        defaultToAccount = nil
    elseif defaultToAccount == nil then
        --v2 backwards compatibility
        if defaults.useAccountSettings ~= nil then
            defaultToAccount = defaults.useAccountSettings
        else
            defaultToAccount = true
        end
    end        
        
    defaults.useAccountSettings = nil -- clear old v2 default
    
    local data
    if accountSavedVarsName and defaultToAccount then
        data = self:NewAccountWide(accountSavedVarsName, version, namespace, defaults, profile, displayName)
    elseif characterSavedVarsName and not defaultToAccount then
        data = self:NewCharacterSettings(characterSavedVarsName, version, namespace, defaults, profile, displayName, 
                                         characterName, characterId, characterKeyType)
    end
    
    if accountSavedVarsName and not defaultToAccount then
        data:AddAccountWideToggle(accountSavedVarsName, version, namespace, defaults, profile, displayName)
    elseif characterSavedVarsName and defaultToAccount then
        data:AddCharacterSettingsToggle(characterSavedVarsName, version, namespace, defaults, profile, displayName, 
                                        characterName, characterId, characterKeyType)
    end
    
    return data
end

--[[
     **DEPRECATED**
     See LibSavedVars.lua 
         => libSavedVars:Migrate()
         => libSavedVars:MigrateAccountWide
         => libSavedVars:MigrateCharacterId()
         => libSavedVars:MigrateCharacterName()
         => libSavedVars:MigrateCharacterNameToId() 
         => libSavedVars:MigrateToMegaserverProfiles()
         
     See classes/LSV_SavedVarsManager.lua 
         => LSV_SavedVarsManager:RegisterMigrateStartCallback() 
         => LSV_SavedVarsManager:UnregisterMigrateStartCallback()

     Moves saved var values from an old legacy saved vars instance into a new saved vars instance or list of instances.
     
     Once migrated, the old legacy saved vars are cleared, and a new var called LibSavedVars.migrated is set to true.
     Successived calls to this method will not migrate again if legacySavedVars.LibSavedVars.migrated is true.
     
     legacySavedVars: The ZO_SavedVars instance to migrate to the new savedvars structure in this instance.
     
     newSavedVars:    (optional) A ZO_SavedVars instance or array of instances to migrate the legacy saved vars to.
                                 If nil or not specified, the following logic is used to determine the list:
                                 
                                 If self.__dataSource.defaultToAccount is true, then the values are copied to
                                 account-wide saved vars for both  NA and EU if on live, or just PTS if on PTS.
                                 
                                 If self.__dataSource.defaultToAccount is NOT true, then the values are 
                                 copied to character-specific settings on only the current server.
     
     beforeCallback:  (optional) If specified, raised right before data is copied, so that any transformations can be
                                 run on the old saved vars table before its values are moved.
                                 Valid signatures include function(addon, legacySavedVars, ...), if addon is not nil,
                                 or function(legacySavedVars, ...) if addon is nil.
                                 
     addon:           (optional) If not nil, will be passed as the first parameter to beforeCallback. 
                                 Helpful when using callbacks defined on your addon itself, so you can access "self".
                                 
     ...:             (optional) Any additional parameters passed will be sent along to beforeCallback(), 
                                 after the legacySavedVars parameter.
  ]]--
function LSV_Data:Migrate(legacySavedVars, newSavedVars, beforeCallback, addon, ...)
    
    if not legacySavedVars then
        return
    end
    
    -- Since newSavedVars is optional, detect if it was omitted entirely instead of being passed as nil
    if type(newSavedVars) == "function" then
        self:Migrate(legacySavedVars, nil, newSavedVars, beforeCallback, addon, ...)
        return
    end
    
    local fromSavedVarsInfo = libSavedVars:GetInfo(legacySavedVars)
    legacySavedVars = libSavedVars:GetRawDataTable(legacySavedVars)
    
    if legacySavedVars and legacySavedVars.libSavedVarsMigrated then
        legacySavedVars[LIBNAME] = legacySavedVars[LIBNAME] or { }
        legacySavedVars[LIBNAME].migrated = true
        legacySavedVars.libSavedVarsMigrated = nil
    end
    if (legacySavedVars[LIBNAME] and legacySavedVars[LIBNAME].migrated) then
        return
    end
    
    if newSavedVars then
        if libSavedVars:IsZOSavedVars(newSavedVars) then
            newSavedVars = { newSavedVars }
        end
    elseif self.__dataSource.account and self.__dataSource.defaultToAccount then
          newSavedVars = self.__dataSource.account
      else
          newSavedVars = self.__dataSource.character
      end
    
    local from = LSV_SavedVarsManager:New(fromSavedVarsInfo)
    
    if beforeCallback and type(beforeCallback) == "function" then
        from:RegisterMigrateStartCallback(beforeCallback, addon, ...)
    end
    
    if not protected.MigrateToMegaserverProfiles(nil, from, true, newSavedVars) then
        return
    end
    
    libSavedVars:ClearSavedVars(legacySavedVars)
    legacySavedVars[LIBNAME] = legacySavedVars[LIBNAME] or {}
    legacySavedVars[LIBNAME].migrated = true
end


---------------------------------------
--
--          Private Members
-- 
---------------------------------------

defaultIterator = LSV_Data.GetIterator(emptyObject)

function initAccountWide(self, savedVariableTable, version, namespace, defaults, profile, displayName)
    
    self.__dataSource.account = 
        LSV_SavedVarsManager:New(
            {
                keyType = LIBSAVEDVARS_ACCOUNT_KEY,
                name=savedVariableTable,
                version=version,
                namespace=namespace,
                defaults=defaults,
                profile=profile or GetWorldName(),
                displayName=displayName
            }
        )
end

function initCharacterSettings(self, savedVariableTable, version, namespace, defaults, profile, displayName, 
                               characterName, characterId, characterKeyType)
    
    self.__dataSource.character = 
        LSV_SavedVarsManager:New(
            {
                keyType=characterKeyType or LIBSAVEDVARS_CHARACTER_ID_KEY,
                name=savedVariableTable,
                version=version,
                namespace=namespace,
                defaults=defaults,
                profile=profile or GetWorldName(),
                displayName=displayName,
                characterName=characterName,
                characterId=characterId
            }
        )
end

function initToggle(self)
    
    local ds = self.__dataSource
    
    if ds.character == nil then
        protected.Debug("Trying to initialized toggle failed. No character-specific saved vars manager found.", debugMode)
        return
    end
    
    if ds.account == nil then
        protected.Debug("Trying to initialized toggle failed. No account-wide saved vars manager found.", debugMode)
        return
    end
    
    local characterRawDataTable = ds.character:LoadRawTableData() or nil
    if not characterRawDataTable
       or (characterRawDataTable[LIBNAME] 
           and characterRawDataTable[LIBNAME].accountSavedVarsActive)
       or (ds.defaultToAccount and not characterRawDataTable[LIBNAME])
    then
        ds.active = ds.account
    else
        ds.active = ds.character
    end
    
    ds.character:RegisterLazyLoadCallback(onToggleLazyLoaded, self)
end

function onToggleLazyLoaded(self)
    protected.Debug("LSV_Data:onToggleLazyLoaded()", debugMode)
    
    local ds = self.__dataSource
    
    ds.character:UnregisterLazyLoadCallback(onToggleLazyLoaded)
    local characterRawDataTable = ds.character:LoadRawTableData()
    if characterRawDataTable[LIBNAME] ~= nil then
        return
    end
    
    -- Library character-specific settings
    local libSettings = { }
    
    -- Upgrade from v2 settings
    if characterRawDataTable.useAccountSettings ~= nil then
        libSettings.accountSavedVarsActive = characterRawDataTable.useAccountSettings
        characterRawDataTable.useAccountSettings = nil
        protected.Debug("Migrated existing toggle value: " .. tostring(libSettings.accountSavedVarsActive), debugMode)
    
    -- If no v2 settings exist, use defaultToAccount
    else
        libSettings.accountSavedVarsActive = ds.defaultToAccount
        protected.Debug("No existing settings to migrate. Setting toggle to default: " .. tostring(ds.defaultToAccount), debugMode)
    end
    
    characterRawDataTable[LIBNAME] = libSettings
    
    ds.active = libSettings.accountSavedVarsActive and ds.account or ds.character
    
    protected.Debug("Toggle initialized.", debugMode)
end

function shiftOptionalParams(version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId, characterKeyType)
    
    if version ~= nil and type(version) ~= "number" then
        return shiftOptionalParams(nil, version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId)
    elseif namespace ~= nil and type(namespace) ~= "string" then
        return shiftOptionalParams(version, nil, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId)
    elseif defaults ~= nil and type(defaults) ~= "table" then
        return shiftOptionalParams(version, namespace, nil, defaults, defaultToAccount, profile, displayName, characterName, characterId)
    elseif defaultToAccount ~= nil and type(defaultToAccount) ~= "boolean" then
        return shiftOptionalParams(version, namespace, defaults, true, defaultToAccount, profile, displayName, characterName, characterId)
    end
    
    return version, namespace, defaults, defaultToAccount, profile, displayName, characterName, characterId, characterKeyType
end

--[[
     Gets a list of all key value pairs in table1 that do not have corresponding keys in table2.
  ]]--
function tableDiffKeys(table1, table2)
    local diff = { }
    for key1, value1 in pairs(table1) do
        if table2[key1] == nil then
            diff[key1] = value1
        end
    end
    return diff
end

--[[
     Gets a new merged table with all keys from table1 and table2.  If the same key exists in both tables, 
     table1's value is used.
  ]]--
function tableMerge(table1, table2)
    local merged = ZO_ShallowTableCopy(table1)
    for key2, value2 in pairs(table2) do
        if table1[key2] == nil then
            merged[key2] = value2
        end
    end
    return merged
end

--[[
     Gets a list of all key value pairs in tbl that have corresponding keys in keyTable.
  ]]--
function tableFilterKeys(tbl, keyTable)
    local filtered = {}
    for key, value in pairs(tbl) do
        if keyTable[key] ~= nil then
            filtered[key] = value
        end
    end
    return filtered
end

function validateScope(scope)
    if scope == nil then
        return
    end
    if type(scope) ~= "number" then
        error("Invalid type for parameter 'scope'. Expected 'number'. Got '" .. type(scope) .. "' instead.", 2)
    end
    if scope < LIBSAVEDVARS_SCOPE_MIN or scope > LIBSAVEDVARS_SCOPE_MAX then
        error("Invalid value for parameter 'scope'.  Valid values must be between " .. tostring(LIBSAVEDVARS_SCOPE_MIN)
              .. " and " .. tostring(LIBSAVEDVARS_SCOPE_MAX) .. ".", 2)
    end
end