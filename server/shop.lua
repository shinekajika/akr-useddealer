-- ============================================================
--  usedcar-dealer  server/shop.lua
--  購入処理
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()

Config.SocietyName = 'used'

-- 出品中リスト取得
RegisterNetEvent('usedcar:server:getShopListings', function()
    local src = source

    local rows = MySQL.query.await([[
        SELECT plate, model, label, price, mods, color_primary, color_secondary, seller_name
        FROM usedcar_listings
        WHERE listed = 1 AND sold = 0
        ORDER BY id DESC
    ]])

    for _, row in ipairs(rows or {}) do
        row.label = GetVehicleLabel(row.model)
    end

    TriggerClientEvent('usedcar:client:openShop', src, rows or {})
end)
-- 購入処理
RegisterNetEvent('usedcar:server:purchaseVehicle', function(plate, paymentType)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    -- 出品情報を取得
    local listing = MySQL.single.await('SELECT * FROM usedcar_listings WHERE plate = ? AND listed = 1', { plate })
    if not listing then
        TriggerClientEvent('usedcar:client:purchaseResult', src, false, 'この車両はすでに売却済みか出品取り下げされています')
        return
    end

    print('[usedcar] mods type=' .. type(listing.mods) .. ' value=' .. tostring(listing.mods):sub(1, 100))

    local price = listing.price

    -- 支払い処理
    if paymentType == 'cash' then
        if player.PlayerData.money.cash < price then
            TriggerClientEvent('usedcar:client:purchaseResult', src, false, '現金が足りません')
            return
        end
        player.Functions.RemoveMoney('cash', price, 'usedcar-purchase')

    elseif paymentType == 'bank' then
        if player.PlayerData.money.bank < price then
            TriggerClientEvent('usedcar:client:purchaseResult', src, false, '銀行残高が足りません')
            return
        end
        player.Functions.RemoveMoney('bank', price, 'usedcar-purchase')

    else
        TriggerClientEvent('usedcar:client:purchaseResult', src, false, '無効な支払い方法です')
        return
    end

    local cid = tostring(player.PlayerData.citizenid)
    local license = player.PlayerData.license
    
    -- player_vehicles のオーナーを購入者に変更
    MySQL.query('UPDATE player_vehicles SET citizenid = ?, license = ?, garage = ?, garage_id = ?, job_vehicle = ?, state = 0 WHERE plate = ?', {
        cid,
        license,
        'Legion Square', 
        'Legion Square',  -- garage_id もレギオンに
        0,                -- job_vehicle を 0 にリセット
        plate,
    })
    -- 売上をjob金庫に入金
    exports['okokBanking']:AddMoney(Config.SocietyName, price)

    -- リスティングから削除
    MySQL.query('UPDATE usedcar_listings SET listed=0, sold=1, sold_at=NOW() WHERE plate = ?', { plate })


    -- 売上を出品者に送金（任意）
    -- 必要なら seller_cid でプレイヤーを探して送金処理を追加

    TriggerClientEvent('usedcar:client:spawnPurchasedVehicle', src, plate, listing.model, listing.mods)

    TriggerClientEvent('usedcar:client:purchaseResult', src, true,
        ('車両 [%s] を $%s で購入しました！'):format(plate, price))

end)