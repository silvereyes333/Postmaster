-- Postmaster Addon for Elder Scrolls Online
-- Author: Anthony Korchak aka Zierk
-- Updated & modified by Garkin and silvereyes

PostMaster = {}

PostMaster.name = "Postmaster"
PostMaster.version = "2.2.0"
PostMaster.author = "@Zierk"
PostMaster.shortname = "PM"

PostMaster.keybindinfo = {}

local stripDescriptor -- variable to call KEYBIND_STRIP, allows visibility of Postmaster keybinds
local settingsPanel   -- main settings panel

PostMaster.attachmentsCounter = 0
PostMaster.moneyCounter = 0
PostMaster.processed = {}
PostMaster.fullBag = false
PostMaster.noMoney = false
PostMaster.takeAll = false

PostMaster.defaults = {
	verbose = true,
	skipOtherPlayerMail = false
}

--[[  = = = = =  EVENT HANDLERS  = = = = =  ]]--

-- Event handler for EVENT_MAIL_OPEN_MAILBOX
local function pMailboxOpen(eventCode)
    PostMaster.UpdateButtonStatus()
    PostMaster.UpdateKeybindInfo()
    KEYBIND_STRIP:AddKeybindButtonGroup(stripDescriptor)
end

-- Event handler for EVENT_MAIL_CLOSE_MAILBOX
local function pMailboxClose(eventCode)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(stripDescriptor)
    PostMaster.takeAll = false
end

-- Event handler for EVENT_MAIL_INBOX_UPDATE
local function pMailboxUpdate(eventCode)
    PostMaster.UpdateKeybindInfo()
    PostMaster.UpdateButtonStatus()
end

-- Event handler used to continue the ProcessMessageQueue loop
local function pEventHandler(event, mailId)
    if PostMaster.takeAll then
        zo_callLater(PostMaster.ProcessMessageQueue, 250)
    end
    PostMaster.UpdateButtonStatus()
end

-- Event handler used to delete processed messages
local function pDeleteProcessedMessage(event, mailId)
    local mailIdKey = Id64ToString(mailId)
    if PostMaster.processed[mailIdKey] then
        local numAttachments, attachedMoney = GetMailAttachmentInfo(mailId)
        if numAttachments == 0 and attachedMoney == 0 then
            DeleteMail(mailId, true)
        end
    end
end

-- Output formatted message to chat window, if configured
local function pOutput(input)
	if not PostMaster.settings.verbose then
		return
	end
	local output = zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: ", PostMaster.name)..input..".|r"
	d(output)
end

--[[  = = = = =  CORE FUNCTIONS  = = = = =  ]]--

function PostMaster.ProcessMessage(mailId)
    local _, unread, numAttachments, attachedMoney, codAmount
    local result = "Failure"

    if type(mailId) == "number" then
        _, _, _, _, unread, _, _, _, numAttachments, attachedMoney, codAmount = GetMailItemInfo(mailId)

        if unread then RequestReadMail(mailId) end -- if mail is unread, read mail

        if attachedMoney > 0 and (GetCurrentMoney() + attachedMoney) < MAX_PLAYER_MONEY then
            TakeMailAttachedMoney(mailId)  -- if mail has money attached, take it
        end

        if numAttachments > 0 then
            if GetNumBagFreeSlots(BAG_BACKPACK) >= numAttachments then
                if codAmount <= GetCurrentMoney() then
                    TakeMailAttachedItems(mailId) -- if mail has an attached item, take it
                    result = "Success"
                else
                    result = "NoMoney"
                end
            else
                result = "FullBag"
            end
        else
            result = "Success"

            local numAttachments, attachedMoney = GetMailAttachmentInfo(mailId)
            if numAttachments == 0 and attachedMoney == 0 then
                DeleteMail(mailId, true)
            end
        end
         
    elseif mailId == nil then
        result = "NoMail"
    end

    return result, numAttachments, attachedMoney, codAmount
end

