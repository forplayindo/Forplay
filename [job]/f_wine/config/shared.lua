-- F_Wine: job bebas (siapa saja), solo. Kebun anggur Marlowe.
-- Koordinat bertanda PERKIRAAN: kalibrasi di game dengan /winepos (admin), lalu tempel di sini.
return {
    debug = false,             -- true = perintah /wineoffset untuk setel posisi prop di tangan / di tong

    -- 3 blok kebun = 3 jenis wine. Harga hanya untuk ditampilkan di menu Mandor;
    -- harga jual sebenarnya ada di f_koperasi/config/shared.lua (kategori 'Wine').
    jenis = {
        merah = { label = 'Wine Merah', anggur = 'Anggur Ungu',  blok = 'Blok sekitar winery', warna = '#8e3fae', harga = 24000,
                  jus = 'botol_jus_merah', wine = 'wine_merah', tandan = `f_anggur_ungu`,  tong = `f_wine_tong_merah` },
        putih = { label = 'Wine Putih', anggur = 'Anggur Hijau', blok = 'Blok tenggara',       warna = '#a5c25a', harga = 27000,
                  jus = 'botol_jus_putih', wine = 'wine_putih', tandan = `f_anggur_hijau`, tong = `f_wine_tong_putih` },
        rose  = { label = 'Wine Rosé',  anggur = 'Anggur Merah', blok = 'Blok lereng utara',   warna = '#d0506e', harga = 30000,
                  jus = 'botol_jus_rose',  wine = 'wine_rose',  tandan = `f_anggur_merah`, tong = `f_wine_tong_rose` },
    },
    urutan = { 'merah', 'putih', 'rose' },

    lokasi = {
        mandor = vec4(-1928.80, 2059.75, 141.00, 250.0),     -- PERKIRAAN (titik olah f_vineyard lama)
        fermentasi = {                                        -- 3 tong fermentasi di winery, PERKIRAAN
            vec4(-1926.10, 2063.00, 141.00, 160.0),
            vec4(-1925.10, 2064.20, 141.00, 160.0),
            vec4(-1924.10, 2065.40, 141.00, 160.0),
        },
        injak = {                                             -- pos injak di pinggir tiap blok (bebas barisan pohon), PERKIRAAN
            merah = vec4(-1868.56, 2101.54, 136.74, 0.0),
            putih = vec4(-1755.28, 1974.62, 120.00, 0.0),
            rose  = vec4(-1675.11, 2243.34, 81.89, 0.0),
        },
    },

    keranjangMax = 20,         -- tandan per keranjang penuh
    botolPerJus = 4,           -- 1 botol jus (1 keranjang) = 4 botol wine
    tumbuhMenit = 10,          -- tandan yang dipetik tumbuh lagi (per pemain)
    fermentasiMenit = 15,
    tongPerPemain = 3,
    jusPerTong = 5,

    jarak = {
        mandor = 3.0,
        petik = 2.6,           -- pemain ke tandan
        keranjangKeTandan = 15.0, -- keranjang harus ditaruh dekat tandan yang dipetik
        keranjang = 2.5,       -- pemain ke keranjang (masukkan / angkat)
        injak = 3.0,
        fermentasi = 3.5,
        render = 45.0,         -- tandan dimunculkan dalam radius ini
    },

    injakMinDetik = 8,         -- minigame tidak bisa selesai lebih cepat dari ini (cek server)
    keranjangTinggalMenit = 10, -- keranjang di tanah ditinggal > 150 m selama ini -> kembali ke tangan
}
