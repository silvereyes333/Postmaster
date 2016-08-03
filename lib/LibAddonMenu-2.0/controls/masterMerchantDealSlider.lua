
--[[ Custom slider widget for displaying 

masterMerchantDealSliderData = {
    type = "masterMerchantDealSlider",
    ...
    <see>lib\LibAddonMenu-2.0\controls\slider.lua for all options</see>
    min, max, and step arguments are ignored/overwritten
} ]]

local widgetVersion = 1
local LAM = LibStub("LibAddonMenu-2.0")
if not LAM:RegisterWidget("masterMerchantDealSlider", widgetVersion) then return end

local function GetMasterMerchantDealText(value)
    local stringId = _G["SI_PM_COD_MM_DEAL_"..tostring(value)]
    return GetString(stringId)
end
local isOverSlider
local function MasterMerchantSliderEnter(self)
    isOverSlider = true
    
    -- Anchor the tooltip to the tracker control
    local thumbTexture = self:GetThumbTextureControl()
    InitializeTooltip(InformationTooltip, thumbTexture, BOTTOM, 0, -2, TOP)
    
    -- Update the tooltip to be the MM deal text for the current value
    local tooltipText = GetMasterMerchantDealText(self:GetValue())
    SetTooltipText(InformationTooltip, tooltipText)
end
local function MasterMerchantSliderExit(self)
    isOverSlider = false
    -- Hide tooltip
    ZO_Options_OnMouseExit(self)
end
local originalSliderSetValue
local function SliderSetValue(self, value)
    
    -- Set the tracker texture color using the item quality color for the deal value
    local colorType, fieldValue
    if value == ITEM_QUALITY_TRASH then
        colorType  = INTERFACE_COLOR_TYPE_GENERAL
        fieldValue = INTERFACE_GENERAL_COLOR_ERROR
    else
        colorType  = INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS
        fieldValue = value
    end
    local r, g, b = GetInterfaceColor(colorType, fieldValue)
    self:GetThumbTextureControl():SetColor(r, g, b, 1)
    
    -- Call the original slider SetValue() method
    originalSliderSetValue(self, value)
    
    -- Refresh tooltip if the mouse is currently over the slider
    if isOverSlider then MasterMerchantSliderEnter(self) end
end
local disabled
local function Disabled()
    if not MasterMerchant then
        return true
    elseif disabled then
        return disabled()
    end
end
--[[ Slider constructor ]]
function LAMCreateControl.masterMerchantDealSlider(parent, sliderData, controlName)

    -- Set default min and max to be min and max item quality
    sliderData.min       = ITEM_QUALITY_TRASH
    sliderData.max       = ITEM_QUALITY_LEGENDARY
    sliderData.step      = 1
    
    -- Wire up Master Merchant detection for disabled and warning methods
    disabled = sliderData.disabled
    sliderData.disabled = Disabled
    if not sliderData.warning then
        sliderData.warning = not MasterMerchant and GetString(SI_PM_MASTER_MERCHANT_WARNING)
    end

    -- Call the default LAM-2.0 slider constructor. The rest of this method will
    -- just be tweaks.
    local control = LAMCreateControl.slider(parent, sliderData, controlName)
    local slider = control.slider
    
    -- Save the original SetValue function definition for the slider.
    -- It is used in our custom SliderSetValue() method.
    originalSliderSetValue = slider.SetValue
    
    -- Override the slider SetValue with our custom method
    slider.SetValue = SliderSetValue
    
    -- Show the text representations of MM deals for min and max, rather than
    -- their numerical equivalents
    control.minText:SetText(GetMasterMerchantDealText(sliderData.min))
    control.maxText:SetText(GetMasterMerchantDealText(sliderData.max))
    
    -- Set the active texture to empty and disabled texture to a grey square
    slider:SetThumbTexture(nil, "art/fx/texture/graysquare.dds", nil, 8, 16)
    
    -- Set the texture dimensions
    local thumbTexture = slider:GetThumbTextureControl()
    thumbTexture:SetDimensions(15, 15)
    
    -- Hide the slider textbox and textbox background
    control.slidervalue:SetHidden(true)
    control.slidervalueBG:SetHidden(true)
    
    -- Initialize the slider value and color
    slider:SetValue(sliderData.getFunc())
    
    -- Override tooltips on the slider itself
    slider:SetHandler("OnMouseEnter", MasterMerchantSliderEnter)
    slider:SetHandler("OnMouseExit", MasterMerchantSliderExit)
    
    return control
end