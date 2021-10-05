-- Postmaster Addon for Elder Scrolls Online
-- Original Authors: Anthony Korchak aka Zierk + Garkin
-- Completely rewritten by silvereyes

Postmaster = {
    name = "Postmaster",
    title = GetString(SI_PM_NAME),
    version = "4.0.0",
    author = "silvereyes, Garkin & Zierk",
    
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
    
    keybinds = { basegame = {} },
    
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

-- Baertram - Remember
--Pointers to ZOs mail fields used
local mailReceiverEdit  = ZO_MailSendToField
local mailSubjectEdit   = ZO_MailSendSubjectField
local mailBodyEdit      = ZO_MailSendBodyField
--Subtable for the remember functions and values, tables etc.
Postmaster.Remember = {
    --Constants
    PM_REMEMBER_RECEIVER = 1,
    PM_REMEMBER_SUBJECT = 2,
    PM_REMEMBER_BODY = 3,

    isSettingEnabledAndDoWeNeedToRunPreHooks = false,

    --The generated context menu entries of LibCustomMenu
    mailReceiverContextMenuEntries = {},
    mailSubjectContextMenuEntries = {},
    mailBodyContextMenuEntries = {},
}

--Local speed up variables
local EM = EVENT_MANAGER
local strsub = string.sub
local remember = Postmaster.Remember
local PM_REMEMBER_RECEIVER = remember.PM_REMEMBER_RECEIVER
local PM_REMEMBER_SUBJECT = remember.PM_REMEMBER_SUBJECT
local PM_REMEMBER_BODY = remember.PM_REMEMBER_BODY

remember.contextMenusNameByIdx = {
  [PM_REMEMBER_RECEIVER]  = GetString(SI_PM_REMEMBER_MESSAGE_RECIPIENTS),
  [PM_REMEMBER_SUBJECT]   = GetString(SI_PM_REMEMBER_MESSAGE_SUBJECTS),
  [PM_REMEMBER_BODY]      = GetString(SI_PM_REMEMBER_MESSAGE_TEXT),
}
remember.contextMenusAnchorVars = {
  [PM_REMEMBER_RECEIVER]  = mailReceiverEdit,
  [PM_REMEMBER_SUBJECT]   = mailSubjectEdit,
  [PM_REMEMBER_BODY]      = mailBodyEdit,
}
remember.contextMenuHandlerWasAddedToControl = {
  [PM_REMEMBER_RECEIVER]  = false, --receiver
  [PM_REMEMBER_SUBJECT]   = false, --subjects
  [PM_REMEMBER_BODY]      = false, --body
}
remember.contextMenuSVVariableNames = {
  [PM_REMEMBER_RECEIVER]  = {"rememberRecipients",  "rememberSavedRecipients"},
  [PM_REMEMBER_SUBJECT]   = {"rememberSubjects",    "rememberSavedSubjects"},
  [PM_REMEMBER_BODY]      = {"rememberBodies",      "rememberSavedBodies"},
}


--[[ True if Postmaster is doing any operations on the inbox. ]]
function Postmaster:IsBusy()
    return self.taking or self.takingAll or self.AutoReturn:IsRunning()
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
    KEYBIND_STRIP:UpdateKeybindButtonGroup(MAIL_INBOX.selectionKeybindStripDescriptor)
    
    -- Print attachment summary
    self.summary:Print()
end

-- Initalizing the addon
local function OnAddonLoaded(eventCode, addOnName)

    local self = Postmaster
    
    if ( addOnName ~= self.name ) then return end
    EVENT_MANAGER:UnregisterForEvent(self.name, eventCode)
    
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

    --Baertram - Remember
    -- Add LibCustomMenu context menus to the mail recipient, subject, body fields
    self:RememberSetup()

    
    -- TODO: add gamepad inbox UI keybind support
end

-- Register events
EM:RegisterForEvent(Postmaster.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


--[[
    ===============================================================================
          REMEMBER - by Baertram
          Remember the receiver, subject, body text of manually created mails
          and allow to select from previously saved values via a righ click
          context menu at the ZO_MailSend fields
    ===============================================================================
  ]]

function Postmaster:RememberSetup()
    --LibCustomMenu is mandatory
    if not LibCustomMenu then return end

    --Check settings and if context menus need to added to the ZO_MailSend controls
    self:RememberCheckAddContextMenu(-1)

    --Add the handlers to the ZO_MailSend controls
    self:RememberCheckAddOnMouseHandler(-1)
end

local function trimTableEntries(tableVar, maxSavedEntries)
    --Sort the SV table by timestamp: Newest first, oldest last
    table.sort(tableVar, function(a, b)
        return a.timestamp > b.timestamp
    end)

    --Delete all entries > max entries to keep
    local countOld = #tableVar
    for i=maxSavedEntries+1, countOld, 1 do
        if tableVar[i] ~= nil then
            tableVar[i] = nil
        end
    end
    return tableVar
end

local function addAndTrimRememberedEntry(idx, textToAdd)
    local timeStamp = GetTimeStamp()
    local svVariableNames = remember.contextMenuSVVariableNames
    local contextMenuSVSavedVarName = svVariableNames[idx][2]
    local settings = Postmaster.settings
    local maxSavedEntries = settings.rememberSavedEntries

    --Prepare the new entry
    local newEntry = {
        timestamp = timeStamp,
        text = textToAdd,
    }
    --Add it to the SavedVariables table, if not already in there
    for oldEntryIdx, oldEntryData in ipairs(settings[contextMenuSVSavedVarName]) do
        if oldEntryData.text == textToAdd then return end
    end
    table.insert(Postmaster.settings[contextMenuSVSavedVarName], newEntry)

    --Check if the entries in the context menu needs to be trimmed
    if #Postmaster.settings[contextMenuSVSavedVarName] > maxSavedEntries then
        Postmaster.settings[contextMenuSVSavedVarName] = ZO_ShallowTableCopy(trimTableEntries(Postmaster.settings[contextMenuSVSavedVarName], maxSavedEntries))
    end
end

local function rememberSaveMailData()
    local toText =  mailReceiverEdit:GetText()
    local subjectText = mailSubjectEdit:GetText()
    local bodyText = mailBodyEdit:GetText()
--d("[Postmaster]Mail was (tried) to send to \'" .. toText .. "\' with subject \'" .. subjectText .. "\' with text \'" .. bodyText .. "\'")

    local settings = Postmaster.settings
    local svVariableNames = remember.contextMenuSVVariableNames
    --Save the receiver
    if settings[svVariableNames[PM_REMEMBER_RECEIVER][1]] == true and toText ~= nil and toText ~= "" then
        addAndTrimRememberedEntry(PM_REMEMBER_RECEIVER, toText)
    end
    --Save the subject
    if settings[svVariableNames[PM_REMEMBER_SUBJECT][1]] == true and subjectText ~= nil and subjectText ~= "" then
        addAndTrimRememberedEntry(PM_REMEMBER_SUBJECT, subjectText)
    end
    --Save the body text
    if settings[svVariableNames[PM_REMEMBER_BODY][1]] == true and bodyText ~= nil and bodyText ~= "" then
        addAndTrimRememberedEntry(PM_REMEMBER_BODY, bodyText)
    end

end

function Postmaster:RememberCheckAddPreHooksForMailSend()
    ZO_PreHook(MAIL_SEND, "Send", function()
--d("[Postmaster]PreHook MAIL_SEND")
        if remember.isSettingEnabledAndDoWeNeedToRunPreHooks == true then
            rememberSaveMailData()
------------------------------------------------------------------------------------------------------------------------
            --TODO DEBUGGING Remove before go-live
            --return true
------------------------------------------------------------------------------------------------------------------------
        end
    end)
end

function Postmaster:RememberCheckAddContextMenu(whichContextMenu)
    local atLeastOneSettingIsEnabled = false
    local settings = self.settings
    local svVariableNames = remember.contextMenuSVVariableNames
    local contextMenuAnchorVars = remember.contextMenusAnchorVars

    local function checkIfContextMenuShouldBeBuild(idx, contextMenuSVVarData)
        --Set the flag to show and build a context menu at the ZO_SendMailcontrol directly
        local anchorControl = contextMenuAnchorVars[idx]
        if not anchorControl then return false end
        --Reset flag to add context menu to the control
        anchorControl.PostMasterShowRememberContextMenuIdx = nil

        --Check SavedVariables and entries
        local contextMenuSVVarName = contextMenuSVVarData[1]
        local contextMenuSVSavedVarName = contextMenuSVVarData[2]
        --Settings enabled and data was saved before?
        if (not idx or not contextMenuSVVarName or not contextMenuSVSavedVarName)
                or not settings[contextMenuSVVarName] or settings[contextMenuSVSavedVarName] == nil then return false end

        --Check if the entries in the context menu needs to be trimmed
        local maxSavedEntries = settings.rememberSavedEntries
        if #settings[contextMenuSVSavedVarName] > maxSavedEntries then
            self.settings[contextMenuSVSavedVarName] = ZO_ShallowTableCopy(trimTableEntries(self.settings[contextMenuSVSavedVarName], maxSavedEntries))
        end

        --Set flag to add context menu to the control
        anchorControl.PostMasterShowRememberContextMenuIdx = idx
        return true
    end

    --All context menus?
    if whichContextMenu == -1 then
        --Reset the variables of the context menus
        for idx, contextMenuSVVarData in ipairs(svVariableNames) do
            local atLeastOneSettingIsEnabledInLoop = checkIfContextMenuShouldBeBuild(idx, contextMenuSVVarData)
            if atLeastOneSettingIsEnabledInLoop == true then
                atLeastOneSettingIsEnabled = true
            end
        end
    else
        local contextMenuSVVarData = svVariableNames[whichContextMenu]
        atLeastOneSettingIsEnabled = checkIfContextMenuShouldBeBuild(whichContextMenu, contextMenuSVVarData)
    end

    --Add the PreHooks for MAIL SEND to save the last used recipient, subject and body text
    remember.isSettingEnabledAndDoWeNeedToRunPreHooks = atLeastOneSettingIsEnabled
    self:RememberCheckAddPreHooksForMailSend()
end

local function onContextMenuRememberEntrySelected(controlDoneMouseUpAt, contextMenuIdx, contextmenuEntriesFromSV, entryIdx)
    --d("onContextMenuRememberEntrySelected - contextMenuIdx: " .. tostring(contextMenuIdx) .. ", entryIdx: " ..tostring(entryIdx))
    local selectedSVText = contextmenuEntriesFromSV[entryIdx].text
    --d("Selected text: " .. selectedSVText)
    if controlDoneMouseUpAt.SetText then controlDoneMouseUpAt:SetText(selectedSVText) end
end

local function onMouseUpRememberContextMenuHandlerFunc(controlDoneMouseUpAt, mouseButton, upInside, altKey, shiftKey, ctrlKey, commandKey)
    if not upInside or mouseButton ~= MOUSE_BUTTON_INDEX_RIGHT then ClearMenu() return end
--d("onMouseUpRememberContextMenuHandlerFunc-ctrl: " ..tostring(controlDoneMouseUpAt:GetName()))
    local contextMenuIdx = controlDoneMouseUpAt.PostMasterShowRememberContextMenuIdx
    if contextMenuIdx ~= nil then
        --d(">Show context menu idx: " ..tostring(contextMenuIdx))
        local contextMenuSVData = remember.contextMenuSVVariableNames
        local settings = Postmaster.settings
        local contextmenuEntriesFromSV = settings[contextMenuSVData[contextMenuIdx][2]]
        if contextmenuEntriesFromSV == nil or #contextmenuEntriesFromSV == 0 then return end
        local contextMenusNameByIdx = remember.contextMenusNameByIdx
        local countPreviewChars = settings.rememberBodiesPreviewChars

        ClearMenu()
        AddCustomMenuItem(contextMenusNameByIdx[contextMenuIdx], function() end, MENU_ADD_OPTION_HEADER)
        for entryIdx, entryData in ipairs(contextmenuEntriesFromSV) do
            local entryText = entryData.text
            local textForCMEntry = (contextMenuIdx ~= PM_REMEMBER_BODY and entryText) or (strsub(entryText, 1, countPreviewChars) .. "...")
            AddCustomMenuItem(textForCMEntry,
                function() onContextMenuRememberEntrySelected(controlDoneMouseUpAt, contextMenuIdx, contextmenuEntriesFromSV, entryIdx) end,
                MENU_ADD_OPTION_LABEL
            )
        end
        ShowMenu(controlDoneMouseUpAt)
    end
end

function Postmaster:RememberCheckAddOnMouseHandler(whichContextMenu)
    local contextMenusAnchorVars = remember.contextMenusAnchorVars
    local function addContextMenuHandlerToControlOnce(idx, contextMenuAnchorControl)
        --Add the context menu to the control, if not already done
        if not remember.contextMenuHandlerWasAddedToControl[idx] then
            contextMenuAnchorControl:SetHandler("OnMouseUp", onMouseUpRememberContextMenuHandlerFunc)
            remember.contextMenuHandlerWasAddedToControl[idx] = true
        end
    end

    --All context menus?
    if whichContextMenu == -1 then
        for idx, contextMenuAnchorControl in ipairs(contextMenusAnchorVars) do
            if contextMenuAnchorControl then
                addContextMenuHandlerToControlOnce(idx, contextMenuAnchorControl)
            end
        end
    else
        local contextMenuAnchorControl = contextMenusAnchorVars[whichContextMenu]
        if not contextMenuAnchorControl then return end
        addContextMenuHandlerToControlOnce(whichContextMenu, contextMenuAnchorControl)
    end
end