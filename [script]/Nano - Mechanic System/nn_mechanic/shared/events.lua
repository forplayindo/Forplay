Events = {
    Role = {
        Create = 'nn_mechanic:createRole',
        Update = 'nn_mechanic:updateRole',
        Delete = 'nn_mechanic:deleteRole',
    },
    Employee = {
        Hire             = 'nn_mechanic:hireEmployee',
        Fire             = 'nn_mechanic:fireEmployee',
        Update           = 'nn_mechanic:updateEmployee',
        ClearShopAccess  = 'nn_mechanic:clearShopAccess',
        ReinitializeShop = 'nn_mechanic:reinitializeShop',
        UpdateShopState  = 'nn_mechanic:updateShopState',
    },
    Preset = {
        -- Bridge.Callback names (request/response from admin panel UI).
        Status  = 'nn_mechanic:preset:status',
        Browse  = 'nn_mechanic:preset:browse',
        Get     = 'nn_mechanic:preset:get',
        Submit  = 'nn_mechanic:preset:submit',
        Apply   = 'nn_mechanic:preset:apply',
        Vote    = 'nn_mechanic:preset:vote',
        Report  = 'nn_mechanic:preset:report',
    },
}