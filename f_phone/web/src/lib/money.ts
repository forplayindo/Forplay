export function formatMoney(n: number, opts: {
    decimals?:   number;
    showSign?:   boolean;
    whole?:      boolean;
    alwaysSign?: boolean;
} = {}): string {
    // Rupiah: no cents unless the value really has a fraction (stock/crypto prices)
    const decimals = opts.decimals ?? (opts.whole || Number.isInteger(n) ? 0 : 2);
    const abs = Math.abs(n).toLocaleString('id-ID', {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
    });
    if (n < 0) return `-Rp ${abs}`;
    if (opts.alwaysSign) return `+Rp ${abs}`;
    return opts.showSign && n > 0 ? `+Rp ${abs}` : `Rp ${abs}`;
}
