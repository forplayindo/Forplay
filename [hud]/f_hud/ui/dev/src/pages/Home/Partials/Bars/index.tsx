import "./index.scss";
import Icon from "@/components/Icon";
import useData from "@/hooks/useData";
import { BarType, HYGIENE_BARS, iBar } from "@/types/BasicTypes";
import { padNumber, VOICE_TALKING_COLOR } from "@/utils/misc";
import classNames from "classnames";
import { useEffect, useRef } from "react";
import { useTranslation } from "react-i18next";
import { DragDropContainer } from "react-drag-drop-container-typescript";
import { FaLocationCrosshairs } from "react-icons/fa6";

const ARMOR_SEGMENTS = 5;
/** Default distance (px) of the status block from the bottom of the screen. */
export const STATUS_BOTTOM = 14;
// small stats under health, in this order (voice is appended last)
const MINI: BarType[] = ["hunger", "thirst", "stress", "stamina", "oxygen"];

/** Same auto-hide rule the old bar styles used: hide while value is above the player's threshold. */
const isAutoHidden = ({ autoHide, value }: iBar) => typeof autoHide == "number" && autoHide < 100 && (autoHide < value || autoHide === 0);

const clamp = (v?: number) => Math.max(0, Math.min(100, Math.round(v || 0)));

const MainRow = ({ slot, bar, label, segments }: { slot: BarType; bar: iBar; label: string; segments?: number }) => {
  const value = clamp(bar?.value);
  const color = bar?.color || "#ffffff";
  return (
    <div className="g6b-row">
      <div className="g6b-ico">
        <Icon iconReq={`${slot}.1`} color={color} size="19px" />
      </div>
      <div className="g6b-main">
        <div className="g6b-label">{label}</div>
        {segments ? (
          <div className="g6b-segs">
            {Array.from({ length: segments }).map((_, i) => {
              const fill = Math.max(0, Math.min(1, (value / 100) * segments - i));
              return (
                <div key={i} className="g6b-seg">
                  <div style={{ width: `${fill * 100}%`, background: color }} />
                </div>
              );
            })}
          </div>
        ) : (
          <div className="g6b-track">
            <div style={{ width: `${value}%`, background: color }} />
          </div>
        )}
      </div>
      <div className="g6b-value">{value}</div>
    </div>
  );
};

const MiniStat = ({ icon, color, text, fill, wide }: { icon: string; color: string; text: string | number; fill: number; wide?: boolean }) => (
  <div className={classNames("g6b-mini", { wide })}>
    <div className="g6b-mini-top">
      <Icon iconReq={icon} color={color} size="14px" />
      <span>{text}</span>
    </div>
    <div className="g6b-mini-line">
      <div style={{ width: `${fill}%`, background: color }} />
    </div>
  </div>
);

/** GTA VI style status block: armor (segmented), health, then hunger / thirst / stress / … / voice. */
/**
 * @param anchorLeft default CSS `left` (the minimap's left edge) when the player hasn't dragged the bars
 * @param anchorWidth CSS width of the minimap, so both edges of the block line up with it
 * @param onHeight reports the block's rendered height (rows auto-hide, so it changes)
 * @param stackInline render the location card + hygiene row as the top rows of this block (used while the minimap is hidden)
 */
