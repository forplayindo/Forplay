return {
	['testburger'] = {
		label = 'Burger Tes',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Jilat',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Peras',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	-- Medis (f_ambulancejob). Bandage & Painkillers bisa dipakai sendiri dari inventory; item lain hanya
	-- dipakai EMS lewat panel Cek Pasien (server yang mengambil item-nya).
	['bandage'] = {
		label = 'Perban',
		weight = 115,
		degrade = 4320, -- 3 hari
		description = 'Luka ringan & pendarahan ringan. Bisa dipakai sendiri.',
		client = { export = 'f_ambulancejob.useBandage' },
	},

	['painkillers'] = {
		label = 'Obat Pereda Nyeri',
		weight = 50,
		degrade = 4320, -- 3 hari
		description = 'Menahan rasa nyeri sementara. Tidak menyembuhkan luka.',
		client = { export = 'f_ambulancejob.usePainkillers' },
	},

	['tas_emergency'] = {
		label = 'Tas Darurat',
		weight = 1500,
		stack = false,
		degrade = 2880, -- 2 hari sejak diambil dari armory
		description = 'Tas medis EMS. Wajib dibawa untuk tindakan di Cek Pasien; obat diambil dari Stok Gudang.',
	},

	['tas_operasi'] = {
		label = 'Tas Operasi',
		weight = 2000,
		stack = false,
		degrade = 1440, -- 24 jam sejak diambil dari armory
		description = 'Tas operasi Dokter. Wajib dibawa untuk operasi; obat diambil dari Stok Gudang.',
	},

	['tas_perkakas'] = {
		label = 'Tas Perkakas',
		weight = 2000,
		stack = false,
		degrade = 2880, -- 2 hari sejak diambil di Gudang Bengkel
		description = 'Tas perkakas mekanik. Wajib dibawa untuk memperbaiki kendaraan; bahan diambil dari Stok Gudang Bengkel.',
	},

	['hemostatic'] = {
		label = 'Kasa Hemostatik',
		weight = 120,
		description = 'Menghentikan pendarahan berat. Dipakai EMS.',
	},

	['splint'] = {
		label = 'Bidai',
		weight = 400,
		description = 'Menstabilkan tulang retak / patah. Dipakai EMS.',
	},

	['suture'] = {
		label = 'Alat Jahit Luka',
		weight = 200,
		description = 'Menjahit luka terbuka di kepala, leher & badan. Dipakai EMS.',
	},

	['firstaid'] = {
		label = 'Kotak P3K',
		weight = 600,
		description = 'Untuk menyadarkan pasien yang tergeletak. Dipakai EMS.',
	},

	['blood_bag_empty'] = {
		label = 'Kantong Darah Kosong',
		weight = 50,
		description = 'Untuk mengambil darah pendonor. Dipakai EMS.',
	},

	['blood_bag'] = {
		label = 'Kantong Darah',
		weight = 500,
		stack = false,
		description = 'Darah donor untuk transfusi. 1 kantong = darah pasien penuh.',
	},

	['calm_pills'] = {
		label = 'Pil Penenang',
		weight = 40,
		degrade = 4320, -- 3 hari
		description = 'Obat penenang. Menurunkan stress. Jeda antar minum 5 menit.',
		client = { export = 'f_ambulancejob.useCalmPills' },
		server = { export = 'f_ambulancejob.calmPills' },
	},

	['anesthetic'] = {
		label = 'Obat Bius',
		weight = 150,
		description = 'Obat bius untuk operasi. Dipakai Dokter.',
	},

	['surgical_kit'] = {
		label = 'Alat Operasi',
		weight = 2000,
		stack = false,
		description = 'Alat operasi. Aus setelah dipakai beberapa kali. Dipakai Dokter.',
	},

	['crutch'] = {
		label = 'Crutch',
		weight = 1500,
		stack = false,
		description = 'Tongkat untuk berjalan selama masa pemulihan kaki. Pakai untuk memegang / melepas.',
		client = { export = 'f_ambulancejob.useCrutch' },
	},

	-- f_dirtymoney: item lama, otomatis dikonversi jadi cash kotor saat masuk inventory pemain
	['black_money'] = {
		label = 'Uang Kotor (lama)',
	},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
		},
	},

	['tosti'] = {
		label = 'Tosti',
		weight = 220,
		client = {
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
		},
	},
	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parasut',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Sampah',
	},

	['paperbag'] = {
		label = 'Kantong Kertas',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['id_card'] = {
		label = 'KTP',
		client = {
			image = 'card_id.png'
		}
	},

	['ktp_sementara'] = {
		label = 'KTP Sementara',
		stack = false,
		description = 'Kartu Tanda Penduduk Sementara untuk warga baru. Berlaku 1 × 24 jam; buat KTP di Balai Kota.',
		client = {
			image = 'card_id.png'
		}
	},

	['etoll_card'] = {
		label = 'Kartu E-Toll',
		weight = 10,
		stack = false,
		description = 'Kartu bayar gerbang tol. Saldo tersimpan di kartu; isi ulang di loket tol atau minimarket.',
		client = {
			image = 'card_bank.png'
		}
	},

	['driver_license'] = {
		label = 'SIM',
		client = {
			image = 'sim.png'
		}
	},

	['weaponlicense'] = {
		label = 'Lisensi Senjata',
		client = {
			image = 'card_id.png'
		}
	},

	['stnk'] = {
		label = 'STNK',
		stack = false,
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Celana Dalam',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
    label = 'Lockpick',
    weight = 160,
},

['handcuffs'] = {
    label = 'Borgol',
    weight = 300,
    description = 'Borgol besi, dibuka dengan kunci polisi, lockpick, atau pemotong besi',
},

['zipties'] = {
    label = 'Tali Pengikat',
    weight = 20,
    description = 'Pengikat tangan sekali pakai',
},

['bolt_cutter'] = {
    label = 'Pemotong Besi',
    weight = 2500,
    description = 'Bisa memotong borgol',
},

['tameng_balistik'] = {
    label = 'Tameng Balistik',
    weight = 8000,
    stack = false,
    close = true,
    description = 'Tameng besi anti peluru, dipakai bersama pistol. Pakai lagi untuk melepas',
},

['car_key'] = {
    label = 'Kunci Mobil',
    weight = 1,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'f_vehiclekeys.useCarKey'
    }
},

