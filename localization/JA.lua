-- Japanese strings
local strings = {
    ["SI_PM_WORD_SEPARATOR"]                     = "",
    ["SI_PM_CHAT_MESSAGES"]                      = "チャットメッセージ",
    ["SI_PM_SHORT_PREFIX"]                       = "短いプレフィックスを使用",
    ["SI_PM_SHORT_PREFIX_TOOLTIP"]               = "チャットメッセージの先頭に[Postmaster]ではなく[PM]を付けます。",
    ["SI_PM_PREFIX_HEADER"]                      = "プレフィックス",
    ["SI_PM_COLORED_PREFIX"]                     = "Postmaster 3.8プレフィックスカラーを使用",
    ["SI_PM_COLORED_PREFIX_TOOLTIP"]             = { "チャットメッセージのプレフィックスの色として、[チャットメッセージの色]設定ではなく、青いPostmaster 3.8の色（<<1>>|rまたは<<2>>|r）を使用します。", SI_PM_PREFIX_COLOR, SI_PM_PREFIX_SHORT_COLOR },
    ["SI_PM_CHAT_USE_SYSTEM_COLOR"]              = "システムチャットメッセージと同じ色を使用する",
    ["SI_PM_CHAT_COLOR"]                         = "チャットメッセージの色",
    ["SI_PM_DELETE_DIALOG_SUPPRESS"]             = "削除確認を抑制",
    ["SI_PM_DELETE_DIALOG_SUPPRESS_TOOLTIP"]     = "このオプションが有効化されている場合、添付ファイルのないメッセージを削除するときに、確認が出ることがなくなります。メッセージは即座に削除されます。",
    ["SI_PM_RETURN_DIALOG_SUPPRESS"]             = "返却確認を抑制",
    ["SI_PM_BOUNCE"]                             = "自動メール返却",
    ["SI_PM_BOUNCE_TOOLTIP"]                     = "インボックスの新規メールをモニターし、もしサブジェクトがRETURN、BOUNCE、RTSのどれかから始まるか、一致した場合送信者に自動的に返却します。",
    ["SI_PM_BOUNCE_MESSAGE"]                     = { "<<1>>からの返却メール", POSTMASTER_STRING_NO_FORMAT },
    ["SI_PM_WYKKYD_MAILBOX_RETURN_WARNING"]      = "Wykkyd Mailbox返却ボットが有効になっています。",
    ["SI_PM_WYKKYD_MAILBOX_DETECTED_WARNING"]    = "Wykkyd Mailboxが検知されました。自動メール返却はWykkyd Mailbox返却ボットが有効化されている場合、無効化されるので注意してください。",
    ["SI_PM_RESERVED_SLOTS"]                     = "予約済みスロット",
    ["SI_PM_RESERVED_SLOTS_TOOLTIP"]             = "<<1>> が設定したスロットの数バックパックを空けておいてくれます。",
    ["SI_PM_SYSTEM"]                             = "システムメール",
    ["SI_PM_SYSTEM_TAKE_ATTACHED"]               = "添付アイテムありのシステムメール",
    ["SI_PM_SYSTEM_DELETE_ATTACHED"]             = "添付アイテムありのシステムメールを削除する",
    ["SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP"]       = "このオプションが有効化されている場合、<<1>>コマンドは添付ファイルがある雇用メールやAvAリワードメールと言ったシステムメールから添付されたファイルを取得し、要求時削除します。",
    ["SI_PM_SYSTEM_TAKE_ATTACHED_TOOLTIP_QUICK"] = { "このオプションが有効化されている場合、<<1>>コマンドは添付ファイルがある雇用メールやAvAリワードメールと言ったシステムメールから添付されたファイルを取得し、削除します。", SI_PM_TAKE },
    ["SI_PM_SYSTEM_TAKE_PVP"]                    = "PvP・同盟戦争の報酬",
    ["SI_PM_SYSTEM_TAKE_CRAFTING"]               = "雇用メール",
    ["SI_PM_SYSTEM_TAKE_UNDAUNTED"]              = "ダンジョンとトライアル・アンドーンテッド",
    ["SI_PM_SYSTEM_TAKE_OTHER"]                  = "他のすべて添付アイテム",
    ["SI_PM_SYSTEM_DELETE_EMPTY"]                = "添付ファイルのないシステムメールを削除",
    ["SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP"]        = "このオプションが有効化されている場合、<<1>>コマンドはアイテムがコレクションに追加されたなどの通知のような、添付ファイルのないシステムメールを削除します。",
    ["SI_PM_SYSTEM_DELETE_EMPTY_TOOLTIP_QUICK"]  = { "このオプションが有効化されている場合、<<1>>コマンドはアイテムがコレクションに追加されたなどの通知のような、添付ファイルのないシステムメールを削除します。", SI_PM_TAKE },
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER"]         = "添付ファイルのないシステムメールフィルタ",
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER_TOOLTIP"] = { "このフィルタが空白ではない場合、<<1>>コマンドは設定されたワードやフレーズが送信者、サブジェクト、添付されたアイテムのないシステムメールを削除します。<<2>>", SI_PM_TAKE_ALL, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_SYSTEM_DELETE_EMPTY_FILTER_TOOLTIP_QUICK"] = { "このフィルタが空白ではない場合、<<1>>コマンドは設定されたワードやフレーズが送信者、サブジェクト、添付されたアイテムのないシステムメールを削除します。<<2>>", SI_PM_TAKE, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_PLAYER"]                             = "プレイヤーメール",
    ["SI_PM_PLAYER_TAKE_ATTACHED"]               = "添付ファイルありのプレイヤーメール",
    ["SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP"]       = "このオプションが有効化されている場合、<<1>>コマンドは着払いでない他プレイヤーからの添付ファイルありのメールから添付されたファイルを取得し、要求時削除します。",
    ["SI_PM_PLAYER_TAKE_ATTACHED_TOOLTIP_QUICK"] = { "このオプションが有効化されている場合、<<1>>コマンドは着払いでない他プレイヤーからの添付ファイルありのメールから添付されたファイルを取得し、削除します。", SI_PM_TAKE },
    ["SI_PM_PLAYER_TAKE_RETURNED"]               = "返却メール",
    ["SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP"]       = "このオプションが有効化されている場合、<<1>>コマンドは他のプレイヤーから返信されてきたどのメールからも添付ファイルを受け取り、要求時削除します。",
    ["SI_PM_PLAYER_TAKE_RETURNED_TOOLTIP_QUICK"] = { "このオプションが有効化されている場合、<<1>>コマンドは他のプレイヤーから返信されてきたどのメールからも添付ファイルを受け取り、削除します。", SI_PM_TAKE },
    ["SI_PM_PLAYER_DELETE_EMPTY"]                = "添付ファイルのないプレイヤーメールを削除",
    ["SI_PM_PLAYER_DELETE_EMPTY_TOOLTIP_QUICK"]  = { "このオプションが有効化されている場合、<<1>>コマンドは、他プレイヤーからの添付ファイルのないメールを削除します。", SI_PM_TAKE },
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER"]         = "添付ファイルのないプレイヤーメールフィルタ",
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER_TOOLTIP"] = { "このフィルタが空白ではない場合、<<1>>コマンドは設定されたワードやフレーズが送信者、サブジェクト、添付されたアイテムのない他プレイヤーからのメールを削除します。<<2>>", SI_PM_TAKE_ALL, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_PLAYER_DELETE_EMPTY_FILTER_TOOLTIP_QUICK"] = { "このフィルタが空白ではない場合、<<1>>コマンドは設定されたワードやフレーズが送信者、サブジェクト、添付されたアイテムのない他プレイヤーからのメールを削除します。<<2>>", SI_PM_TAKE, "SI_PM_SEPARATOR_HINT" },
    ["SI_PM_COD"]                                = { "<<1>> メール", SI_MAIL_SEND_COD },
    ["SI_PM_COD_TOOLTIP"]                        = { "このオプションが有効化されている場合、<<1>>コマンドは、<<2>>メールを以下の基準にそって取得します。", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_COD_TOOLTIP_QUICK"]                  = { "このオプションが有効化されている場合、<<1>>コマンドは、<<2>>メールを以下の基準にそって取得します。", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_COD_LIMIT"]                          = { "<<1>> リミット", SI_MAIL_SEND_COD },
    ["SI_PM_COD_LIMIT_TOOLTIP"]                  = { "この値より少ない量の<<1>>メールのみ支払われます。(0)に設定すると無制限になります。", SI_MAIL_SEND_COD },
    ["SI_PM_MASTER_MERCHANT_WARNING"]            = "Master Merchantが有効化されていません。",
    ["SI_PM_COD_MM_DEAL_0"]                      = "高価すぎる",
    ["SI_PM_COD_MM_DEAL_1"]                      = "Ok",
    ["SI_PM_COD_MM_DEAL_2"]                      = "値頃",
    ["SI_PM_COD_MM_DEAL_3"]                      = "良い",
    ["SI_PM_COD_MM_DEAL_4"]                      = "素晴らしい",
    ["SI_PM_COD_MM_DEAL_5"]                      = "買うべき！",
    ["SI_PM_COD_MM_MIN_DEAL"]                    = { "<<1>> 最小取引", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_MIN_DEAL_TOOLTIP"]            = { "<<1>>メールの添付アイテムを分析し、関連したMaster Merchantマーケットの値段で最小でも良い取引でないと支払いません。'高価すぎる'をセットすることで無制限になります。", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA"]                     = { "Master Merchantデータのない<<1>>", SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA_TOOLTIP"]             = { "このオプションが有効化されている場合、<<1>>コマンドはMaster Merchant値段データのない<<2>>メールの添付ファイルを取得します。", SI_PM_TAKE_ALL, SI_MAIL_SEND_COD },
    ["SI_PM_COD_MM_NO_DATA_TOOLTIP_QUICK"]       = { "このオプションが有効化されている場合、<<1>>コマンドはMaster Merchant値段データのない<<2>>メールの添付ファイルを取得します。", SI_PM_TAKE, SI_MAIL_SEND_COD },
    ["SI_PM_HELP_01"]                            = "|cFF00FF/pm|rか|cFF00FF/postmaster|rコマンドはチャットウィンドウで使用することにより、このオプション画面へのショートカットとして使用できます。",
    ["SI_PM_HELP_02"]                            = { "<<1>>とインタラクトするには、メールインボックスを開いてください。", SI_PM_NAME },
    ["SI_PM_HELP_03"]                            = { "<<1>>ボタンは、|cEFEBBE現在選択されている|rメールを取得し、削除します。", SI_PM_TAKE },
    ["SI_PM_HELP_04"]                            = "<<1>>ボタンは下記オプションと合致したインボックスにある|cEFEBBE全ての|rメールを取得し、削除します。",
    ["SI_PM_CRAFT_BLACKSMITH"]                   = "鍛冶師用素材",
    ["SI_PM_CRAFT_CLOTHIER"]                     = "仕立師用素材",
    ["SI_PM_CRAFT_ENCHANTER"]                    = "付呪師用素材",
    ["SI_PM_CRAFT_PROVISIONER"]                  = "調理師用素材",
    ["SI_PM_CRAFT_WOODWORKER"]                   = "木工師用素材",
    ["SI_PM_GUILD_STORE_CANCELED"]               = "アイテム掲載取消",
    ["SI_PM_GUILD_STORE_EXPIRED"]                = "アイテム掲載終了",
    ["SI_PM_GUILD_STORE_PURCHASED"]              = "アイテム購入",
    ["SI_PM_GUILD_STORE_SOLD"]                   = "アイテム売却",
    ["SI_PM_PVP_FOR_THE_WORTHY"]                 = "貢献に見合った報酬です！",
    ["SI_PM_PVP_THANKS"]                         = "戦士よ、貴殿に感謝を",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_1"]             = "ドミニオンの為に！",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_2"]             = "パクトの為に！",
    ["SI_PM_PVP_FOR_THE_ALLIANCE_3"]             = "カバナントの為に！",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_1"]          = "ドミニオンより感謝を",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_2"]          = "パクトより感謝を",
    ["SI_PM_PVP_THE_ALLIANCE_THANKS_3"]          = "カバナントより感謝を",
    ["SI_PM_PVP_LOYALTY"]                        = "戦役忠誠褒賞",
    ["SI_PM_UNDAUNTED_NPC_NORMAL"]               = "マジ・アルラガス",
    ["SI_PM_UNDAUNTED_NPC_VET"]                  = "赤髭グリリオン",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_1"]              = "赤爪トゥルク",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_2"]              = "斧のカイルスティグ",
    ["SI_PM_UNDAUNTED_NPC_TRIAL_3"]              = "強きモルドラ",
    ["SI_PM_BATTLEGROUNDS_NPC"]                  = "バトルマスター・リヴィン",
    ["SI_PM_DELETE_FAILED"]                      = "メールの削除で問題が発生しました。もう一度やり直してください。",
    ["SI_PM_TAKE_ATTACHMENTS_FAILED"]            = "添付ファイルの収集に問題がありました。もう一度やり直してください。",
    ["SI_PM_READ_FAILED"]                        = "次の電子メールメッセージの読み取りに問題がありました。もう一度やり直してください。",
    ["SI_PM_MESSAGE"]                            = "メッセージ",
    ["SI_PM_KEYBOARD"]                           = "(キーボード)",
    ["SI_PM_TAKE_ALL_BY_SUBJECT"]                = "件名で取る",
    ["SI_PM_TAKE_ALL_BY_SENDER"]                 = "差出人で取る",
    ["SI_PM_KEYBIND_ENABLE_TOOLTIP"]             = { "Postmasterショートカットをアクティブにします：<<1>>および<<2>>", SI_LOOT_TAKE, SI_LOOT_TAKE_ALL },

    --Baertram - Mail Send save message settings
    ["SI_PM_SENDMAIL_MESSAGE_RECIPIENTS"]        = "受信者を保存",
    ["SI_PM_SENDMAIL_MESSAGE_RECIPIENTS_TT"]     = "最近送信された電子メール受信者のリストは、電子メールを送信した後に自動的に保存されます。メールを作成しているときに、メール受信者のテキストボックスを右クリックして、リストを表示します。",
    ["SI_PM_SENDMAIL_MESSAGE_SUBJECTS"]          = "件名を保存",
    ["SI_PM_SENDMAIL_MESSAGE_SUBJECTS_TT"]       = "最近送信された電子メールの件名のリストは、電子メールを送信した後に自動的に保存されます。メールを作成しているときに、メールの件名のテキストボックスを右クリックして、リストを表示します。",
    ["SI_PM_SENDMAIL_MESSAGE_TEXT"]              = "メッセージテキストを保存",
    ["SI_PM_SENDMAIL_MESSAGE_TEXT_TT"]           = "最近送信された電子メールメッセージのリストは、電子メールを送信した後に自動的に保存されます。電子メールの作成中に、電子メールメッセージのテキストボックスを右クリックしてリストを表示します。",
    ["SI_PM_SENDMAIL_MESSAGE_RECENT_SUBJECTS"]   = "最近のテーマ",
    ["SI_PM_SENDMAIL_MESSAGE_RECENT_TEXT"]       = "最近のメッセージ",
    ["SI_PM_SENDMAIL_AMOUNT"]                    = "保存する最近のエントリの数",
    ["SI_PM_SENDMAIL_PREVIEW_CHARS"]             = "最近のメッセージメニュー文字幅",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    POSTMASTER_STRINGS[stringId] = value
end