--[[ 
     A customized version of the ChatProxy class from LibChatMessage
]]--

local addon = Postmaster
local class = addon.classes
local debug = false
local TAG_FORMAT = "[%s]"
local COLOR_FORMAT = "|c%s%s|r"
local baseClass = getmetatable(LibChatMessage("__", "_"))

class.ChatProxy = baseClass:Subclass()

function class.ChatProxy:New(...)
    local chat = baseClass.New(self, ...)
    chat.retainTagColor = true
    chat.tagSuffix = ""
    return chat
end

--- Internal method to retrieve the colored tag. 
--- @return string, the colored tag
function class.ChatProxy:GetTag()
    local tag
    if self.shortTagPrefixEnabled ~= nil then
        tag = self.shortTagPrefixEnabled and self.shortTag or self.longTag
    else
        tag = LibChatMessage.settings.shortTagPrefixEnabled and self.shortTag or self.longTag
    end
    tag = tag .. self.tagSuffix
    tag = TAG_FORMAT:format(tag)
    if(self.tagColor) then
        tag = COLOR_FORMAT:format(self.tagColor, tag)
        if not self.retainTagColor then
            self.tagColor = nil
        end
    end
    return tag
end

function class.ChatProxy:SetRetainTagColor(retainTagColor)
    self.retainTagColor = retainTagColor
end

function class.ChatProxy:SetLongTag(longTag)
    self.longTag = longTag
end

function class.ChatProxy:SetShortTag(shortTag)
    self.shortTag = shortTag
end

function class.ChatProxy:SetShortTagPrefixEnabled(shortTagPrefixEnabled)
    self.shortTagPrefixEnabled = shortTagPrefixEnabled
end

function class.ChatProxy:SetTagSuffix(tagSuffix)
    self.tagSuffix = tagSuffix
end