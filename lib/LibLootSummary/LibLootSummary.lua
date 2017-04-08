-- LibLootSummary & its files © silvereyes                          --
-- Distributed under the MIT license (see LICENSE.txt)          --
------------------------------------------------------------------

--Register LTO with LibStub
local MAJOR, MINOR = "LibLootSummary", 1
local lls, minorVersion = LibStub:NewLibrary(MAJOR, MINOR)
if not lls then return end --the same or newer version of this lib is already loaded into memory

local lootList = {}
local currencyList = {}
local prefix = ""
local delimiter = " "
local linkStyle = LINK_STYLE_DEFAULT
local linkFormat = "|H%s:item:%s:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local combineDuplicates = true
local function AddQuantity(list, key, quantity)
    if list[key] then
        if combineDuplicates then
            list[key][1] = list[key][1] + quantity
        else
            table.insert(list[key], quantity)
        end
    else
        list[key] = { [1] = quantity }
    end
end
function lls:AddCurrency(currencyType, quantity)
    AddQuantity(currencyList, currencyType, quantity)
end
function lls:AddItem(bagId, slotIndex, quantity)
    local itemLink = GetItemLink(bagId, slotIndex, linkStyle)
    if not quantity then
        local stackSize, maxStackSize = GetSlotStackSize(bagId, slotIndex)
        quantity = math.min(stackSize, maxStackSize)
    end
    self:AddItemLink(itemLink, quantity, true)
end
function lls:AddItemId(itemId, quantity)
    local itemLink = string.format(linkFormat, linkStyle, itemId)
    self:AddItemLink(itemLink, quantity, true)
end
function lls:AddItemLink(itemLink, quantity, dontChangeStyle)

    if not dontChangeStyle then
        itemLink = string.gsub(itemLink, "|H[0-1]:", "|H"..tostring(linkStyle)..":")
    end
    
    AddQuantity(lootList, itemLink, quantity)
end
local function appendText(text, currentText, maxLength, lines)
    local newLine
    if string.len(currentText) + string.len(delimiter) + string.len(text) > maxLength then
        table.insert(lines, currentText)
        currentText = prefix
    elseif string.len(currentText) > string.len(prefix) then
        currentText = currentText .. delimiter
    end
    currentText = currentText .. text
    return currentText
end

--[[ Outputs a verbose summary of all loot and currency ]]
function lls:Print()

    local summary = prefix
    local maxLength = MAX_TEXT_CHAT_INPUT_CHARACTERS - string.len(prefix)
    
    -- Add items summary
    local lines = {}
    for itemLink, quantities in pairs(lootList) do
        for _, quantity in ipairs(quantities) do
            local countString = zo_strformat(GetString(SI_HOOK_POINT_STORE_REPAIR_KIT_COUNT), quantity)
            local itemString = zo_strformat("<<1>> <<2>>", itemLink, countString)
            summary = appendText(itemString, summary, maxLength, lines)
        end
    end
    
    -- Add money summary
    for currencyType, quantities in pairs(currencyList) do
        for _, quantity in ipairs(quantities) do
            local moneyString = zo_strformat("<<1>>", 
                                            ZO_CurrencyControl_FormatCurrencyAndAppendIcon(
                                                quantity, true, currencyType, IsInGamepadPreferredMode()))
            summary = appendText(moneyString, summary, maxLength, lines)
        end
    end
    
    -- Append last line
    if string.len(summary) > string.len(prefix) then
        table.insert(lines, summary)
    end
    
    -- Print to chat
    for _, line in ipairs(lines) do
        d(line)
    end
    
    self:Reset()
end

function lls:Reset()
    -- Reset lists
    lootList = {}
    currencyList = {}
    
    -- Reset options
    prefix = ""
    delimiter = " "
    linkStyle = LINK_STYLE_DEFAULT
    combineDuplicates = true
end

function lls:SetCombineDuplicates(newCombineDuplicates)
    combineDuplicates = newCombineDuplicates
end

function lls:SetDelimiter(newDelimiter)
    delimiter = newDelimiter
end

function lls:SetLinkStyle(newLinkStyle)
    linkStyle = newLinkStyle
end

function lls:SetPrefix(newPrefix)
    prefix = newPrefix
end