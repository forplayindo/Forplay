// f_phone: semua tulisan dinaikkan FONT_BUMP_PX tanpa mengubah tata letak. Ukuran huruf di f_phone
// ditulis langsung (class Tailwind text-[17px], text-sm, dll.) dan tidak punya skala global,
// jadi setiap deklarasi `font-size` di CSS hasil build ditambah 1px di sini. Ukuran yang
// ditulis inline di komponen (style={{ fontSize }}) tidak ikut - jumlahnya sedikit.
const FONT_BUMP_PX = 5;

const fontBump = () => ({
    postcssPlugin: 'f-phone-font-bump',
    Declaration: {
        'font-size'(decl) {
            if (decl.__fPhoneBumped) return;
            decl.__fPhoneBumped = true;
            const v = decl.value.trim();
            const px = /^(\d+(?:\.\d+)?)px$/.exec(v);
            if (px) {
                decl.value = `${parseFloat(px[1]) + FONT_BUMP_PX}px`;
            } else if (/^\d+(?:\.\d+)?rem$/.test(v)) {
                // em sengaja tidak: relatif ke induk yang sudah ikut naik, jadi akan berlipat
                decl.value = `calc(${v} + ${FONT_BUMP_PX}px)`;
            }
        },
    },
});
fontBump.postcss = true;

module.exports = {
    plugins: [
        require('tailwindcss'),
        fontBump(),
        require('autoprefixer'),
    ],
};
