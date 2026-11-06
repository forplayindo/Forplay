import { useState } from 'react';
import { Map as MapIcon } from 'lucide-react';

import { t } from '@/i18n';
import { InitialsAvatar } from '@/shared/ContactAvatar';
import { Sheet } from '@/ui/Sheet';
import { useRyde } from '../store';
import { money } from '../data';
import type { Ride } from '../data';
import { useRydeDriverCut } from '../rydeApi';
import { RouteMap } from './RouteMap';

// Fixed-fare request card: the fare is set by the server from the distance, the driver only
// takes it. First driver to take a request wins it.
export function OfferSheet({ request, onClose }: { request: Ride; onClose: () => void }) {
    const g = useRyde();
    const r = request;
    const [showRoute, setShowRoute] = useState(false);
    const cut = useRydeDriverCut();

    const net = Math.round(r.fare * cut);
    const taxPct = Math.round((1 - cut) * 100);

    return (
        <Sheet title={t('ryde.takeThisRide', 'Take this ride?')} onClose={onClose} fit="content" className="bg-surface px-5 pt-3">
            {() => (
                <>
                    <div className="mb-4 flex items-center gap-3.5">
                        <InitialsAvatar name={r.riderName ?? t('ryde.rider', 'Rider')} size={52} />
                        <div className="min-w-0 flex-1">
                            <p className="truncate text-[18px] font-bold text-black dark:text-white">{r.riderName}</p>
                            <p className="text-[15px] text-ios-gray">{t('ryde.kmAboutMin', '{km} km · about {min} min', { km: r.distanceKm.toFixed(1), min: r.durationMin })}</p>
                        </div>
                    </div>

                    <div className="mb-3 space-y-2.5 rounded-2xl bg-black/[0.05] p-4 dark:bg-white/[0.07]">
                        <div className="flex items-center gap-3"><span className="h-3 w-3 shrink-0 rounded-full bg-[#22c55e]" /><span className="truncate text-[16px] font-medium text-black dark:text-white">{r.pickup.name}</span></div>
                        <div className="flex items-center gap-3"><span className="h-3 w-3 shrink-0 rounded-full bg-black dark:bg-white" /><span className="truncate text-[16px] font-medium text-black dark:text-white">{r.dropoff.name}</span></div>
                    </div>

                    <button
                        onClick={() => setShowRoute(true)}
                        className="mb-5 flex w-full items-center justify-center gap-2.5 rounded-[14px] bg-black/[0.05] py-4 text-[16px] font-semibold text-ios-blue active:opacity-70 dark:bg-white/10"
                    >
                        <MapIcon className="h-[21px] w-[21px]" strokeWidth={2.3} /> {t('ryde.viewRouteOnMap', 'View route on map')}
                    </button>

                    <div className="mb-2 flex items-center justify-between rounded-2xl bg-black/[0.05] px-4 py-3.5 dark:bg-white/[0.08]">
                        <p className="text-[15px] font-semibold text-ios-gray">{t('ryde.fixedFare', 'Fare')}</p>
                        <p className="text-[26px] font-extrabold tracking-tight text-black dark:text-white">{money(r.fare)}</p>
                    </div>

                    <p className="mb-5 text-center text-[14px] text-ios-gray">
                        {taxPct > 0
                            ? <>{t('ryde.afterTaxYouGet', 'After {pct}% tax, you get ', { pct: taxPct })}<span className="font-bold text-[#22c55e]">{money(net)}</span></>
                            : <>{t('ryde.youGetFull', 'You get the full ')}<span className="font-bold text-[#22c55e]">{money(net)}</span></>}
                    </p>

                    <div className="flex gap-3">
                        <button onClick={onClose} className="flex-1 rounded-[14px] bg-black/[0.06] py-4 text-[17px] font-bold text-black dark:bg-white/10 dark:text-white">{t('ryde.cancel', 'Cancel')}</button>
                        <button
                            onClick={() => { g.takeRequest(r.id); onClose(); }}
                            className="flex-[2] rounded-[14px] bg-black py-4 text-[17px] font-bold text-white dark:bg-white dark:text-black"
                        >
                            {t('ryde.takeRide', 'Take ride')}
                        </button>
                    </div>

                    {showRoute && <RouteMap request={r} onClose={() => setShowRoute(false)} />}
                </>
            )}
        </Sheet>
    );
}
