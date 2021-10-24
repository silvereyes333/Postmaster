--[[   
 
    Represents a field in the Send Mail panel that can have its recent values saved and restored in a context menu.
    
  ]]

local addon = Postmaster
local class = addon.classes
local debug = false
local closure, noop, trimTableEntries, timestampCompare
local strsub = string.sub
local strlen = ZoUTF8StringLength
local PM_REMOVE_MENU_INDENT = "|t100%:100%:Postmaster/art/remove.dds|t"

class.SendMailField = ZO_Object:Subclass()

function class.SendMailField:New(...)
    local instance = ZO_Object.New(self)
    instance.name = addon.name .. "SendMailField"
    instance:Initialize(...)
    return instance
end

function class.SendMailField:Initialize(control, settingsKeyEnabled, settingsKeyValues, contextMenuLabel, previewChars)
    self.control = control
    self.settingsKeyEnabled = settingsKeyEnabled
    self.settingsKeyValues = settingsKeyValues
    self.contextMenuLabel = contextMenuLabel
    self.previewChars = previewChars
    
    if LibCustomMenu then
        local handlerName = self.name .. "_" .. self.control:GetName() .. "_OnMouseUp"
        self.control:SetHandler("OnMouseUp",
            closure(self, self.OnControlMouseUp), handlerName, CONTROL_HANDLER_ORDER_NONE, nil)
    end
    
    self:TrimSavedValues()
    
    addon.Utility.Debug("Initialized SendMailField " .. tostring(self.contextMenuLabel), debug)
end

function class.SendMailField:Clear()
    ZO_ClearNumericallyIndexedTable(addon.settings[self.settingsKeyValues])
end

function class.SendMailField:CreateOnEntrySelectedClosure(entryText)
    return function()
        self:OnEntrySelected(entryText)
    end
end

function class.SendMailField:CreateRemoveEntryClosure(entryText)
    return function()
        self:RemoveEntry(entryText)
    end
end

function class.SendMailField:GetSavedValues()
    return addon.settings[self.settingsKeyValues]
end

function class.SendMailField:IsEnabled()
    return addon.settings[self.settingsKeyEnabled]
end

function class.SendMailField:OnControlMouseUp(control, mouseButton, upInside, altKey, shiftKey, ctrlKey, commandKey)
    
    if not upInside or mouseButton ~= MOUSE_BUTTON_INDEX_RIGHT then 
        ClearMenu()
        return
    end
    
    local savedValues = self:GetSavedValues()
    if savedValues == nil or #savedValues == 0 then
        return
    end

    ClearMenu()
    AddCustomMenuItem(self.contextMenuLabel, noop, MENU_ADD_OPTION_HEADER)
    
    local removeEntries = {}
    for entryIdx, entryData in ipairs(savedValues) do
        local entryText = entryData.text
        if entryText and entryText ~= "" then
            local formattedEntryText = entryText
            if self.previewChars and strlen(entryText) > self.previewChars then
                formattedEntryText = (strsub(formattedEntryText, 1, self.previewChars) .. "...")
            end
            AddCustomMenuItem(formattedEntryText,
                self:CreateOnEntrySelectedClosure(entryText),
                MENU_ADD_OPTION_LABEL
            )
            table.insert(removeEntries, {
                label = formattedEntryText,
                callback = self:CreateRemoveEntryClosure(entryText)
            })
        end
    end
    
    -- Divider
    AddCustomMenuItem("-")
    
    -- Remove sub-menu
    local removeLabel = PM_REMOVE_MENU_INDENT .. GetString(SI_ABILITY_ACTION_CLEAR_SLOT)
    AddCustomSubMenuItem(removeLabel, removeEntries)
    
    ShowMenu(control)
end

function class.SendMailField:OnEntrySelected(entryText)
    if self.control.SetText then
        self.control:SetText(entryText)
    end
end

function class.SendMailField:RemoveEntry(entryText)
    local savedValues = self:GetSavedValues()
    if not savedValues then
        return
    end
    for i=#savedValues, 1, -1 do
        local value = savedValues[i]
        if value.text == entryText then
            table.remove(savedValues, i)
            return
        end
    end
end

function class.SendMailField:SaveControlTextToValues()
    if not self.control or self.control and not self.control.GetText then
        return
    end
    
    local textToAdd = self.control:GetText()
    if textToAdd == nil or textToAdd == "" then
        return
    end

    local timeStamp = GetTimeStamp()

    --Add it to the SavedVariables table, if not already in there
    local savedValues = self:GetSavedValues()
    for _, oldEntryData in ipairs(savedValues) do
        if oldEntryData.text == textToAdd then
            return
        end
    end

    --Prepare the new entry
    local newEntry = {
        timestamp = timeStamp,
        text = textToAdd,
    }
    table.insert(savedValues, newEntry)
    
    self:TrimSavedValues()
end

function class.SendMailField:SetSavedValues(values)
    addon.settings[self.settingsKeyValues] = values
end

function class.SendMailField:TrimSavedValues()

    local savedValues = self:GetSavedValues()
    
    --Settings enabled and data was saved before?
    if not savedValues then
        return
    end

    --Check if the entries in the context menu needs to be trimmed
    local trimmedTable = trimTableEntries(savedValues)
    if trimmedTable then
        self:SetSavedValues(trimmedTable)
    end
end

function closure(self, callback)
    return function(...)
        return callback(self, ...)
    end
end

function noop()
end

function timestampCompare(a, b)
    return a.timestamp > b.timestamp
end

function trimTableEntries(entries)
    if not entries then
        return
    end

    local trimmedEntries
    local maxSavedEntries = addon.settings.sendmailSavedEntryCount
    
    maxSavedEntries = (maxSavedEntries ~= nil and maxSavedEntries > 0 and maxSavedEntries)
                      or addon.defaults.sendmailSavedEntryCount --fallback: 10 entries
    
    if #entries > maxSavedEntries then
        trimmedEntries = ZO_ShallowTableCopy(entries)
    else
        return
    end

    --Sort the SV table by timestamp: Newest first, oldest last
    table.sort(trimmedEntries, timestampCompare)

    --Delete all entries which are > maxSavedEntries
    for i=maxSavedEntries+1, #trimmedEntries, 1 do
        if trimmedEntries[i] ~= nil then
            trimmedEntries[i] = nil
        end
    end
    return trimmedEntries
end