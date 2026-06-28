-- ============================================================
--  usedcar-dealer  server/garage.lua
--  jg-advancedgarages との橋渡しレイヤー
-- ============================================================
local QBCore = exports['qb-core']:GetCoreObject()
-- jg-advancedgarages がジョブガレージ格納・取り出しに使う
-- イベント名はバージョンにより異なる場合があります。
-- 以下は一般的なパターン。実際のイベント名は
-- jg-advancedgarages/server/main.lua を確認して合わせてください。

-- ジョブガレージへ格納
AddEventHandler('jg-advancedgarages:server:storeJobVehicle', function(data)
    print('[usedcar] storeJobVehicle fired! plate=' .. tostring(data.plate) .. ' garage=' .. tostring(data.garage))
    
    MySQL.query('UPDATE player_vehicles SET garage = ?, state = 0 WHERE plate = ?', {
        data.garage,
        data.plate,
    })
end)
-- ガレージから取り出し（試乗・カスタム用）
AddEventHandler('jg-advancedgarages:server:returnJobVehicle', function(data)
    -- jg-advancedgarages 側の取り出し処理を呼ぶ
    -- exports があれば使う
    local ok = pcall(function()
        exports['jg-advancedgarages']:SpawnJobVehicle(data.garage, data.plate, data.source)
    end)

    if not ok then
        -- fallback: クライアントへ直接スポーン指示
        TriggerClientEvent('usedcar:client:spawnFromGarage', data.source, data.plate)
    end
end)

-- ============================================================
--  モッズ情報をサーバーに保存（カスタム後に呼ぶ）
-- ============================================================
RegisterNetEvent('usedcar:server:saveMods', function(plate, mods)
    local src = source
    print('[usedcar] saveMods plate=' .. tostring(plate) .. ' mods type=' .. type(mods))
    if type(mods) == 'table' then
        print('[usedcar] colorPrimary=' .. tostring(mods.colorPrimary) .. ' color1=' .. tostring(mods.color1) .. ' mods.mods=' .. tostring(mods.mods))
    end
    MySQL.query([[
        UPDATE usedcar_listings
        SET mods=?
        WHERE plate=? AND seller_cid=?
    ]], {
        json.encode(mods),
        plate,
        tostring(QBCore.Functions.GetPlayer(src).PlayerData.citizenid),
    })
end)