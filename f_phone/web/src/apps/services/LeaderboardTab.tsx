import { Fragment, useCallback, useState } from 'react';
import { RotateCcw, Trophy } from 'lucide-react';

import { AlertDialog } from '@/ui/AlertDialog';
import { EmptyState } from '@/ui/EmptyState';
import { useAsyncData } from '@/hooks/useAsyncData';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { failText } from '@/core/api';
import { t } from '@/i18n';
import { fetchLeaderboard, resetLeaderboard, type LeaderboardResult, type LeaderRow } from './servicesApi';

const MEDALS = ['#F5C542', '#C0C4CC', '#CD8B4E'];

function fmtDuration(seconds: number): string {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    return h > 0 ? `${h}j ${m}m` : `${m}m`;
}

// On-duty time per member of the player's active job, most at the top. Everyone in the job reads
// it; only a boss sees Reset, and the server re-checks that on the call.
export function LeaderboardTab() {
    const { data: fetched, settled, refetch } = useAsyncData<LeaderboardResult>(fetchLeaderboard, []);
    const [override, setOverride]   = useState<LeaderboardResult | null>(null);
    const [confirming, setConfirming] = useState(false);
    const [busy, setBusy]           = useState(false);
    const [error, setError]         = useState<string | null>(null);

    const res   = override ?? fetched;
    const board = res?.success ? res.data : undefined;

    useNuiEvent('f_phone:services:leaderboard', useCallback(() => { setOverride(null); refetch(); }, [refetch]));

    async function doReset() {
        setConfirming(false);
        if (busy) return;
        setBusy(true);
        const r = await resetLeaderboard();
        setBusy(false);
        if (r.success) setOverride(r);
        else setError(failText(r, t('services.somethingWentWrong', 'Something went wrong')));
    }

    return (
        <div className="flex min-h-0 flex-1 flex-col">
            <div className="flex items-end justify-between px-5 pb-2 pt-1">
                <h1 className="text-[34px] font-bold tracking-tight text-black dark:text-white">{t('services.leaderboard', 'Leaderboard')}</h1>
                {board?.isBoss && (
                    <button
                        type="button"
                        disabled={busy}
                        onClick={() => setConfirming(true)}
                        className="mb-1.5 flex items-center gap-1.5 rounded-full bg-ios-red/10 px-4 py-1.5 text-[15px] font-semibold text-ios-red active:opacity-60 disabled:opacity-40"
                    >
                        <RotateCcw className="h-[15px] w-[15px]" strokeWidth={2.5} />
                        {t('services.leaderboardReset', 'Reset')}
                    </button>
                )}
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto no-scrollbar px-4 pb-6">
                {!board ? (
                    settled && (
                        <EmptyState
                            icon={Trophy}
                            title={t('services.noCompany', 'No Company')}
                            subtitle={res ? failText(res, t('services.notPartOfCompany', "You're not part of a company.")) : t('services.notPartOfCompany', "You're not part of a company.")}
                        />
                    )
                ) : (
                    <>
                        <div className="mb-2 mt-1 px-1 text-[13px] font-medium uppercase tracking-wide text-ios-gray">
                            {board.label} · {t('services.leaderboardHint', '1 poin = 1 menit on duty')}
                        </div>
                        {board.rows.length === 0 ? (
                            <EmptyState icon={Trophy} title={t('services.leaderboardEmpty', 'Belum ada data')} subtitle={t('services.leaderboardEmptySub', 'Waktu duty akan muncul di sini.')} />
                        ) : (
                            <div className="overflow-hidden rounded-[12px] bg-surface">
                                {board.rows.map((row, i) => (
                                    <Fragment key={`${row.rank}-${row.name}`}>
                                        <LeaderRowView row={row} />
                                        {i < board.rows.length - 1 && <div className="ms-[64px] h-px bg-hairline/10" />}
                                    </Fragment>
                                ))}
                            </div>
                        )}
                    </>
                )}
            </div>

            {confirming && (
                <AlertDialog
                    title={t('services.leaderboardResetTitle', 'Reset Leaderboard?')}
                    message={t('services.leaderboardResetMsg', 'Semua waktu duty dan poin di job ini kembali ke 0. Tidak bisa dibatalkan.')}
                    confirmLabel={t('services.leaderboardReset', 'Reset')}
                    cancelLabel={t('common.cancel', 'Cancel')}
                    destructive
                    onCancel={() => setConfirming(false)}
                    onConfirm={() => void doReset()}
                />
            )}

            {error && (
                <AlertDialog
                    title={t('services.somethingWentWrong', 'Something went wrong')}
                    message={error}
                    confirmLabel={t('common.ok', 'OK')}
                    onCancel={() => setError(null)}
                    onConfirm={() => setError(null)}
                />
            )}
        </div>
    );
}

function LeaderRowView({ row }: { row: LeaderRow }) {
    const medal = MEDALS[row.rank - 1];
    return (
        <div className={`flex items-center gap-3 px-4 py-3 ${row.me ? 'bg-ios-blue/[0.07]' : ''}`}>
            <div
                className="flex h-[36px] w-[36px] shrink-0 items-center justify-center rounded-full text-[16px] font-bold"
                style={medal ? { background: medal, color: '#fff' } : undefined}
            >
                <span className={medal ? '' : 'text-ios-gray'}>{row.rank}</span>
            </div>
            <div className="min-w-0 flex-1">
                <div dir="auto" className="truncate text-[17px] font-semibold text-black dark:text-white">{row.name}</div>
                <div className="mt-0.5 flex items-center gap-1.5 text-[14px] text-ios-gray">
                    {row.onDuty && <span className="h-[7px] w-[7px] rounded-full bg-[#34C759]" />}
                    <span>{fmtDuration(row.seconds)}</span>
                </div>
            </div>
            <div className="shrink-0 text-end">
                <div className="text-[18px] font-bold tabular-nums text-black dark:text-white">{row.points.toLocaleString('id-ID')}</div>
                <div className="text-[12px] font-medium uppercase tracking-wide text-ios-gray">{t('services.points', 'Poin')}</div>
            </div>
        </div>
    );
}
