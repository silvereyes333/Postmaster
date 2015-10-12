-- Postmaster Addon for Elder Scrolls Online
-- Author: Anthony Korchak aka Zierk
-- Updated & modified by Garkin and silvereyes

PostMaster = {}

PostMaster.name = "Postmaster"
PostMaster.version = "2.1.0"
PostMaster.author = "@Zierk"
PostMaster.shortname = "PM"

PostMaster.keybindinfo = {}

local stripDescriptor -- variable to call KEYBIND_STRIP, allows visibility of Postmaster keybinds

PostMaster.attachmentsCounter = 0
PostMaster.moneyCounter = 0
PostMaster.processed = {}
PostMaster.fullBag = false
PostMaster.noMoney = false
PostMaster.takeAll = false

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
        PostMaster.ProcessMessageQueue()
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

    while not (type(PostMaster.mailId) == "number" or (PostMaster.mailId == nil and GetNumMailItems() == 0)) do
        PostMaster.mailId = GetNextMailId(PostMaster.mailId)
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
            d(zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: Not enough bag space to take all attachments.|r", PostMaster.name))
        end
        if PostMaster.noMoney then
            d(zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: Not enough money to pay for all C.O.D. items.|r", PostMaster.name))
        end
        d(zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: Received|r |cFFFF00<<2>> <<2[items/item/items]>>|r |cFFFFFFand|r |c00FF00<<3>> gold|r |cFFFFFFfrom message.|r", PostMaster.name, PostMaster.attachmentsCounter, PostMaster.moneyCounter))

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
        d(zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: Received|r |cFFFF00<<2>> <<2[items/item/items]>>|r |cFFFFFFand|r |c00FF00<<3>> gold|r |cFFFFFFfrom message.|r", PostMaster.name, numAttachments, attachedMoney - codAmount))
    elseif result == "NoMoney" then
        d(zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: Not enough money to pay COD.|r", PostMaster.name))
    elseif result == "FullBag" then
        d(zo_strformat("|cEFEBBE<<1>>|r|cFFFFFF: Not enough bag space.|r", PostMaster.name))
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
            name = "Take",
            keybind = "TAKE_BUTTON",
            callback = function() PostMaster.Take() end,
            visible = function() return PostMaster.keybindinfo.Take ~= nil end,
        },

        -- Take All
        {
            name = "Take All",
            keybind = "TAKEALL_BUTTON",
            callback = function() PostMaster.TakeAll() end,
            visible = function() return PostMaster.keybindinfo.Take ~= nil end,
        },
    }

end

local function pCreateButtons()
    PostMaster.takeButton = WINDOW_MANAGER:CreateControlFromVirtual("PostMasterTake", ZO_MailInbox, "ZO_DefaultButton")
    PostMaster.takeButton:SetAnchor(TOPLEFT, ZO_MailInboxList, BOTTOMLEFT, 24, 2)
    PostMaster.takeButton:SetText("Take")
    PostMaster.takeButton:SetHandler("OnMouseDown", PostMaster.Take) 
  
    PostMaster.takeAllButton = WINDOW_MANAGER:CreateControlFromVirtual("PostMasterTakeAll", ZO_MailInbox, "ZO_DefaultButton")
    PostMaster.takeAllButton:SetAnchor(TOPRIGHT, ZO_MailInboxList, BOTTOMRIGHT, -24, 2)
    PostMaster.takeAllButton:SetText("Take All")
    PostMaster.takeAllButton:SetHandler("OnMouseDown", PostMaster.TakeAll) 
end

-- Handler for /slash commands
local function commandHandler(text)
    -- Make all input lowercase
    local  input = string.lower(text)

    -- General help when using slash commands
    d("|cFFFFFF---------------------------------------------------------------------------------|r")
    d(zo_strformat("|cEFEBBE<<1>>|r |cFFFFFFby|r |cEFEBBE<<2>>|r |cFFFFFFversion|r |cEFEBBE<<3>>|r", PostMaster.name, PostMaster.author, PostMaster.version))
    d(zo_strformat("|cEE7600<<1>>|r|cFFFFFF: Open your mailbox to interact with the Postmaster frame.|r", PostMaster.shortname))
    d(zo_strformat("|cEE7600<<1>>|r|cFFFFFF: The '|r|cEFEBBETake|r|cFFFFFF' button will Loot and Delete the|r |cEFEBBEcurrently selected|r |cFFFFFFmail.|r", PostMaster.shortname))
    d(zo_strformat("|cEE7600<<1>>|r|cFFFFFF: The '|r|cEFEBBETake All|cFFFFFF' button will Loot and Delete|r |cEFEBBEall|r |cFFFFFFmails in your inbox.|r", PostMaster.shortname))
    d(zo_strformat("|cEE7600<<1>>|r|cFFFFFF: You can now set custom keybinds in the|r |cEFEBBEControls->Keybindings|r |cFFFFFFmenu.|r", PostMaster.shortname))
    d("|cFFFFFF---------------------------------------------------------------------------------|r")
end

-- Initalizing the addon
local function pInitialize(eventCode, addOnName)
    if ( addOnName ~= "Postmaster" ) then return end
    EVENT_MANAGER:UnregisterForEvent(addOnName, eventCode)

    -- Establish EVENT handlers for RegisteredEvents
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_OPEN_MAILBOX, pMailboxOpen)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_CLOSE_MAILBOX, pMailboxClose)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_KEYBINDING_SET, PostMaster.UpdateKeybindInfo)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_INBOX_UPDATE, pMailboxUpdate)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_REMOVED, pEventHandler)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_READABLE, pEventHandler)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, pDeleteProcessedMessage)
    EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS, pDeleteProcessedMessage)

    -- Establish keybinds
    ZO_CreateStringId("SI_BINDING_NAME_TAKE_BUTTON", "Take")
    ZO_CreateStringId("SI_BINDING_NAME_TAKEALL_BUTTON", "Take All")

    -- Establish /slash commands
    SLASH_COMMANDS["/postmaster"] = commandHandler
    SLASH_COMMANDS["/pm"] = commandHandler

    -- Additional functions to run to setup addon
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
                if not (mailData.fromSystem or mailData.returned) then
                    AddMenuItem("Reply", PostMaster.Reply)
                end
                AddMenuItem("Take & Delete", PostMaster.Take)
                if GetNumMailItems() > 1 then
                    AddMenuItem("Take & Delete All", PostMaster.TakeAll)
                end
                if MailR and MailR.SaveMail then
                    AddMenuItem("Save Message", MailR.SaveMail)
                end
                ShowMenu(self)
            end
            return true
        end
    end    
    ZO_PreHook("ZO_MailInboxRow_OnMouseUp", OnMouseUp_Hook) 
end

-- Register events
EVENT_MANAGER:RegisterForEvent("Postmaster", EVENT_ADD_ON_LOADED, pInitialize)
