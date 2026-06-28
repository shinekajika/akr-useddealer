Config = {}

-- 中古車ディーラージョブ名
Config.DealerJob = 'used'

-- ジョブガレージ名（jg-advancedgarages側で定義したガレージ名と一致させること）
Config.JobGarage = 'usedcardealer_stock'

-- 出品時の手数料（0.0 = 0%、0.05 = 5%）
Config.ListingFee = 0.01

-- 最大出品台数
Config.MaxListings = 100

-- jg-dealerships に登録するディーラー名（dealerships.lua 側と一致させる）
Config.DealershipName = 'used_cars'

-- コマンド定義
Config.Commands = {
    stockIn   = 'stockin',    -- 乗っている車をジョブガレージへ
    stockOut  = 'stockout',   -- 出品取り下げ → ジョブガレージから出す
    manage    = 'ucmanage',   -- 管理画面を開く
}

-- ショールーム設定
Config.Showroom = {
    camera = vector4(155.2, 6407.65, 32.2, 28.87), -- カメラ位置（要調整）
    previewSpawn = vector4(150.64, 6416.39, 31.31, 254.65), -- 車両プレビュー位置（要調整、既存のshopCoordsと合わせる）
}

-- ジョブガレージの取り出し位置（jg-advancedgarages の spawn 座標と合わせる）
Config.GarageSpawn = vector4(195.3, 6405.04, 31.39, 27.26)

-- NUI テーマカラー
Config.UITheme = {
    primary  = '#e8a020',
    bg       = '#1a1a2e',
    card     = '#16213e',
    text     = '#eaeaea',
}
