-- ============================================================
--  usedcar-dealer  client/dealer.lua
--  車両モッズ取得・適用ユーティリティ
-- ============================================================

-- 車両の全カスタム情報をテーブルで返す
local function GetVehicleMods(vehicle)
    local mods = {}

    -- 標準モッズ (0-49)
    mods.mods = {}
    for i = 0, 49 do
        local idx = GetVehicleMod(vehicle, i)
        if idx ~= -1 then
            mods.mods[tostring(i)] = idx
        end
    end

    -- トグルモッズ (0-23)
    mods.toggleMods = {}
    for i = 0, 23 do
        if IsToggleModOn(vehicle, i) then
            mods.toggleMods[tostring(i)] = true
        end
    end

    -- ホイール
    mods.wheelType  = GetVehicleWheelType(vehicle)
    mods.wheelMod   = GetVehicleMod(vehicle, 23)

    -- カラー（販売時は不変だが保存はしておく）
    local p, s = GetVehicleColours(vehicle)
    mods.colorPrimary   = p
    mods.colorSecondary = s

    -- カスタムカラー
    local pr, pg, pb = GetVehicleCustomPrimaryColour(vehicle)
    local sr, sg, sb = GetVehicleCustomSecondaryColour(vehicle)
    mods.customColorPrimary   = { r = pr, g = pg, b = pb }
    mods.customColorSecondary = { r = sr, g = sg, b = sb }

    -- エクストラ
    mods.extras = {}
    for i = 1, 12 do
        if DoesExtraExist(vehicle, i) then
            mods.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    -- ネオン
    mods.neonEnabled = {
        IsVehicleNeonLightEnabled(vehicle, 0),
        IsVehicleNeonLightEnabled(vehicle, 1),
        IsVehicleNeonLightEnabled(vehicle, 2),
        IsVehicleNeonLightEnabled(vehicle, 3),
    }
    local nr, ng, nb = GetVehicleNeonLightsColour(vehicle)    mods.neonColor = { r = nr, g = ng, b = nb }

    -- タイヤスモーク
    local tr, tg, tb = GetVehicleTyreSmokeColor(vehicle)
    mods.tyreSmokeColor = { r = tr, g = tg, b = tb }

    -- ウィンドウティント
    mods.windowTint = GetVehicleWindowTint(vehicle)

    -- プレート
    mods.plateStyle = GetVehicleNumberPlateTextIndex(vehicle)

    return mods
end

-- 保存済みモッズをスポーン済み車両に適用する
local function ApplyVehicleMods(vehicle, mods)
    if not mods then return end

    SetVehicleModKit(vehicle, 0)
    Wait(200) -- ★追加：ModKit設定後に待機

    if mods.mods then
        for i, idx in pairs(mods.mods) do
            SetVehicleMod(vehicle, tonumber(i), idx, false)
        end
    end

    if mods.toggleMods then
        for i, _ in pairs(mods.toggleMods) do
            ToggleVehicleMod(vehicle, tonumber(i), true)
        end
    end

    if mods.wheelType then
        SetVehicleWheelType(vehicle, mods.wheelType)
    end

    if mods.colorPrimary ~= nil then
        SetVehicleColours(vehicle, mods.colorPrimary, mods.colorSecondary or 0)
    end
    if mods.customColorPrimary then
        SetVehicleCustomPrimaryColour(vehicle, mods.customColorPrimary.r, mods.customColorPrimary.g, mods.customColorPrimary.b)
    end
    if mods.customColorSecondary then
        SetVehicleCustomSecondaryColour(vehicle, mods.customColorSecondary.r, mods.customColorSecondary.g, mods.customColorSecondary.b)
    end

    if mods.extras then
        for i, state in pairs(mods.extras) do
            SetVehicleExtra(vehicle, tonumber(i), state and 0 or 1)
        end
    end

    if mods.neonEnabled then
        for i, v in ipairs(mods.neonEnabled) do
            SetVehicleNeonLightEnabled(vehicle, i - 1, v)
        end
    end

    if mods.neonColor then
        SetVehicleNeonLightsColour(vehicle, mods.neonColor.r, mods.neonColor.g, mods.neonColor.b)
    end

    if mods.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, mods.tyreSmokeColor.r, mods.tyreSmokeColor.g, mods.tyreSmokeColor.b)
    end

    if mods.windowTint then
        SetVehicleWindowTint(vehicle, mods.windowTint)
    end

    if mods.plateStyle then
        SetVehicleNumberPlateTextIndex(vehicle, mods.plateStyle)
    end
end

-- exports として公開
exports('GetVehicleMods', GetVehicleMods)
exports('ApplyVehicleMods', ApplyVehicleMods)

-- jg-dealerships が車両スポーン後にモッズを適用するフック
-- jg-dealerships:client:vehicleSpawned イベントをリッスン
AddEventHandler('jg-dealerships:client:vehicleSpawned', function(dealerName, vehicle, vehicleData)
    if dealerName ~= Config.DealershipName then return end
    if not vehicleData.extras then return end

    -- mods フィールドに保存済みカスタムを適用
    Wait(500) -- スポーン安定待ち
    ApplyVehicleMods(vehicle, vehicleData.extras)
end)
