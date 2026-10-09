import { formatClockTime, useDisplayClock } from '@/hooks/useClock';
import { t } from '@/i18n';
import { signalBarOpacities } from '@/lib/signal';
import { SIDE_DOCK_W } from '@/device/grid';
import { useFoldOpen } from '@/stores/foldStore';

export interface StatusBarProps {
    use24h: boolean;
    signal: number;
    showWifi: boolean;
    wifiBars?: number | null;
    battery: number;
    airplane?: boolean;
    focus?: boolean;
    noSim?: boolean;
    noService?: boolean;
    light?: boolean;
    controlHint?: boolean;
    editing?: boolean;
    /**
     * f_phone (Duo): homescreen & lockscreen - jam dan ikon Wi-Fi/sinyal dalam lingkaran ditumpuk
     * di kolom kanan, di bawah kamera bolong, seperti iPhone lipat asli.
     */
    side?: boolean;
}

// f_phone: kamera bolong di kanan atas (shell 'ios': lebar 44, jarak kanan 40). Ikon status di
// dalam aplikasi digeser ke kirinya supaya tidak tertutup kamera.
const CAMERA_CLEAR = 44 + 40 + 12;
// Jam di dalam aplikasi: dijauhkan dari bezel kiri. Dibentangkan, sudut kiri atas ikut membulat
// penuh (bukan sisi engsel yang rata), jadi jaraknya lebih besar.
const CLOCK_START = 36;
const CLOCK_START_OPEN = 64;

export function StatusBar({ use24h, signal, showWifi, wifiBars = null, battery, airplane = false, focus = false, noSim = false, noService = false, light = true, controlHint = false, editing = false, side = false }: StatusBarProps) {
    const time  = formatClockTime(useDisplayClock(), use24h);
    const color = light ? '#ffffff' : '#000000';
    const unfolded = useFoldOpen();

    if (side) {
        return (
            <div className="pointer-events-none relative z-40 h-[54px] transition-colors duration-300 ease-out" style={{ color }}>
                <div
                    className="absolute flex flex-col items-center gap-[8px]"
                    style={{ insetInlineEnd: 0, top: 80, width: SIDE_DOCK_W, visibility: editing ? 'hidden' : undefined }}
                >
                    <span className="font-sf text-[18px] font-bold leading-none">{time}</span>
                    <div className="relative flex h-[46px] w-[46px] items-center justify-center" style={{ opacity: 0.95 }}>
                        <SignalRing bars={airplane || noSim || noService ? 0 : signal} />
                        {airplane ? (
                            <Airplane size={22} />
                        ) : noSim || noService ? (
                            <span className="font-sf text-[11px] font-bold leading-none">{noSim ? 'SIM' : 'SOS'}</span>
                        ) : (
                            // selalu ikon Wi-Fi di tengah cincin, seperti HP aslinya
                            <Wifi size={21} bars={wifiBars} />
                        )}
                    </div>
                    <div className="flex items-center gap-[4px]">
                        {focus && <Moon size={14} />}
                        <Battery size={24} pct={battery} />
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div
            className="pointer-events-none relative z-40 flex h-[54px] items-center justify-between transition-colors duration-300 ease-out"
            style={{ color, paddingInlineStart: unfolded ? CLOCK_START_OPEN : CLOCK_START, paddingInlineEnd: CAMERA_CLEAR }}
        >
            {!editing && (
                <span className="font-sf text-[18px] font-bold leading-none" style={{ marginLeft: 5 }}>
                    {time}
                </span>
            )}

            <div className="relative flex items-center gap-[6px]" style={{ marginInlineEnd: 5, visibility: editing ? 'hidden' : undefined }}>
                {airplane ? (
                    <Airplane size={23} />
                ) : noSim ? (
                    <span className="font-sf text-[13px] font-semibold leading-none opacity-80">{t('shell.noSim', 'No SIM')}</span>
                ) : noService ? (
                    <>
                        <span className="font-sf text-[13px] font-semibold leading-none opacity-80">{t('shell.noService', 'No Service')}</span>
                        <WifiGlyph bars={wifiBars} showWifi={false} />
                    </>
                ) : (
                    <>
                        {signal > 0 && <Cellular size={21} bars={signal} />}
                        <WifiGlyph bars={wifiBars} showWifi={showWifi} />
                    </>
                )}
                {focus && <Moon size={17} />}
                <Battery size={28} pct={battery} />

                {controlHint && (
                    <span
                        aria-hidden
                        className="pointer-events-none absolute left-1/2 top-full mt-[3px] block h-[4px] w-[34px] -translate-x-1/2 rounded-full transition-colors duration-300 ease-out"
                        style={{ backgroundColor: color, opacity: 0.5 }}
                    />
                )}
            </div>
        </div>
    );
}


const BAR_PATHS = [
    'M88 432H40a24 24 0 01-24-24v-96a24 24 0 0124-24h48a24 24 0 0124 24v96a24 24 0 01-24 24z',
    'M216 432h-48a24 24 0 01-24-24V248a24 24 0 0124-24h48a24 24 0 0124 24v160a24 24 0 01-24 24z',
    'M344 432h-48a24 24 0 01-24-24V184a24 24 0 0124-24h48a24 24 0 0124 24v224a24 24 0 01-24 24z',
    'M472 432h-48a24 24 0 01-24-24V104a24 24 0 0124-24h48a24 24 0 0124 24v304a24 24 0 01-24 24z',
];

function Cellular({ size, bars }: { size: number; bars: number }) {
    const opacities = signalBarOpacities(bars);
    return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
            {BAR_PATHS.map((d, i) => (
                <path key={d} d={d} opacity={opacities[i]} />
            ))}
        </svg>
    );
}

