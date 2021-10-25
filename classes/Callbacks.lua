--[[ 
    ===================================
             CALLBACK HANDLERS
    ===================================
  ]]
  
local addon = Postmaster
local debug = false

-- Singleton class
local Callbacks = ZO_Object:Subclass()

function Callbacks:New()
    return ZO_Object.New(self)
end
  
--[[ Wire up all callback handlers ]]
function Callbacks:Initialize()
    CALLBACK_MANAGER:RegisterCallback("BackpackFullUpdate", self:CreateCallback(self.BackpackFullUpdate))
    local stateChangeCallback = self:CreateCallback(self.MailInboxStateChange)
    MAIL_INBOX_SCENE:RegisterCallback("StateChange", stateChangeCallback)
    GAMEPAD_MAIL_INBOX_FRAGMENT:RegisterCallback("StateChange", stateChangeCallback)
end

--[[ Raised whenever the backpack inventory is populated. ]]
function Callbacks:BackpackFullUpdate()
    -- Initialize or refresh the unique items manager, which tracks all unique items in the backpack.
    if addon.UniqueBackpackItemsList then
        addon.UniqueBackpackItemsList:ScanBag()
    else
        addon.UniqueBackpackItemsList = addon.classes.UniqueBagItemsList:New(BAG_BACKPACK)
    end
end

function Callbacks:CreateCallback(callback)
    return function(...)
        callback(self, ...)
    end
end

--[[ Raised whenever the inbox is shown or hidden. ]]
function Callbacks:MailInboxStateChange(oldState, newState)
    
    addon.Utility.Debug("Callbacks:MailInboxStateChange(" .. tostring(oldState) .. ", " .. tostring(newState) .. ")", debug)
    
    -- Inbox shown
    if newState == SCENE_SHOWN then
        
        addon.Prehooks:InboxRefreshAttachmentsHeaderShown(MAIL_INBOX)
      
        -- Delete any mail that was requested to be deleted, but failed because the inbox hid before.
        -- Note, if this is true, AutoReturn:QueueAndReturn() will be run after it finishes.
        if addon.Delete:DeleteQueued() then
            return
        end
        
        -- If not deleting mail, then try auto returning mail
        if addon.AutoReturn:QueueAndReturn() then
            return
        end
    
    -- Inbox hidden
    -- Reset state back to default when inbox hidden, since most server events
    -- will no longer fire with the inbox closed.
    elseif newState == SCENE_HIDDEN then
    
        addon:Reset()
    end
end

addon.Callbacks = Callbacks:New()