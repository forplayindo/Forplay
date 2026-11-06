import { useSyncExternalStore } from "react";

/**
 * HUD radio (di atas baris hygiene): siapa yang sedang bicara di channel radio.
 * Data dari modules/radio (Lua): ui:radioHud { channel, count } dan ui:radioTalk { id, name, talking }.
 * State disimpan di luar komponen supaya tidak hilang saat HUD pindah posisi (minimap tampil / sembunyi).
 */
type Speaker = { id: string; name: string };
type RadioState = { channel: number; count: number; speakers: Speaker[] };

const MAX_SPEAKERS = 3;
const LINGER_MS = 1000; // nama tetap tampil 1 detik setelah selesai bicara

let state: RadioState = { channel: 0, count: 0, speakers: [] };
const listeners = new Set<() => void>();
const timers = new Map<string, number>();

const emit = (next: RadioState) => {
  state = next;
  listeners.forEach((l) => l());
};

window.addEventListener("message", (e: MessageEvent) => {
  const { action, data } = (e.data || {}) as { action?: string; data?: any };
  if (action === "ui:radioHud") {
    const channel = Number(data?.channel) || 0;
    if (!channel) timers.forEach((t) => clearTimeout(t)), timers.clear();
    emit({ channel, count: Number(data?.count) || 0, speakers: channel ? state.speakers : [] });
  } else if (action === "ui:radioTalk") {
    const id = String(data?.id);
    const old = timers.get(id);
    if (old) clearTimeout(old), timers.delete(id);
    if (data?.talking) {
      const others = state.speakers.filter((s) => s.id !== id);
      emit({ ...state, speakers: [...others, { id, name: String(data?.name || id) }].slice(-MAX_SPEAKERS) });
    } else {
      timers.set(
        id,
        window.setTimeout(() => {
          timers.delete(id);
          emit({ ...state, speakers: state.speakers.filter((s) => s.id !== id) });
        }, LINGER_MS)
      );
    }
  }
});

const subscribe = (l: () => void) => {
  listeners.add(l);
  return () => listeners.delete(l);
};

const formatFreq = (ch: number) => `${Math.round(ch * 100) / 100}`;

const SignalIcon = ({ size }: { size: number }) => (
  <svg className="g6r-sig" width={size} height={size} viewBox="0 0 24 24">
    <circle className="dot" cx="12" cy="12" r="2.2" />
    <path d="M8.2 8.2a5.4 5.4 0 0 0 0 7.6M15.8 8.2a5.4 5.4 0 0 1 0 7.6" />
    <path d="M5 5a10 10 0 0 0 0 14M19 5a10 10 0 0 1 0 14" />
  </svg>
);

export const RadioHud = () => {
  const { channel, count, speakers } = useSyncExternalStore(subscribe, () => state);
  if (!channel) return null;
  const freq = formatFreq(channel);

  if (speakers.length === 0) {
    return (
      <div className="g6r">
        <div className="g6r-row idle">
          <SignalIcon size={20} />
          <div className="g6r-txt">
            <div className="g6r-k">Radio terhubung</div>
            <div className="g6r-n">
              {freq} MHz{count > 0 && <span className="g6r-cnt"> · {count} anggota</span>}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="g6r">
      {speakers.map((s) => (
        <div key={s.id} className="g6r-row">
          <SignalIcon size={22} />
          <div className="g6r-txt">
            <div className="g6r-k">Radio {freq} MHz</div>
            <div className="g6r-n">{s.name}</div>
          </div>
          <div className="g6r-wave">
            <i />
            <i />
            <i />
            <i />
            <i />
          </div>
        </div>
      ))}
    </div>
  );
};
