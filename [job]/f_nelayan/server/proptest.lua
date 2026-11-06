-- sementara: uji tampilan prop nelayan di depan admin (objek lokal, hanya terlihat oleh admin itu)
lib.addCommand('nelayanprop', {
    help = 'Uji prop nelayan (f_nelayan)',
    params = { { name = 'prop', help = 'tangan / lempar / laut / ikan / peti / kosong / tumpuk / hapus', optional = true } },
    restricted = 'group.admin',
}, function(src, args)
    TriggerClientEvent('f_nelayan:client:propTest', src, args.prop or 'semua')
end)
