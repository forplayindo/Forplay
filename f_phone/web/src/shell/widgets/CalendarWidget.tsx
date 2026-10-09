import { useEffect, useState } from 'react';

import { calendarList } from '@/apps/calendar/calendarApi';
import type { CalEvent } from '@/apps/calendar/data';
import { getLocaleTag, t } from '@/i18n';
import { WidgetTile } from './WidgetTile';

// f_phone (Duo): widget kalender tetap di Layar Utama saat HP dibentangkan, seperti iPhone lipat.
// Hari (merah, kapital), tanggal besar, lalu acara terdekat hari ini dari aplikasi Kalender.

function todayKey(d: Date): string {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Acara hari ini yang belum selesai, yang paling awal; seharian didahulukan. */
function nextToday(events: CalEvent[], now: Date): CalEvent | null {
    const key = todayKey(now);
    const hhmm = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    const today = events
        .filter(e => e.dayKey === key && e.myStatus !== 'declined')
        .filter(e => e.allDay || !e.end || e.end > hhmm)
        .sort((a, b) => (a.allDay === b.allDay ? (a.start ?? '').localeCompare(b.start ?? '') : a.allDay ? -1 : 1));
    return today[0] ?? null;
}

export function CalendarWidget({ width, height }: { width: number; height: number }) {
    const [now, setNow] = useState(() => new Date());
    const [events, setEvents] = useState<CalEvent[]>([]);

    useEffect(() => {
        let alive = true;
        void calendarList().then(list => { if (alive && list) setEvents(list); });
        // Ganti hari / acara selesai tanpa perlu membuka ulang HP.
        const id = window.setInterval(() => setNow(new Date()), 60_000);
        return () => { alive = false; window.clearInterval(id); };
    }, []);

    const day = now.toLocaleDateString(getLocaleTag(), { weekday: 'long' }).toUpperCase();
    const ev = nextToday(events, now);

    return (
        <WidgetTile width={width} height={height} radius={22} tint="#1c1c1e">
            <div className="flex h-full w-full flex-col p-3.5 text-white">
                <div className="truncate text-[13px] font-bold leading-tight tracking-[0.02em]" style={{ color: '#ff453a' }}>{day}</div>
                <div className="mt-0.5 text-[40px] font-normal leading-none tabular-nums">{now.getDate()}</div>
                {ev ? (
                    <div className="mt-4 min-w-0">
                        <div className="truncate text-[13px] font-semibold leading-tight">{ev.title}</div>
                        <div className="truncate text-[12px] leading-tight opacity-70">
                            {ev.allDay ? t('calendar.allDay', 'All-day') : `${ev.start ?? ''}${ev.end ? ` – ${ev.end}` : ''}`}
                        </div>
                    </div>
                ) : (
                    <div className="mt-4 text-[13px] leading-tight opacity-80">
                        {t('widgets.noEventsToday', 'No Events Today')}
                    </div>
                )}
            </div>
        </WidgetTile>
    );
}
