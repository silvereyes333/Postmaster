-- Russian strings
local strings = {
    ["SI_PM_TAKE_ALL_BY_SUBJECT"]                = "Взять по теме",
    ["SI_PM_TAKE_ALL_BY_SENDER"]                 = "Взять по отправитель",
    ["SI_PM_KEYBIND_ENABLE_TOOLTIP"]             = { "Активирует настройки Postmaster: <<1>> и <<2>>", SI_LOOT_TAKE, SI_LOOT_TAKE_ALL },
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    POSTMASTER_STRINGS[stringId] = value
end