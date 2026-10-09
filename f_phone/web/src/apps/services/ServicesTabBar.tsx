import { Briefcase, Building2, MessageSquare, MonitorSmartphone, Trophy } from 'lucide-react';

import { TabBar, type TabBarItem } from '@/ui/TabBar';
import { t } from '@/i18n';

export type ServicesTab = 'companies' | 'jobs' | 'messages' | 'actions' | 'leaderboard';

export function ServicesTabBar({ tab, onChange, showJobs, showLeaderboard = false, messagesBadge = 0, jobsBadge = 0, actionsBadge = 0 }: {
    tab: ServicesTab;
    onChange: (t: ServicesTab) => void;
    showJobs: boolean;
    showLeaderboard?: boolean;
    messagesBadge?: number;
    jobsBadge?: number;
    /** Pending job applications (boss only). */
    actionsBadge?: number;
}) {
    const companies: TabBarItem<ServicesTab> = { id: 'companies', label: t('services.companies', 'Companies'), icon: a => <Building2         className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} /> };
    const jobs:      TabBarItem<ServicesTab> = { id: 'jobs',      label: t('services.jobs', 'Jobs'),      icon: a => <Briefcase         className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} />, badge: jobsBadge };
    const messages:  TabBarItem<ServicesTab> = { id: 'messages',  label: t('services.messages', 'Messages'),  icon: a => <MessageSquare     className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} />, badge: messagesBadge };
    const actions:   TabBarItem<ServicesTab> = { id: 'actions',   label: t('services.actions', 'Actions'),   icon: a => <MonitorSmartphone className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} />, badge: actionsBadge };
    const leaders:   TabBarItem<ServicesTab> = { id: 'leaderboard', label: t('services.leaderboard', 'Leaderboard'), icon: a => <Trophy className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} /> };
    const tabs = showJobs ? [companies, jobs, messages, actions] : [companies, messages, actions];
    if (showLeaderboard) tabs.push(leaders);
    return <TabBar tabs={tabs} active={tab} onChange={onChange} />;
}
