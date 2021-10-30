-- Postmaster Addon for Elder Scrolls Online
-- Original Authors: Anthony Korchak aka Zierk + Garkin
-- Completely rewritten by silvereyes

Postmaster = {
    name = "Postmaster",
    title = GetString(SI_PM_NAME),
    version = "4.1.1",
    author = "silvereyes, Baertram, Garkin & Zierk",
    
    -- For development use only. Set to true to see a ridiculously verbose 
    -- activity log for this addon in the chat window.
    debugMode = false,
    
    -- Flag to signal that once one email is taken and deleted, the next message 
    -- should be selected and the process should continue on it
    takingAll = false,
    
    -- Flag to signal that a message is in the process of having its attachments
    -- taken and then subsequently being deleted.  Used to disable other keybinds
    -- while this occurs.
    taking = false,
    
    -- Used to synchronize item and money attachment retrieval events so that
    -- we know when to issue a DeleteMail() call.  DeleteMail() will not work
    -- unless all server-side events related to a mail are done processing.
    -- For normal mail, this includes EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS
    -- and/or EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS.  
    -- For C.O.D. mail, the events are EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, 
    -- EVENT_MONEY_UPDATE, and EVENT_MAIL_SEND_SUCCESS (for the outgoing gold mail)
    awaitingAttachments = {},
    
    -- Contains detailed information about mail attachments (links, money, cod)
    -- for mail currently being taken.  Used to display summaries to chat.
    attachmentData = {},
    
    keybinds = {
        gamepad = {},
        keyboard = {},
    },
    
    -- Remembers mail ids that fail to delete during a Take All operation
    -- for whatever reason, and therefore should not be taken again during the same
    -- operation.
    mailIdsFailedDeletion = {},
    
    -- Contains details about C.O.D. mail being taken, since events related to
    -- taking C.O.D.s do not contain mail ids as parameters.
    codMails = {},
    
    classes = {},
    
    quaternaryChoices = {
        GetString(SI_ACTION_IS_NOT_BOUND),
        GetString(SI_PM_TAKE_ALL_BY_SUBJECT),
        GetString(SI_PM_TAKE_ALL_BY_SENDER),
    },
    
    quaternaryChoicesValues = {
        "",
        "subject",
        "senderDisplayName",
    },
    
    systemEmailSenders = {
        ["undaunted"] = {
            zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_NORMAL)),
            zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_VET)),
            zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_1)),
            zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_2)),
            zo_strlower(GetString(SI_PM_UNDAUNTED_NPC_TRIAL_3)),
        },
        ["pvp"] = {
            zo_strlower(GetString(SI_PM_BATTLEGROUNDS_NPC)),
        },
    },
    
    systemEmailSubjects = {
        ["craft"] = {
            zo_strlower(GetString(SI_PM_CRAFT_BLACKSMITH)),
            zo_strlower(GetString(SI_PM_CRAFT_CLOTHIER)),
            zo_strlower(GetString(SI_PM_CRAFT_ENCHANTER)),
            zo_strlower(GetString(SI_PM_CRAFT_PROVISIONER)),
            zo_strlower(GetString(SI_PM_CRAFT_WOODWORKER)),
        },
        ["guildStoreSales"] = {
            zo_strlower(GetString(SI_PM_GUILD_STORE_SOLD)),
        },
        ["guildStoreItems"] = {
            zo_strlower(GetString(SI_PM_GUILD_STORE_CANCELED)),
            zo_strlower(GetString(SI_PM_GUILD_STORE_EXPIRED)),
            zo_strlower(GetString(SI_PM_GUILD_STORE_PURCHASED)),
        },
        ["pvp"] = {
            zo_strlower(GetString(SI_PM_PVP_FOR_THE_WORTHY)),
            zo_strlower(GetString(SI_PM_PVP_THANKS)),
            zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_1)),
            zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_2)),
            zo_strlower(GetString(SI_PM_PVP_FOR_THE_ALLIANCE_3)),
            zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_1)),
            zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_2)),
            zo_strlower(GetString(SI_PM_PVP_THE_ALLIANCE_THANKS_3)),
            zo_strlower(GetString(SI_PM_PVP_LOYALTY)),
        }
      },
}

-- Max milliseconds to wait for a mail removal event from the server after calling DeleteMail
PM_DELETE_MAIL_TIMEOUT_MS = 1500

-- Number of time to try deleting the message if it fails
PM_DELETE_MAIL_MAX_RETRIES = 3

PM_MAIL_READ_TIMEOUT_MS = 1500
PM_MAIL_READ_MAX_RETRIES = 1

-- Max milliseconds to wait for attachments to be retreived after calling ZO_MailInboxShared_TakeAll
PM_TAKE_TIMEOUT_MS = 1500

-- Number of time to try taking attachments if the attempt fails
PM_TAKE_ATTACHMENTS_MAX_RETRIES = 3

-- Prefixes for bounce mail subjects
PM_BOUNCE_MAIL_PREFIXES = {
    "RTS",
    "BOUNCE",
    "RETURN"
}

--Local speed up variables
local EM = EVENT_MANAGER

--[[ True if Postmaster is doing any operations on the inbox. ]]
function Postmaster:IsBusy()
    return self.taking or self.takingAll or self.Delete:IsRunning() or self.AutoReturn:IsRunning()
end

--[[ Sets state variables back to defaults and ensures a consistent inbox state ]]
function Postmaster:Reset()
    -- Unwire timeout callbacks
    self.Events:UnregisterAllForUpdate()
    self.Utility.Debug("Reset()")
    self.taking = false
    self.takingAll = false
    self.mailIdsFailedDeletion = {}
    self.filterFieldValue = nil
    self.filterFieldKeybind = nil
    self.Utility.UpdateKeybindButtonGroup()
    
    -- Print attachment summary
    self.summary:Print()
end

-- Initalizing the addon
local function OnAddonLoaded(eventCode, addOnName)

    local self = Postmaster
    
    if ( addOnName ~= self.name ) then return end
    EM:UnregisterForEvent(self.name, eventCode)
    
    -- Initialize settings menu, saved vars, and slash commands to open settings
    self:SettingsSetup()
    
    -- Wire up scene callbacks
    self.Callbacks:Initialize()
    
    -- Wire up server event handlers
    self.Events:Initialize()
    
    -- Wire up prehooks for ESOUI functions
    self.Prehooks:Initialize()
    
    -- Wire up posthooks for ESOUI functions
    self.SecurePostHooks:Initialize()
    
    -- Replace keybinds in the mouse/keyboard inbox UI
    self.KeyboardKeybinds:Initialize()
    
    -- Replace keybinds in the gamepad inbox UI
    self.GamepadKeybinds:Initialize()

    --Baertram - Send Mail save
    -- Add LibCustomMenu context menus to the mail recipient, subject, body fields
    self.SendMail:Initialize()
end

-- Register events
EM:RegisterForEvent(Postmaster.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
