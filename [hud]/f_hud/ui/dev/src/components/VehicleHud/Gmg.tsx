import "./Gmg.scss";
import { iVehicleInfo } from "@/types/BasicTypes";
import classNames from "classnames";
import { FaCarSide, FaGasPump, FaLightbulb, FaOilCan } from "react-icons/fa6";
import { MdAirlineSeatReclineExtra, MdElectricBolt, MdSpeed } from "react-icons/md";

// bikes / cycles / boats / helis / planes have no seatbelt
const NO_BELT_CLASSES = [8, 13, 14, 15, 16];

/**
 * "GMG" vehicle style (vehicle_hud_style 6), replaced by a line design: framed engine icon, big speed with an
 * RPM underline, gear box + unit, vertical fuel gauge, and door / belt / light telltales underneath.
 */
const Gmg = ({ veh }: { veh: iVehicleInfo }) => {
  const speed = Math.max(0, Math.round(veh.speed || 0));
  const rpm = Math.max(0, Math.min(1, veh.rpm || 0));
  const fuel = Math.max(0, Math.min(100, Math.round(veh.fuel?.level ?? 0)));
  const engine = Math.max(0, Math.min(100, Math.round(veh.engineHealth ?? 100)));
  const electric = veh.fuel?.type == "electric";
  const hasBelt = !NO_BELT_CLASSES.includes(veh.veh_class);
  const doorOpen = !!(veh.isFrontLeftDoorOn || veh.isFrontRightDoorOn || veh.isBackLeftDoorOn || veh.isBackRightDoorOn || veh.isTrunkOn || veh.isHoodOn);

  return (
    <div className="gmg2">
      <div className="gmg2-line" />
      <div className={classNames("gmg2-cruise", { on: veh.isCruiseOn })}>
        <MdSpeed />
      </div>

      <div className="gmg2-main">
        <div className={classNames("gmg2-engine", { warn: engine <= 60, bad: engine <= 30 })}>
          <FaOilCan />
        </div>

        <div className="gmg2-speed">
          <div className="num">{speed}</div>
          <div className="rpm">
            <div style={{ width: `${rpm * 100}%` }} />
          </div>
        </div>

        <div className="gmg2-gear">
          <div className="box">{veh.currentGear ?? "N"}</div>
          <div className="unit">{veh.kmH ? "KM/H" : "MPH"}</div>
        </div>

        <div className={classNames("gmg2-fuel", { low: fuel <= 20 })}>
          <span className="f">F</span>
          <div className="bar">
            <div style={{ height: `${fuel}%` }} />
          </div>
          <span className="e">E</span>
          <div className="pump">{electric ? <MdElectricBolt /> : <FaGasPump />}</div>
        </div>
      </div>

      <div className="gmg2-tells">
        <div className={classNames("tell", { on: doorOpen })}>
          <FaCarSide />
        </div>
        {hasBelt && (
          <div className={classNames("tell", { off: !veh.isSeatbeltOn, on: veh.isSeatbeltOn })}>
            <MdAirlineSeatReclineExtra />
          </div>
        )}
        <div className={classNames("tell", { on: veh.isLightOn })}>
          <FaLightbulb />
        </div>
      </div>
    </div>
  );
};

export default Gmg;
