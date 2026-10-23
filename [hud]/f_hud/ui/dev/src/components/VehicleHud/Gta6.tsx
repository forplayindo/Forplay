import "./Gta6.scss";
import { iVehicleInfo } from "@/types/BasicTypes";
import classNames from "classnames";
import { useTranslation } from "react-i18next";
import { FaGasPump, FaLightbulb, FaOilCan } from "react-icons/fa6";
import { MdAirlineSeatReclineExtra, MdElectricBolt, MdSpeed } from "react-icons/md";

const ACCENT = "#f3b354";
const WARN = "#ffc148";
const DANGER = "#ff4d5e";
const RPM_MAX = 8; // x1000, ruler 0..8
const REDLINE = 7; // last segment drawn red
// bikes / cycles / boats / helis / planes have no seatbelt
const NO_BELT_CLASSES = [8, 13, 14, 15, 16];

type Indicator = { key: string; icon: React.ReactNode; label: string; value: string; color: string; fill: number; dim?: boolean };

/** GTA VI style speedometer: digital speed + gear box, horizontal RPM ruler, status indicators. */
const Gta6 = ({ veh }: { veh: iVehicleInfo }) => {
  const { t } = useTranslation();
  const speed = Math.max(0, Math.round(veh.speed || 0));
  const digits = String(Math.min(speed, 999)).padStart(3, "0");
  const lead = 3 - String(Math.min(speed, 999)).length;
  const rpm = Math.max(0, Math.min(1, veh.rpm || 0));
  const fuel = Math.max(0, Math.min(100, Math.round(veh.fuel?.level ?? 0)));
  const electric = veh.fuel?.type == "electric";
  const engine = Math.max(0, Math.min(100, Math.round(veh.engineHealth ?? 100)));
  const hasBelt = !NO_BELT_CLASSES.includes(veh.veh_class);

  const onOff = (on: boolean) => t(on ? "state_on" : "state_off");
  const engineColor = engine > 60 ? ACCENT : engine > 30 ? WARN : DANGER;
  const indicators: Indicator[] = [
    {
      key: "fuel",
      icon: electric ? <MdElectricBolt /> : <FaGasPump />,
      label: t(electric ? "battery" : "fuel"),
      value: `${fuel}%`,
      color: fuel <= 20 ? DANGER : ACCENT,
      fill: fuel,
    },
    {
      key: "engine",
      icon: <FaOilCan />,
      label: t("engine"),
      value: t(engine > 60 ? "engine_ok" : engine > 30 ? "engine_warn" : "engine_bad"),
      color: engineColor,
      fill: engine,
    },
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
    {
      key: "lights",
      icon: <FaLightbulb />,
      label: t("lights"),
      value: onOff(!!veh.isLightOn),
      color: ACCENT,
      fill: veh.isLightOn ? 100 : 0,
      dim: !veh.isLightOn,
    },
  ];

  return (
    <div className="g6s">
      <div className="g6s-top">
        <div className="g6s-speed">
          <div className="g6s-digits">
            {digits.split("").map((d, i) => (
              <span key={i} className={classNames({ lead: i < lead })}>
                {d}
              </span>
            ))}
          </div>
          <div className="g6s-unit">{veh.kmH ? "KM/H" : "MPH"}</div>
        </div>
        <div className="g6s-gear">
          <div className="num">{veh.currentGear ?? "N"}</div>
          <div className="lbl">GEAR</div>
        </div>
      </div>

      <div className="g6s-rpm">
        <div className="g6s-rpm-label">RPM</div>
        <div className="g6s-rpm-body">
          <div className="g6s-rpm-track">
            <div className="fill" style={{ width: `${rpm * 100}%` }} />
            <div className="red" style={{ left: `${(REDLINE / RPM_MAX) * 100}%` }} />
            <div className="knob" style={{ left: `${rpm * 100}%` }} />
          </div>
          <div className="g6s-rpm-scale">
            {Array.from({ length: RPM_MAX + 1 }).map((_, i) => (
              <span key={i} className={classNames({ red: i >= REDLINE })} style={{ left: `${(i / RPM_MAX) * 100}%` }}>
                {i}
              </span>
            ))}
          </div>
        </div>
      </div>

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
    </div>
  );
};

export default Gta6;
