Permissions = {
    TABLET       = 'tablet',
    STORAGE      = 'storage',
    ORDERS       = 'orders',
    LIFT         = 'lift',
    CATALOG      = 'catalog',
    MANAGEMENT   = 'management',
    HIRE_FIRE    = 'hire_fire',
    FINANCE      = 'finance',
    PRICES       = 'prices',
    COLOR_MIXING = 'color_mixing',
}

-- Default role templates created automatically for every new shop.
-- Employees with existing legacy role names (Trainee/Mechanic/Manager/Owner)
-- are migrated to these on first server start after the update.
DefaultRoles = {
    {
        name        = 'Owner',
        permissions = {},
        isOwner     = true,
        isDefault   = false,
    },
    {
        name = 'Manager',
        permissions = {
            tablet       = true,
            storage      = true,
            orders       = true,
            lift         = true,
            catalog      = true,
            management   = true,
            hire_fire    = true,
            finance      = true,
            prices       = true,
            color_mixing = true,
        },
        isOwner   = false,
        isDefault = false,
    },
    {
        name = 'Mechanic',
        permissions = {
            tablet       = true,
            storage      = true,
            orders       = true,
            lift         = true,
            catalog      = true,
            color_mixing = true,
        },
        isOwner   = false,
        isDefault = true,
    },
    {
        name = 'Trainee',
        permissions = {
            tablet = true,
            orders = true,
        },
        isOwner   = false,
        isDefault = false,
    },
}