
import type { GameClock } from '@/stores/gameClockStore';
import type { BirdyMessage, BirdyPollCounts } from '@/apps/birdy/data';
import type { CrashBust, CrashSettled, CrashSnapshot, CrashTick } from '@/apps/casino/crash/data';
import type { HoldemHandEnd, HoldemStatePush } from '@/apps/casino/holdem/data';
import type { DocFile } from '@/apps/documents/data';
import type { MedicalId } from '@/apps/health/medicalApi';
import type { BodycamRecording, Bulletin, Call, ChatMsg, LiveEvent, Unit } from '@/apps/mdt/data';
import type { DMsg as PhotogramDM, User as PhotogramUser } from '@/apps/photogram/data';
import type {
    HudMarker, HudPosition, HudState, HudStyle, LineupState, RaceResult, StartBoard, Standing,
} from '@/apps/racing/data';
import type { VUser as VibezUser } from '@/apps/vibez/data';
import type { Reaction } from '@/shared/chat/data';

export interface OpenPayload {
    locale?: string;
    locales?: string[];
    forceLtr?: boolean;
    locked: boolean;
    battery: number;
    frameColor?: string;
    carrier: string;
    signal: number;
    showWifi: boolean;
    wifiConfigured?: boolean;
    bluetoothConfigured?: boolean;
    use24h: boolean;
    showDate: boolean;
    dock: string[];
    apps: AppDef[];
    firstPageApps?: number;
    installedApps?: string[];
    homeLayout?: string;
    mailDomain?: string;
    /** Phone-number display config (config.Phone.Number); formats are keyed by digit count. */
    number?: {
        formats?: Record<string, string>;
        length?: number;
        custom?: { min: number; max: number };
    };
    bootScreen?: boolean;
    casino?: {
        games?: string[];
    };
    music?: {
        youtube?: boolean;
        anyAudio?: boolean;
        hosts?: string[];
        videos?: string[];
        tracks?: { url: string; title?: string; artist?: string }[];
    };
    wallpaper: {
        lock: string;
        home: string;
    };
    sim?: SimStatePush;
}

/** Unique-phones SIM snapshot: enabled=false means the feature is off (stock behaviour). */
export interface SimStatePush {
    enabled: boolean;
    hasSim?: boolean;
    number?: string;
    /** DeviceIdentity mode: the phone owns its data and opens without a SIM (no No-SIM wall,
     *  "No Service" in the status bar instead). Absent/false = legacy SIM-is-identity mode. */
    device?: boolean;
    /** Device mode only: the phone's device identity, used to namespace per-phone UI state
     *  (setup completion, auth cache) so swapping SIMs on one phone never resets it. */
    profile?: string;
}

/** One Wi-Fi network the phone can see. `strength` is 0..1 raw, `bars` the 0..3 the icon draws. */
export interface WifiNetwork {
    id: string;
    ssid: string;
    /** Already joined once by this character, so rejoining needs no password. */
    known?: boolean;
    /** Password protected. The client omits it on the connected network, where it normalizes to false. */
    secured: boolean;
    strength: number;
    bars: number;
}

/** Live Wi-Fi snapshot: enabled=false means the radio is off, so there is nothing to join. */
export interface WifiState {
    enabled: boolean;
    /** This server runs Wi-Fi at all. Distinguishes a switched-off radio from no networks. */
    configured?: boolean;
    connected: WifiNetwork | null;
    networks: WifiNetwork[];
    providesData?: boolean;
}

export type IdCardKind = 'state' | 'licence' | 'job';

export interface IdCardField { key: string; value: string }

export interface IdCardData {
    key:       string;
    kind:      IdCardKind;
    title:     string;
    subtitle?: string;
    color:     string;
    name:      string;
    portrait:  string | null;
    issuer:    string;
    fields:    IdCardField[];
}

export interface ReceivedIdCard {
    id:        string;
    card:      IdCardData;
    fromName:  string;
    expiresAt: number;
}

