--[[ 
    Tracks unique items in an inventory bag.
  ]]
  
local addon = Postmaster
local class = addon.classes
local debug = false

addon.classes.UniqueBagItemsList = ZO_InitializingObject:Subclass()
  
--[[ Wire up all callback handlers ]]
function class.UniqueBagItemsList:Initialize(bagId)
    self.bagId = bagId
    self.uniqueItemIds = {}
    for slotIndex in ZO_IterateBagSlots(self.bagId) do
        self:Update(slotIndex)
    end
end

--[[ Returns true if the given item link is for a unique item that is already in the bag. ]]--
function class.UniqueBagItemsList:ContainsItemLink(itemLink)
    local isUnique = IsItemLinkUnique(itemLink)
    if isUnique then
        local itemId = GetItemLinkItemId(itemLink)
        if self.uniqueItemIds[itemId] then
            return true
        end
    end
end

--[[ Registers a potential backpack slot as unique ]]--
function class.UniqueBagItemsList:Update(slotIndex)
    local itemLink = GetItemLink(self.bagId, slotIndex)
    if not itemLink or itemLink == "" then
        return
    end
    local itemId = GetItemLinkItemId(itemLink)
    self.uniqueItemIds[itemId] = IsItemLinkUnique(itemLink) or nil
end