export const BarsComponent = ({ anchorLeft, anchorWidth, onHeight, stackInline }: { anchorLeft?: string; anchorWidth?: string; onHeight?: (h: number) => void; stackInline?: boolean }) => {
  const { t } = useTranslation();
  const { BarsInfo, HudStyle, onChangeHudPositions, isEditorOpen, ClientInfo } = useData();
  const blockRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = blockRef.current;
    if (!el || !onHeight) return;
    const ro = new ResizeObserver(() => onHeight(el.offsetHeight));
    ro.observe(el);
    onHeight(el.offsetHeight);
    return () => ro.disconnect();
  }, [onHeight]);

  const pos = {} as React.CSSProperties;
  pos.left = HudStyle.positions.bar_default.x || anchorLeft || 16;
  if (HudStyle.positions.bar_default.y) pos.top = HudStyle.positions.bar_default.y;
  else pos.bottom = STATUS_BOTTOM;

  const voice = BarsInfo.voice;
  const talkRange = Math.max(1, Math.min(3, voice?.talkRange || 2));
  const voiceColor = voice?.isTalking ? VOICE_TALKING_COLOR : voice?.color || "#ffffff";

  return (
    <div className="absolute select-none" style={pos}>
      <DragDropContainer noDragging={!isEditorOpen} dragElemOpacity={0.75} onDragEnd={(_, __, x, y) => onChangeHudPositions("bar_default", x, y)}>
        {isEditorOpen && (
          <button className="absolute -left-5 -top-6 z-10 p-2 rounded-full border border-white/15 bg-white/15">
            <FaLocationCrosshairs />
          </button>
        )}
        <div ref={blockRef} className="g6b" style={anchorWidth ? { width: anchorWidth } : undefined}>
          {stackInline && <HygieneRow />}
          {stackInline && <LocationCard />}
          {!isAutoHidden(BarsInfo.armor) && <MainRow slot="armor" bar={BarsInfo.armor} label={t("armor")} segments={ARMOR_SEGMENTS} />}
          {!isAutoHidden(BarsInfo.health) && <MainRow slot="health" bar={BarsInfo.health} label={t("health")} />}
          <div className="g6b-minis">
            {MINI.map((slot) => {
              const bar = BarsInfo[slot];
              if (!bar || isAutoHidden(bar)) return null;
              // stamina / oxygen only matter while they are draining
              if ((slot == "stamina" || slot == "oxygen") && clamp(bar.value) >= 100) return null;
              const color = bar.color || "#ffffff";
              return <MiniStat key={slot} icon={`${slot}.1`} color={color} text={clamp(bar.value)} fill={clamp(bar.value)} />;
            })}
            {voice && !isAutoHidden(voice) && (
              <MiniStat
                wide
                icon={`voice.${ClientInfo.radio?.inChannel ? 2 : 1}`}
                color={voiceColor}
                text={t(`voice_range_${talkRange}`)}
                fill={(talkRange / 3) * 100}
              />
            )}
          </div>
        </div>
      </DragDropContainer>
    </div>
  );
};

/** Hygiene row content (mandi / kencing / poop from f_hygiene): three bars side by side. Null when hidden (F3 / auto-hide). */
const HygieneRow = () => {
  const { t } = useTranslation();
  const { BarsInfo, hygieneVisible } = useData();
  if (!hygieneVisible) return null;
  // hygiene values are a NEED level (100 = urgent), so auto-hide works on the inverse:
  // threshold 50 = only show once the need reaches 50, 100 = always show
  const shown = HYGIENE_BARS.filter((slot) => BarsInfo[slot] && !isAutoHidden({ ...BarsInfo[slot], value: 100 - (BarsInfo[slot].value || 0) }));
  if (!shown.length) return null;
  return (
    <div className="g6h">
      {shown.map((slot) => {
        const bar = BarsInfo[slot];
        const value = clamp(bar.value);
        const color = bar.color || "#ffffff";
        return (
          <div key={slot} className="g6h-item" title={t(slot)}>
            <div className="g6h-ico">
              <Icon iconReq={`${slot}.1`} color={color} size="15px" />
            </div>
            <div className="g6h-track">
              <div style={{ width: `${value}%`, background: color }} />
            </div>
            <div className="g6h-val">{value}</div>
          </div>
        );
      })}
    </div>
  );
};

/** Location card (street, area, game time) on a blurred glass panel (`.gl` is picked up by blur.js). */
const LocationCard = () => {
  const { t } = useTranslation();
  const { NavigationWidget, Compass, Cinematic, ClientInfo } = useData();
  if (!(NavigationWidget.active && NavigationWidget.show && !Cinematic.show)) return null;
  const nav = NavigationWidget.navigation;
  const street = (nav?.isDestinationActive && nav?.currentStreet) || Compass.street1 || t("location");
  const area = (nav?.isDestinationActive && nav?.destinationStreet) || Compass.street2;
  const { gameHours, gameMinutes } = ClientInfo.time;
  const isDay = gameHours >= 6 && gameHours < 18;
  return (
    <div className="gl g6l">
      <img className="g6l-ico" src="images/icons/navigation.svg" alt="" />
      <div className="g6l-txt">
        <div className="g6l-street">{street}</div>
        {area && <div className="g6l-area">{area}</div>}
      </div>
      <div className="g6l-time">
        <img src={isDay ? "images/icons/time_morning.svg" : "images/icons/time_night.svg"} alt="" />
        <span>
          {padNumber(gameHours)}:{padNumber(gameMinutes)}
        </span>
      </div>
    </div>
  );
};

/** Hygiene row on top of the location card, stacked right above the minimap (while the radar is shown). */
export const MapTopStack = ({ left, bottom, width }: { left: string | number; bottom: string; width?: string }) => (
  <div className="absolute select-none g6-stack" style={{ left, bottom, width: width ?? 280 }}>
    <HygieneRow />
    <LocationCard />
  </div>
);
