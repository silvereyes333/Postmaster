local strings = {
    ["SI_LSV_ACCOUNT_WIDE"]    = "アカウント全体設定",
    ["SI_LSV_ACCOUNT_WIDE_TT"] = "全キャラクターで以下の設定が同じになります。",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    LIBSAVEDVARS_STRINGS[stringId] = value
end