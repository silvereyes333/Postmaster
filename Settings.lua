--[[ 
    ===================================
                SETTINGS
    ===================================
  ]]
local function InvertBooleanSetting(settings, oldSetting, newSetting)
    if settings[oldSetting] == nil then 
        return
    end
    settings[newSetting] = not settings[oldSetting]
    settings[oldSetting] = nil
end
local function RenameSetting(settings, oldSetting, newSetting)
    if settings[oldSetting] == nil then 
        return
    end
    settings[newSetting] = settings[oldSetting]
    settings[oldSetting] = nil
end
local function UpgradeSettings(settings)
    if not settings.dataVersion then
        settings.dataVersion = 3
        InvertBooleanSetting(settings, "skipCod", "takeAllCodTake")
        InvertBooleanSetting(settings, "skipEmptyPlayerMail", "takeAllPlayerDeleteEmpty")
        InvertBooleanSetting(settings, "skipOtherPlayerMail", "takeAllPlayerAttached")
        InvertBooleanSetting(settings, "skipEmptySystemMail", "takeAllSystemDeleteEmpty")
    elseif settings.dataVersion < 3 then
        settings.dataVersion = 3
        RenameSetting(settings, "codTake", "takeAllCodTake")
        RenameSetting(settings, "codGoldLimit", "takeAllCodGoldLimit")
        RenameSetting(settings, "playerDeleteEmpty", "takeAllPlayerDeleteEmpty")
        RenameSetting(settings, "playerTakeAttached", "takeAllPlayerAttached")
        RenameSetting(settings, "playerTakeReturned", "takeAllPlayerReturned")
        RenameSetting(settings, "systemDeleteEmpty", "takeAllSystemDeleteEmpty")
        RenameSetting(settings, "systemTakeAttached", "takeAllSystemAttached")
        RenameSetting(settings, "systemTakeGuildStore", "takeAllSystemGuildStore")
        RenameSetting(settings, "systemTakeHireling", "takeAllSystemHireling")
        RenameSetting(settings, "systemTakeOther", "takeAllSystemOther")
        RenameSetting(settings, "systemTakePvp", "takeAllSystemPvp")
        RenameSetting(settings, "systemTakeUndaunted", "takeAllSystemUndaunted")
    end