export interface AppDef {
    id: string;
    label: string;
    icon: string;
    route: string;
    accent: string;
    base?: boolean;
    /** Wi-Fi network id (configs/wifi.lua) the phone must be joined to before this app downloads. */
    wifi?: string;
}

export interface CustomWidgetDef {
    id:    string;
    name:  string;
    ui:    string;
    sizes: ('sm' | 'md' | 'lg')[];
    /**
     * Opt-in: lets the widget's iframe receive real pointer events (taps, buttons) instead of
     * being purely decorative. Off by default so existing third-party widgets that never
     * expected clicks keep behaving exactly as before.
     */
    interactive?: boolean;
}

export interface CustomLockscreenWidgetDef {
    id: string;
    name: string;
    ui: string;
    height: number;
    interactive?: boolean;
}

export interface CustomAppDef {
    id:          string;
    name:        string;
    description?: string;
    developer?:  string;
    icon?:       string;
    images?:     string[];
    size?:       number;
    price?:      number;
    defaultApp?: boolean;
    game?:       boolean;
    ui?:         string;
    fixBlur?:    boolean;
    keepOpen?:   boolean;
    landscape?:  boolean;
    /** Wi-Fi network id (configs/wifi.lua) the phone must be joined to before this app downloads. */
    wifi?:       string;
    /** Device ids this app appears on. Absent means every device. */
    devices?:    string[];
    widgets?:    CustomWidgetDef[];
    lockscreenWidgets?: CustomLockscreenWidgetDef[];
    resource:    string;
}

export interface WeatherPayload {
    current: string;
    next:    string;
    time?:   { hour: number; minute: number };
}

interface SessionPayload {
    startMs: number;
}

export interface HealthPayload {
    steps:     number;
    distanceM: number;
    heartRate: number;
    state:     'idle' | 'walking' | 'running' | 'sprinting' | 'vehicle' | 'dead';
    pending?:  { steps: number; distanceM: number; activeMs: number };
}

interface GroupInvitePush {
    id:          string;
    groupId:     string;
    groupName:   string;
    invitedBy:   string;
    memberCount: number;
    color:       string;
}

interface GroupRosterPush {
    groupId: string;
}

interface GroupDisbandPush {
    groupId: string;
    name?:   string;
}

interface CallPush {
    channel: number;
    name?:   string;
    number:  string;
    video?:  boolean;
}

interface CallEndedPush {
    channel: number;
    reason:  string;
    /** Present on the caller's teardown when the callee never answered and the number they
     *  dialled owns a mailbox, so the call screen can offer to record a message. */
    voicemail?: { number: string; name?: string };
}

interface FriendsUpdatePush {
    friends: {
        id:         string;
        name:       string;
        phone:      string;
        color:      string;
        youShare:   boolean;
        theyShare:  boolean;
        x?:         number;
        y?:         number;
        updatedAt?: number;
        unavailable?: boolean;
    }[];
}

export interface MessagesIncomingPush {
    id:           string;
    groupName?:   string;
    participants: { id: string; name: string; initials: string; color: string; avatar?: string; phone?: string }[];
    messages:     { id: string; from: string; body: string; kind: string; ts: number; read: boolean; reactions?: { emoji: string; count: number; mine: boolean }[]; gifUrl?: string; amount?: number; duration?: number; wpCode?: string; wpSub?: string }[];
    pinned:       boolean;
    muted:        boolean;
}

export interface RydeLatLng { label: string; x: number; y: number }
export interface RydeRequestPush { id: string; riderName: string; pickup: RydeLatLng; dropoff: RydeLatLng; distance: number; fare?: number; createdAt: number }
interface RydeTripPush {
    id: string; status: string; role: 'rider' | 'driver';
    requestId?: string;
    riderName?: string; driverName?: string;
    vehicle?: string; plate?: string; color?: string; rating?: number; number?: string;
    fare?: number; payment?: string; distance?: number;
    pickup?: RydeLatLng; dropoff?: RydeLatLng;
    rideId?: string; paid?: boolean; earn?: number; by?: string;
    waypoint?: { x: number; y: number };
}