// f_phone (Duo): cincin status seperti iPhone lipat - busur tipis di atas, sinyal seluler sebagai
// 4 titik di bawah (kiri ke kanan), ikon Wi-Fi di tengahnya.
const RING_C = 23;
const RING_R = 20;
const RING_DOTS = [140, 107, 73, 40];
const ringPt = (deg: number) => {
    const a = (deg * Math.PI) / 180;
    return { x: RING_C + RING_R * Math.cos(a), y: RING_C + RING_R * Math.sin(a) };
};
const RING_ARC = (() => {
    const a = ringPt(190);
    const b = ringPt(350);
    return `M${a.x} ${a.y} A${RING_R} ${RING_R} 0 0 1 ${b.x} ${b.y}`;
})();

function SignalRing({ bars }: { bars: number }) {
    const opacities = signalBarOpacities(bars);
    return (
        <svg className="absolute inset-0" width={46} height={46} viewBox="0 0 46 46" fill="none" aria-hidden>
            <path d={RING_ARC} stroke="currentColor" strokeWidth={2} strokeLinecap="round" />
            {RING_DOTS.map((deg, i) => {
                const p = ringPt(deg);
                return <circle key={deg} cx={p.x} cy={p.y} r={2.4} fill="currentColor" opacity={opacities[i]} />;
            })}
        </svg>
    );
}

const WIFI_ARC_PATHS = [
    'M346.65 304.3a136 136 0 00-180.71 0 21 21 0 1027.91 31.38 94 94 0 01124.89 0 21 21 0 0027.91-31.4z',
    'M256.28 183.7a221.47 221.47 0 00-151.8 59.92 21 21 0 1028.68 30.67 180.28 180.28 0 01246.24 0 21 21 0 1028.68-30.67 221.47 221.47 0 00-151.8-59.92z',
    'M462 175.86a309 309 0 00-411.44 0 21 21 0 1028 31.29 267 267 0 01355.43 0 21 21 0 0028-31.31z',
];

const WIFI_DIM = 0.28;

function WifiGlyph({ bars, showWifi }: { bars?: number | null; showWifi?: boolean }) {
    if (bars !== null && bars !== undefined) return <Wifi size={21} bars={bars} />;
    if (showWifi) return <Wifi size={21} />;
    return null;
}

function Wifi({ size, bars }: { size: number; bars?: number | null }) {
    const lit = bars === null || bars === undefined
        ? WIFI_ARC_PATHS.length
        : Math.max(0, Math.min(WIFI_ARC_PATHS.length, Math.round(bars)));
    return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
            {WIFI_ARC_PATHS.map((d, i) => (
                <path key={d} d={d} opacity={i < lit ? 1 : WIFI_DIM} />
            ))}
            <circle cx="256.28" cy="393.41" r="32" />
        </svg>
    );
}

function Airplane({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
            <path d="M186.62 464H160a16 16 0 01-14.57-22.6l64.46-142.25L113.1 297l-35.3 42.77C71.07 348.23 65.7 352 52 352H34.08a17.66 17.66 0 01-14.7-7.06c-2.38-3.21-4.72-8.65-2.44-16.41l19.82-71c.15-.53.33-1.06.53-1.58a.38.38 0 000-.15 14.82 14.82 0 01-.53-1.59l-19.84-71.45c-2.15-7.61.2-12.93 2.56-16.06a16.83 16.83 0 0113.6-6.7H52c10.23 0 20.16 4.59 26 12l34.57 42.05 97.32-1.44-64.44-142A16 16 0 01160 48h26.91a25 25 0 0119.35 9.8l125.05 152 57.77-1.52c4.23-.23 15.95-.31 18.66-.31C463 208 496 225.94 496 256c0 9.46-3.78 27-29.07 38.16-14.93 6.6-34.85 9.94-59.21 9.94-2.68 0-14.37-.08-18.66-.31l-57.76-1.54-125.36 152a25 25 0 01-19.32 9.75z" />
        </svg>
    );
}

function Moon({ size }: { size: number }) {
    return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
            <path d="M264 480A232 232 0 0132.86 213.44 231.63 231.63 0 01166.28 33.7a16 16 0 0121.11 20.51A184.15 184.15 0 00376.4 297.34a16 16 0 0119.71 19.71A232.66 232.66 0 01264 480z" />
        </svg>
    );
}

function Battery({ size, pct }: { size: number; pct: number }) {
    const value = Math.max(0, Math.min(100, Math.round(pct)));
    const fillW = (292.63 * value) / 100;
    const fill  = value <= 20 ? '#ff453a' : 'currentColor';
    return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="none" aria-hidden>
            <rect x="32" y="144" width="400" height="224" rx="45.7" ry="45.7" stroke="currentColor" strokeLinecap="square" strokeMiterlimit="10" strokeWidth="32" />
            <path d="M480 218.67v74.66" stroke="currentColor" strokeLinecap="round" strokeMiterlimit="10" strokeWidth="32" />
            {value > 0 && <rect x="85.69" y="198.93" width={fillW} height="114.14" rx="8" ry="8" fill={fill} />}
        </svg>
    );
}