['key_blank'] = {
    label = 'Kunci Kosong',
    weight = 30,
    description = 'Kunci kosong untuk menduplikat kunci kendaraan (dipakai mekanik)',
},

['unlock_tool'] = {
    label = 'Alat Pembuka Kunci',
    weight = 200,
    stack = false,
    close = true,
},

['security_chip_1'] = {
    label = 'Chip Keamanan Tier 1',
    weight = 50,
    stack = false,
    close = true,
},

['security_chip_2'] = {
    label = 'Chip Keamanan Tier 2',
    weight = 50,
    stack = false,
    close = true,
},

['security_chip_3'] = {
    label = 'Chip Keamanan Tier 3',
    weight = 50,
    stack = false,
    close = true,
},

['signal_jammer'] = {
    label = 'Pengacau Sinyal',
    weight = 400,
    stack = false,
    close = false,
    consume = 0
},

	['phone'] = {
		label = 'HP',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Uang',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Air Mineral',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Rompi Antipeluru',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Pakaian',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Kartu Fleeca',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Besi Tua',
		weight = 80,
	},

	['phone_black'] = {
    label = 'HP',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_black' }
},

['phone_blue'] = {
    label = 'HP Biru',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_blue' }
},

['phone_green'] = {
    label = 'HP Hijau',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_green' }
},

['phone_orange'] = {
    label = 'HP Oranye',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_orange' }
},

['phone_pink'] = {
    label = 'HP Pink',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_pink' }
},

['phone_purple'] = {
    label = 'HP Ungu',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_purple' }
},

['phone_red'] = {
    label = 'HP Merah',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_red' }
},

['phone_yellow'] = {
    label = 'HP Kuning',
    weight = 190,
    stack = false,
    consume = 0,
    server = { export = 'f_phone.usePhone_yellow' }
},

