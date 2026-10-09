// EMS bills (foreplay): unpaid service bills from f_ambulancejob's Check Patient panel. "Tagih"
// pulls the total straight from the patient's bank (refused when short). Text is Indonesian by
// request of the server owner.
import { useEffect, useMemo, useState } from 'react';
import { Receipt, Search } from 'lucide-react';

import { t } from '@/i18n';
import { colorFor } from '@/lib/format';
import { InitialsAvatar } from '@/shared/ContactAvatar';
import { EmptyState } from '@/ui/EmptyState';
import { ListColumn } from '@/ui/ListColumn';
import { MasterDetail } from '@/ui/MasterDetail';
import { Pill } from '@/ui/Pill';
import { Scroller } from '@/ui/Scroller';
import { useAsyncData } from '@/hooks/useAsyncData';
import { useSessionState } from '@/hooks/useSessionState';

import { mdtBillCollect, mdtBills, type EmsBill } from './mdtApi';
import { useMdtSession, useViewEnter } from './useMdtSession';
import { mdtPanePad, mdtRef, mdtRowHover, mdtRowMeta, mdtRowTitle, mdtSectionHeader } from './mdtTheme';
import { MdtButton } from './ui/MdtButton';
import { MdtCard } from './ui/MdtCard';

const money = (n: number) => 'Rp ' + Math.floor(n).toLocaleString('id-ID');

