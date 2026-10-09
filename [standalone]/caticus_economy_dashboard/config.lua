Config = {}


Config.Framework = 'auto'


Config.AdminPermissions = {
    qbcore = {'god', 'admin'},          
    qbox = {'god', 'admin'},             
    esx = {'superadmin', 'admin'},      
    standalone = {                       
        'license:',
        'license2:',
    },
    acePermission = 'economy.dashboard', 
}


Config.TrackCash = true
Config.TrackBank = true
Config.TrackDirty = true      
Config.TrackCrypto = true     


Config.Alerts = {
    RapidWealthGain = {
        enabled = true,
        amount = 25000000,
        timeWindow = 600,      
        severity = 'high',
    },
    LargeTransaction = {
        enabled = true,
        amount = 100000000,
        severity = 'medium',
    },
    InflationSpike = {
        enabled = true,
        threshold = 0.05,       
        severity = 'medium',
    },
    FaucetImbalance = {
        enabled = true,
        threshold = 0.30,       
        severity = 'low',
    },
    SinkDrought = {
        enabled = true,
        threshold = 0.50,       
        severity = 'medium',
    },
    NewPlayerStruggle = {
        enabled = false,        
        threshold = 500000,
        severity = 'low',
    },
}


Config.Discord = {
    enabled = false,
    alertWebhook = '',
    dailyReportWebhook = '',
    weeklyReportWebhook = '',
    adminLogWebhook = '',
    botName = 'Economy Dashboard',
    botAvatar = '', 
}


Config.InflationMode = 'both'


Config.InflationBasket = {
    {item = 'burger', basePrice = 10},
    {item = 'water', basePrice = 5},
    {item = 'pistol_ammo', basePrice = 50},
    {item = 'repairkit', basePrice = 250},
    {item = 'lockpick', basePrice = 100},
    {item = 'bandage', basePrice = 50},
}


Config.FaucetKeywords = {
    jobs = {
        'salary', 'paycheck', 'job', 'work', 'delivery', 'trucking', 
        'garbage', 'fishing', 'mining', 'hunting', 'farming', 'taxi',
        'mechanic', 'tow', 'bus', 'postal'
    },
    criminal = {
        'robbery', 'heist', 'drugs', 'stolen', 'fence', 'chopshop', 
        'bank_hack', 'atm', 'store_robbery', 'house_robbery', 'meth',
        'weed', 'coke', 'cocaine', 'oxy'
    },
    government = {
        'welfare', 'unemployment', 'police_salary', 'ems_salary', 
        'government', 'doj', 'judge', 'mayor'
    },
    sales = {
        'sold', 'sale', 'vendor', 'shop_sell', 'player_sale'
    },
}

Config.SinkKeywords = {
    vehicles = {
        'vehicle', 'car', 'repair', 'insurance', 'impound', 'fuel',
        'garage', 'dealership', 'motorcycle', 'boat', 'aircraft'
    },
    property = {
        'house', 'apartment', 'rent', 'property', 'furniture', 
        'storage', 'warehouse', 'business'
    },
    items = {
        'bought', 'purchase', 'shop', 'store', 'crafting', 'weapon',
        'ammo', 'food', 'drink'
    },
    services = {
        'hospital', 'mechanic_bill', 'lawyer', 'taxi_fare', 'ems_bill',
        'repair_bill'
    },
    government = {
        'fine', 'tax', 'license', 'ticket', 'jail', 'bail', 'seized'
    },
}


Config.BatchInsertInterval = 30      
Config.TransactionRetentionDays = 90 
Config.SnapshotRetentionDays = 365   
Config.DailySnapshotHour = 4         


Config.OpenCommand = 'economydash'  
Config.OpenKey = ''                 
Config.RequireProp = false          


Config.API = {
    enabled = false,
    port = 3000,
    apiKey = 'change_this_to_a_secure_key',
}


Config.Debug = false
