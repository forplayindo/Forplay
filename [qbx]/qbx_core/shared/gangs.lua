---Gang names must be lower case (top level table key)
---Gang buatan pemain tidak ditulis di sini: disimpan di database dan didaftarkan saat server start.
---@type table<string, Gang>
return {
    ['none'] = {
        label = 'Tanpa Geng',
        grades = {
            [0] = {
                name = 'Tidak Bergabung'
            },
        },
    },
}