-----------------------------------------------------------------------
-- f_cafe: menu (kadaluarsa 3 hari = 4320 menit; stok di stash siap jual
-- tidak kadaluarsa karena di-strip oleh hook f_cafe)
-----------------------------------------------------------------------
['cafe_burger'] = {
    label = 'Classic Beef Burger', weight = 100, degrade = 4320,
    description = 'Burger daging sapi dengan keju. Kadaluarsa 3 hari.',
    client = { status = { hunger = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_cs_burger_01`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_hotdog'] = {
    label = 'Hot Dog Sausage', weight = 100, degrade = 4320,
    description = 'Hot dog sosis dengan mustard. Kadaluarsa 3 hari.',
    client = { status = { hunger = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_cs_hotdog_01`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_nachos'] = {
    label = 'Loaded Nachos', weight = 100, degrade = 4320,
    description = 'Nachos dengan keju leleh dan salsa. Kadaluarsa 3 hari.',
    client = { status = { hunger = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_taco_01`, bone = 60309, pos = vec3(-0.017, 0.007, -0.021), rot = vec3(107.98, -105.03, 55.78) } },
},
['cafe_donut'] = {
    label = 'Glazed Donut', weight = 80, degrade = 4320,
    description = 'Donat glaze manis. Kadaluarsa 3 hari.',
    client = { status = { hunger = 15, stress = -2 }, usetime = 4000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_amb_donut`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_sandwich'] = {
    label = 'Fresh Sandwich', weight = 100, degrade = 4320,
    description = 'Sandwich ayam dan keju. Kadaluarsa 3 hari.',
    client = { status = { hunger = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_sandwich_01`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_nasigoreng'] = {
    label = 'Nasi Goreng', weight = 150, degrade = 4320,
    description = 'Nasi goreng kecap dengan telur. Kadaluarsa 3 hari.',
    -- prop & animasi dari f_addonprop (stream/makanan)
    client = { status = { hunger = 50, stress = -1 }, usetime = 7000,
        anim = { dict = 'eat@fork', clip = 'fork_clip', flag = 49 },
        prop = {
            { model = `prop_sendok`, bone = 57005, pos = vec3(0.14, 0.02, 0.01), rot = vec3(-118.0, 192.0, 24.0) },
            { model = `prop_nasi_goreng_v2`, bone = 60309, pos = vec3(0.1, 0.03, 0.02), rot = vec3(-11.08, 0.0, 0.0) },
        } },
},
-- prop dari f_addonprop (stream/makanan, dibangun dari _sumber/makanan/*.glb)
['mie_goreng_telor'] = {
    label = 'Mie Goreng Telor', weight = 150, degrade = 4320,
    description = 'Mie goreng dengan telur ceplok, sawi dan kerupuk. Kadaluarsa 3 hari.',
    client = { status = { hunger = 25, stress = -2 }, usetime = 7000,
        anim = { dict = 'eat@fork', clip = 'fork_clip', flag = 49 },
        prop = {
            { model = `devkit_spork`, bone = 57005, pos = vec3(0.14, 0.02, 0.01), rot = vec3(-118.0, 192.0, 24.0) },
            { model = `prop_mie_goreng_telor`, bone = 60309, pos = vec3(0.1, 0.03, 0.02), rot = vec3(-11.08, 0.0, 0.0) },
        } },
},
['mie_rebus_telor'] = {
    label = 'Mie Telor Rebus', weight = 200, degrade = 4320,
    description = 'Mie rebus berkuah dengan telur ceplok. Kadaluarsa 3 hari.',
    client = { status = { hunger = 25, stress = -2 }, usetime = 7000,
        anim = { dict = 'eat@fork', clip = 'fork_clip', flag = 49 },
        prop = {
            { model = `prop_sendok`, bone = 57005, pos = vec3(0.14, 0.02, 0.01), rot = vec3(-118.0, 192.0, 24.0) },
            { model = `prop_mie_rebus_telor`, bone = 60309, pos = vec3(0.09, 0.02, 0.01), rot = vec3(-09.08, 0.0, 0.0) },
        } },
},
['steak'] = {
    label = 'Steak', weight = 200, degrade = 4320,
    description = 'Steak daging sapi panggang. Kadaluarsa 3 hari.',
    client = { status = { hunger = 50, stress = -1 }, usetime = 7000,
        anim = { dict = 'eat@fork', clip = 'fork_clip', flag = 49 },
        prop = {
            { model = `devkit_spork`, bone = 57005, pos = vec3(0.14, 0.02, 0.01), rot = vec3(-118.0, 192.0, 24.0) },
            { model = `prop_nycsteak`, bone = 60309, pos = vec3(0.1, 0.03, 0.02), rot = vec3(-11.08, 0.0, 0.0) },
        } },
},
['cafe_cappuccino'] = {
    label = 'Classic Cappuccino', weight = 120, degrade = 4320,
    description = 'Cappuccino hangat dengan kayu manis. Kadaluarsa 3 hari.',
    client = { status = { thirst = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_colafloat'] = {
    label = 'Iced Cola Float', weight = 120, degrade = 4320,
    description = 'Cola dingin dengan es krim vanila. Kadaluarsa 3 hari.',
    client = { status = { thirst = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_milkshake'] = {
    label = 'Chocolate Milkshake', weight = 120, degrade = 4320,
    description = 'Milkshake coklat dingin. Kadaluarsa 3 hari.',
    client = { status = { thirst = 25, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_orangejuice'] = {
    label = 'Fresh Orange Juice', weight = 120, degrade = 4320,
    description = 'Jus jeruk segar. Kadaluarsa 3 hari.',
    client = { status = { thirst = 25, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_energysoda'] = {
    label = 'Energy Soda', weight = 120, degrade = 4320,
    description = 'Soda berenergi. Kadaluarsa 3 hari.',
    client = { status = { thirst = 15, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_stmj'] = {
    label = 'STMJ', weight = 150, degrade = 4320,
    description = 'Susu, telur, madu dan jahe hangat. Kadaluarsa 3 hari.',
    client = { status = { thirst = 25, stress = -2 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_kelapamuda'] = {
    label = 'Es Kelapa Muda Utuh', weight = 400, degrade = 4320,
    description = 'Satu buah kelapa muda utuh dengan es. Kadaluarsa 3 hari.',
    client = { status = { thirst = 50, stress = -1 }, usetime = 7000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_jusalpukat'] = {
    label = 'Jus Alpukat Jumbo', weight = 300, degrade = 4320,
    description = 'Jus alpukat gelas jumbo dengan susu coklat. Kadaluarsa 3 hari.',
    client = { status = { thirst = 50, stress = -1 }, usetime = 7000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop', flag = 49 },
        prop = { model = `prop_cup_warmindo`, bone = 60309, pos = vec3(0.01, -0.03, -0.13), rot = vec3(5.0, 5.0, -180.5) } },
},

-----------------------------------------------------------------------
-- f_cafe: bahan baku
-----------------------------------------------------------------------
['roti_burger']      = { label = 'Roti Burger',      weight = 60,  description = 'Bahan baku cafe.' },
['roti_hotdog']      = { label = 'Roti Hotdog',      weight = 60,  description = 'Bahan baku cafe.' },
['roti_tawar']       = { label = 'Roti Tawar',       weight = 150, description = 'Bahan baku cafe.' },
['daging_sapi']      = { label = 'Daging Sapi',      weight = 100, description = 'Bahan baku cafe.' },
['daging_ayam']      = { label = 'Daging Ayam',      weight = 100, description = 'Bahan baku cafe.' },
['sosis']            = { label = 'Sosis',            weight = 50,  description = 'Bahan baku cafe.' },
['keju']             = { label = 'Keju',             weight = 30,  description = 'Bahan baku cafe.' },
['saus_mustard']     = { label = 'Saus Mustard',     weight = 200, description = 'Bahan baku cafe.' },
['saus_salsa']       = { label = 'Saus Salsa',       weight = 200, description = 'Bahan baku cafe.' },
['keripik_tortilla'] = { label = 'Keripik Tortilla', weight = 150, description = 'Bahan baku cafe.' },
['adonan_donat']     = { label = 'Adonan Donat',     weight = 100, description = 'Bahan baku cafe.' },
['minyak_goreng']    = { label = 'Minyak Goreng',    weight = 500, description = 'Bahan baku cafe.' },
['gula']             = { label = 'Gula',             weight = 100, description = 'Bahan baku cafe.' },
['bubuk_kopi']       = { label = 'Bubuk Kopi',       weight = 100, description = 'Bahan baku cafe.' },
['bubuk_coklat']     = { label = 'Bubuk Coklat',     weight = 100, description = 'Bahan baku cafe.' },
['kayu_manis']       = { label = 'Kayu Manis',       weight = 30,  description = 'Bahan baku cafe.' },
['susu']             = { label = 'Susu',             weight = 250, description = 'Bahan baku cafe.' },
['es_batu']          = { label = 'Es Batu',          weight = 200, description = 'Bahan baku cafe.' },
['es_krim_vanila']   = { label = 'Es Krim Vanila',   weight = 150, description = 'Bahan baku cafe.' },
['soda_cola']        = { label = 'Soda Cola',        weight = 150, description = 'Bahan baku cafe.' },
['air_soda']         = { label = 'Air Soda',         weight = 150, description = 'Bahan baku cafe.' },
['sirup_energi']     = { label = 'Sirup Energi',     weight = 100, description = 'Bahan baku cafe.' },
['jeruk']            = { label = 'Jeruk',            weight = 100, description = 'Bahan baku cafe.' },
['beras']            = { label = 'Beras',            weight = 200, description = 'Bahan baku cafe.' },
['telur']            = { label = 'Telur',            weight = 50,  description = 'Bahan baku cafe.' },
['kecap_manis']      = { label = 'Kecap Manis',      weight = 200, description = 'Bahan baku cafe.' },
['mie_instan']       = { label = 'Mie Instan',       weight = 80,  description = 'Bahan baku cafe.' },
['madu']             = { label = 'Madu',             weight = 200, description = 'Bahan baku cafe.' },
['jahe']             = { label = 'Jahe',             weight = 50,  description = 'Bahan baku cafe.' },
['kelapa_muda']      = { label = 'Kelapa Muda',      weight = 400, description = 'Bahan baku cafe.' },
['alpukat']          = { label = 'Alpukat',          weight = 150, description = 'Bahan baku cafe.' },
['susu_kental_manis'] = { label = 'Susu Kental Manis', weight = 200, description = 'Bahan baku cafe.' },

-- Bahan baku (bengkel mekanik, recycle, scrapyard, house robbery)
['metalscrap'] = { label = 'Besi Bekas', weight = 100, description = 'Potongan logam bekas. Bahan perbaikan mesin.' },
['plastic']    = { label = 'Plastik',     weight = 100, description = 'Plastik daur ulang. Bahan perbaikan body & tangki.' },
['steel']      = { label = 'Baja',       weight = 100, description = 'Baja. Bahan perbaikan radiator & suspensi.' },
['aluminum']   = { label = 'Aluminium',    weight = 100, description = 'Aluminium. Bahan perbaikan as roda.' },
['copper']     = { label = 'Tembaga',      weight = 500, description = 'Tembaga. Bahan perbaikan rem & kopling.' },
['iron']       = { label = 'Besi',        weight = 100, description = 'Besi.' },
['glass']      = { label = 'Kaca',       weight = 100, description = 'Kaca bekas.' },
['rubber']     = { label = 'Karet',      weight = 100, description = 'Karet.' },

-- Suku cadang & cairan bengkel (dipakai mekanik di panel Periksa Kendaraan)
['engine_oil']  = { label = 'Oli Mesin',         weight = 1000, description = 'Oli mesin. Dipakai mekanik untuk ganti oli.' },
['coolant']     = { label = 'Cairan Pendingin',            weight = 1000, description = 'Cairan pendingin mesin.' },
['brake_fluid'] = { label = 'Minyak Rem',        weight = 500,  description = 'Minyak rem.' },
['trans_fluid'] = { label = 'Oli Transmisi', weight = 1000, description = 'Oli transmisi.' },
['spark_plug']  = { label = 'Busi',        weight = 200,  description = 'Satu set busi.' },
['air_filter']  = { label = 'Filter Udara',         weight = 300,  description = 'Filter udara mesin.' },

-- Peralatan kendaraan (vehiclehandler). Dijual di toko bengkel mekanik.
['repairkit'] = {
    label = 'Alat Perbaikan', weight = 2500, close = true,
    description = 'Perbaikan darurat: mesin naik ke 50% supaya bisa jalan ke bengkel. Berdiri di depan kap mesin.',
    server = { export = 'vehiclehandler.repairkit' },
},
['tirekit'] = {
    label = 'Alat Tambal Ban', weight = 1000, close = true,
    description = 'Tambal ban yang bocor. Berdiri di dekat ban. Keausan ban tetap perlu mekanik.',
    server = { export = 'vehiclehandler.tirekit' },
},
['cleaningkit'] = {
    label = 'Alat Pembersih', weight = 250, close = true,
    description = 'Membersihkan kendaraan.',
    server = { export = 'vehiclehandler.cleaningkit' },
},

-- Hewan peliharaan (f_petshop). Diberikan lewat target pada hewanmu.
['pet_food'] = { label = 'Makanan Hewan', weight = 200, stack = true, close = true, description = 'Makanan untuk hewan peliharaan. Arahkan target ke hewanmu lalu pilih "Beri Makanan Hewan".' },
['pet_leash'] = { label = 'Tali Anjing', weight = 200, stack = true, close = true, description = 'Tali untuk hewan peliharaan. Pasang/lepas lewat Menu Hewan (target hewanmu).' },
['pet_water'] = { label = 'Air Minum Hewan', weight = 300, stack = true, close = true, description = 'Air minum untuk hewan peliharaan. Arahkan target ke hewanmu lalu pilih "Beri Air Minum Hewan".' },

-- Gang Wars Rebut Bendera (f_crew). Metadata crew = gang pemilik; hanya dari admin (/peranggang > Bendera) / mafia.
['bendera_gang'] = {
    label = 'Bendera Gang', weight = 2000, stack = false, close = true,
    description = 'Bendera gang. Pakai untuk memegang, tancapkan saat Rebut Bendera.',
    client = { export = 'f_crew.useFlag' },
},

-- Tambang (f_mining). Bijih tidak bisa dijual: lebur di tungku lobby tambang -> batangan, jual di pengepul.
-- Hasil lebur memakai item yang sudah ada: copper (mekanik), goldbar & diamond (f_pawnshop / f_bankrobbery).
['kapak_tambang'] = { label = 'Kapak Tambang', weight = 2000, stack = false, close = true, description = 'Untuk menambang batu di gua. Patah setelah 200 pukulan.' },
['bijih_tembaga'] = { label = 'Bijih Tembaga', weight = 500, description = 'Bijih mentah. Lebur di tungku tambang jadi Tembaga.' },
['bijih_perak']   = { label = 'Bijih Perak',   weight = 500, description = 'Bijih mentah. Lebur di tungku tambang jadi Batang Perak.' },
['bijih_emas']    = { label = 'Bijih Emas',    weight = 500, description = 'Bijih mentah. Lebur di tungku tambang jadi Batang Emas.' },
['silverbar']     = { label = 'Batang Perak',  weight = 1000, description = 'Batang perak. Jual di pengepul Balai Kota.' },
['goldbar']       = { label = 'Batang Emas',   weight = 1000, description = 'Batang emas. Jual di pengepul Balai Kota.' },
['diamond']       = { label = 'Berlian',       weight = 50,   description = 'Berlian. Jual di pengepul Balai Kota.' },
['chainsaw']      = { label = 'Chainsaw',      weight = 3000, stack = false, close = true, description = 'Untuk menebang pohon. Rusak setelah 50 pohon.' },
['papan_kayu']    = { label = 'Papan Kayu',    weight = 400,  description = 'Papan hasil sawmill Paleto. Jual di koperasi Balai Kota.' },
-- Nelayan (f_nelayan): jaring tebar, durability turun 20 tiap tarikan berhasil -> rusak setelah 5 kali dapat ikan
['jaring_ikan']   = { label = 'Jaring Ikan',   weight = 1500, stack = false, close = true, description = 'Jaring tebar untuk melaut. Rusak setelah 5 kali dapat ikan (tarikan gagal tidak dihitung). Beli di Syahbandar dermaga.' },
}
