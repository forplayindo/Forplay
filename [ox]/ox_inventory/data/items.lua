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
		client = { image = 'medikit.png' },
	},

	['tas_operasi'] = {
		label = 'Tas Operasi',
		weight = 2000,
		stack = false,
		degrade = 1440, -- 24 jam sejak diambil dari armory
		description = 'Tas operasi Dokter. Wajib dibawa untuk operasi; obat diambil dari Stok Gudang.',
		client = { image = 'advancedkit.png' },
	},

	['tas_perkakas'] = {
		label = 'Tas Perkakas',
		weight = 2000,
		stack = false,
		degrade = 2880, -- 2 hari sejak diambil di Gudang Bengkel
		description = 'Tas perkakas mekanik. Wajib dibawa untuk memperbaiki kendaraan; bahan diambil dari Stok Gudang Bengkel.',
		client = { image = 'WEAPON_WRENCH.png' },
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
		label = 'Kruk',
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

	['driver_license'] = {
		label = 'SIM',
		client = {
			image = 'card_id.png'
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
    client = { image = 'cafe_burger.png', status = { hunger = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_cs_burger_01`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_hotdog'] = {
    label = 'Hot Dog Sausage', weight = 100, degrade = 4320,
    description = 'Hot dog sosis dengan mustard. Kadaluarsa 3 hari.',
    client = { image = 'cafe_hotdog.png', status = { hunger = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_cs_hotdog_01`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_nachos'] = {
    label = 'Loaded Nachos', weight = 100, degrade = 4320,
    description = 'Nachos dengan keju leleh dan salsa. Kadaluarsa 3 hari.',
    client = { image = 'cafe_nachos.png', status = { hunger = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_taco_01`, bone = 60309, pos = vec3(-0.017, 0.007, -0.021), rot = vec3(107.98, -105.03, 55.78) } },
},
['cafe_donut'] = {
    label = 'Glazed Donut', weight = 80, degrade = 4320,
    description = 'Donat glaze manis. Kadaluarsa 3 hari.',
    client = { image = 'cafe_donut.png', status = { hunger = 10 }, usetime = 4000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_amb_donut`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_sandwich'] = {
    label = 'Fresh Sandwich', weight = 100, degrade = 4320,
    description = 'Sandwich ayam dan keju. Kadaluarsa 3 hari.',
    client = { image = 'cafe_sandwich.png', status = { hunger = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49 },
        prop = { model = `prop_sandwich_01`, bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
},
['cafe_cappuccino'] = {
    label = 'Classic Cappuccino', weight = 120, degrade = 4320,
    description = 'Cappuccino hangat dengan kayu manis. Kadaluarsa 3 hari.',
    client = { image = 'cafe_cappuccino.png', status = { thirst = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 },
        prop = { model = `p_amb_coffeecup_01`, bone = 60309, pos = vec3(0.01, 0.01, 0.02), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_colafloat'] = {
    label = 'Iced Cola Float', weight = 120, degrade = 4320,
    description = 'Cola dingin dengan es krim vanila. Kadaluarsa 3 hari.',
    client = { image = 'cafe_colafloat.png', status = { thirst = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 },
        prop = { model = `prop_ecola_can`, bone = 60309, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_milkshake'] = {
    label = 'Chocolate Milkshake', weight = 120, degrade = 4320,
    description = 'Milkshake coklat dingin. Kadaluarsa 3 hari.',
    client = { image = 'cafe_milkshake.png', status = { thirst = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 },
        prop = { model = `prop_cs_bs_cup`, bone = 60309, pos = vec3(0.01, 0.01, 0.02), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_orangejuice'] = {
    label = 'Fresh Orange Juice', weight = 120, degrade = 4320,
    description = 'Jus jeruk segar. Kadaluarsa 3 hari.',
    client = { image = 'cafe_orangejuice.png', status = { thirst = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 },
        prop = { model = `prop_plastic_cup_02`, bone = 60309, pos = vec3(0.01, 0.01, 0.02), rot = vec3(5.0, 5.0, -180.5) } },
},
['cafe_energysoda'] = {
    label = 'Energy Soda', weight = 120, degrade = 4320,
    description = 'Soda berenergi. Kadaluarsa 3 hari.',
    client = { image = 'cafe_energysoda.png', status = { thirst = 10 }, usetime = 5000,
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49 },
        prop = { model = `prop_energy_drink`, bone = 60309, pos = vec3(0.008, 0.001, 0.016), rot = vec3(3.57, 4.66, -49.91) } },
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

-- Bahan baku (bengkel mekanik, recycle, scrapyard, house robbery)
['metalscrap'] = { label = 'Besi Bekas', weight = 100, description = 'Potongan logam bekas. Bahan perbaikan mesin.' },
['plastic']    = { label = 'Plastik',     weight = 100, description = 'Plastik daur ulang. Bahan perbaikan body & tangki.' },
['steel']      = { label = 'Baja',       weight = 100, description = 'Baja. Bahan perbaikan radiator & suspensi.' },
['aluminum']   = { label = 'Aluminium',    weight = 100, description = 'Aluminium. Bahan perbaikan as roda.' },
['copper']     = { label = 'Tembaga',      weight = 100, description = 'Tembaga. Bahan perbaikan rem & kopling.' },
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
}