interface ClassifiedFeedItem {
    id: string;
    title: string;
    body: string;
    price?: number;
    image?: string;
    images?: string[];
    number: string;
    email?: string;
    date?: string;
    mine?: boolean;
}
interface ClassifiedFeedPush {
    type: 'added' | 'updated' | 'removed';
    item?: ClassifiedFeedItem;
    id?: string;
}

interface MusicSharedTrack {
    id?: string;
    title?: string;
    artist?: string;
    album?: string;
    url: string;
    addedAt?: number;
}
interface MusicSharePush {
    kind: 'track' | 'playlist';
    track?: MusicSharedTrack;
    name?: string;
    tracks?: MusicSharedTrack[];
}

/**
 * Pushed by `exports('f_phone'):setExternalNowPlaying(appId, track)` — lets a third-party
 * resource (its own audio engine, not f_phone's built-in Music) drive the Control Center card,
 * the dynamic-island mini-player, and the native Now Playing widget, the same way the built-in
 * Music app does. Only one provider is "active" at a time: the most recent `set` wins, and a
 * `clear` from a stale appId (one that already lost the slot to a newer provider) is ignored.
 */
export interface ExternalNowPlayingTrack {
    title:    string;
    artist?:  string;
    thumb?:   string;
    playing:  boolean;
    position: number;
    duration: number;
    canNext?: boolean;
    canPrev?: boolean;
}

/** One registered custom-app widget currently visible in the lock-screen notification stack. */
export interface ActiveLockscreenWidget {
    key: string;
    appId: string;
    widgetId: string;
    payload: Record<string, unknown>;
}

