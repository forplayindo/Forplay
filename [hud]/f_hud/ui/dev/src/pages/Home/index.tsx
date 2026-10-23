import "./index.scss";
import { useState } from "react";
import { ClientInfo as ClientInfoC } from "./Partials/ClientInfo";
import { Compass as CompassC } from "./Partials/Compass";
import { NavigationWidget as NavigationWidgetC } from "./Partials/NavigationWidget";
import { BarsComponent, MapTopStack, STATUS_BOTTOM } from "./Partials/Bars";
import { Gta6Hud, Gta6MapState } from "./Partials/Gta6";
import useData from "@/hooks/useData";
import { useNuiEvent } from "@/hooks/useNuiEvent";
import { MoiveBars } from "./Partials/MoiveBars";
import { VehicleHud } from "./Partials/VehicleHud";

export const Home: React.FC = () => {
  const { Cinematic } = useData();
  // GTA VI minimap overlay (modules/minimap): waypoint distance on the map
  const [gta6Map, setGta6Map] = useState<Gta6MapState | null>(null);
  useNuiEvent<Gta6MapState>("ui:setGta6Map", setGta6Map);
  const [statusHeight, setStatusHeight] = useState(0);

  // status bars + navigation widget line up with the minimap's left edge; the widget sits 6px above the map,
  // or right above the status bars while the radar is hidden (e.g. on foot with "minimap only in vehicle")
  const mapAnchor = gta6Map
    ? {
        left: `${gta6Map.rect.left * 100}vw`,
        bottom: gta6Map.radar ? `calc(${(1 - gta6Map.rect.top) * 100}vh + 6px)` : `${STATUS_BOTTOM + statusHeight + 8}px`,
        width: `${gta6Map.rect.width * 100}vw`,
      }
    : undefined;

  return (
    <>
      {!Cinematic.show ? (
        <>
          <ClientInfoC />
          <CompassC />
          {/* hygiene row + location card: stacked above the minimap, or as the top rows of the status block (above armor) when the radar is hidden */}
          <BarsComponent anchorLeft={mapAnchor?.left} anchorWidth={mapAnchor?.width} onHeight={setStatusHeight} stackInline={!gta6Map?.radar} />
          {gta6Map?.radar && <MapTopStack left={mapAnchor?.left ?? 16} width={mapAnchor?.width} bottom={`${(1 - gta6Map.rect.top) * 100}vh`} />}
          {gta6Map && <Gta6Hud map={gta6Map} />}
          <VehicleHud />
        </>
      ) : (
        <MoiveBars />
      )}
      <NavigationWidgetC anchor={mapAnchor} />
    </>
  );
};
