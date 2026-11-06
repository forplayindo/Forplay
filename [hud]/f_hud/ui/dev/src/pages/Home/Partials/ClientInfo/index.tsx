import useData from "@/hooks/useData";
import { formatNumberWithComma, getFormattedDate } from "@/utils/misc";
import { useTranslation } from "react-i18next";
import { DragDropContainer } from "react-drag-drop-container-typescript";
import { FaLocationCrosshairs } from "react-icons/fa6";

/** Space kept free at the very top-right for the server logo (px @1080p).
 *  Harus sama dengan hudTop di [standalone]/f_serverlogo/html/index.html (logo 4PLAY selebar panel ini). */
const LOGO_SAFE_TOP = 127;
/** Panel size at 1080p (px) – used to keep it inside the screen. PANEL_W = .gl-info width di glass.css = hudWidth logo. */
const PANEL_W = 224;
const PANEL_H = 275;
const DAYS = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

export const ClientInfo = () => {
  const { t } = useTranslation();
  const { ClientInfo, onChangeHudPositions, isEditorOpen } = useData();
  const { real_time, server_info, bank, active, cash, extra_currency, job, player_source, time, weapon, positions } = ClientInfo;
  const ci: any = ClientInfo;

  // Scale with screen height (1080p = 1.0) and never let the panel leave the screen,
  // even if an old saved position (localStorage) points outside the viewport.
  const SC = Math.min(2, Math.max(0.85, window.innerHeight / 1080));
  const PW = PANEL_W * SC;
  const PH = PANEL_H * SC;
  const posStyle: any = {};
  if (positions.x) posStyle.left = Math.min(Math.max(8, positions.x), window.innerWidth - PW - 8);
  else posStyle.right = Math.round(12 * SC);
  posStyle.top = Math.min(Math.max(8, positions.y || Math.round(LOGO_SAFE_TOP * SC)), Math.max(8, window.innerHeight - PH - 8));

  const money = (v: number) => `${t("money_type")}${formatNumberWithComma(v)}`;
  const now = new Date();
  const gang = ci.gang || {};
  const showServer = server_info.active && server_info.show;
  const showPlayer = player_source.active && player_source.show;
  const showJob = job.active && job.show;
  const showTime = time.active && time.show;
  const hasAmmo = weapon.ammo.inClip > 0 && weapon.ammo.inWeapon > 0;

  if (!active) return null;

  const onlineBubble = (
    <div className="gl gl-round gl-bubble gl-bubble--online gl--accent">
      <span className="v">{server_info.playerCount || 0}</span>
      <svg viewBox="0 0 24 24"><path d="M16 11a3 3 0 1 0-3-3 3 3 0 0 0 3 3Zm-8 0a3 3 0 1 0-3-3 3 3 0 0 0 3 3Zm0 2c-2.3 0-7 1.2-7 3.5V19h14v-2.5C15 14.2 10.3 13 8 13Zm8 0c-.3 0-.6 0-1 .1a4.2 4.2 0 0 1 2 3.4V19h6v-2.5c0-2.3-4.7-3.5-7-3.5Z" /></svg>
    </div>
  );

  return (
    <>
      <div id="client_info" className="absolute select-none" style={posStyle}>
        <DragDropContainer noDragging={!isEditorOpen} dragElemOpacity={0.75} onDragEnd={(_, __, x, y) => onChangeHudPositions("client_info", x, y)}>
          {isEditorOpen && (
            <button className="absolute -left-5 -top-6 z-10 p-2 rounded-full border border-white/15 bg-white/15">
              <FaLocationCrosshairs />
            </button>
          )}
          <div className="gl-info" style={{ transform: `scale(${SC})`, transformOrigin: positions.x ? "top left" : "top right" }}>
            {/* Bagian yang di-hide (Pengaturan) tidak dirender sama sekali, jadi yang di bawahnya naik dan layout tetap rapat.
                Baris job hanya ada kalau job tampil; bulatan online pindah ke baris nama kalau job di-hide. */}
            {showJob && (
              <div className="gl-row">
                {showServer && onlineBubble}
                <div className="gl gl-card">
                  <div className="txt">
                    <div className="t1">{(job.label || "") + (job.gradeLabel ? ` | ${job.gradeLabel}` : "")}</div>
                    <div className="t2">{gang.label ? gang.label + (gang.gradeLabel ? ` | ${gang.gradeLabel}` : "") : "Tanpa Geng"}</div>
                  </div>
                </div>
              </div>
            )}

            <div className="gl-row">
              {!showJob && showServer && onlineBubble}
              {showTime && (
                <div className="gl gl-round gl-bubble">
                  <span className="k">{DAYS[now.getDay()]}</span>
                  <span className="v">{now.getDate()}</span>
                </div>
              )}
              {/* radio tidak ditampilkan di sini lagi: sudah ada di HUD radio kiri */}
              <div className="gl gl-card">
                {showPlayer && <div className="gl-idbox">{player_source.source}</div>}
                <div className="txt">
                  <div className="t1">{ci.player_name || "—"}</div>
                </div>
              </div>
            </div>

            {cash.active && cash.show && (
              <div className="gl gl--cash gl-money">
                <span className="ico">
                  <img src="images/icons/coin.svg" alt="" />
                </span>
                <span className="lbl">{t("cash")}</span>
                <span className="amt">{money(cash.amount)}</span>
              </div>
            )}
            {bank.active && bank.show && (
              <div className="gl gl--bank gl-money">
                <span className="ico">
                  <img src="images/icons/bank.svg" alt="" />
                </span>
                <span className="lbl">{t("bank")}</span>
                <span className="amt">{money(bank.amount)}</span>
              </div>
            )}
            {extra_currency.active && extra_currency.show && extra_currency.amount > 0 && (
              <div className="gl gl--extra gl-money">
                <span className="ico">
                  <img src="images/icons/coin.svg" alt="" />
                </span>
                <span className="lbl">{t("other_currency")}</span>
                <span className="amt">{money(extra_currency.amount)}</span>
              </div>
            )}
            {weapon.active && weapon.show && weapon.isGun && (
              <div className="gl gl-money">
                <span className="ico">
                  <img src="images/icons/weapon.svg" alt="" />
                </span>
                <span className="lbl">{weapon.name}</span>
                {hasAmmo && (
                  <span className="amt">
                    {weapon.ammo.inClip}
                    {weapon.ammo.inWeapon - weapon.ammo.inClip > 0 ? ` / ${weapon.ammo.inWeapon - weapon.ammo.inClip}` : ""}
                  </span>
                )}
              </div>
            )}

            {real_time.active && time.show && <div className="gl-realtime">{getFormattedDate()}</div>}
          </div>
        </DragDropContainer>
      </div>
    </>
  );
};
