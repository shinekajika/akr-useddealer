-- ============================================================
--  usedcar-dealer  client/shop.lua
--  �w���}�[�J�[�EE������3D�V���[���[�����J��
-- ============================================================

local shopCoords = vector3(154.24, 6395.46, 31.29) -- �� used_cars �� openShowroom ���W
local markerActive = false
local showroomOpen = false
local showroomCam = nil
local previewVehicle = nil
local currentListings = {}

-- ============================================================
--  �}�[�J�[�`��EE�������m
-- ============================================================
CreateThread(function()
    while true do
        local sleep = 1000
        if not showroomOpen then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local dist = #(pos - shopCoords)

            if dist < 30.0 then
                sleep = 0
                DrawMarker(
                    2,
                    shopCoords.x, shopCoords.y, shopCoords.z - 0.1,
                    0, 0, 0,
                    0, 0, 0,
                    0.7, 0.7, 0.7,
                    255, 255, 255, 100,
                    false, false, 2, true, nil, nil, false
                )

                if dist < 2.0 then
                    if not markerActive then
                        markerActive = true
                        lib.showTextUI('[E] ���ÎԂ�����')
                    end
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('usedcar:server:getShopListings')
                    end
                else
                    if markerActive then
                        markerActive = false
                        lib.hideTextUI()
                    end
                end
            else
                if markerActive then
                    markerActive = false
                    lib.hideTextUI()
                end
            end
        end
        Wait(sleep)
    end
end)

-- ============================================================
--  �v���r���[�ԗ��̃X�|�[���E�폜
-- ============================================================
local function clearPreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = nil
end

local function spawnPreviewVehicle(listing)
    clearPreviewVehicle()

    local model = listing.model
    local hash = GetHashKey(model)

    -- ���f�������S�Ƀ��[�h�����܂ő҂�
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 5000 do
            Wait(50)
            timeout = timeout + 50
        end
    end

    local spawn = Config.Showroom.previewSpawn

    previewVehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, false, false)

    local timeout = 0
    while not DoesEntityExist(previewVehicle) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end

    if not DoesEntityExist(previewVehicle) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(previewVehicle, true, true)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleNumberPlateText(previewVehicle, listing.plate)
    SetVehicleOnGroundProperly(previewVehicle)

    -- �ԗ��G���e�B�e�B���̂̏�����������҂�
    Wait(500)

    if listing.mods and listing.mods ~= '' and listing.mods ~= '{}' then
        local ok, props = pcall(json.decode, listing.mods)
        if ok then
            if type(props) == 'string' then
                local ok2, props2 = pcall(json.decode, props)
                if ok2 and type(props2) == 'table' then props = props2 end
            end
            if type(props) == 'table' then
                props.model = nil
                lib.setVehicleProperties(previewVehicle, props)
            end
        end
    end
    SetModelAsNoLongerNeeded(hash)
end
-- ============================================================
--  �V���[���[���J����
-- ============================================================
local function openShowroomCamera()
    local cam = Config.Showroom.camera
    showroomCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(showroomCam, cam.x, cam.y, cam.z)
    SetCamRot(showroomCam, 0.0, 0.0, cam.w)
    SetCamFov(showroomCam, 50.0)
    RenderScriptCams(true, true, 800, true, true)
    DisplayRadar(false)
end

local function closeShowroomCamera()
    if showroomCam then
        RenderScriptCams(false, true, 800, true, true)
        DestroyCam(showroomCam, false)
        showroomCam = nil
    end
    DisplayRadar(true)
end

-- ============================================================
--  �T�[�o�[����V���[���[��UI�\���w��
-- ============================================================
RegisterNetEvent('usedcar:client:openShop', function(listings)
    currentListings = listings or {}
    showroomOpen = true
    lib.hideTextUI()

    openShowroomCamera()

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openShop', listings = currentListings })

    -- �ŏ���1��������v���r���[
    if currentListings[1] then
        spawnPreviewVehicle(currentListings[1])
    end
end)

-- ============================================================
--  ���X�g�ŎԂ�I�������Ƃ��̃v���r���[�؂�ւ�
-- ============================================================
RegisterNUICallback('previewVehicle', function(data, cb)
    local listing = currentListings[tonumber(data.index) + 1]
    if listing then
        spawnPreviewVehicle(listing)
    end
    cb('ok')
end)

-- ============================================================
--  NUI����i�V���[���[�����o��j
-- ============================================================
RegisterNUICallback('closeShop', function(_, cb)
    SetNuiFocus(false, false)
    showroomOpen = false
    closeShowroomCamera()
    clearPreviewVehicle()
    lib.showTextUI('[E] ���ÎԂ�����')
    cb('ok')
end)

-- ============================================================
--  �w������
-- ============================================================
RegisterNUICallback('purchaseVehicle', function(data, cb)
    TriggerServerEvent('usedcar:server:purchaseVehicle', data.plate, data.paymentType)
    cb('ok')
end)

-- ============================================================
--  �w�������Ԃ����̏�ŃX�|�[��
-- ============================================================
RegisterNetEvent('usedcar:client:spawnPurchasedVehicle', function(plate, model, mods)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local spawnCoords = vector4(137.52, 6390.84, 31.26, 118.34)

    lib.requestModel(model)

    local vehicle = CreateVehicle(GetHashKey(model), spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)

    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end

    if not DoesEntityExist(vehicle) then
        lib.notify({ title = '���Îԃf�B�[���[', description = '�X�|�[���Ɏ��s���܂���', type = 'error' })
        SetModelAsNoLongerNeeded(GetHashKey(model))
        return
    end

    SetVehicleNumberPlateText(vehicle, plate)

    if mods and mods ~= '' and mods ~= '{}' then
        local ok, props = pcall(json.decode, mods)
        if ok then
            if type(props) == 'string' then
                local ok2, props2 = pcall(json.decode, props)
                if ok2 and type(props2) == 'table' then props = props2 end
            end
            if type(props) == 'table' then
                props.model = nil
                Wait(500)
                lib.setVehicleProperties(vehicle, props)
            end
        end
    end

    TriggerEvent('vehiclekeys:client:SetOwner', plate)

    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    SetVehicleEngineOn(vehicle, true, true, false)
    SetModelAsNoLongerNeeded(GetHashKey(model))
end)

-- ============================================================
--  �w�����ʂ�UI�ɒʒm
-- ============================================================
RegisterNetEvent('usedcar:client:purchaseResult', function(success, message)
    if success then
        lib.notify({ title = '���Îԃf�B�[���[', description = message, type = 'success' })
        SetNuiFocus(false, false)
        showroomOpen = false
        closeShowroomCamera()
        clearPreviewVehicle()
        SendNUIMessage({ action = 'closeShop' })
        lib.showTextUI('[E] ���ÎԂ�����')
    else
        lib.notify({ title = '���Îԃf�B�[���[', description = message, type = 'error' })
        SendNUIMessage({ action = 'purchaseFailed' })
    end
end)