function when(ts: number): string {
    const d = new Date(ts * 1000);
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function BillRow({ bill, selected, onPress }: { bill: EmsBill; selected: boolean; onPress: () => void }) {
    return (
        <button
            type="button"
            onClick={onPress}
            className={`flex w-full items-center gap-3 rounded-[10px] px-3 py-2.5 text-start ${selected ? 'bg-ios-blue/10' : mdtRowHover}`}
        >
            <InitialsAvatar name={bill.name} color={colorFor(bill.citizenid)} size={38} />
            <span className="min-w-0 flex-1">
                <span className={`block truncate ${mdtRowTitle}`}>{bill.name}</span>
                <span className={`block truncate ${mdtRowMeta}`}>#{bill.id}  ·  {when(bill.createdAt)}</span>
            </span>
            <Pill tone="red">{money(bill.total)}</Pill>
        </button>
    );
}

function BillSheet({ bill, onDone }: { bill: EmsBill; onDone: () => void }) {
    const enter = useViewEnter(String(bill.id));
    const [confirm, setConfirm] = useState(false);
    const [busy, setBusy] = useState(false);
    const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

    const collect = async () => {
        setBusy(true);
        const err = await mdtBillCollect(bill.id);
        setBusy(false);
        setConfirm(false);
        if (err) {
            setMsg({ ok: false, text: err });
            return;
        }
        setMsg({ ok: true, text: `${money(bill.total)} berhasil ditarik dari bank ${bill.name} dan masuk ke rekening organisasi. Email pemberitahuan sudah dikirim.` });
        window.setTimeout(onDone, 1800);
    };

    return (
        <Scroller key={bill.id} className={`h-full ${mdtPanePad} ${enter}`}>
            <div className="flex flex-wrap items-center gap-3">
                <span dir="ltr" className={mdtRef}>#{bill.id}</span>
                <Pill tone="red">{t('mdt.billUnpaid', 'Belum bayar')}</Pill>
            </div>
            <h1 className="mt-2 text-[26px] font-bold tracking-ios-display text-black dark:text-white">{bill.name}</h1>
            <div className={`mt-1 ${mdtRowMeta}`}>
                {bill.citizenid}  ·  dibuat {when(bill.createdAt)}  ·  oleh {bill.by}
            </div>

            <div className={`mt-6 ${mdtSectionHeader}`}>{t('mdt.billItems', 'Rincian layanan')}</div>
            <MdtCard className="mt-2 divide-y divide-black/5 px-5 dark:divide-white/10">
                {bill.items.map((item, i) => (
                    <div key={i} className="flex items-center justify-between gap-3 py-3 text-[15px] text-black dark:text-white">
                        <span className="min-w-0 truncate">{item.label}</span>
                        <span className="shrink-0 tabular-nums">
                            {item.normal !== undefined && item.normal > item.price && (
                                <span className={`me-2 line-through ${mdtRowMeta}`}>{money(item.normal)}</span>
                            )}
                            {money(item.price)}
                        </span>
                    </div>
                ))}
                <div className="flex items-center justify-between py-3 text-[17px] font-bold text-black dark:text-white">
                    <span>Total</span>
                    <span className="tabular-nums">{money(bill.total)}</span>
                </div>
            </MdtCard>

            <div className={`mt-6 ${mdtSectionHeader}`}>{t('mdt.billCollect', 'Tagih')}</div>
            <MdtCard className="mt-2 flex flex-col gap-3 p-5">
                <p className={`text-[14px] leading-relaxed ${mdtRowMeta}`}>
                    Pasien belum membayar invoice di HP. Tombol ini menarik {money(bill.total)} langsung dari
                    rekening <b>bank</b> pasien (bisa saat pasien offline). Kalau saldo bank tidak cukup,
                    tagihan ditolak. Pasien menerima email pemberitahuan penarikan.
                </p>
                {msg && (
                    <div className={`rounded-[10px] px-3 py-2 text-[14px] font-semibold ${msg.ok ? 'bg-ios-green/15 text-ios-green' : 'bg-ios-red/10 text-ios-red'}`}>
                        {msg.text}
                    </div>
                )}
                {!msg?.ok && (confirm ? (
                    <div className="flex flex-wrap gap-2">
                        <MdtButton accent="rgb(var(--ios-red))" disabled={busy} onClick={collect}>
                            {busy ? 'Memproses...' : `Ya, tarik ${money(bill.total)}`}
                        </MdtButton>
                        <MdtButton variant="text" disabled={busy} onClick={() => setConfirm(false)}>Batal</MdtButton>
                    </div>
                ) : (
                    <MdtButton icon={<Receipt size={16} />} onClick={() => { setMsg(null); setConfirm(true); }}>
                        Tagih dari Bank
                    </MdtButton>
                ))}
            </MdtCard>
        </Scroller>
    );
}

export function BillsPane() {
    const { selected, select } = useMdtSession();
    const [query, setQuery] = useSessionState('mdt:bills:query', '');
    const [term, setTerm] = useState(query.trim());

    useEffect(() => {
        const id = window.setTimeout(() => setTerm(query.trim()), 250);
        return () => window.clearTimeout(id);
    }, [query]);

    const { data, loading, settled, refetch } = useAsyncData(() => mdtBills(term), [term]);
    const rows = data?.rows ?? [];
    const current = useMemo(() => rows.find(b => String(b.id) === selected) ?? null, [rows, selected]);

    const empty = (
        <EmptyState
            center
            icon={Search}
            title={loading ? t('mdt.loading', 'Loading') : term ? 'Tidak ada yang cocok' : 'Semua tagihan sudah lunas'}
            subtitle={loading ? undefined : term ? 'Tidak ada tagihan belum bayar atas nama / ID itu.' : undefined}
        />
    );

    const master = (
        <ListColumn
            className="flex-1"
            title={t('mdt.bills', 'Tagihan')}
            count={rows.length}
            query={query}
            onQuery={setQuery}
            placeholder="Nama atau citizen ID"
            isEmpty={settled && rows.length === 0}
            empty={empty}
            footer={rows.length > 0 ? (
                <div className={`px-4 py-2 text-[13px] ${mdtRowMeta}`}>
                    Total belum dibayar: <b className="tabular-nums">{money(data?.sum ?? 0)}</b>
                </div>
            ) : undefined}
        >
            <div className="mdt-stagger flex flex-col gap-0.5">
                {rows.map(bill => (
                    <BillRow
                        key={bill.id}
                        bill={bill}
                        selected={String(bill.id) === selected}
                        onPress={() => select(String(bill.id))}
                    />
                ))}
            </div>
        </ListColumn>
    );

    return (
        <MasterDetail
            master={master}
            hasDetail={current !== null}
            detail={current ? <BillSheet key={current.id} bill={current} onDone={() => { select(null); refetch(); }} /> : undefined}
            placeholder={
                <EmptyState
                    center
                    icon={Receipt}
                    title="Pilih tagihan"
                    subtitle="Tagihan layanan EMS yang belum dibayar pasien lewat HP. Pilih untuk melihat rincian dan menarik dari bank pasien."
                />
            }
            onCloseDetail={() => select(null)}
        />
    );
}