function PostMaster.ProcessMessageQueue()
    if PostMaster.mailId == nil then
        PostMaster.mailId = MAIL_INBOX:GetOpenMailId()
    else
        PostMaster.mailId = GetNextMailId(PostMaster.mailId)
    end

    if PostMaster.FilterMessage(PostMaster.mailId) then
        PostMaster.mailId = nil
    end 
   
    if PostMaster.mailId ~= nil then
        local mailIdKey = Id64ToString(PostMaster.mailId)
        local result, numAttachments, attachedMoney, codAmount = PostMaster.ProcessMessage(PostMaster.mailId)

        if result == "Success" then
            if not PostMaster.processed[mailIdKey] then
                PostMaster.attachmentsCounter = PostMaster.attachmentsCounter + numAttachments
                PostMaster.moneyCounter = PostMaster.moneyCounter + attachedMoney - codAmount
                PostMaster.processed[mailIdKey] = true
            end
            PostMaster.mailId = nil
        else
            if result == "FullBag" then
                if not PostMaster.processed[mailIdKey] then
                    PostMaster.moneyCounter = PostMaster.moneyCounter + attachedMoney
                end
                PostMaster.fullBag = true
            elseif result == "NoMoney" then
                PostMaster.noMoney = true
            end
            zo_callLater(PostMaster.ProcessMessageQueue, 250)
        end

    else
    
        if PostMaster.fullBag then
            pOutput(GetString(SI_PM_FULLBAG))
        end
        if PostMaster.noMoney then
            pOutput(GetString(SI_PM_NOMONEY))
        end
        pOutput(zo_strformat(GetString(SI_PM_SUCCESS), PostMaster.attachmentsCounter, PostMaster.moneyCounter))

        PostMaster.takeAll = false
        ZO_ClearTable(PostMaster.processed)
        PostMaster.attachmentsCounter = 0
        PostMaster.moneyCounter = 0
        PostMaster.fullBag = false
        PostMaster.noMoney = false
    end
end

-- Function to take all attachments and money from the currently selected mail, then delete
function PostMaster.Take()
    ZO_ClearTable(PostMaster.processed)

    local mailId = MAIL_INBOX:GetOpenMailId()
    if type(mailId) ~= "number" then
        PostMaster.UpdateKeybindInfo()
        PostMaster.UpdateButtonStatus()
        return
    end
    local mailIdKey = Id64ToString(mailId)

    local result, numAttachments, attachedMoney, codAmount = PostMaster.ProcessMessage(mailId)
    PostMaster.processed[mailIdKey] = true

    if result == "Success" then
        pOutput(zo_strformat(GetString(SI_PM_SUCCESS), numAttachments, attachedMoney - codAmount))
    elseif result == "NoMoney" then
         pOutput(GetString(SI_PM_NOMONEY))
    elseif result == "FullBag" then
        pOutput(GetString(SI_PM_FULLBAG))
    end
end

-- Function triggered by mouse-click on the "Take All" XML button
function PostMaster.TakeAll()
    PostMaster.attachmentsCounter = 0
    PostMaster.moneyCounter = 0
    PostMaster.fullBag = false
    PostMaster.noMoney = false
    PostMaster.takeAll = true
    ZO_ClearTable(PostMaster.processed)

    PostMaster.ProcessMessageQueue()
end

-- Returns true if the given mail id should be skipped and the next message retrieved
function PostMaster.FilterMessage(mailId)
	
	if mailId == nil then
		return false
		
	elseif type(mailId) == "number" then
		if not PostMaster.settings.skipOtherPlayerMail then
			return false
			
		else
			local _, senderDisplayName, fromSystem
			senderDisplayName, _, _, _, _, fromSystem = GetMailItemInfo(mailId)

			if fromSystem then
				return false
			else
				pOutput(zo_strformat(GetString(SI_PM_SKIPPING), senderDisplayName))
				return true
			end
		end
		
	end
end

-- Function called from context menu
function PostMaster.Reply()
    local mailId = MAIL_INBOX:GetOpenMailId()
    if type(mailId) == "number" then
        local mailData = MAIL_INBOX:GetMailData(mailId)
        if mailData and not (mailData.fromSystem or mailData.returned) then
            local address = mailData.senderDisplayName
            local subject = mailData.subject
            if subject and subject ~= "" then
                subject = "Re: " .. subject
            end   

            MAIN_MENU:ShowScene("mailSend")
            MAIL_SEND:ClearFields()
            SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, function() MAIL_SEND:SetReply(address, subject) end)
        end
    end
