import "./Gta6.scss";
import { iVehicleInfo } from "@/types/BasicTypes";
import classNames from "classnames";
import { useTranslation } from "react-i18next";
import { FaFan, FaGasPump, FaLightbulb, FaOilCan, FaPlane, FaShip } from "react-icons/fa6";
import { MdAirlineSeatReclineExtra, MdElectricBolt, MdSpeed } from "react-icons/md";

const ACCENT = "#f3b354";
const WARN = "#ffc148";
const DANGER = "#ff4d5e";
const RPM_MAX = 8; // x1000, ruler 0..8
const REDLINE = 7; // last segment drawn red
// bikes / cycles / boats / helis / planes have no seatbelt
const NO_BELT_CLASSES = [8, 13, 14, 15, 16];
const BOAT = 14;
const AIR_CLASSES = [15, 16]; // helicopters, planes
const AIR_SPD_MAX = 300; // km/h ruler 0..300
const AIR_SPD_RED = 260;
const LOW_ALT = 30; // m: below this while descending fast -> warning
const LOW_ALT_VS = -6; // m/s

// compass tape: 1 degree = 3px, drawn over 0..720 so it can scroll without a seam
const TAPE_PX = 3;
const DIRS: Record<number, string> = { 0: "U", 45: "TL", 90: "T", 135: "TG", 180: "S", 225: "BD", 270: "B", 315: "BL" };
const TAPE = (() => {
  const marks: { x: number; cls: string; label?: string; card?: boolean }[] = [];
  for (let d = 0; d <= 720; d += 5) {
    const a = d % 360;
    marks.push({
      x: d * TAPE_PX,
      cls: a % 45 === 0 ? "maj" : a % 15 === 0 ? "mid" : "min",
      label: a % 45 === 0 ? DIRS[a] : a % 15 === 0 ? String(a) : undefined,
      card: a % 45 === 0,
    });
  }
  return marks;
})();
const TAPE_WIDTH = 310; // same as .g6s width

type Indicator = { key: string; icon: React.ReactNode; label: string; value: string; color: string; fill: number; dim?: boolean };

const clamp = (v: number | undefined, min: number, max: number, def = 0) => Math.max(min, Math.min(max, v ?? def));

const Digits = ({ value, len }: { value: number; len: number }) => {
  const s = String(Math.min(Math.max(0, Math.round(value)), 10 ** len - 1));
  const lead = len - s.length;
  return (
    <div className="g6s-digits">
      {s
        .padStart(len, "0")
        .split("")
        .map((d, i) => (
          <span key={i} className={classNames({ lead: i < lead })}>
            {d}
          </span>
        ))}
    </div>
  );
};

