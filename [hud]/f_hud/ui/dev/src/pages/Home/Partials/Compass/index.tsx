import useData from "@/hooks/useData";
import { useRef } from "react";
import "./index.scss";

const PX = 4; // pixels per degree
const SPAN = 70; // degrees rendered each side of the needle
const CARDINALS: Record<number, string> = { 0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW" };

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

  const ticks = [];
  for (let d = Math.floor((u - SPAN) / 5) * 5; d <= u + SPAN; d += 5) {
    const a = ((d % 360) + 360) % 360;
    const major = a % 15 === 0;
    ticks.push(<div key={"t" + d} className={major ? "tk maj" : "tk"} style={{ left: d * PX }} />);
    if (major) {
      const c = CARDINALS[a];
      ticks.push(
        <div key={"l" + d} className={c && c.length === 1 ? "lb card" : "lb"} style={{ left: d * PX }}>
          {c || a}
        </div>
      );
    }
  }

  return (
    <div id="compass" className="absolute top-0 left-1/2 -translate-x-1/2 select-none flex flex-col items-center gl-compass-wrap">
      <div className="gl gl-compass">
        <div className="win">
          <div className="tape" style={{ transform: `translateX(${-u * PX}px)` }}>
            {ticks}
          </div>
        </div>
        <div className="needle" />
        <div className="notch" />
      </div>
      {(Compass.street1 || Compass.street2) && (
        <div className="gl gl-round gl-compass-street">
          <span>{Compass.street1}</span>
          {Compass.street2 && <span className="sep" />}
          {Compass.street2 && <span className="s2">{Compass.street2}</span>}
        </div>
      )}
    </div>
  );
};
