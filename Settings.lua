--[[ 
    ===================================
                SETTINGS
    ===================================
  ]]
local createChatProxy, refreshPrefix, version6, version7

function Postmaster:SettingsSetup()

    self.defaults = {
        bounce = false,
        reservedSlots = 0,
        deleteDialogSuppress = false,
        returnDialogSuppress = false,
        verbose = true,
        chatColor = { 1, 1, 1, 1 },
        shortPrefix = true,
        chatUseSystemColor = true,
        chatContentsSummary = {
            enabled = true,
            minQuality = ITEM_QUALITY_MIN_VALUE or ITEM_FUNCTIONAL_QUALITY_MIN_VALUE,
            showIcon = true,
            showTrait = true,
            showNotCollected = true,
            hideSingularQuantities = true,
            iconSize = 90,
            delimiter = " ",
            combineDuplicates = true,
            sortedByQuality = true,
            linkStyle = LINK_STYLE_DEFAULT,
            showCounter = true,
        },
        takeAllCodTake = false,
        takeAllCodDelete = true,
        takeAllCodGoldLimit = 10000,
        takeAllPlayerDeleteEmpty = false,
        takeAllPlayerAttached = true,
        takeAllPlayerAttachedDelete = true,
        takeAllPlayerReturned = false,
        takeAllPlayerReturnedDelete = true,
        takeAllSystemDeleteEmpty = false,
        takeAllSystemAttached = true,
        takeAllSystemAttachedDelete = true,
        takeAllSystemGuildStoreSales = true,
        takeAllSystemGuildStoreSalesDelete = true,
        takeAllSystemGuildStoreItems = true,
        takeAllSystemGuildStoreItemsDelete = true,
        takeAllSystemHireling = true,
        takeAllSystemHirelingDelete = true,
        takeAllSystemOther = true,
        takeAllSystemOtherDelete = true,
        takeAllSystemPvp = true,
        takeAllSystemPvpDelete = true,
        takeAllSystemUndaunted = true,
        takeAllSystemUndauntedDelete = true,
        quickTakeCodTake = true,
        quickTakeCodGoldLimit = 0,
        quickTakePlayerAttached = true,
        quickTakePlayerReturned = true,
        quickTakeSystemAttached = true,
        quickTakeSystemGuildStoreSales = true,
        quickTakeSystemGuildStoreItems = true,
        quickTakeSystemHireling = true,
        quickTakeSystemOther = true,
        quickTakeSystemPvp = true,
        quickTakeSystemUndaunted = true,
        takeAllSubjectDelete = true,
        takeAllSenderDisplayNameDelete = true,

        --Baertram - Remember settings variables
        sendmailSaveRecipients = false,
        sendmailRecipients = {},
        sendmailSaveSubjects = false,
        sendmailSubjects = {},
        sendmailSaveMessages = false,
        sendmailMessages = {},
        sendmailMessagesPreviewChars = 75,
        sendmailSavedEntryCount = 10,
	
        keybinds = {
            enable = true,
            quaternary = "",
        },
    }
    
    -- Initialize saved variables
    self.settings = LibSavedVars
        :NewAccountWide(self.name .. "_Account", self.defaults)
        :AddCharacterSettingsToggle(self.name .. "_Character")
        :RemoveSettings(5, "dataVersion")
        :Version(6, version6)
        :Version(7, version7)
    
    if LSV_Data.EnableDefaultsTrimming then
        self.settings:EnableDefaultsTrimming()
    end
    
    self.chat = self.classes.ChatProxy:New()
    self.templateSummary = self.classes.AccountSummary:New({ chat = self.chat, sortedByQuality = true })
    self.templateSummary:SetCounterText(GetString(SI_PM_MESSAGE))
    
    self.chatColor = ZO_ColorDef:New(unpack(self.settings.chatColor))
    refreshPrefix()

    --Baertram - Remember local speed up variables
    local sendmail = self.SendMail
    local PM_SENDMAIL_RECIPIENT = sendmail.PM_SENDMAIL_RECIPIENT
    local PM_SENDMAIL_SUBJECT = sendmail.PM_SENDMAIL_SUBJECT
    local PM_SENDMAIL_MESSAGE = sendmail.PM_SENDMAIL_MESSAGE
    
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
    self.settingsPanel = LibAddonMenu2:RegisterAddonPanel(Postmaster.name .. "Options", panelData)
    
    self.chatContentsSummaryProxy = setmetatable({},
        {
            __index = function(_, key)
                return Postmaster.settings.chatContentsSummary[key]
            end,
            __newindex = function(_, key, value)
                Postmaster.settings.chatContentsSummary[key] = value
            end,
        })
    
    local optionsTable = {
        
        -- Account-wide settings
        self.settings:GetLibAddonMenuAccountCheckbox(),
        
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
        
		
        --[[ KEYBINDINGS ]]--
        { type = "submenu", name = GetString(SI_KEYBINDINGS_BINDINGS), controls = {
        
        
        -- Enable Keyind Overrides
        {
            type = "checkbox",
            name = GetString(SI_ADDON_MANAGER_ENABLED),
            tooltip = GetString(SI_PM_KEYBIND_ENABLE_TOOLTIP),
            getFunc = function() return self.settings.keybinds.enable end,
            setFunc =
                function(value)
                    self.settings.keybinds.enable = value
                    self.GamepadKeybinds:Update()
                    self.KeyboardKeybinds:Update()
                end,
            width = "full",
            default = self.defaults.keybinds.enable,
        },
        
        -- Keyboard Quaternary Action
        {
            type = "dropdown",
            name = GetString(SI_BINDING_NAME_UI_SHORTCUT_QUATERNARY) .. GetString(SI_PM_KEYBOARD),
            width = "full",
            choices = self.quaternaryChoices,
            choicesValues = self.quaternaryChoicesValues,
            getFunc = function() return self.settings.keybinds.quaternary end,
            setFunc =
                function(value)
                    self.settings.keybinds.quaternary = value
                    self.KeyboardKeybinds:Update()
                end,
            default = self.defaults.keybinds.quaternary,
        }}},
		
		
        --[[ TAKE (QUICK) ]]--
        
        { type = "submenu", name = GetString(SI_LOOT_TAKE), controls = {
        
        {
            type = "description",
            text = GetString(SI_PM_HELP_03),
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
            
        -- Guild store sales
        {
            type = "checkbox",
            name = zo_strformat(GetString(SI_INVENTORY_FILTER_WITH_SUB_TAB), GetString(SI_WINDOW_TITLE_TRADING_HOUSE), GetString("SI_GUILDHISTORYCATEGORY", GUILD_HISTORY_STORE)),
            getFunc = function() return self.settings.quickTakeSystemGuildStoreSales end,
            setFunc = function(value) self.settings.quickTakeSystemGuildStoreSales = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemGuildStoreSales,
        },
        
        -- Guild store items
        {
            type = "checkbox",
            name = zo_strformat(GetString(SI_INVENTORY_FILTER_WITH_SUB_TAB), GetString(SI_WINDOW_TITLE_TRADING_HOUSE), GetString(SI_GAMEPAD_MAIL_SEND_ITEMS_HEADER)),
            getFunc = function() return self.settings.quickTakeSystemGuildStoreItems end,
            setFunc = function(value) self.settings.quickTakeSystemGuildStoreItems = value end,
            width = "full",
            disabled = function() return not self.settings.quickTakeSystemAttached end,
            default = self.defaults.quickTakeSystemGuildStoreItems,
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
        }}},
        
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
        }}},
        
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
        }}}},
		
		
        --[[ TAKE ALL ]]--
		
        { type = "submenu", name = GetString(SI_LOOT_TAKE_ALL), controls = {
		
        {
            type = "description",
            text = GetString(SI_PM_HELP_04),
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
        {
            type = "checkbox",
            name = GetString(SI_PM_SYSTEM_DELETE_ATTACHED),
            getFunc = function() return self.settings.takeAllSystemAttachedDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemAttachedDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemAttachedDelete,
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
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSystemPvpDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemPvpDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached or not self.settings.takeAllSystemAttachedDelete or not self.settings.takeAllSystemPvp end,
            default = self.defaults.takeAllSystemPvpDelete,
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
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSystemHirelingDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemHirelingDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached or not self.settings.takeAllSystemAttachedDelete or not self.settings.takeAllSystemHireling end,
            default = self.defaults.takeAllSystemHirelingDelete,
        },
        
        -- Guild store sales
        {
            type = "checkbox",
            name = zo_strformat(GetString(SI_INVENTORY_FILTER_WITH_SUB_TAB), GetString(SI_WINDOW_TITLE_TRADING_HOUSE), GetString("SI_GUILDHISTORYCATEGORY", GUILD_HISTORY_STORE)),
            getFunc = function() return self.settings.takeAllSystemGuildStoreSales end,
            setFunc = function(value) self.settings.takeAllSystemGuildStoreSales = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemGuildStoreSales,
        },
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSystemGuildStoreSalesDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemGuildStoreSalesDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached or not self.settings.takeAllSystemAttachedDelete or not self.settings.takeAllSystemGuildStoreSales end,
            default = self.defaults.takeAllSystemGuildStoreSalesDelete,
        },
        
        -- Guild store items
        {
            type = "checkbox",
            name = zo_strformat(GetString(SI_INVENTORY_FILTER_WITH_SUB_TAB), GetString(SI_WINDOW_TITLE_TRADING_HOUSE), GetString(SI_GAMEPAD_MAIL_SEND_ITEMS_HEADER)),
            getFunc = function() return self.settings.takeAllSystemGuildStoreItems end,
            setFunc = function(value) self.settings.takeAllSystemGuildStoreItems = value end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached end,
            default = self.defaults.takeAllSystemGuildStoreItems,
        },
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSystemGuildStoreItemsDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemGuildStoreItemsDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached or not self.settings.takeAllSystemAttachedDelete or not self.settings.takeAllSystemGuildStoreItems end,
            default = self.defaults.takeAllSystemGuildStoreItemsDelete,
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
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE), 
            getFunc = function() return self.settings.takeAllSystemUndauntedDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemUndauntedDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached or not self.settings.takeAllSystemAttachedDelete or not self.settings.takeAllSystemUndaunted end,
            default = self.defaults.takeAllSystemUndauntedDelete,
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
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSystemOtherDelete end,
            setFunc = function(value)
                if value then
                    self.settings.takeAllSystemDeleteEmpty = false
                end
                self.settings.takeAllSystemOtherDelete = value 
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllSystemAttached or not self.settings.takeAllSystemAttachedDelete or not self.settings.takeAllSystemOther end,
            default = self.defaults.takeAllSystemOtherDelete,
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
            
            -- We need to disable Take All deleting empty system mail if *any* of the options 
            -- for deleting system mail *with* attachments are disabled, 
            -- since once the attachments have been removed, they will become empty.
            disabled = function() 
                if not self.settings.takeAllSystemAttached then return false end
                if not self.settings.takeAllSystemAttachedDelete then return true end
                if not self.settings.takeAllSystemPvpDelete
                   or not self.settings.takeAllSystemHirelingDelete
                   or not self.settings.takeAllSystemGuildStoreSalesDelete
                   or not self.settings.takeAllSystemGuildStoreItemsDelete
                   or not self.settings.takeAllSystemUndauntedDelete
                   or not self.settings.takeAllSystemOtherDelete
                then
                    return true
                else
                    return false
                end
             end,
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
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllPlayerAttachedDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllPlayerDeleteEmpty = false
                end
                self.settings.takeAllPlayerAttachedDelete = value
            end,
            width = "full",
            default = self.defaults.takeAllPlayerAttachedDelete,
            disabled = function() return not self.settings.takeAllPlayerAttached end,
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
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllPlayerReturnedDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllPlayerDeleteEmpty = false
                end
                self.settings.takeAllPlayerReturnedDelete = value
            end,
            width = "full",
            default = self.defaults.takeAllPlayerReturnedDelete,
            disabled = function() return not self.settings.takeAllPlayerReturned end,
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
            
            -- We need to disable Take All deleting empty player if *any* of the options 
            -- for deleting player/cod mail *with* attachments are disabled, 
            -- since once the attachments have been removed, they will become empty.
            disabled = function() 
                if (self.settings.takeAllPlayerAttached and not self.settings.takeAllPlayerAttachedDelete)
                   or (self.settings.takeAllPlayerReturned and not self.settings.takeAllPlayerReturnedDelete)
                   or (self.settings.takeAllCodTake and not self.settings.takeAllCodTakeDelete)
                then
                    return true
                else
                    return false
                end
             end,
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
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllCodDelete end,
            setFunc = function(value)
                if not value then
                    self.settings.takeAllPlayerDeleteEmpty = false
                end
                self.settings.takeAllCodDelete = value
            end,
            width = "full",
            disabled = function() return not self.settings.takeAllCodTake end,
            default = self.defaults.takeAllCodDelete,
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
        }}}}},
        
        --[[ TAKE BY SUBJECT ]]--
        { type = "submenu", name = GetString(SI_PM_TAKE_ALL_BY_SUBJECT), controls = {
        
        {
            type = "description",
            text = GetString(SI_PM_TAKE_ALL_BY_SUBJECT_HELP_01),
            width = "full"
        },
        
        {
            type = "description",
            text = GetString(SI_PM_TAKE_ALL_BY_FIELD_HELP_02),
            width = "full"
        },
            
        -- Delete while taking by subject
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSubjectDelete end,
            setFunc = function(value) self.settings.takeAllSubjectDelete = value end,
            width = "full",
            default = self.defaults.takeAllSubjectDelete,
        }}},
		
        --[[ TAKE BY SENDER ]]--
        { type = "submenu", name = GetString(SI_PM_TAKE_ALL_BY_SENDER), controls = {
        
        {
            type = "description",
            text = GetString(SI_PM_TAKE_ALL_BY_SENDER_HELP_01),
            width = "full"
        },
        
        {
            type = "description",
            text = GetString(SI_PM_TAKE_ALL_BY_FIELD_HELP_02),
            width = "full"
        },
            
        -- Delete while taking by sender
        {
            type = "checkbox",
            name = GetString(SI_PM_MAIL_DELETE),
            getFunc = function() return self.settings.takeAllSenderDisplayNameDelete end,
            setFunc = function(value) self.settings.takeAllSenderDisplayNameDelete = value end,
            width = "full",
            default = self.defaults.takeAllSenderDisplayNameDelete,
        }}},
        
        --[ CHAT MESSAGES ]--        
        
        {
            type     = "submenu",
            name     = GetString(SI_PM_CHAT_MESSAGES),
            controls = {
                -- Use default system color
                {
                    type = "checkbox",
                    name = GetString(SI_PM_CHAT_USE_SYSTEM_COLOR),
                    getFunc = function() return self.settings.chatUseSystemColor end,
                    setFunc = function(value)
                                  self.settings.chatUseSystemColor = value
                                  refreshPrefix()
                              end,
                    default = self.defaults.chatUseSystemColor,
                },
                -- Message color
                {
                    type = "colorpicker",
                    name = GetString(SI_PM_CHAT_COLOR),
                    getFunc = function() return unpack(self.settings.chatColor) end,
                    setFunc = function(r, g, b, a)
                                  self.settings.chatColor = { r, g, b, a }
                                  self.chatColor = ZO_ColorDef:New(r, g, b, a)
                                  refreshPrefix()
                              end,
                    default = function()
                                  local r, g, b, a = unpack(self.defaults.chatColor)
                                  return { r=r, g=g, b=b, a=a }
                              end,
                    disabled = function() return self.settings.chatUseSystemColor end,
                },
                
                -- Prefix header
                {
                    type = "header",
                    name = GetString(SI_PM_PREFIX_HEADER),
                },
                -- Short prefix
                {
                    type = "checkbox",
                    name = GetString(SI_PM_SHORT_PREFIX),
                    tooltip = GetString(SI_PM_SHORT_PREFIX_TOOLTIP),
                    getFunc = function() return self.settings.shortPrefix end,
                    setFunc = function(value)
                                  self.settings.shortPrefix = value
                                  refreshPrefix()
                              end,
                    default = self.defaults.shortPrefix,
                },
                -- Old Prefix Colors
                {
                    type = "checkbox",
                    name = GetString(SI_PM_COLORED_PREFIX),
                    tooltip = GetString(SI_PM_COLORED_PREFIX_TOOLTIP),
                    getFunc = function() return self.settings.coloredPrefix end,
                    setFunc = function(value)
                                  self.settings.coloredPrefix = value
                                  refreshPrefix()
                              end,
                    default = self.defaults.coloredPrefix,
                },
                
                -- Loot History
                {
                    type = "header",
                    name = GetString(SI_INTERFACE_OPTIONS_LOOT_TOGGLE_LOOT_HISTORY),
                },
                
                -- Log loot summary to chat
                self.templateSummary:GenerateLam2LootOptions(self.title, self.chatContentsSummaryProxy, self.defaults.chatContentsSummary),
            },
        },
		
		
        --[[ Baertram - Send Mail save settings
            only enabled if LibCustomMenu 7.11 or newer is given
        ]]
        -- Send Mail
        {
            type     = "submenu",
            name     = GetString(SI_SOCIAL_MENU_SEND_MAIL),
            controls = {
                -- Remember message recipients
                {
                    type    = "checkbox",
                    name    = GetString(SI_PM_SENDMAIL_MESSAGE_RECIPIENTS),
                    tooltip = GetString(SI_PM_SENDMAIL_MESSAGE_RECIPIENTS_TT),
                    getFunc = function() return self.settings.sendmailSaveRecipients end,
                    setFunc = function(value) self.settings.sendmailSaveRecipients = value end,
                    default = self.defaults.sendmailSaveRecipients,
                    disabled = function() return LibCustomMenu == nil end
                },
                -- Clear recipients button
                {
                    type = "button",
                    name = GetString(SI_PM_SENDMAIL_CLEAR_RECIPIENTS),
                    func = function()
                        local field = self.SendMail:GetField("sendmailRecipients")
                        field:Clear()
                        self.Utility.ShowMessageDialog(
                          GetString(SI_PM_SENDMAIL_CLEAR_RECIPIENTS), 
                          GetString(SI_PM_SENDMAIL_CLEAR_RECIPIENTS_SUCCESS))
                    end,
                    width = "half",
                    disabled = function() return LibCustomMenu == nil end,
                },
                -- Remember message subjects
                {
                    type    = "checkbox",
                    name    = GetString(SI_PM_SENDMAIL_MESSAGE_SUBJECTS),
                    tooltip = GetString(SI_PM_SENDMAIL_MESSAGE_SUBJECTS_TT),
                    getFunc = function() return self.settings.sendmailSaveSubjects end,
                    setFunc = function(value) self.settings.sendmailSaveSubjects = value end,
                    default = self.defaults.sendmailSaveSubjects,
                    disabled = function() return LibCustomMenu == nil end
                },
                -- Clear subjects button
                {
                    type = "button",
                    name = GetString(SI_PM_SENDMAIL_CLEAR_SUBJECTS),
                    func = function()
                        local field = self.SendMail:GetField("sendmailSubjects")
                        field:Clear()
                        self.Utility.ShowMessageDialog(
                          GetString(SI_PM_SENDMAIL_CLEAR_SUBJECTS), 
                          GetString(SI_PM_SENDMAIL_CLEAR_SUBJECTS_SUCCESS))
                    end,
                    width = "half",
                    disabled = function() return LibCustomMenu == nil end,
                },
                -- Remember message bodies
                {
                    type    = "checkbox",
                    name    = GetString(SI_PM_SENDMAIL_MESSAGE_TEXT),
                    tooltip = GetString(SI_PM_SENDMAIL_MESSAGE_TEXT_TT),
                    getFunc = function() return self.settings.sendmailSaveMessages end,
                    setFunc = function(value) self.settings.sendmailSaveMessages = value end,
                    default = self.defaults.sendmailSaveMessages,
                    disabled = function() return LibCustomMenu == nil end
                },
                -- Clear message bodies button
                {
                    type = "button",
                    name = GetString(SI_PM_SENDMAIL_CLEAR_MESSAGES),
                    func = function()
                        local field = self.SendMail:GetField("sendmailMessages")
                        field:Clear()
                        self.Utility.ShowMessageDialog(
                          GetString(SI_PM_SENDMAIL_CLEAR_MESSAGES), 
                          GetString(SI_PM_SENDMAIL_CLEAR_MESSAGES_SUCCESS))
                    end,
                    width = "half",
                    disabled = function() return LibCustomMenu == nil end,
                },
                {
                    type = "slider",
                    name = GetString(SI_PM_SENDMAIL_PREVIEW_CHARS),
                    getFunc = function() return self.settings.sendmailMessagesPreviewChars end,
                    setFunc = function(value) self.settings.sendmailMessagesPreviewChars = value end,
                    min = 10,
                    max = 250,
                    width = "full",
                    disabled = function() return not self.settings.sendmailSaveMessages end,
                    default = self.defaults.sendmailMessagesPreviewChars,
                },
                {
                    type = "slider",
                    name = GetString(SI_PM_SENDMAIL_AMOUNT),
                    getFunc = function() return self.settings.sendmailSavedEntryCount end,
                    setFunc = function(value) self.settings.sendmailSavedEntryCount = value end,
                    min = 1,
                    max = 20,
                    width = "full",
                    clampInput = false,
                    disabled = function() return not self.settings.sendmailSaveRecipients and not self.settings.sendmailSaveSubjects and not self.settings.sendmailSaveMessages end,
                    default = self.defaults.sendmailSavedEntryCount,
                },
            } -- controls
        },--submenu
        
        -- header
        {
            type = "header",
            name = GetString(SI_GAMEPAD_OPTIONS_MENU),
            width = "full"
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
        
    LibAddonMenu2:RegisterOptionControls(Postmaster.name .. "Options", optionsTable)
    
    self.summary = self.classes.GroupedAccountSummary:New(self.templateSummary)
    
    SLASH_COMMANDS["/postmaster"] = self.Utility.OpenSettingsPanel
    SLASH_COMMANDS["/pm"] = self.Utility.OpenSettingsPanel
end

----------------------------------------------------------------------------
--
--       Local methods
-- 
----------------------------------------------------------------------------

function refreshPrefix()
    local self = Postmaster
    local shortTag = self.settings.coloredPrefix and GetString(SI_PM_PREFIX_SHORT_COLOR) or GetString(SI_PM_PREFIX_SHORT)
    self.chat:SetShortTag(shortTag)
    local longTag = self.settings.coloredPrefix and GetString(SI_PM_PREFIX_COLOR) or GetString(SI_PM_PREFIX)
    self.chat:SetLongTag(longTag)
    self.chat:SetShortTagPrefixEnabled(self.settings.shortPrefix)
    
    if self.settings.chatUseSystemColor or self.settings.coloredPrefix then
        self.chat:SetTagColor(nil)
    else
        self.chat:SetTagColor(self.chatColor)
    end
    
    self.prefix = self.settings.chatUseSystemColor and "" or ("|c" .. self.chatColor:ToHex())
    self.suffix = self.settings.chatUseSystemColor and "" or "|r"
    self.templateSummary:SetPrefix(self.prefix)
    self.templateSummary:SetSuffix(self.suffix)
end

function version6(sv)
    sv.chatContentsSummary = {
        enabled = sv.verbose
    }
end

function version7(sv)
    sv.takeAllSystemGuildStoreSales = sv.takeAllSystemGuildStore
    sv.takeAllSystemGuildStoreItems = sv.takeAllSystemGuildStore
    sv.takeAllSystemGuildStore = nil
    sv.takeAllSystemGuildStoreSalesDelete = sv.takeAllSystemGuildStoreDelete
    sv.takeAllSystemGuildStoreItemsDelete = sv.takeAllSystemGuildStoreDelete
    sv.takeAllSystemGuildStoreDelete = nil
    sv.quickTakeSystemGuildStoreSales = sv.quickTakeSystemGuildStore
    sv.quickTakeSystemGuildStoreItems = sv.quickTakeSystemGuildStore
    sv.quickTakeSystemGuildStore = nil
end