end

-- Function to update keybind strip when keybinds are modified by player, additional check made on mailbox open event
function PostMaster.UpdateKeybindInfo(eventCode)
    local takeKeybind = ZO_Keybindings_GetHighestPriorityBindingStringFromAction("TAKE_BUTTON") 
    local takeallKeybind = ZO_Keybindings_GetHighestPriorityBindingStringFromAction("TAKEALL_BUTTON")
    PostMaster.keybindinfo.Take = takeKeybind
    PostMaster.keybindinfo.TakeAll = takeallKeybind
end

function PostMaster.UpdateButtonStatus()
    local enabled = GetNumMailItems() > 0
    local validMailId = type(MAIL_INBOX:GetOpenMailId()) == "number"
   
    PostMaster.takeButton:SetEnabled(enabled and validMailId)
    PostMaster.takeAllButton:SetEnabled(enabled)
end

-- Initialize the keybind strip
local function pInitalizeKeybindStrip()

    stripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,

        -- Take
        {
            name = GetString(SI_BINDING_NAME_TAKE_BUTTON),
            keybind = "TAKE_BUTTON",
            callback = function() PostMaster.Take() end,
            visible = function() return PostMaster.keybindinfo.Take ~= nil end,
        },

        -- Take All
        {
            name = GetString(SI_BINDING_NAME_TAKEALL_BUTTON),
            keybind = "TAKEALL_BUTTON",
            callback = function() PostMaster.TakeAll() end,
            visible = function() return PostMaster.keybindinfo.Take ~= nil end,
        },
    }

end

local function pCreateButtons()
    PostMaster.takeButton = WINDOW_MANAGER:CreateControlFromVirtual(PostMaster.name .. "Take", ZO_MailInbox, "ZO_DefaultButton")
    PostMaster.takeButton:SetAnchor(TOPLEFT, ZO_MailInboxList, BOTTOMLEFT, 24, 2)
    PostMaster.takeButton:SetText(GetString(SI_BINDING_NAME_TAKE_BUTTON))
    PostMaster.takeButton:SetHandler("OnMouseDown", PostMaster.Take) 
  
    PostMaster.takeAllButton = WINDOW_MANAGER:CreateControlFromVirtual(PostMaster.name .. "TakeAll", ZO_MailInbox, "ZO_DefaultButton")
    PostMaster.takeAllButton:SetAnchor(TOPRIGHT, ZO_MailInboxList, BOTTOMRIGHT, -24, 2)
    PostMaster.takeAllButton:SetText(GetString(SI_BINDING_NAME_TAKEALL_BUTTON))
    PostMaster.takeAllButton:SetHandler("OnMouseDown", PostMaster.TakeAll) 
end

-- Handler for /slash commands
local function commandHandler(text)

	local LAM = LibStub('LibAddonMenu-2.0')
	LAM:OpenToPanel(settingsPanel)
	
end


