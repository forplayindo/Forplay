return {
    serverName = '4play Indonesia',
    defaultSpawn = vec4(-1042.13, -2745.19, 20.36, 328.01),
    notifyPosition = 'top-right', -- 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left'
    ---@type { name: string, amount: integer, metadata: fun(source: number): table }[]
    starterItems = { -- Character starting items
        { name = 'phone', amount = 1 },
        -- warga baru hanya mendapat KTP Sementara (berlaku 1 hari); KTP dibuat di Balai Kota, SIM di kantor polisi
        { name = 'ktp_sementara', amount = 1, metadata = function(source)
                assert(GetResourceState('f_idcard') == 'started', 'f_idcard resource not found. Required to give an id_card as a starting item')
                return exports.f_idcard:GetMetaLicense(source, {'ktp_sementara'})
            end
        },
    }
}
