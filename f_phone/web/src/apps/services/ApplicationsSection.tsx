import { Fragment, useCallback, useState } from 'react';
import { Check, X } from 'lucide-react';

import { AlertDialog } from '@/ui/AlertDialog';
import { useAsyncData } from '@/hooks/useAsyncData';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { failText } from '@/core/api';
import { t } from '@/i18n';
import {
    acceptApplication, fetchApplications, rejectApplication,
    type ApplicationsResult, type JobApplication,
} from './servicesApi';

function fmtDate(ts: number): string {
    return new Date(ts).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
}

// Boss-only "Lamaran Masuk" block in the Actions tab. Fetched only when this section mounts (the
// boss opened Actions) and refetched on the server's new-application nudge.
export function ApplicationsSection() {
    const { data: fetched, refetch } = useAsyncData<ApplicationsResult>(fetchApplications, []);
    const [override, setOverride] = useState<JobApplication[] | null>(null);
    const [confirm, setConfirm]   = useState<{ app: JobApplication; accept: boolean } | null>(null);
    const [busy, setBusy]         = useState(false);
    const [error, setError]       = useState<string | null>(null);

    useNuiEvent('f_phone:services:applications', useCallback(() => { setOverride(null); refetch(); }, [refetch]));

    const list = override ?? (fetched?.success ? fetched.data?.applications ?? [] : []);

    async function decide(app: JobApplication, accept: boolean) {
        setConfirm(null);
        if (busy) return;
        setBusy(true);
        const res = await (accept ? acceptApplication(app.id) : rejectApplication(app.id));
        setBusy(false);
        if (res.success) setOverride(res.data?.applications ?? []);
        else setError(failText(res, t('services.somethingWentWrong', 'Something went wrong')));
    }

    return (
        <>
            <div className="px-1 pb-2 pt-7 text-[19px] font-bold tracking-tight text-black dark:text-white">
                {t('services.applicationsTitle', 'Lamaran Masuk')}
                {list.length > 0 && <span className="ms-2 text-[15px] font-semibold text-ios-gray">{list.length}</span>}
            </div>
            <div className="overflow-hidden rounded-[12px] bg-surface">
                {list.length === 0 ? (
                    <div className="px-4 py-5 text-center text-[16px] font-medium text-ios-gray">
                        {t('services.applicationsEmpty', 'Belum ada lamaran.')}
                    </div>
                ) : list.map((app, i) => (
                    <Fragment key={app.id}>
                        {i > 0 && <div className="pointer-events-none bg-hairline/10" style={{ height: '0.5px' }} />}
                        <div className="flex items-start gap-3 px-4 py-3.5">
                            <div className="min-w-0 flex-1">
                                <div className="flex items-baseline gap-2">
                                    <span dir="auto" className="truncate text-[18px] font-medium text-black dark:text-white">{app.name}</span>
                                    <span className="shrink-0 text-[14px] text-ios-gray">{fmtDate(app.ts)}</span>
                                </div>
                                <div dir="auto" className="mt-1 whitespace-pre-wrap break-words text-[16px] text-black/75 dark:text-white/75">{app.message}</div>
                            </div>
                            <div className="flex shrink-0 items-center gap-1.5 pt-0.5">
                                <button
                                    type="button"
                                    disabled={busy}
                                    aria-label={t('services.applicationReject', 'Tolak')}
                                    onClick={() => setConfirm({ app, accept: false })}
                                    className="flex h-[34px] w-[34px] items-center justify-center rounded-full bg-ios-red/10 text-ios-red active:opacity-60 disabled:opacity-40"
                                >
                                    <X className="h-[19px] w-[19px]" strokeWidth={2.6} />
                                </button>
                                <button
                                    type="button"
                                    disabled={busy}
                                    aria-label={t('services.applicationAccept', 'Terima')}
                                    onClick={() => setConfirm({ app, accept: true })}
                                    className="flex h-[34px] w-[34px] items-center justify-center rounded-full bg-[#34C759]/15 text-[#34C759] active:opacity-60 disabled:opacity-40"
                                >
                                    <Check className="h-[19px] w-[19px]" strokeWidth={2.6} />
                                </button>
                            </div>
                        </div>
                    </Fragment>
                ))}
            </div>

            {confirm && (
                <AlertDialog
                    title={confirm.accept
                        ? t('services.applicationAcceptTitle', 'Terima {name}?', { name: confirm.app.name })
                        : t('services.applicationRejectTitle', 'Tolak {name}?', { name: confirm.app.name })}
                    message={confirm.accept
                        ? t('services.applicationAcceptMsg', 'Tawaran kerja (grade terendah) dikirim. Dia bisa menerimanya di Services → Jobs, walau sedang offline. Hasil dikirim lewat Mail.')
                        : t('services.applicationRejectMsg', 'Lamaran dihapus dan pelamar diberi tahu lewat Mail.')}
                    confirmLabel={confirm.accept ? t('services.applicationAccept', 'Terima') : t('services.applicationReject', 'Tolak')}
                    destructive={!confirm.accept}
                    onCancel={() => setConfirm(null)}
                    onConfirm={() => void decide(confirm.app, confirm.accept)}
                />
            )}

            {error && (
                <AlertDialog
                    title={t('services.couldntComplete', "Couldn't complete that")}
                    message={error}
                    confirmLabel={t('services.ok', 'OK')}
                    hideCancel
                    onCancel={() => setError(null)}
                    onConfirm={() => setError(null)}
                />
            )}
        </>
    );
}
