-- ============================================================
--  usedcar-dealer  server/main.lua
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()
-- DB初期化
MySQL.query([[
    CREATE TABLE IF NOT EXISTS `usedcar_listings` (
        `id`           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `plate`        VARCHAR(8)    NOT NULL,          -- ← UNIQUE を外す
        `model`        VARCHAR(64)   NOT NULL,
        `label`        VARCHAR(128)  NOT NULL DEFAULT '',
        `price`        INT UNSIGNED  NOT NULL DEFAULT 0,
        `buy_amount`   INT UNSIGNED  NOT NULL DEFAULT 0,
        `seller_cid`   VARCHAR(50)   NOT NULL,
        `seller_name`  VARCHAR(100)  NOT NULL DEFAULT '',
        `mods`         LONGTEXT      DEFAULT NULL,
        `color_primary`   SMALLINT  DEFAULT 0,
        `color_secondary` SMALLINT  DEFAULT 0,
        `listed`       TINYINT(1)    NOT NULL DEFAULT 0,
        `sold`         TINYINT(1)    NOT NULL DEFAULT 0,
        `sold_at`      TIMESTAMP     NULL DEFAULT NULL,
        INDEX `idx_listed` (`listed`),
        INDEX `idx_sold` (`sold`, `sold_at`)
    )
]])
-- ============================================================
-- model(spawnコード) -> 表示名 の逆引きテーブルを構築
-- ============================================================
VehicleNameLookup = {}
CreateThread(function()
    for _, v in pairs(QBCore.Shared.Vehicles) do
        if v.model and v.name then
            VehicleNameLookup[v.model] = v.name
        end
    end
end)

function GetVehicleLabel(model)
    return VehicleNameLookup[model] or model
end

-- ============================================================
--  ヘルパー
-- ============================================================
local function isDealer(source)
    local player = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
    if not player then return false end
    return player.PlayerData.job.name == Config.DealerJob
end

-- ============================================================
--  車をジョブガレージへ登録（stockin）
-- ============================================================
RegisterNetEvent('usedcar:server:stockIn', function(vehicleNetId, plate, model, buyAmount, mods)
    local src = source
    if not isDealer(src) then return end

    buyAmount = tonumber(buyAmount) or 0

    -- player_vehicles に登録されているか確認
    local vehicleRecord = MySQL.single.await('SELECT plate, citizenid FROM player_vehicles WHERE plate = ?', { plate })
    if not vehicleRecord then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '中古車ディーラー',
            description = ('車両 [%s] はDBに登録されていません'):format(plate),
            type = 'error',
        })
        return
    end

    -- ジョブ金庫から引いて手持ちに加える
    if buyAmount > 0 then
        local societyMoney = exports['okokBanking']:GetAccount(Config.SocietyName)
        if societyMoney < buyAmount then
            TriggerClientEvent('ox_lib:notify', src, {
                title = '中古車ディーラー',
                description = 'ジョブ金庫の残高が不足しています',
                type = 'error',
            })
            return
        end
        exports['okokBanking']:RemoveMoney(Config.SocietyName, buyAmount)
        local player = QBCore.Functions.GetPlayer(src)
        player.Functions.AddMoney('cash', buyAmount)
    end

    MySQL.query('UPDATE player_vehicles SET citizenid = ?, garage = NULL, garage_id = ?, job_vehicle = ?, state = 0 WHERE plate = ?', {
        Config.DealerJob,
        Config.JobGarage,
        1,
        plate,
    })

    local player = QBCore.Functions.GetPlayer(src)
    local cid    = tostring(player.PlayerData.citizenid)
    local name   = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname

    MySQL.query('DELETE FROM usedcar_listings WHERE plate = ? AND sold = 0', { plate })

    MySQL.query([[
        INSERT INTO usedcar_listings (plate, model, label, buy_amount, seller_cid, seller_name, mods, listed, sold, sold_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, NULL)
    ]], { plate, model, model, buyAmount, cid, name, json.encode(mods or {}) })
    TriggerClientEvent('ox_lib:notify', src, {
        title = '中古車ディーラー',
        description = ('車両 [%s] をストックに入庫しました（仕入額: $%s）'):format(plate, buyAmount),
        type  = 'success',
    })

    TriggerClientEvent('usedcar:client:deleteVehicle', src, vehicleNetId)
end)
-- ============================================================
--  出品リスト取得
-- ============================================================
RegisterNetEvent('usedcar:server:getStockList', function()
    local src = source
    if not isDealer(src) then return end

    local rows = MySQL.query.await('SELECT * FROM usedcar_listings WHERE sold = 0 ORDER BY id DESC', {})
    local history = MySQL.query.await('SELECT * FROM usedcar_listings WHERE sold = 1 ORDER BY sold_at DESC', {})

    for _, row in ipairs(rows) do
        row.label = GetVehicleLabel(row.model)
    end
    for _, row in ipairs(history) do
        row.label = GetVehicleLabel(row.model)
        if row.sold_at then
            row.sold_at = os.date('%Y-%m-%d %H:%M', row.sold_at / 1000)
        end
    end
    TriggerClientEvent('usedcar:client:openManage', src, rows, history)
end)
-- ============================================================
--  出品設定保存
-- ============================================================
RegisterNetEvent('usedcar:server:setListing', function(plate, price, mods, id)
    local src = source
    if not isDealer(src) then return end
    if type(price) ~= 'number' or price < 1 then return end

    print('[usedcar] setListing id=' .. tostring(id) .. ' plate=' .. tostring(plate))
    MySQL.query('UPDATE usedcar_listings SET price=?, mods=?, listed=1 WHERE id=?', {
        math.floor(price),
        json.encode(mods or {}),
        tonumber(id),
    })

    -- jg-dealerships の動的在庫へ追加
    TriggerEvent('usedcar:server:syncToDealership')

    TriggerClientEvent('ox_lib:notify', src, {
        title = '中古車ディーラー',
        description = ('[%s] を $%s で出品しました'):format(plate, price),
        type  = 'success',
    })
end)

-- ============================================================
--  出品取り下げ
-- ============================================================
RegisterNetEvent('usedcar:server:unlist', function(plate, id)
    local src = source
    if not isDealer(src) then return end

    MySQL.query('UPDATE usedcar_listings SET listed=0 WHERE id=?', {
        tonumber(id),
    })

    -- jg-advancedgarages からジョブガレージへ戻す（試乗・カスタム可能状態）
    TriggerEvent('jg-advancedgarages:server:returnJobVehicle', {
        garage = Config.JobGarage,
        plate  = plate,
        source = src,
    })

    TriggerEvent('usedcar:server:syncToDealership')

    TriggerClientEvent('ox_lib:notify', src, {
        title = '中古車ディーラー',
        description = ('[%s] の出品を取り下げました。ガレージから取り出せます'):format(plate),
        type  = 'inform',
    })
end)

-- ============================================================
--  リソース起動時に1回だけ、5日以上前の販売済みレコードを削除
-- ============================================================
CreateThread(function()
    Wait(5000) -- DB接続が安定するまで少し待つ
    MySQL.query('DELETE FROM usedcar_listings WHERE sold = 1 AND sold_at < (NOW() - INTERVAL 5 DAY)', {}, function(affected)
        print(('[usedcar-dealer] 5日以上前の販売履歴を削除しました（%s件）'):format(affected and affected.affectedRows or 0))
    end)
end)