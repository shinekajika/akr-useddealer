AddEventHandler('usedcar:server:syncToDealership', function()
end)

AddEventHandler('jg-dealerships:server:vehiclePurchased', function(src, dealerName, vehicleData)
    if dealerName ~= Config.DealershipName then return end
    local plate = vehicleData.plate
    if not plate then return end
    MySQL.query('DELETE FROM usedcar_listings WHERE plate = ?', { plate })
end)