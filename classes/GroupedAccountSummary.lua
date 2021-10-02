local addon = Postmaster
local class = addon.classes
local debug = false
local getSummary, sortByAccount

class.GroupedAccountSummary = ZO_Object:Subclass()

function class.GroupedAccountSummary:New(...)
    local instance = ZO_Object.New(self)
    self.Initialize(instance, ...)
    return instance
end

function class.GroupedAccountSummary:Initialize(templateSummary)
    self.templateSummary = templateSummary
    self.summaries = {}
end

function class.GroupedAccountSummary:AddCurrency(sender, currencyType, quantity)
    local summary = getSummary(self, sender)
    summary:AddCurrency(currencyType, quantity)
end
function class.GroupedAccountSummary:AddItem(sender, bagId, slotIndex, quantity)
    local summary = getSummary(self, sender)
    summary:AddItem(bagId, slotIndex, quantity)
end
function class.GroupedAccountSummary:AddItemId(sender, itemId, quantity)
    local summary = getSummary(self, sender)
    summary:AddItemId(itemId, quantity)
end
function class.GroupedAccountSummary:AddItemLink(sender, itemLink, quantity, dontChangeStyle)
    local summary = getSummary(self, sender)
    summary:AddItemLink(itemLink, quantity, dontChangeStyle)
end
function class.GroupedAccountSummary:IncrementMailCount(sender)
    local summary = getSummary(self, sender)
    summary:IncrementCounter()
end
function class.GroupedAccountSummary:Print()
    local summaries = {}
    for _, summary in pairs(self.summaries) do
        table.insert(summaries, summary)
    end
    table.sort(summaries, sortByAccount)
    for _, summary in ipairs(summaries) do
        summary:Print()
    end
    self.summaries = {}
end

function getSummary(self, sender)
    local summary = self.summaries[sender]
    if not summary then
        summary = self.templateSummary:Clone()
        summary:SetAccount(sender)
        self.summaries[sender] = summary
    end
    return summary
end

function sortByAccount(summary1, summary2)
    return summary1.account < summary2.account
end