--[[
    ===============================================================================
          SEND MAIL SAVE - by Baertram
          Save the receiver, subject, body text of manually created mails
          and allow to select from previously saved values via a right click
          context menu at the ZO_MailSend fields
    ===============================================================================
  ]]
     
local addon = Postmaster
local debug = false

-- Singleton class
local SendMail = ZO_Object:Subclass()

function SendMail:New(...)
    local instance = ZO_Object.New(self)
    instance.name = addon.name .. "SendMail"
    return instance
end

function SendMail:Initialize()
    
    self.fields = {
        
        addon.classes.SendMailField:New(
            ZO_MailSendToField, "sendmailSaveRecipients", "sendmailRecipients", GetString(SI_GAMEPAD_MAIL_SEND_RECENT_CONTACTS)),
        
        addon.classes.SendMailField:New(
            ZO_MailSendSubjectField, "sendmailSaveSubjects", "sendmailSubjects", GetString(SI_PM_SENDMAIL_MESSAGE_RECENT_SUBJECTS)),
        
        addon.classes.SendMailField:New(
            ZO_MailSendBodyField, "sendmailSaveMessages", "sendmailMessages", GetString(SI_PM_SENDMAIL_MESSAGE_RECENT_TEXT),
            addon.settings.sendmailMessagesPreviewChars),
    }
    
    self.fieldsByValueSettingsKeys = {}
    for _, field in ipairs(self.fields) do
        self.fieldsByValueSettingsKeys[field.settingsKeyValues] = field
    end
end

function SendMail:GetField(key)
    return self.fieldsByValueSettingsKeys[key]
end

function SendMail:SaveData()
    for _, field in ipairs(self.fields) do
        if field:IsEnabled() then
            field:SaveControlTextToValues()
        end
    end
end

addon.SendMail = SendMail:New()