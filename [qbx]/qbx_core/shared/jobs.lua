---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'Warga Sipil',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Pekerja Lepas',
                payment = 75000
            },
        },
    },
    ['police'] = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Petugas',
                payment = 400000
            },
            [2] = {
                name = 'Sersan',
                payment = 475000
            },
            [3] = {
                name = 'Letnan',
                payment = 550000
            },
            [4] = {
                name = 'Kepala',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['bcso'] = {
        label = 'BCSO',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Petugas',
                payment = 400000
            },
            [2] = {
                name = 'Sersan',
                payment = 475000
            },
            [3] = {
                name = 'Letnan',
                payment = 550000
            },
            [4] = {
                name = 'Kepala',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['sasp'] = {
        label = 'SASP',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Petugas',
                payment = 400000
            },
            [2] = {
                name = 'Sersan',
                payment = 475000
            },
            [3] = {
                name = 'Letnan',
                payment = 550000
            },
            [4] = {
                name = 'Kepala',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['ambulance'] = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Paramedis',
                payment = 400000
            },
            [2] = {
                name = 'Dokter',
                payment = 475000
            },
            [3] = {
                name = 'Dokter Bedah',
                payment = 550000
            },
            [4] = {
                name = 'Kepala',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['realestate'] = {
        label = 'Properti',
        type = 'realestate',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Penjual Rumah',
                payment = 400000
            },
            [2] = {
                name = 'Penjual Bisnis',
                payment = 475000
            },
            [3] = {
                name = 'Makelar',
                payment = 550000
            },
            [4] = {
                name = 'Manajer',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['taxi'] = {
        label = 'Taksi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 75000
            },
            [1] = {
                name = 'Sopir',
                payment = 75000
            },
            [2] = {
                name = 'Sopir Acara',
                payment = 75000
            },
            [3] = {
                name = 'Penjual',
                payment = 75000
            },
            [4] = {
                name = 'Manajer',
                isboss = true,
                bankAuth = true,
                payment = 75000
            },
        },
    },
    ['bus'] = {
        label = 'Bus',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Sopir',
                payment = 75000
            },
        },
    },
    ['cardealer'] = {
        label = 'Dealer Kendaraan',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Sales Showroom',
                payment = 400000
            },
            [2] = {
                name = 'Penjual Bisnis',
                payment = 475000
            },
            [3] = {
                name = 'Keuangan',
                payment = 550000
            },
            [4] = {
                name = 'Manajer',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['mechanic'] = {
        label = 'Mekanik',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Rekrutan',
                payment = 350000
            },
            [1] = {
                name = 'Pemula',
                payment = 400000
            },
            [2] = {
                name = 'Berpengalaman',
                payment = 475000
            },
            [3] = {
                name = 'Mahir',
                payment = 550000
            },
            [4] = {
                name = 'Manajer',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['government'] = {
        label = 'Pemerintah Kota',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Staf Pelayanan',
                payment = 350000
            },
            [1] = {
                name = 'Petugas Administrasi',
                payment = 400000
            },
            [2] = {
                name = 'Kepala Dinas',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
    ['judge'] = {
        label = 'Kehakiman',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Hakim',
                payment = 550000
            },
        },
    },
    ['lawyer'] = {
        label = 'Firma Hukum',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Pengacara',
                payment = 350000
            },
        },
    },
    ['reporter'] = {
        label = 'Reporter',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Jurnalis',
                payment = 350000
            },
        },
    },
    ['trucker'] = {
        label = 'Sopir Truk',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Sopir',
                payment = 75000
            },
        },
    },
    ['tow'] = {
        label = 'Derek',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Sopir',
                payment = 75000
            },
        },
    },
    ['garbage'] = {
        label = 'Kebersihan',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Petugas Sampah',
                payment = 75000
            },
        },
    },
    ['vineyard'] = {
        label = 'Kebun Anggur',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Pemetik',
                payment = 75000
            },
        },
    },
    ['hotdog'] = {
        label = 'Hotdog',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Penjual',
                payment = 75000
            },
        },
    },
    ['cafe'] = {
        label = 'Kafe',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Pelayan',
                payment = 350000
            },
            [1] = {
                name = 'Koki',
                payment = 400000
            },
            [2] = {
                name = 'Manajer',
                isboss = true,
                bankAuth = true,
                payment = 700000
            },
        },
    },
}
