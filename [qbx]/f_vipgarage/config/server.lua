return {
    Commands = {
        invite = {
            name = 'invite',
            help = 'Undang pemain ke garasimu',
            enable = false -- inviting is done with the [E] invite marker inside the garage
        }
    },

    -- Garages are not bought by players: the purchase is roleplayed and an admin activates the
    -- garage for the player from the garage menu at its entrance.
    Admin = {
        ace = 'group.admin',  -- ACE a player needs to activate garages
        atGarageDistance = 10.0, -- the admin must stand this close to the garage entrance
        playerDistance = 5.0,    -- players this close to the admin can be picked
    },
}
