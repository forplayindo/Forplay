import type { ComponentType, ReactNode } from 'react';

/**
 * Two-column layout for the unfolded phone: the app's navigation (lists) on the left, the open
 * item on the right. Both panes are positioned containers, so pages written as `absolute inset-0`
 * overlays fill their own pane instead of the whole screen.
 */
export function SplitLayout({ list, detail, emptyIcon: Icon, emptyTitle, emptyHint, listWidth = 470 }: {
    list:       ReactNode;
    detail:     ReactNode;
    emptyIcon:  ComponentType<{ className?: string; strokeWidth?: number }>;
    emptyTitle: string;
    emptyHint?: string;
    listWidth?: number;
}) {
    return (
        <div className="absolute inset-0 flex">
            <div
                className="relative flex h-full shrink-0 flex-col overflow-hidden border-e border-black/10 dark:border-white/10"
                style={{ width: listWidth }}
            >
                {list}
            </div>
            <div className="relative h-full min-w-0 flex-1 overflow-hidden">
                {detail || (
                    <div className="flex h-full flex-col items-center justify-center gap-2 px-10 text-center text-black/40 dark:text-white/40">
                        <Icon className="mb-2 h-[64px] w-[64px]" strokeWidth={1.4} />
                        <div className="text-[20px] font-semibold">{emptyTitle}</div>
                        {emptyHint && <div className="text-[15px]">{emptyHint}</div>}
                    </div>
                )}
            </div>
        </div>
    );
}
