import "./index.scss";
import classNames from "classnames";

export interface Gta6MapState {
  rect: { left: number; top: number; width: number; height: number };
  radar: boolean;
  night: number;
  nightOpacity: number;
  distance?: string;
  radius: number;
  frame: boolean;
  statusGap: number;
  coverRight?: number;
  debug?: boolean;
}

/** Frame, night tint and waypoint distance drawn on top of the game radar. */
const MapOverlay = ({ map }: { map: Gta6MapState }) => {
  const { rect, radius } = map;
  const cover = map.coverRight || 0;
  if (!map.radar && !map.debug) return null;
  const top = `${rect.top * 100}vh`;
  const height = `${rect.height * 100}vh`;
  // with a cover panel the frame's right side is square and the panel carries the rounded corners
  const frameRadius = cover > 0 ? `${radius}px 0 0 ${radius}px` : radius;
  return (
    <>
      <div
        className={classNames("g6-map", { frame: map.frame, cover: cover > 0, debug: map.debug })}
        style={{ left: `${rect.left * 100}vw`, top, width: `${rect.width * 100}vw`, height, borderRadius: frameRadius }}
      >
        <div className="g6-night" style={{ opacity: map.night * map.nightOpacity, borderRadius: frameRadius }} />
        {map.distance && <div className="g6-distance">{map.distance}</div>}
      </div>
      {cover > 0 && (
        <div
          className={classNames("g6-cover", { frame: map.frame })}
          style={{ left: `${(rect.left + rect.width) * 100}vw`, top, width: cover, height, borderRadius: `0 ${radius}px ${radius}px 0` }}
        />
      )}
    </>
  );
};

/** Status bars are f_hud's own BarsComponent (configurable in the HUD settings); only the map overlay lives here. */
export const Gta6Hud = ({ map }: { map: Gta6MapState }) => <MapOverlay map={map} />;