export type NuiMessage =
    | { action: 'f_phone:open';    data: OpenPayload }
    | { action: 'f_phone:apps';    data: { installedApps?: string[]; homeLayout?: string | null } }
    | { action: 'f_phone:simState'; data: SimStatePush }
    | { action: 'f_phone:frameColor'; data: { color: string } }
    | { action: 'f_phone:fold'; data: { open?: boolean; foldable?: boolean; openW?: number; restore?: boolean } }
    | { action: 'f_phone:music:receive'; data: MusicSharePush }
    | { action: 'f_phone:nowPlaying:set';   data: { appId: string; track: ExternalNowPlayingTrack } }
    | { action: 'f_phone:nowPlaying:clear'; data: { appId: string } }
    | { action: 'f_phone:cctv:enter'; data: { cameraId: string; label: string; category: string } }
    | { action: 'f_phone:cctv:exit';  data: Record<string, never> }
    | { action: 'f_phone:lockscreenWidget:show'; data: ActiveLockscreenWidget }
    | { action: 'f_phone:lockscreenWidget:hide'; data: { key: string } }
    | { action: 'f_phone:pages:feed';       data: ClassifiedFeedPush }
    | { action: 'f_phone:weazelnews:feed';  data: { type: 'changed' | 'job' } }
    | { action: 'f_phone:marketplace:feed'; data: ClassifiedFeedPush }
    | { action: 'f_phone:ryde:requestAdded';   data: RydeRequestPush }
    | { action: 'f_phone:ryde:requestRemoved'; data: { id: string } }
    | { action: 'f_phone:ryde:waitingCount';   data: { count: number } }
    | { action: 'f_phone:ryde:matched';        data: RydeTripPush }
    | { action: 'f_phone:ryde:tripUpdate';     data: RydeTripPush }
    | { action: 'f_phone:ryde:ratingReceived'; data: { id: string; stars: number; tip?: number } }
    | { action: 'f_phone:ryde:peerLocation';   data: { tripId: string; role: 'rider' | 'driver'; x: number; y: number; h: number } }
    | { action: 'f_phone:close' }
    | { action: 'f_phone:profileReset' }
    | { action: 'f_phone:client:characterLoaded' }
    | { action: 'f_phone:launchApp'; data: { id: string; link?: Record<string, unknown> } }
    | { action: 'f_phone:escape' }
    | { action: 'f_phone:escapeKey' }
    | { action: 'f_phone:battery'; data: number }
    | { action: 'f_phone:service'; data: { bars: number; level: number; data: boolean } }
    | { action: 'f_phone:wifi'; data: WifiState }
    | { action: 'f_phone:weather'; data: WeatherPayload }
    | { action: 'f_phone:session'; data: SessionPayload }
    | { action: 'f_phone:gameClock'; data: GameClock }
    | { action: 'f_phone:health';  data: HealthPayload }
    | { action: 'f_phone:bank:received'; data: { amount: number; from: string } }
    | { action: 'f_phone:bank:txAdded' }
    | { action: 'f_phone:bank:orgChanged' }
    | { action: 'f_phone:services:leaderboard' }
    | { action: 'f_phone:services:applications' }
    | { action: 'f_phone:stocks:prices'; data: { assets: { symbol: string; price: number; changePct: number }[] } }
    | { action: 'f_phone:crash:tick';     data: CrashTick }
    | { action: 'f_phone:crash:bust';     data: CrashBust }
    | { action: 'f_phone:crash:settled';  data: CrashSettled }
    | { action: 'f_phone:crash:snapshot'; data: CrashSnapshot }
    | { action: 'f_phone:holdem:state';   data: HoldemStatePush }
    | { action: 'f_phone:holdem:hand';    data: HoldemHandEnd }
    | { action: 'f_phone:mail:received';         data: unknown }
    | { action: 'f_phone:calendar:invited';      data: { event?: unknown } }
    | { action: 'f_phone:calendar:refresh';      data: { eventId?: string } }
    | { action: 'f_phone:camera:key';            data: { key: string } }
    | { action: 'f_phone:camera:lock';           data: { on: boolean } }
    | { action: 'f_phone:camera:faceCam';        data: { on: boolean } }
    | { action: 'f_phone:photos:added';          data: { id: string; url: string; createdAt: string } }
    | { action: 'f_phone:id:received';           data: ReceivedIdCard }
    | { action: 'f_phone:medical:scanned';       data: { record?: MedicalId } }
    | { action: 'f_phone:photos:uploadFailed';   data: { code?: string } }
    | { action: 'f_phone:groups:inviteReceived'; data: GroupInvitePush }
    | { action: 'f_phone:groups:memberJoined';   data: GroupRosterPush }
    | { action: 'f_phone:groups:memberLeft';     data: GroupRosterPush }
    | { action: 'f_phone:groups:disbanded';      data: GroupDisbandPush }
    | { action: 'f_phone:groups:kicked';         data: GroupDisbandPush }
    | { action: 'f_phone:groups:updated';        data: GroupRosterPush }
    | { action: 'f_phone:maps:pinAdded';         data: { id: string; label: string; x: number; y: number; icon: string; color: string } }
    | { action: 'f_phone:birdy:dmReceived';      data: {
        conversationId: string;
        user:    { name: string; handle: string; verified: boolean };
        message: BirdyMessage;
      } }
    | { action: 'f_phone:birdy:dmReaction';      data: {
        conversationId: string;
        id:        string;
        reactions: Reaction[];
      } }
    | { action: 'f_phone:birdy:notification' }
    | { action: 'f_phone:birdy:feedChanged'; data: { postId?: string; poll?: BirdyPollCounts } }
    | { action: 'f_phone:darkchat:message'; data: {
        roomId:  string;
        message: {
          id: string; author: string; body: string; at: string;
          kind?: string; mediaUrl?: string; audioUrl?: string; duration?: number; waveform?: number[];
          wpCode?: string; wpSub?: string; replyTo?: { name: string; body: string };
          reactions?: { emoji: string; count: number; mine: boolean }[];
        };
      } }
    | { action: 'f_phone:darkchat:active'; data: { roomId: string; active: number } }
    | { action: 'f_phone:darkchat:reaction'; data: { roomId: string; messageId: string; reactions: { emoji: string; count: number; mine: boolean }[] } }
    | { action: 'f_phone:darkchat:kicked'; data: { roomId: string } }
    | { action: 'f_phone:darkchat:code'; data: { roomId: string; code: string } }
    | { action: 'f_phone:darkchat:members'; data: { roomId: string; members: number } }
    | { action: 'f_phone:call:incoming';  data: CallPush }
    | { action: 'f_phone:call:outgoing';  data: CallPush }
    | { action: 'f_phone:call:connected'; data: { channel: number } }
    | { action: 'f_phone:call:ended';     data: CallEndedPush }
    | { action: 'f_phone:call:dropped';   data: { lost: boolean } }
    | { action: 'f_phone:ring:nearby';    data: { rings: { id: number; tone: string; volume: number }[] } }
    | { action: 'f_phone:call:roster';    data: { channel?: number; others?: { name?: string; number: string }[]; pending?: { name?: string; number: string } | null } }
    | { action: 'f_phone:payphone:open';     data: { number: string; anonymous: boolean; myNumber?: string | null; favorites: { name: string; phone: string }[]; connected?: boolean; callerName?: string; coin?: { enabled: boolean; cost: number }; credited?: boolean } }
    | { action: 'f_phone:payphone:outgoing'; data: { channel: number; number: string } }
    | { action: 'f_phone:payphone:ended';    data: { channel: number; reason: string } }
    | { action: 'f_phone:payphone:incoming';      data: { channel: number } }
    | { action: 'f_phone:payphone:incomingEnded'; data: { channel: number } }
    | { action: 'f_phone:radio:status';   data: { on: boolean; freq: number; standby?: boolean } }
    | { action: 'f_phone:radio:onair';    data: { active: boolean } }
    | { action: 'f_phone:radio:count';    data: { count: number } }
    | { action: 'f_phone:radio:forceoff'; data: { message?: string } }
    | { action: 'f_phone:video:request' }
    | { action: 'f_phone:video:accept' }
    | { action: 'f_phone:video:stop' }
    | { action: 'f_phone:video:signal';   data: { kind: 'offer' | 'answer' | 'ice'; slot?: 'video' | 'record'; sdp?: string; candidate?: unknown } }
    | { action: 'f_phone:video:key';      data: { key: string } }
    | { action: 'f_phone:video:lock';     data: { on: boolean } }
    | { action: 'f_phone:video:faceCam';  data: { on: boolean } }
    | { action: 'f_phone:video:cursorState'; data: { on: boolean } }
    | { action: 'f_phone:video:begin';    data: { initiator?: boolean } }
    | { action: 'f_phone:record:peerStart';  data: undefined }
    | { action: 'f_phone:record:peerStop';   data: undefined }
    | { action: 'f_phone:callrec:added';     data: { id: string; peerNumber: string; peerName?: string | null; direction: 'incoming' | 'outgoing'; oneSided: boolean; url: string; duration: number; date: string } }
    | { action: 'f_phone:callrec:failed';    data: { message: string } }
    | { action: 'f_phone:voice:added';        data: { id: string; name: string; url: string; duration: number; date: string } }
    | { action: 'f_phone:voicemail:new';      data: { id: string; number: string; name?: string | null; url: string; duration: number; listened: boolean; date: string } }
    | { action: 'f_phone:notes:added';        data: { id: string; body: string; sketches: string[]; images: string[]; createdAt: string; updatedAt: string } }
    | { action: 'f_phone:documents:added';    data: { doc: DocFile } }
    | { action: 'f_phone:documents:receive';  data: { doc: DocFile; fromName?: string } }
    | { action: 'f_phone:documents:signRequest'; data: { requestId: string; fromName: string; doc: DocFile } }
    | { action: 'f_phone:voice:uploadFailed'; data: { message?: string } }
    | { action: 'f_phone:contacts:shared';    data: { id: string; name: string; phone: string; color: string; initials: string; avatar?: string } }
    | { action: 'f_phone:contacts:removed';   data: { phone: string } }
    | { action: 'f_phone:messages:incoming';  data: MessagesIncomingPush }
    | { action: 'f_phone:messages:reaction';  data: { conversation: string; id: string; reactions: { emoji: string; count: number; mine: boolean }[] } }
    | { action: 'f_phone:messages:removed';   data: { conversation: string } }
    | { action: 'f_phone:messages:meta';      data: { conversation: string; id: string; requestStatus?: 'pending' | 'paid' | 'declined' | 'accepted' } }
    | { action: 'f_phone:messages:typing';    data: { conversation: string; from: string; on: boolean } }
    | { action: 'f_phone:messages:seen';      data: { conversation: string; seenAt: number } }
    | { action: 'f_phone:cherry:message';     data: { matchId: string; message: unknown } }
    | { action: 'f_phone:cherry:match';       data: unknown }
    | { action: 'f_phone:cherry:reaction';    data: { matchId: string; id: string; reactions: { emoji: string; count: number; mine: boolean }[] } }
    | { action: 'f_phone:cherry:unmatch';     data: { matchId: string } }
    | { action: 'f_phone:cherry:partner';     data: { username: string; partner: unknown } }
    | { action: 'f_phone:photogram:notification' }
    | { action: 'f_phone:photogram:dmReceived'; data: { peer: string; user: PhotogramUser; message: PhotogramDM } }
    | { action: 'f_phone:photogram:dmReaction'; data: { peer: string; id: string; reactions: Reaction[] } }
    | { action: 'f_phone:photogram:postChanged'; data: { postId: string; likes?: number; comments?: number; comment?: unknown } }
    | { action: 'f_phone:photogram:feedChanged' }
    | { action: 'f_phone:photogram:postRemoved'; data: { postId: string } }
    | { action: 'f_phone:photogram:followChanged'; data: { target: string; status: 'none' | 'pending' | 'accepted' | 'self' } }
    | { action: 'f_phone:photogram:liveFrame';   data: { liveId: string; frame: string } }
    | { action: 'f_phone:photogram:liveChunk';   data: { liveId: string; chunk: string; init?: boolean; mime?: string; gen?: number } }
    | { action: 'f_phone:photogram:liveTransport'; data: { liveId: string; transport: 'relay' | 'event' } }
    | { action: 'f_phone:photogram:liveComment'; data: { liveId: string; comment: { id: string; user: PhotogramUser; text: string } } }
    | { action: 'f_phone:photogram:liveHeart';   data: { liveId: string } }
    | { action: 'f_phone:photogram:liveViewers'; data: { liveId: string; viewers: number } }
    | { action: 'f_phone:photogram:liveEnded';   data: { liveId: string } }
    | { action: 'f_phone:photogram:liveChanged' }
    | { action: 'f_phone:vibez:notification' }
    | { action: 'f_phone:vibez:feedChanged' }
    | { action: 'f_phone:vibez:postChanged';   data: { postId: string; likes?: number; comments?: number } }
    | { action: 'f_phone:vibez:postRemoved';   data: { postId: string } }
    | { action: 'f_phone:vibez:followChanged'; data: { target: string; following: boolean } }
    | { action: 'f_phone:vibez:liveFrame';     data: { liveId: string; frame: string } }
    | { action: 'f_phone:vibez:liveChunk';     data: { liveId: string; chunk: string; init?: boolean; mime?: string; gen?: number } }
    | { action: 'f_phone:vibez:liveTransport'; data: { liveId: string; transport: 'relay' | 'event' } }
    | { action: 'f_phone:vibez:liveComment';   data: { liveId: string; comment: { id: string; user: VibezUser; text: string } } }
    | { action: 'f_phone:vibez:liveHeart';     data: { liveId: string } }
    | { action: 'f_phone:vibez:liveViewers';   data: { liveId: string; viewers: number } }
    | { action: 'f_phone:vibez:liveEnded';     data: { liveId: string } }
    | { action: 'f_phone:vibez:liveChanged' }
    | { action: 'f_phone:voice:signalIn';        data: { from?: number; sid: string; kind: 'offer' | 'answer' | 'ice'; data: unknown } }
    | { action: 'f_phone:voice:talkingState';    data: { on: boolean } }
    | { action: 'f_phone:streaks:newPost';     data: { id: number; author: string; imageUrl: string; caption?: string; dayStreak: number; postDate: string; createdAt: number; likeCount: number; citizenid: string } }
    | { action: 'f_phone:streaks:postChanged'; data: { postId: number; likeCount: number } }
    | { action: 'f_phone:streaks:refresh' }
    | { action: 'f_phone:mdt:dispatch'; data: { units: Unit[]; calls: Call[] } }
    | { action: 'f_phone:mdt:call';     data: { call: Call } }
    | { action: 'f_phone:mdt:chat';     data: { message: ChatMsg } }
    | { action: 'f_phone:mdt:bulletin'; data: { bulletins: Bulletin[] } }
    | { action: 'f_phone:mdt:warrant';  data: { citizenid: string; wanted: boolean } }
    | { action: 'f_phone:mdt:live';     data: LiveEvent }
    | { action: 'f_phone:mdt:offences'; data: Record<string, never> }
    | { action: 'f_phone:mdt:sops';     data: Record<string, never> }
    | { action: 'f_phone:mdt:shares';   data: { type: 'report' | 'case' | 'warrant'; ref: string; access?: 'view' | 'edit' } }
    | { action: 'f_phone:mdt:bodycam:enter'; data: { cameraId: string; kind: string; officer: string; callsign: string | null; plate: string | null; model: string | null; unit: string | null; rank: string | null; canRecord: boolean; auto: boolean; profile: { fps: number; width: number; bitrate: number; maxSeconds: number; minSeconds: number } } }
    | { action: 'f_phone:mdt:bodycam:exit';   data: Record<string, never> }
    | { action: 'f_phone:mdt:bodycam:record'; data: Record<string, never> }
    | { action: 'f_phone:mdt:recSaved';       data: BodycamRecording }
    | { action: 'f_phone:mdt:recFailed';      data: { message?: string } }
    | { action: 'f_phone:mdt:recShared';      data: { by?: string } }
    | { action: 'f_phone:racing:racesChanged' }
    | { action: 'f_phone:racing:standings';  data: { raceId: string; entries: Standing[] } }
    | { action: 'f_phone:racing:raceResult'; data: RaceResult }
    | { action: 'f_phone:racing:hud:show';   data: { style: HudStyle; position: HudPosition; scale: number } }
    | { action: 'f_phone:racing:hud:hide' }
    | { action: 'f_phone:racing:hud:state';  data: Partial<HudState> }
    | { action: 'f_phone:racing:hud:countdown'; data: { from: number } }
    | { action: 'f_phone:racing:hud:clock' }
    | { action: 'f_phone:racing:hud:dnf';    data: { seconds: number } }
    | { action: 'f_phone:racing:markers';    data: { markers: HudMarker[]; color: string; colorClosest: string } }
    | { action: 'f_phone:racing:board:show'; data: StartBoard }
    | { action: 'f_phone:racing:board:pos';  data: { on: boolean; x: number; y: number; joined: boolean } }
    | { action: 'f_phone:racing:board:hide' }
    | { action: 'f_phone:racing:board:lineup'; data: { state: LineupState | null } }
    | { action: 'f_phone:wipe' }
    | { action: 'f_phone:admin:open'; data: { adminName?: string; sim?: boolean; racing?: boolean } }
    | { action: 'f_phone:admin:migrate'; data: import('@/admin/types').MigrationPush }
    | { action: 'chess:invited';  data: { fromSrc: string; fromName: string; lobbyId: string } }
    | { action: 'chess:lobby';    data: { id: string; host: string; public: boolean; wager: number; isHost: boolean; canStart: boolean; members: { name: string; you: boolean; host: boolean; color: 'w' | 'b' | 'random'; canAfford: boolean; ready: boolean; returned: boolean }[] } }
    | { action: 'chess:lobbyClosed'; data: Record<string, never> }
    | { action: 'chess:start';    data: { gameId: string; color: 'w' | 'b'; opponent: string; pot: number } }
    | { action: 'chess:move';     data: { gameId: string; move: { from: number; to: number; promo?: string; flag?: string } } }
    | { action: 'chess:ended';    data: { reason: string } }
    | { action: 'connectfour:invited';  data: { fromSrc: string; fromName: string; lobbyId: string } }
    | { action: 'connectfour:lobby';    data: { id: string; host: string; public: boolean; wager: number; isHost: boolean; canStart: boolean; members: { name: string; you: boolean; host: boolean; color: string; canAfford: boolean; ready: boolean; returned: boolean }[] } }
    | { action: 'connectfour:lobbyClosed'; data: Record<string, never> }
    | { action: 'connectfour:start';    data: { gameId: string; color: string; opponent: string; pot: number } }
    | { action: 'connectfour:move';     data: { gameId: string; move: { col: number } } }
    | { action: 'connectfour:ended';    data: { reason: string } }
    | { action: 'battleship:invited';  data: { fromSrc: string; fromName: string; lobbyId: string } }
    | { action: 'battleship:lobby';    data: { id: string; host: string; public: boolean; wager: number; isHost: boolean; canStart: boolean; members: { name: string; you: boolean; host: boolean; color: string; canAfford: boolean; ready: boolean; returned: boolean }[] } }
    | { action: 'battleship:lobbyClosed'; data: Record<string, never> }
    | { action: 'battleship:start';    data: { gameId: string; color: string; opponent: string; pot: number } }
    | { action: 'battleship:move';     data: { gameId: string; move: { shot: { r: number; c: number } | null; prevResult: { hit: boolean; sunk: string | null } | null } } }
    | { action: 'battleship:ended';    data: { reason: string } }
    | { action: 'wordle:invited';      data: { fromSrc: string; fromName: string; lobbyId: string } }
    | { action: 'wordle:lobby';        data: { id: string; host: string; public: boolean; wager: number; isHost: boolean; canStart: boolean; members: { name: string; you: boolean; host: boolean; color: string; canAfford: boolean; ready: boolean; returned: boolean }[] } }
    | { action: 'wordle:lobbyClosed';  data: Record<string, never> }
    | { action: 'wordle:start';        data: { gameId: string; color: string; opponent: string; pot: number } }
    | { action: 'wordle:move';         data: { gameId: string; move: { rows: string[][]; solved: boolean; failed: boolean; tries: number; finishMs: number } } }
    | { action: 'wordle:ended';        data: { reason: string } }
    | { action: 'f_phone:notification';       data: { id?: string; app?: string; image?: string; titleKey?: string; title: string; titleVars?: Record<string, string | number>; bodyKey?: string; body?: string; bodyVars?: Record<string, string | number>; time?: string; appId?: string; quietInApp?: boolean; emergency?: boolean; otherPhone?: boolean; phoneColor?: string; profileKey?: string; link?: Record<string, unknown> } }
    | { action: 'f_phone:badges';             data: Record<string, number> }
    | { action: 'f_phone:badges:patch';       data: Record<string, number> }
    | { action: 'f_phone:airshare';           data: { id: string; kind: string; fromName: string } }
    | { action: 'f_phone:maps:friends:update'; data: FriendsUpdatePush }
    | { action: 'f_phone:maps:location';       data: { x: number; y: number; h: number } }
    | { action: 'f_phone:maps:calibrate';      data: { on: boolean } }
    | { action: 'f_phone:maps:tilecheck' }
    | { action: 'f_phone:services:inbox' }
    | { action: 'f_phone:services:jobsChanged' }
    | { action: 'f_phone:services:rosterChanged' }
    | { action: 'f_phone:services:invoices' }
    | { action: 'f_phone:homes:refresh' }
    | { action: 'customApps:set';     data: CustomAppDef[] }
    | { action: 'customApps:message'; data: { id: string; message: unknown } };
