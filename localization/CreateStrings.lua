for stringId, value in pairs(POSTMASTER_STRINGS) do
    local stringValue
    if type(value) == "table" then
        if #value > 1 and value[2] ~= POSTMASTER_STRING_NO_FORMAT then
            for i=2,#value do
                if type(value[i]) == "string" then
                    value[i] = _G[value[i]]
                end
                value[i] = GetString(value[i])
            end
            stringValue = zo_strformat(unpack(value))
        else
            stringValue = value[1]
        end
    else
        stringValue = zo_strformat(value, GetString(SI_PM_TAKE_ALL))
    end
	ZO_CreateStringId(stringId, stringValue)
end
POSTMASTER_STRINGS = nil
ZO_CreateStringId("SI_PM_MAIL_DELETE", " + " .. GetString(SI_MAIL_DELETE))