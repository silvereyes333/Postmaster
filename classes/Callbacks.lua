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
    MAIL_INBOX_SCENE:RegisterCallback("StateChange", self:CreateCallback("MailInboxStateChange"))
end

function Callbacks:CreateCallback(callbackName)
    return function(...)
        self[callbackName](self, ...)
    end
end

--[[ Raised whenever the inbox is shown or hidden. ]]
function Callbacks:MailInboxStateChange(oldState, newState)
    if IsInGamepadPreferredMode() then return end
    
    addon.Utility.Debug("Callbacks:MailInboxStateChange(" .. tostring(oldState) .. ", " .. tostring(newState) .. ")", debug)
    
    -- Inbox shown
    if newState == SCENE_SHOWN then
        -- Request mail from the server that was originally requested while
        -- the inbox was closed
        if(MAIL_INBOX.requestMailId) then
            MAIL_INBOX:RequestReadMessage(MAIL_INBOX.requestMailId)
            MAIL_INBOX.requestMailId = nil
        end
        -- If a mail is selected that was previously marked for deletion but never
        -- finished, automatically delete it.
        if not addon.Delete:ByMailIdIfPending(MAIL_INBOX.mailId) then
            -- If not deleting mail, then try auto returning mail
            addon.AutoReturn:QueueAndReturn()
        end
    
    -- Inbox hidden
    -- Reset state back to default when inbox hidden, since most server events
    -- will no longer fire with the inbox closed.
    elseif newState == SCENE_HIDDEN then
    
        addon:Reset()
    end
end

addon.Callbacks = Callbacks:New()