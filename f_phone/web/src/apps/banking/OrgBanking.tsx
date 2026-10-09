import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Building2, ChevronRight, Lock } from 'lucide-react';

import { useDeckActive } from '@/shell/deckActive';
import { useAsyncData } from '@/hooks/useAsyncData';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { failText } from '@/core/api';
import { t } from '@/i18n';
import { useStreamerHidden } from '@/stores/themeStore';
import { HIDDEN_TEXT } from '@/shell/streamerMode';
import { StatusBarSpacer } from '@/ui/StatusBarSpacer';
import { formatMoney } from './data';
import { fetchOrgOverview, sendOrgMoney, type OrgOverviewResult } from './bankingApi';
import { AllTransactions } from './AllTransactions';
import { SendMoney } from './SendMoney';
import { TxRows } from './TxRow';

// The Bank app on a device with `orgBank` (the organisation tablet): the player's JOB account
// rather than their personal Wallet. Every member reads the balance and history; Send is shown
// only when the server says this grade is `isboss` - and the server re-checks it on every send.
export function OrgBanking({ onClose }: { onClose: () => void }) {
    const { data: res, loading, settled, refetch } = useAsyncData<OrgOverviewResult>(fetchOrgOverview, []);

    const hideBalance = useStreamerHidden('balance');
    const [showAll, setShowAll] = useState(false);
    const [sending, setSending] = useState(false);

    useNuiEvent('f_phone:bank:orgChanged', useCallback(() => { refetch(); }, [refetch]));

    // Same foreground re-sync as the Wallet: a backgrounded app misses pushes.
    const deckActive = useDeckActive();
    const wasActive  = useRef(deckActive);
    useEffect(() => {
        const rising = deckActive && !wasActive.current;
        wasActive.current = deckActive;
        if (!rising) return;
        const id = window.setTimeout(refetch, 420);
        return () => window.clearTimeout(id);
    }, [deckActive, refetch]);

    const org    = res?.success ? res.data : undefined;
    const txs    = useMemo(() => org?.transactions ?? [], [org]);
    const latest = useMemo(() => txs.slice(0, 10), [txs]);

    return (
        <div className="absolute inset-0 z-10 flex flex-col bg-base text-black dark:text-white">
            <StatusBarSpacer />
            <div className="px-5 pb-2 pt-0.5 text-[34px] font-bold tracking-tight">{t('banking.orgTitle', 'Rekening Organisasi')}</div>

            <div className="flex-1 overflow-y-auto overscroll-contain no-scrollbar px-4 pb-10 pt-3" style={{ contain: 'paint' }}>
                {!org ? (
                    settled && !loading && (
                        <div className="rounded-[14px] bg-surface px-4 py-9 text-center text-[18px] font-medium text-ios-gray">
                            {res ? failText(res, t('banking.orgUnavailable', 'Rekening organisasi tidak tersedia')) : t('banking.orgUnavailable', 'Rekening organisasi tidak tersedia')}
                        </div>
                    )
                ) : (
                    <>
                        <div className="flex items-center gap-3 rounded-[16px] bg-surface px-5 py-4">
                            <Building2 className="h-[30px] w-[30px] shrink-0 text-ios-blue" strokeWidth={2} />
                            <div className="min-w-0">
                                <div dir="auto" className="truncate text-[20px] font-bold">{org.label}</div>
                                <div className="text-[15px] text-ios-gray">{org.job}</div>
                            </div>
                        </div>

                        <div className="mt-3 flex items-center justify-between rounded-[16px] bg-surface px-5 py-3">
                            <div>
                                <div className="text-[17px] font-semibold">{t('banking.balance', 'Balance')}</div>
                                <div className="mt-0.5 text-[26px] font-bold tabular-nums tracking-tight">
                                    <span dir="ltr">{hideBalance ? HIDDEN_TEXT : formatMoney(org.balance, { whole: true })}</span>
                                </div>
                            </div>
                            {org.canTransfer ? (
                                <button
                                    type="button"
                                    onClick={() => setSending(true)}
                                    className="rounded-full bg-black px-6 py-2.5 text-[16px] font-semibold text-white active:opacity-70 dark:bg-white dark:text-black"
                                >
                                    {t('banking.send', 'Send')}
                                </button>
                            ) : (
                                <div className="flex items-center gap-1.5 rounded-full bg-black/[0.06] px-4 py-2 text-[14.5px] font-semibold text-black/60 dark:bg-white/10 dark:text-white/65">
                                    <Lock className="h-[15px] w-[15px]" strokeWidth={2.4} />
                                    {t('banking.orgViewOnly', 'Hanya lihat')}
                                </div>
                            )}
                        </div>

                        <div className="mb-3 mt-6 flex items-center justify-between">
                            <h2 className="text-[20px] font-bold tracking-tight">{t('banking.latestTransactions', 'Latest Transactions')}</h2>
                            {txs.length > 0 && (
                                <button type="button" onClick={() => setShowAll(true)} className="flex items-center gap-0.5 text-[17px] font-medium text-ios-blue active:opacity-60">
                                    {t('banking.allTransactions', 'All Transactions')}
                                    <ChevronRight className="h-[18px] w-[18px]" strokeWidth={2.5} />
                                </button>
                            )}
                        </div>

                        {latest.length === 0 ? (
                            <div className="rounded-[14px] bg-surface px-4 py-9 text-center text-[18px] font-medium text-ios-gray">
                                {t('banking.noTransactionsYet', 'No transactions yet.')}
                            </div>
                        ) : (
                            <TxRows items={latest} />
                        )}
                    </>
                )}
            </div>

            <button type="button" onClick={onClose} aria-label={t('banking.closeWallet', 'Close Wallet')} className="absolute inset-x-0 bottom-0 h-7 cursor-default" />

            {showAll && <AllTransactions transactions={txs} onBack={() => setShowAll(false)} />}

            {sending && org?.canTransfer && (
                <SendMoney
                    balance={org.balance}
                    allowAnonymous={false}
                    sendFn={sendOrgMoney}
                    backLabel={org.label}
                    onClose={() => setSending(false)}
                    onSent={() => { setSending(false); refetch(); }}
                />
            )}
        </div>
    );
}
