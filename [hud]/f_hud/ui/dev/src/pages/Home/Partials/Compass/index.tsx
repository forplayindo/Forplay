import useData from "@/hooks/useData";
import { useRef } from "react";
import "./index.scss";

const PX = 3.7; // pixels per degree
const SPAN = 75; // degrees rendered each side of the pointer
const CARDINALS: Record<number, string> = { 0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW" };

/** GTA VI style compass: heading readout, open tick ruler (no glass) and streets underneath. */
export const Compass = () => {
  const { Compass, VehicleInfo } = useData();
  // "unwrapped" heading so 359° -> 1° animates 2° instead of spinning back 358°
  const acc = useRef<number | null>(null);

  if (!(Compass.active && Compass.show && (!Compass.onlyInVehicle || !!VehicleInfo.entity))) return null;

  const h = Number(Compass.heading) || 0;
  if (acc.current === null) acc.current = h;
  else {
    const cur = ((acc.current % 360) + 360) % 360;
    acc.current += ((h - cur + 540) % 360) - 180;
  }
  const u = acc.current;
  const shown = Math.round(((h % 360) + 360) % 360) % 360;

  const marks = [];
  for (let d = Math.floor((u - SPAN) / 5) * 5; d <= u + SPAN; d += 5) {
    const a = ((d % 360) + 360) % 360;
    if (a % 15 === 0) {
      const c = CARDINALS[a];
      marks.push(
        <div key={d} className={c ? (c.length === 1 ? "lb card" : "lb inter") : "lb"} style={{ left: d * PX }}>
          {c || a}
        </div>
      );
    } else {
      marks.push(<div key={d} className="tk" style={{ left: d * PX }} />);
    }
  }

  return (
    <div id="compass" className="g6-compass select-none">
      <div className="heading">{shown}</div>
      <div className="pointer" />
      <div className="ruler">
        <div className="tape" style={{ transform: `translateX(${-u * PX}px)` }}>
          {marks}
        </div>
      </div>
      {(Compass.street1 || Compass.street2) && (
        <div className="streets">
          <span className="s1">{Compass.street1}</span>
          {Compass.street2 && <span className="sep">-</span>}
          {Compass.street2 && <span className="s2">{Compass.street2}</span>}
        </div>
      )}
    </div>
  );
};
