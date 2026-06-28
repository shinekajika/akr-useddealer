-- ============================================================
--  usedcar-dealer  client/main.lua
--  コマンド登録・共通ユーティリティ
-- ============================================================

local QBCore = exports['qb-core']:GetCoreObject()
local playerJob = nil

AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
    playerJob = job
    print('[used] job updated: ' .. tostring(job and job.name))
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local pd = QBCore.Functions.GetPlayerData()
    playerJob = pd and pd.job
end)

local function isDealer()
    local pd = QBCore.Functions.GetPlayerData()
    playerJob = pd and pd.job
    return playerJob and playerJob.name == Config.DealerJob
end
-- ============================================================
--  /stockin  ─ 乗っている車をジョブガレージへ
-- ============================================================
TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.stockIn, '乗っている車両を中古車ストックへ入庫します', {
    { name = '金額', help = '仕入額（ジョブ金庫から引き落とし、手持ちに加算）' }
})
RegisterCommand(Config.Commands.stockIn, function(source, args)
    if not isDealer() then
        lib.notify({ title='中古車ディーラー', description='このコマンドは使用できません', type='error' })
        return
    end

    local amount = tonumber(args[1])
    if not amount or amount < 0 then
        lib.notify({ title='中古車ディーラー', description='使用方法: /stockin [金額]', type='error' })
        return
    end

    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        lib.notify({ title='中古車ディーラー', description='車両に乗ってから使用してください', type='error' })
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        lib.notify({ title='中古車ディーラー', description='運転席に乗ってください', type='error' })
        return
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        lib.notify({ title='中古車ディーラー', description='この車両は使用できません', type='error' })
        return
    end

    -- ネットワーク同期が完了するまで待つ
    local timeout = 0
    while not NetworkGetEntityIsNetworked(vehicle) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
    local model = GetEntityModel(vehicle)

    local modelName = ''
    for k, v in pairs(GetAllVehicleModels and GetAllVehicleModels() or {}) do
        if GetHashKey(v) == model then modelName = v break end
    end
    if modelName == '' then modelName = tostring(model) end

    -- モッズ取得前に少し待つ
    Wait(10)
    local mods = lib.getVehicleProperties(vehicle)
    TriggerServerEvent('usedcar:server:stockIn', netId, plate, modelName, amount, mods)

end, false)
-- ============================================================
--  /ucmanage  ─ 管理画面を開く
-- ============================================================
TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.manage, '中古車の在庫・出品・販売履歴を管理する画面を開きます')
RegisterCommand(Config.Commands.manage, function()
    if not isDealer() then
        lib.notify({ title='中古車ディーラー', description='このコマンドは使用できません', type='error' })
        return
    end
    TriggerServerEvent('usedcar:server:getStockList')
end, false)

-- ============================================================
--  サーバーから管理画面を開く指示
-- ============================================================
RegisterNetEvent('usedcar:client:openManage', function(listings, history)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openManage', listings = listings, history = history })
end)

-- ============================================================
--  サーバーから車両削除指示
-- ============================================================
RegisterNetEvent('usedcar:client:deleteVehicle', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        DeleteEntity(veh)
    end
end)

-- ============================================================
--  ガレージからスポーン（fallback）
-- ============================================================
RegisterNetEvent('usedcar:client:spawnFromGarage', function(plate)
    lib.notify({
        title = '中古車ディーラー',
        description = 'ガレージから車両を取り出してください: ' .. plate,
        type = 'inform',
    })
end)
