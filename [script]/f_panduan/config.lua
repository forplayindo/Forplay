-- Alur Kerja tiap job. Teks boleh memakai <b>tebal</b>.
-- Job memanggil exports.f_panduan:Start('<kunci>') saat mulai kerja dan Stop('<kunci>') saat selesai.
-- Saat panel dibuka di tengah kerja, f_panduan memicu event 'f_panduan:client:requestStep' (kunci job)
-- dan job menjawab dengan exports.f_panduan:SetStep('<kunci>', nomorLangkah) untuk tanda "Sekarang".
return {
    autoTimes = 3,          -- panel muncul otomatis saat Mulai Kerja di sekian kerja pertama tiap job (per karakter)
    key = 'F7',             -- tombol default buka / tutup (pemain bisa ganti di Settings > Key Bindings > FiveM)
    autoDelay = 1200,       -- jeda setelah Mulai Kerja sebelum panel muncul (menu job sempat tertutup dulu)

    order = { 'kayu', 'tambang', 'nelayan', 'sampah', 'kurir' },

    jobs = {
        kayu = {
            name = 'Penebang Kayu', icon = 'tree',
            steps = {
                { 'Pergi ke hutan dengan truk kerja',
                  'Ikuti petunjuk arah di peta menuju hutan, pakai truk yang sudah disiapkan. Jangan lupa <b>beli chainsaw</b> di Mandor untuk menebang. Satu chainsaw bisa dipakai untuk <b>50 pohon</b>.' },
                { 'Tebang pohon dan muat ke bak truk',
                  'Arahkan target ke pohon lalu pilih <b>Tebang pohon</b>. Kalau kerja sendiri, potong batangnya jadi 3 bagian lalu panggul satu per satu ke belakang truk. Kalau berdua, angkat batang besar bersama (satu di depan, satu di belakang).' },
                { 'Bawa kayu ke tempat pengolahan',
                  'Parkir truk di tempat yang sudah disediakan, dengan <b>bagian belakang truk menghadap mesin</b>. Tekan <b>[E] Olah Kayu</b>, lalu tunggu kayu masuk mesin satu per satu.' },
                { 'Ambil papan hasil olahan',
                  'Papan hasil olahan ada di tumpukan <b>di bawah mesin pengolahan</b>. Parkir truk di dekatnya, arahkan target ke tumpukan papan, lalu pilih <b>Pindahkan papan ke truk</b>.' },
                { 'Kembali ke gudang untuk menyimpan papan',
                  'Bawa truk ke Mandor di Paleto, arahkan target ke truk lalu pilih <b>Bongkar papan</b>. Papan masuk gudang dan bisa diambil kapan saja di <b>petugas gudang (Mandor)</b>, lalu dijual di Koperasi.' },
            },
            rules = {
                'Kalau kamu berhenti bekerja, papan yang belum dibongkar tetap otomatis masuk gudang.',
                'Truk ditinggal lebih dari 300 meter selama 5 menit = pekerjaan dibatalkan.',
            },
        },

        tambang = {
            name = 'Penambang', icon = 'pick',
            steps = {
                { 'Turun ke tambang dan ganti baju',
                  'Pilih <b>Turun ke Tambang</b> di pintu tambang, lalu ganti baju di <b>loker lobby</b> (helm sudah termasuk). Kamu <b>tidak bisa menambang tanpa baju tambang</b>. Beli <b>Kapak Tambang</b> di rak lobby, satu kapak bisa dipakai 200 kali pukul.' },
                { 'Masuk ke gua',
                  'Pilih <b>Masuk Gua</b> dan pilih gua yang masih ada tempat. Satu gua <b>maksimal 6 penambang</b>.' },
                { 'Tambang batu di dinding gua',
                  'Arahkan target ke batu lalu pilih <b>Tambang Batu</b>. Setiap 2 ayunan dapat 1 bijih (tembaga, perak, emas, atau berlian yang langka). Bijih masuk ke tasmu.' },
                { 'Setor bijih ke lori',
                  'Pilih <b>Setor Semua ke Lori</b> di bak lori persimpangan gua. Lori akan mengantar bijih ke Gudang Tambang di lobby.' },
                { 'Lebur bijih di tungku',
                  'Di lobby, pilih <b>Ambil Wadah</b> (maksimal 50 bijih), bawa ke tungku yang kosong lalu pilih <b>Taruh Wadah</b>. Bijih dilebur otomatis jadi batangan dan masuk gudang. <b>Bijih mentah tidak bisa dijual.</b>' },
                { 'Ambil hasil dan jual',
                  'Naik ke atas, buka <b>Gudang Hasil</b> di dekat pintu tambang, pindahkan batangan ke kendaraanmu, lalu jual di <b>Koperasi Balai Kota</b>.' },
            },
            rules = {
                'Tidak memukul batu selama 10 menit = kamu dipindahkan kembali ke lobby.',
            },
        },

        nelayan = {
            name = 'Nelayan', icon = 'fish',
            steps = {
                { 'Naik ke kapal nelayan',
                  'Bicara dengan <b>Syahbandar</b> di dermaga untuk mulai bekerja, lalu arahkan target ke kapal dan pilih <b>Naik ke kapal</b>. Pastikan sudah <b>membeli jaring</b>. Satu jaring bisa dipakai <b>5 kali tebar</b>, setelah itu rusak.' },
                { 'Lihat lokasi menangkap ikan di peta',
                  'Lokasi menangkap ikan ditandai di peta. Bawa kapal ke sana, lalu <b>pelankan kapal</b> sebelum menebar jaring.' },
                { 'Tebar jaring di lokasi',
                  'Tebar jaring lalu tunggu ikan masuk, jangan menjauh dari jaring. Saat menarik jaring ada <b>permainan kecil</b>: tekan [E] saat penanda di zona hijau, <b>minimal 2 dari 3 harus tepat</b>. Kalau gagal, ikan lepas tapi jaring tidak berkurang. Masukkan ikan ke peti di dek kapal.' },
                { 'Kembali ke dermaga dan turunkan peti',
                  'Arahkan target ke tumpukan peti ikan untuk <b>menurunkan peti</b> dari kapal. Gunakan target juga untuk <b>turun dari kapal</b> ke dermaga.' },
                { 'Muat peti ke mobil yang sudah disiapkan',
                  'Angkat peti ikan bagianmu dan masukkan ke <b>bak mobil Bison</b> di parkiran dermaga.' },
                { 'Antar ke Pasar Ikan',
                  'Ikuti petunjuk arah ke Pasar Ikan dan jual peti ikan. Uang langsung masuk <b>rekening bank</b>. Setelah itu kembalikan mobil ke parkiran dermaga.' },
            },
            rules = {
                'Mobil kerja hanya untuk mengantar ikan. Setelah ikan terjual, kembalikan dalam <b>5 menit</b>. Kalau tidak dikembalikan atau dibawa keluar jalur, kena <b>denda Rp 200.000</b>.',
                'Kapal terlalu jauh dari jaring = jaring putus dan hanyut.',
            },
        },

        sampah = {
            name = 'Tukang Sampah', icon = 'trash',
            steps = {
                { 'Ambil pekerjaan di Job Centre',
                  'Di Balai Kota pilih <b>Tukang Sampah</b>, pilih tingkat kesulitan, ajak teman kalau mau (maksimal 4 orang), lalu tekan Mulai.' },
                { 'Ambil truk di depot',
                  'Truk sampah menunggu di <b>depot La Mesa</b>. Ikuti petunjuk arah ke titik sampah pertama.' },
                { 'Angkut kantong sampah',
                  'Kantong sampah ditandai <b>panah kuning</b>. Ambil kantongnya lalu lempar ke atas truk.' },
                { 'Kosongkan kontainer',
                  'Kontainer ditandai <b>panah hijau</b>. Kaitkan ke truk dengan <b>[E]</b>, angkat dan kosongkan dengan <b>[SHIFT]</b>, lalu lepas lagi dengan <b>[E]</b>.' },
                { 'Selesaikan semua titik lalu kembali',
                  'Sisa titik terlihat di HUD. Setelah semua selesai, kembali ke depot dan pilih <b>Selesai Kerja</b>. Bayaran dibagi rata ke semua anggota.' },
            },
            rules = {
                'Truk ditinggal lebih dari 300 meter selama 5 menit = pekerjaan dibatalkan.',
            },
        },

        kurir = {
            name = 'Kurir Paket', icon = 'box',
            steps = {
                { 'Ambil pekerjaan di Job Centre',
                  'Di Balai Kota pilih <b>Kurir</b>, pilih rute, dan ajak 1 teman kalau mau kerja berdua.' },
                { 'Muat paket ke van',
                  'Pergi ke <b>depot GoPostal</b>, van akan muncul. Ambil paket dari tumpukan lalu masukkan ke belakang van.' },
                { 'Antar paket ke alamat',
                  'Ikuti petunjuk arah. Sesampainya di alamat, ambil paket dari van. <b>Paket besar harus diangkat berdua.</b>' },
                { 'Serahkan ke penerima',
                  'Serahkan paket ke penerima yang menunggu di depan alamat. Kadang penerima perlu <b>tanda tangan</b> dulu.' },
                { 'Kembali ke depot',
                  'Setelah semua paket terantar, kembali ke depot dan tekan <b>[E] Selesai rute</b>. Bayaran dibagi, lalu pilih <b>Lanjut Rute</b> atau <b>Selesai Kerja</b>.' },
            },
            rules = {
                'Van ditinggal lebih dari 300 meter selama 5 menit, atau van rusak/tenggelam = pekerjaan dibatalkan.',
            },
        },
    },
}
