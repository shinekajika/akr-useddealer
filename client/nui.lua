-- ============================================================
--  usedcar-dealer  client/nui.lua
--  NUI ↔ クライアント ブリッジ
-- ============================================================

-- NUI を閉じる
RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- 出品設定を保存
RegisterNUICallback('setListing', function(data, cb)
    TriggerServerEvent('usedcar:server:setListing', data.plate, tonumber(data.price), data.mods, data.id)
    cb('ok')
end)

-- 出品取り下げ
RegisterNUICallback('unlist', function(data, cb)
    TriggerServerEvent('usedcar:server:unlist', data.plate, data.id)
    cb('ok')
end)

-- ESC でも閉じる
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsNuiFocused() and IsControlJustReleased(0, 177) then -- Escape
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeManage' })
        end
    end
end)