const Compass = ({ heading }: { heading: number }) => {
  const h = ((Math.round(heading) % 360) + 360) % 360;
  const dir = DIRS[(Math.round(h / 45) * 45) % 360];
  return (
    <div className="g6s-compass">
      <div className="hdg">
        {String(h).padStart(3, "0")}° {dir}
      </div>
      <div className="ptr" />
      <div className="tape" style={{ transform: `translateX(${TAPE_WIDTH / 2 - (h + 360) * TAPE_PX}px)` }}>
        {TAPE.map((m) => (
          <div key={m.x}>
            <i className={m.cls} style={{ left: m.x }} />
            {m.label && (
              <b className={classNames({ card: m.card })} style={{ left: m.x }}>
                {m.label}
              </b>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

const Ruler = ({ label, ratio, redAt, scale, value }: { label: string; ratio: number; redAt: number; scale: { v: number; text: string; red: boolean }[]; value?: React.ReactNode }) => (
  <div className="g6s-rpm">
    <div className="g6s-rpm-label">{label}</div>
    <div className="g6s-rpm-body">
      <div className="g6s-rpm-track">
        <div className="fill" style={{ width: `${ratio * 100}%` }} />
        <div className="red" style={{ left: `${redAt * 100}%` }} />
        <div className="knob" style={{ left: `${ratio * 100}%` }} />
      </div>
      <div className="g6s-rpm-scale">
        {scale.map((s) => (
          <span key={s.v} className={classNames({ red: s.red })} style={{ left: `${s.v * 100}%` }}>
            {s.text}
          </span>
        ))}
      </div>
    </div>
    {value}
  </div>
);

const RPM_SCALE = Array.from({ length: RPM_MAX + 1 }).map((_, i) => ({ v: i / RPM_MAX, text: String(i), red: i >= REDLINE }));
const AIR_SCALE = [0, 50, 100, 150, 200, 250, 300].map((v) => ({ v: v / AIR_SPD_MAX, text: String(v), red: v >= AIR_SPD_RED }));

/** GTA VI style speedometer: digital speed + gear box, horizontal RPM ruler, status indicators.
 *  Boats get a compass + direction box, helicopters / planes an altitude HUD. */
const Gta6 = ({ veh }: { veh: iVehicleInfo }) => {
  const { t } = useTranslation();
  const speed = Math.max(0, Math.round(veh.speed || 0));
  const rpm = clamp(veh.rpm, 0, 1);
  const fuel = Math.round(clamp(veh.fuel?.level, 0, 100));
  const electric = veh.fuel?.type == "electric";
  const engine = Math.round(clamp(veh.engineHealth, 0, 100, 100));
  const isAir = AIR_CLASSES.includes(veh.veh_class);
  const isBoat = veh.veh_class == BOAT;
  const hasBelt = !NO_BELT_CLASSES.includes(veh.veh_class);
  const unit = veh.kmH ? (isAir || isBoat ? "KM/J" : "KM/H") : "MPH";

  const onOff = (on: boolean) => t(on ? "state_on" : "state_off");
  const health = (v: number): [string, string] =>
    v > 60 ? [t("engine_ok"), ACCENT] : v > 30 ? [t("engine_warn"), WARN] : [t("engine_bad"), DANGER];
  const [engineText, engineColor] = health(engine);

  const fuelInd: Indicator = {
    key: "fuel",
    icon: electric ? <MdElectricBolt /> : <FaGasPump />,
    label: t(electric ? "battery" : "fuel"),
    value: `${fuel}%`,
    color: fuel <= 20 ? DANGER : ACCENT,
    fill: fuel,
  };
  const engineInd: Indicator = { key: "engine", icon: <FaOilCan />, label: t("engine"), value: engineText, color: engineColor, fill: engine };
  const lightsInd: Indicator = {
    key: "lights",
    icon: <FaLightbulb />,
    label: t("lights"),
    value: onOff(!!veh.isLightOn),
    color: ACCENT,
    fill: veh.isLightOn ? 100 : 0,
    dim: !veh.isLightOn,
  };
  const healthInd = (key: string, icon: React.ReactNode, label: string, value: number): Indicator => {
    const v = Math.round(clamp(value, 0, 100, 100));
    const [text, color] = health(v);
    return { key, icon, label, value: text, color, fill: v };
  };

  let indicators: Indicator[];
  let top: React.ReactNode;
  let ruler: React.ReactNode;
  let warn = false;

  if (isAir) {
    const isHeli = veh.veh_class == 15;
    const alt = Math.max(0, veh.altitude ?? 0);
    const vs = veh.verticalSpeed ?? 0;
    const ratio = clamp(speed / AIR_SPD_MAX, 0, 1);
    warn = alt < LOW_ALT && vs < LOW_ALT_VS;
    indicators = [
      fuelInd,
      engineInd,
      isHeli ? healthInd("rotor", <FaFan />, t("rotor"), veh.rotorHealth ?? 100) : healthInd("body", <FaPlane />, t("body"), veh.rotorHealth ?? 100),
      lightsInd,
    ];
    top = (
      <div className="g6s-top">
        <div className="g6s-speed">
          <Digits value={alt} len={4} />
          <div className="g6s-unit">
            <small>{t("altitude")}</small>M
          </div>
        </div>
        <div className="g6s-gear wide">
          <div className="num">
            <span className="arr">{vs >= 0.05 ? "▲" : vs <= -0.05 ? "▼" : "•"}</span>
            {Math.abs(vs).toFixed(1)}
          </div>
          <div className="lbl">{t("climb")}</div>
        </div>
      </div>
    );
    ruler = (
      <Ruler
        label={t("speed_short")}
        ratio={ratio}
        redAt={AIR_SPD_RED / AIR_SPD_MAX}
        scale={AIR_SCALE}
        value={
          <div className="g6s-spd-val">
            {speed}
            <small>{unit}</small>
          </div>
        }
      />
    );
  } else {
    if (isBoat) {
      indicators = [fuelInd, engineInd, healthInd("body", <FaShip />, t("body"), veh.bodyHealth ?? 100), lightsInd];
    } else {
      indicators = [
        fuelInd,
        engineInd,
        {
          key: "belt",
          icon: <MdAirlineSeatReclineExtra />,
          label: t("belt"),
          value: hasBelt ? onOff(!!veh.isSeatbeltOn) : "-",
          color: hasBelt && !veh.isSeatbeltOn && speed > 10 ? DANGER : ACCENT,
          fill: hasBelt && veh.isSeatbeltOn ? 100 : 0,
          dim: !hasBelt || (!veh.isSeatbeltOn && speed <= 10),
        },
        {
          key: "cruise",
          icon: <MdSpeed />,
          label: t("cruise"),
          value: onOff(!!veh.isCruiseOn),
          color: ACCENT,
          fill: veh.isCruiseOn ? 100 : 0,
          dim: !veh.isCruiseOn,
        },
        lightsInd,
      ];
    }
    top = (
      <div className="g6s-top">
        <div className="g6s-speed">
          <Digits value={speed} len={3} />
          <div className="g6s-unit">{unit}</div>
        </div>
        <div className="g6s-gear">
          <div className="num">{isBoat ? veh.boatDirection ?? "N" : veh.currentGear ?? "N"}</div>
          <div className="lbl">GEAR</div>
        </div>
      </div>
    );
    ruler = <Ruler label="RPM" ratio={rpm} redAt={REDLINE / RPM_MAX} scale={RPM_SCALE} />;
  }

  return (
    <div className={classNames("g6s", { warn })}>
      {(isAir || isBoat) && <Compass heading={veh.heading ?? 0} />}
      {top}
      {ruler}

      <div className="g6s-inds">
        {indicators.map((ind) => (
          <div key={ind.key} className={classNames("g6s-ind", { dim: ind.dim })} style={{ "--c": ind.color } as React.CSSProperties}>
            <div className="ico">{ind.icon}</div>
            <div className="lbl">{ind.label}</div>
            <div className="val">{ind.value}</div>
            <div className="line">
              <div style={{ width: `${ind.fill}%` }} />
            </div>
          </div>
        ))}
      </div>

      {isAir && <div className="g6s-alert">▼ {t("too_low")} ▼</div>}
    </div>
  );
};

export default Gta6;
