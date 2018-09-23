local strings = {
    ["SI_LSV_ACCOUNT_WIDE"]    = "Настройки на всех персонажей",
    ["SI_LSV_ACCOUNT_WIDE_TT"] = "Все настройки ниже будут применены ко всем персонажам.",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    LIBSAVEDVARS_STRINGS[stringId] = value
end