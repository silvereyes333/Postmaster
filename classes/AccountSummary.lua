--[[ 
     A customized version of the List class from LibLootSummary
]]--

local addon = Postmaster
local class = addon.classes
local debug = false

class.AccountSummary = LibLootSummary.List:Subclass()

function class.AccountSummary:New(...)
    return LibLootSummary.List.New(self, ...)
end

function class.AccountSummary:Initialize(options)
    LibLootSummary.List.Initialize(self, options)
    self.mailType = options and options.mailType or "received"
    if self.mailType == "received" then
        self.mailIcon = "/esoui/art/tutorial/gamepad/gp_mailmenu_mailtype_read.dds"
    else
        self.mailIcon = "/esoui/art/tutorial/gamepad/gp_mailmenu_mailtype_replied.dds"
    end
end

function class.AccountSummary:Clone()
    local summary = class.AccountSummary:New(self.options)
    summary.chat = self.chat
    summary.account = self.account
    summary.counterText = self.counterText
    summary.defaults = self.defaults
    summary.mailIcon = self.mailIcon
    summary.mailType = self.mailType
    summary.prefix = self.prefix
    summary.suffix = self.suffix
    return summary
end

function class.AccountSummary:SetAccount(account)
    self.account = account
end

--[[ Outputs a verbose summary of all loot and currency ]]
function class.AccountSummary:Print()
    local tagSuffix = self.chat.tagSuffix
    if self.account then
        local mailIconSize = math.max(self:GetOption('iconSize'), 100)
        mailIconSize = string.format("%s%%", tostring(mailIconSize))
        local mailIconString = zo_iconFormatInheritColor(self.mailIcon, mailIconSize, mailIconSize)
        local account = mailIconString .. self.account
        if not self.chat.tagColor then
            account = self.prefix .. account .. self.suffix
        end
        self.chat:SetTagSuffix(account)
    end
    LibLootSummary.List.Print(self)
    self.chat:SetTagSuffix(tagSuffix)
end