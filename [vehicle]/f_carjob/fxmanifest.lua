fx_version "cerulean"
game "gta5"
name "f_carjob"
description "Kumpulan kendaraan kerja (jangan di-restart saat server jalan, restart server penuh)"

-- Kendaraan baru: stream/<nama>/ (.yft .ytd + _manifest<nama>.ymf) dan data/<nama>/*.meta,
-- lalu tambah folder data-nya ke files dan blok data_file-nya di bawah.

files {
	"data/master/*.meta",
	"data/17mov_flatbed/*.meta",
}

-- master, master2: truk sampah f_garbagejob
data_file "DLCTEXT_FILE" "data/master/dlctext.meta"
data_file "VEHICLE_LAYOUTS_FILE" "data/master/vehiclelayouts.meta"
data_file "HANDLING_FILE" "data/master/handling.meta"
data_file "VEHICLE_METADATA_FILE" "data/master/vehicles.meta"
data_file "VEHICLE_VARIATION_FILE" "data/master/carvariations.meta"

-- 17mov_flatbed: truk crane penebang kayu (dari 17mov Lumberjack)
data_file "HANDLING_FILE" "data/17mov_flatbed/handling.meta"
data_file "VEHICLE_METADATA_FILE" "data/17mov_flatbed/vehicles.meta"
data_file "VEHICLE_VARIATION_FILE" "data/17mov_flatbed/carvariations.meta"