end
function Postmaster:SettingsSetup()

    self.defaults = {
        bounce = false,
        reservedSlots = 0,
        deleteDialogSuppress = false,
        returnDialogSuppress = false,
        verbose = true,
        takeAllCodTake = false,
        takeAllCodGoldLimit = 10000,
        takeAllPlayerDeleteEmpty = false,
        takeAllPlayerAttached = true,
        takeAllPlayerReturned = false,
        takeAllSystemDeleteEmpty = false,
        takeAllSystemAttached = true,
        takeAllSystemGuildStore = true,
        takeAllSystemHireling = true,
        takeAllSystemOther = true,
        takeAllSystemPvp = true,
        takeAllSystemUndaunted = true,
        quickTakeCodTake = true,
        quickTakeCodGoldLimit = 0,
        quickTakePlayerDeleteEmpty = true,
        quickTakePlayerAttached = true,
        quickTakePlayerReturned = true,
        quickTakeSystemDeleteEmpty = true,
        quickTakeSystemAttached = true,
        quickTakeSystemGuildStore = true,
        quickTakeSystemHireling = true,
        quickTakeSystemOther = true,
        quickTakeSystemPvp = true,
        quickTakeSystemUndaunted = true,
    }
    
    -- Initialize saved variable
    self.settings = ZO_SavedVars:NewAccountWide("Postmaster_Data", 1, nil, self.defaults)
    
    UpgradeSettings(self.settings)
    
    local LAM2 = LibStub("LibAddonMenu-2.0")
    if not LAM2 then return end
    
    local panelData = {
        type = "panel",
        name = Postmaster.title,
        displayName = ZO_HIGHLIGHT_TEXT:Colorize(Postmaster.title),
        author = Postmaster.author,
        version = Postmaster.version,
        website = "http://www.esoui.com/downloads/info850-PostmasterMail.html",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    self.settingsPanel = LAM2:RegisterAddonPanel(Postmaster.name .. "Options", panelData)
    
    local optionsTable = {
        {
            type = "description",
            text = GetString(SI_PM_HELP_01),
            width = "full"
        },
        {
            type = "description",
            text = GetString(SI_PM_HELP_02),
            width = "full"
        },
		
		
		--[[ TAKE ALL ]]--
		
        {
            type = "header",
            name = GetString(SI_LOOT_TAKE_ALL),
            width = "full"
        },
        {
            type = "description",
            text = GetString(SI_PM_HELP_03),
            width = "full"
        },
        -- Reserved slots
        {
            type = "slider",
            name = GetString(SI_PM_RESERVED_SLOTS),
            tooltip = GetString(SI_PM_RESERVED_SLOTS_TOOLTIP),
            getFunc = function() return self.settings.reservedSlots end,
            setFunc = function(value) self.settings.reservedSlots = value end,
            min = 0,
            max = 200,
            step = 1,
            clampInput = true,
            width = "full",
            default = self.defaults.reservedSlots,
        },
        -- divider
        --{ type = "divider", width = "full" },
        
        
        --[ SYSTEM ]--
        { type = "submenu", name = GetString(SI_PM_SYSTEM), controls = {
        
        -- System mail with attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_ATTACHED),
            tooltip = GetString(SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP),
            getFunc = function() return self.settings.takeAllSystemAttached end,
            setFunc = function(value) self.settings.takeAllSystemAttached = value end,
            width = "full",
            default = self.defaults.takeAllSystemAttached,
        },
        -- PvP mail
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_PVP),
            getFunc = function() return self.settings.takeAllSystemPvp end,
            setFunc = function(value) self.settings.takeAllSystemPvp = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemPvp,
        },
        
        -- Hireling mail
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_CRAFTING),
            getFunc = function() return self.settings.takeAllSystemHireling end,
            setFunc = function(value) self.settings.takeAllSystemHireling = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemHireling,
        },
        
        -- Guild store mail
        {
            type = "checkbox",
            name = GetString(SI_WINDOW_TITLE_TRADING_HOUSE),
            getFunc = function() return self.settings.takeAllSystemGuildStore end,
            setFunc = function(value) self.settings.takeAllSystemGuildStore = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemGuildStore,
        },
        
        -- Undaunted mail
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_UNDAUNTED), 
            getFunc = function() return self.settings.takeAllSystemUndaunted end,
            setFunc = function(value) self.settings.takeAllSystemUndaunted = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemUndaunted,
        },
        -- Other system attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_OTHER),
            getFunc = function() return self.settings.takeAllSystemOther end,
            setFunc = function(value) self.settings.takeAllSystemOther = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemOther,
        },
        -- divider
        { type = "divider", width = "full" },
        -- System mail without attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_DELETE_EMPTY),
            tooltip = GetString(SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP),
            getFunc = function() return self.settings.takeAllSystemDeleteEmpty end,
            setFunc = function(value) self.settings.takeAllSystemDeleteEmpty = value end,
            width = "full",
            default = self.defaults.takeAllSystemDeleteEmpty,
        },
        }},
        
        -- divider
        --{ type = "divider", width = "full" },
        -- Player mail with attachments
        
        --[ PLAYER ]--
        { type = "submenu", name = GetString(SI_PM_PLAYER), controls = {
        
        {
            type = "checkbox",
            name = GetString(SI_PM_PLAYER_TAKE_ATTACHED),
            tooltip = GetString(SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP),
            getFunc = function() return self.settings.takeAllPlayerAttached end,
            setFunc = function(value) self.settings.takeAllPlayerAttached = value end,
            width = "full",
            default = self.defaults.takeAllPlayerAttached,
        },
        {
            type = "checkbox",
            name = GetString(SI_PM_PLAYER_TAKE_RETURNED),
            tooltip = GetString(SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP),
            getFunc = function() return self.settings.takeAllPlayerReturned end,
            setFunc = function(value) self.settings.takeAllPlayerReturned = value end,
            width = "full",
            default = self.defaults.takeAllPlayerReturned,
        },
        -- divider
        { type = "divider", width = "full" },
        -- Player mail without attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_PLAYER_DELETE_EMPTY),
            tooltip = GetString(SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP),
            getFunc = function() return self.settings.takeAllPlayerDeleteEmpty end,
            setFunc = function(value) self.settings.takeAllPlayerDeleteEmpty = value end,
            width = "full",
            default = self.defaults.takeAllPlayerDeleteEmpty,
        },
        }},
        
        -- divider
        --{ type = "divider", width = "full" },
        
        --[ COD ]--
        { type = "submenu", name = GetString(SI_MAIL_SEND_COD), controls = {
        -- Take COD mail
        {
            type = "checkbox",
            name = GetString(SI_PM_COD),
            tooltip = GetString(SI_PM_COD_TOOLTIP),
            getFunc = function() return self.settings.takeAllCodTake end,
            setFunc = function(value) self.settings.takeAllCodTake = value end,
            width = "full",
            default = self.defaults.takeAllCodTake,
        },
        -- Absolute COD gold limit
        {
            type = "slider",
            name = GetString(SI_PM_COD_LIMIT),
            tooltip = GetString(SI_PM_COD_LIMIT_TOOLTIP),
            getFunc = function() return self.settings.takeAllCodGoldLimit end,
            setFunc = function(value) self.settings.takeAllCodGoldLimit = value end,
            min = 0,
            max = 200000,
            width = "full", 
            clampInput = false,
            disabled = function() return not self.settings.takeAllCodTake end,
            default = self.defaults.takeAllCodGoldLimit,
        },
        }},
        
		
		
		
		--[[ TAKE (QUICK) ]]--
        
        {
            type = "header",
            name = GetString(SI_LOOT_TAKE),
            width = "full"
        },
        
        {
            type = "description",
            text = GetString(SI_PM_HELP_04),
            width = "full"
        },
        
        
        --[ SYSTEM ]--
        { type = "submenu", name = GetString(SI_PM_SYSTEM), controls = {
        
        -- System mail with attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_ATTACHED),
            tooltip = GetString(SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP_QUICK),
            getFunc = function() return self.settings.quickTakeSystemAttached end,
            setFunc = function(value) self.settings.quickTakeSystemAttached = value end,
            width = "full",
            default = self.defaults.quickTakeSystemAttached,
        },
        -- PvP mail
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_PVP),
            getFunc = function() return self.settings.quickTakeSystemPvp end,
            setFunc = function(value) self.settings.quickTakeSystemPvp = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemPvp,
        },
        
        -- Hireling mail
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_CRAFTING),
            getFunc = function() return self.settings.quickTakeSystemHireling end,
            setFunc = function(value) self.settings.quickTakeSystemHireling = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemHireling,
        },
        
        -- Guild store mail
        {
            type = "checkbox",
            name = GetString(SI_WINDOW_TITLE_TRADING_HOUSE),
            getFunc = function() return self.settings.quickTakeSystemGuildStore end,
            setFunc = function(value) self.settings.quickTakeSystemGuildStore = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemGuildStore,
        },
        
        -- Undaunted mail
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_UNDAUNTED), 
            getFunc = function() return self.settings.quickTakeSystemUndaunted end,
            setFunc = function(value) self.settings.quickTakeSystemUndaunted = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemUndaunted,
        },
        -- Other system attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_TAKE_OTHER),
            getFunc = function() return self.settings.quickTakeSystemOther end,
            setFunc = function(value) self.settings.quickTakeSystemOther = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemOther,
        },
        -- divider
        { type = "divider", width = "full" },
        -- System mail without attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_DELETE_EMPTY),
            tooltip = GetString(SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP_QUICK),
            getFunc = function() return self.settings.quickTakeSystemDeleteEmpty end,
            setFunc = function(value) self.settings.quickTakeSystemDeleteEmpty = value end,
            width = "full",
            default = self.defaults.quickTakeSystemDeleteEmpty,
        },
        }},
        
        -- divider
        --{ type = "divider", width = "full" },
        -- Player mail with attachments
        
        --[ PLAYER ]--
        { type = "submenu", name = GetString(SI_PM_PLAYER), controls = {
        
        {
            type = "checkbox",
            name = GetString(SI_PM_PLAYER_TAKE_ATTACHED),
            tooltip = GetString(SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP_QUICK),
            getFunc = function() return self.settings.quickTakePlayerAttached end,
            setFunc = function(value) self.settings.quickTakePlayerAttached = value end,
            width = "full",
            default = self.defaults.quickTakePlayerAttached,
        },
        {
            type = "checkbox",
            name = GetString(SI_PM_PLAYER_TAKE_RETURNED),
            tooltip = GetString(SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP_QUICK),
            getFunc = function() return self.settings.quickTakePlayerReturned end,
            setFunc = function(value) self.settings.quickTakePlayerReturned = value end,
            width = "full",
            default = self.defaults.quickTakePlayerReturned,
        },
        -- divider
        { type = "divider", width = "full" },
        -- Player mail without attachments
        {
            type = "checkbox",
            name = GetString(SI_PM_PLAYER_DELETE_EMPTY),
            tooltip = GetString(SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP_QUICK),
            getFunc = function() return self.settings.quickTakePlayerDeleteEmpty end,
            setFunc = function(value) self.settings.quickTakePlayerDeleteEmpty = value end,
            width = "full",
            default = self.defaults.quickTakePlayerDeleteEmpty,
        },
        }},
        
        -- divider
        --{ type = "divider", width = "full" },
        
        --[ COD ]--
        { type = "submenu", name = GetString(SI_MAIL_SEND_COD), controls = {
        -- Take COD mail
        {
            type = "checkbox",
            name = GetString(SI_PM_COD),
            tooltip = GetString(SI_PM_COD_TOOLTIP),
            getFunc = function() return self.settings.quickTakeCodTake end,
            setFunc = function(value) self.settings.quickTakeCodTake = value end,
            width = "full",
            default = self.defaults.quickTakeCodTake,
        },
        -- Absolute COD gold limit
        {
            type = "slider",
            name = GetString(SI_PM_COD_LIMIT),
            tooltip = GetString(SI_PM_COD_LIMIT_TOOLTIP),
            getFunc = function() return self.settings.quickTakeCodGoldLimit end,
            setFunc = function(value) self.settings.quickTakeCodGoldLimit = value end,
            min = 0,
            max = 200000,
            width = "full", 
            clampInput = false,
            disabled = function() return not self.settings.quickTakeCodTake end,
            default = self.defaults.quickTakeCodGoldLimit,
        },
        }},
        
        --[ OPTIONS ]--
        
        -- spacer
        { type = "description", width = "full" },
        -- header
        {
            type = "header",
            name = GetString(SI_GAMEPAD_OPTIONS_MENU),
            width = "full"
        },
        -- Verbose option
        {
            type = "checkbox",
            name = GetString(SI_PM_VERBOSE),
            tooltip = GetString(SI_PM_VERBOSE_TOOLTIP),
            getFunc = function() return self.settings.verbose end,
            setFunc = function(value) self.settings.verbose = value end,
            width = "full",
            default = self.defaults.verbose,
        },
        -- Delete confirmation dialog suppression
        {
            type = "checkbox",
            name = GetString(SI_PM_DELETE_DIALOG_SUPPRESS),
            tooltip = GetString(SI_PM_DELETE_DIALOG_SUPPRESS_TOOLTIP),
            getFunc = function() return self.settings.deleteDialogSuppress end,
            setFunc = function(value) self.settings.deleteDialogSuppress = value end,
            width = "full",
            default = self.defaults.deleteDialogSuppress,
        },
        -- Return confirmation dialog suppression
        {
            type = "checkbox",
            name = GetString(SI_PM_RETURN_DIALOG_SUPPRESS),
            getFunc = function() return self.settings.returnDialogSuppress end,
            setFunc = function(value) self.settings.returnDialogSuppress = value end,
            width = "full",
            default = self.defaults.returnDialogSuppress,
        },
        -- Bounce mail option
        {
            type = "checkbox",
            name = GetString(SI_PM_BOUNCE),
            tooltip = GetString(SI_PM_BOUNCE_TOOLTIP),
            getFunc = function() return self.settings.bounce and not (WYK_MailBox and WYK_MailBox.Settings.Enabled) end,
            setFunc = function(value) self.settings.bounce = value end,
            width = "full",
            default = self.defaults.bounce,
            disabled = function() return WYK_MailBox and WYK_MailBox.Settings.Enabled end,
            warning = function() 
                    if not WYK_MailBox then return end
                    if WYK_MailBox.Settings.Enabled then
                        return GetString(SI_PM_WYKKYD_MAILBOX_RETURN_WARNING)
                    else
                        return GetString(SI_PM_WYKKYD_MAILBOX_DETECTED_WARNING)
                    end
                end
        }
    }
        
    LAM2:RegisterOptionControls(Postmaster.name .. "Options", optionsTable)
    
    SLASH_COMMANDS["/postmaster"] = self.OpenSettingsPanel
    SLASH_COMMANDS["/pm"] = self.OpenSettingsPanel
end