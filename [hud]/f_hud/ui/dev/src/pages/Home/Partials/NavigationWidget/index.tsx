import useData from "@/hooks/useData";
import { Settings } from "@/pages/Settings";
import { useState } from "react";
import { DragDropContainer } from "react-drag-drop-container-typescript";
import { FaLocationCrosshairs } from "react-icons/fa6";

/** @param anchor default placement (CSS left/bottom/width) right above the GTA VI minimap, when the player hasn't dragged it */
export const NavigationWidget = ({ anchor }: { anchor?: { left: string; bottom: string; width: string } }) => {
  const { NavigationWidget, MiniMap, HudStyle, VehicleInfo, onChangeHudPositions, isSettingsOpen, isEditorOpen } = useData();

  let widgetBottomStyle = 300;
  if (MiniMap.onlyInVehicle && !VehicleInfo.entity) {
    if (HudStyle.is_res_style_active) {
      widgetBottomStyle = 100;
    } else {
      if (HudStyle.bar_style == "universal") {
        widgetBottomStyle = 105;
      } else if (HudStyle.bar_style != "zarg-m") {
        widgetBottomStyle = 80;
      }
    }
  } else {
    if (!HudStyle.is_res_style_active) {
      if (HudStyle.bar_style == "zarg-m") {
        widgetBottomStyle = 310;
      }
    }
  }

  const { positions } = NavigationWidget;

  const posStyle = {} as any;
  if (positions.x) {
    posStyle.left = positions.x;
  } else {
    posStyle.left = anchor?.left ?? 16;
  }
  if (anchor) posStyle.width = anchor.width;
  if (positions.y) {
    posStyle.top = positions.y;
    if (!isSettingsOpen) {
      posStyle.top += 324;
    }
  } else {
    posStyle.bottom = anchor?.bottom ?? widgetBottomStyle;
  }

  const handleDragEnd = (key: string, x: number, y: number) => {
    onChangeHudPositions(key, x, y);
  };

  const [isDragActive, setDragActive] = useState<boolean>(false);

  const handleMouseDown = () => {
    setTimeout(() => {
      setDragActive(true);
    }, 200);
  };

  const handleMouseUp = () => {
    setTimeout(() => {
      setDragActive(false);
    }, 200);
  };

  return (
    <>
      <div id="navigation-widget" className="absolute select-none w-80" style={posStyle}>
        <DragDropContainer
          noDragging={!isDragActive}
          dragElemOpacity={0.75}
          onDragEnd={(_, __, x, y) => {
            setDragActive(false);
            handleDragEnd("navigation_widget", x, y);
          }}
        >
          <div className="2k:!mb-14 flex flex-col items-center gap-1">
            {isSettingsOpen && (
              <>
                {isEditorOpen && (
                  <button className="absolute -left-5 -top-6 z-10 p-2 rounded-full border border-white/15 bg-white/15" onMouseDown={handleMouseDown} onMouseUp={handleMouseUp}>
                    <FaLocationCrosshairs />
                  </button>
                )}
                <Settings />
              </>
            )}
            {/* location card moved to the top-right stack (ClientInfo), under Bank */}
          </div>
        </DragDropContainer>
      </div>
    </>
  );
};
