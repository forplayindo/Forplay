lib.versionCheck('Qbox-project/f_binoculars')

exports.qbx_core:CreateUseableItem('binoculars', function(source)
    TriggerClientEvent('f_binoculars:client:toggle', source)
end)