local function pInitializeSettingsMenu()
	
	local panelData = {
		type = "panel",
		name = PostMaster.name,
		displayName = ZO_HIGHLIGHT_TEXT:Colorize(PostMaster.name),
		author = PostMaster.author,
		version = PostMaster.version,
		registerForRefresh = true,
		registerForDefaults = true,
	}
	
	local LAM = LibStub('LibAddonMenu-2.0')
	settingsPanel = LAM:RegisterAddonPanel(PostMaster.name .. "Options", panelData)
	
	local optionsTable = {}
	local index = 0

    -- Help header
	index = index + 1
	optionsTable[index] = {
		type = "header",
		name = GetString(SI_PM_HELP_TITLE),
		width = "full"
	}
	
	-- Help section
	index = index + 1
	optionsTable[index] = {
		type = "description",
		text = GetString(SI_PM_HELP_01),
		width = "full"
	}
	index = index + 1
	optionsTable[index] = {
		type = "description",
		text = GetString(SI_PM_HELP_02),
		width = "full"
	}
	index = index + 1
	optionsTable[index] = {
		type = "description",
		text = GetString(SI_PM_HELP_03),
		width = "full"
	}
	index = index + 1
	optionsTable[index] = {
		type = "description",
		text = GetString(SI_PM_HELP_04),
		width = "full"
	}
	index = index + 1
	optionsTable[index] = {
		type = "description",
		text = GetString(SI_PM_HELP_05),
		width = "full"
	}
	
	-- Spacer
	index = index + 1
	optionsTable[index] = {
		type = "description",
		text = "",
		width = "full"
	}
	
    -- Options header
	index = index + 1
	optionsTable[index] = {
		type = "header",
		name = GetString(SI_PM_OPTIONS_TITLE),
		width = "full"
	}
	
	-- Verbose option
	index = index + 1
	optionsTable[index] = {
		type = "checkbox",
		name = GetString(SI_PM_VERBOSE),
		tooltip = GetString(SI_PM_VERBOSE_TOOLTIP),
		getFunc = function() return PostMaster.settings.verbose end,
		setFunc = function(newValue) PostMaster.settings.verbose = newValue end,
		width = "full",
		default = PostMaster.defaults.verbose,
	}
	
	-- Skip other players option
	index = index + 1
	optionsTable[index] = {
		type = "checkbox",
		name = GetString(SI_PM_SKIPPLAYERMAIL),
		tooltip = GetString(SI_PM_SKIPPLAYERMAIL_TOOLTIP),
		getFunc = function() return PostMaster.settings.skipOtherPlayerMail end,
		setFunc = function(newValue) PostMaster.settings.skipOtherPlayerMail = newValue end,
		width = "full",
		default = PostMaster.defaults.skipOtherPlayerMail,
	}
	
	LAM:RegisterOptionControls(PostMaster.name .. "Options", optionsTable)

end

-- Initalizing the addon
local function pInitialize(eventCode, addOnName)
    if ( addOnName ~= PostMaster.name ) then return end
    EVENT_MANAGER:UnregisterForEvent(addOnName, eventCode)

    -- Establish EVENT handlers for RegisteredEvents
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_MAIL_OPEN_MAILBOX, pMailboxOpen)
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_MAIL_CLOSE_MAILBOX, pMailboxClose)
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_KEYBINDING_SET, PostMaster.UpdateKeybindInfo)
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_MAIL_INBOX_UPDATE, pMailboxUpdate)
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_MAIL_READABLE, pEventHandler)
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, pDeleteProcessedMessage)
    EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS, pDeleteProcessedMessage)

    -- Establish /slash commands
    SLASH_COMMANDS["/postmaster"] = commandHandler
    SLASH_COMMANDS["/pm"] = commandHandler
    
    -- Initialize saved variable
	PostMaster.settings = ZO_SavedVars:NewAccountWide("Postmaster_Data", 1, nil, PostMaster.defaults)

    -- Additional functions to run to setup addon
    pInitializeSettingsMenu()
    pCreateButtons()
    pInitalizeKeybindStrip()
    PostMaster.UpdateKeybindInfo()
    
    -- Right click handler
    local function OnMouseUp_Hook(self, button, upInside)
        if upInside and button == 2 then
            MAIL_INBOX:SelectRow(self)
            local mailId = MAIL_INBOX:GetOpenMailId()
            if type(mailId) == "number" then
                local mailData = MAIL_INBOX:GetMailData(mailId)
                ClearMenu()
                
                -- Reply menu command
                if not (mailData.fromSystem or mailData.returned) then
                    AddMenuItem(GetString(SI_PM_REPLY), PostMaster.Reply)
                end
                
                -- Take & Delete menu command
                AddMenuItem(GetString(SI_PM_TAKEDELETE), PostMaster.Take)
                
                -- Take & Delete All menu command
                if GetNumMailItems() > 1 then
                    AddMenuItem(GetString(SI_PM_TAKEDELETEALL), PostMaster.TakeAll)
                end
                
                -- MailR Save menu command
                if MailR and MailR.SaveMail then
                    AddMenuItem(GetString(SI_PM_SAVE), MailR.SaveMail)
                end
                
                ShowMenu(self)
            end
            return true
        end
    end    
    ZO_PreHook("ZO_MailInboxRow_OnMouseUp", OnMouseUp_Hook) 
end

-- Register events
EVENT_MANAGER:RegisterForEvent(PostMaster.name, EVENT_ADD_ON_LOADED, pInitialize)
