import classNames from "classnames";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import useData from "@/hooks/useData";
import { BarType } from "@/types/BasicTypes";
import Icon from "@/components/Icon";

const Bars: BarType[] = ["health", "armor", "hunger", "thirst", "stamina", "oxygen", "stress", "voice", "vehicle_engine", "vehicle_nitro", "mandi", "kencing", "poop"];

const Bucket = () => {
  const { t } = useTranslation();
  const { onChangeBar, BarsInfo, setBarsInfo, useableColors } = useData();

  const BarColors = useableColors;

  const [activeBar, setActiveBar] = useState<BarType | undefined>("health");

  const handleChangeActiveBar = (bar: BarType) => {
    if (activeBar == bar) {
      setActiveBar(undefined);
    } else setActiveBar(bar);
  };

  const updateActiveBarColor = (newColor: string) => {
    if (!activeBar) return;
    if (BarsInfo[activeBar]?.color == newColor) return;
    const updatedBar = {
      ...BarsInfo[activeBar],
      color: newColor,
    };
    setBarsInfo((prevBarsInfo) => ({
      ...prevBarsInfo,
      [activeBar]: updatedBar,
    }));
    onChangeBar(activeBar, updatedBar);
  };

  const updateActiveBarAutoHide = (value: string) => {
    if (!activeBar) return;
    const newValue = Math.max(0, Math.min(100, parseInt(value, 10)));
    if (isNaN(newValue) || BarsInfo[activeBar]?.autoHide === newValue) return;
    const updatedBar = {
      ...BarsInfo[activeBar],
      autoHide: newValue,
    };
    setBarsInfo((prevBarsInfo) => ({
      ...prevBarsInfo,
      [activeBar]: updatedBar,
    }));
    onChangeBar(activeBar, updatedBar);
  };

  return (
    <div className="p-2.5 flex flex-col flex-1 justify-between">
      <div
        className={classNames("transition-[opacity,max-height] duration-300", {
          "flex flex-col flex-1 max-h-96": activeBar,
          "max-h-0 opacity-0 overflow-hidden": !activeBar,
        })}
      >
        <div className="mx-auto p-2.5 rounded-l bg-black/40 w-full">
          <div className="w-full grid grid-cols-10 gap-[4.25px] justify-center">
            {[...Array(20)].map((_, i) => (
              <button key={i} onClick={() => updateActiveBarColor(BarColors[i])} className="w-[23.389px] h-[23.389px] rounded border-2 border-white/10 hover:brightness-110" style={{ backgroundColor: BarColors[i] }}></button>
            ))}
          </div>
        </div>
        <div className="mt-2 w-full flex justify-between">
          <div
            className="w-full rounded flex p-1 gap-2 items-center"
            style={{
              background: "linear-gradient(90deg, rgba(0, 0, 0, 0.45) 0%, rgba(0, 0, 0, 0.00) 100%)",
            }}
          >
            <input type="number" onChange={(e) => updateActiveBarAutoHide(e.currentTarget.value)} value={activeBar && BarsInfo[activeBar] ? BarsInfo[activeBar].autoHide ?? 100 : 100} className={classNames("w-[45px] h-[28px]", "rounded bg-white/[0.08]", "outline-none ring-0", "text-center text-white/35 font-bold text-sm 4k:text-base")} />
            <div className="whitespace-nowrap max-w-24 overflow-hidden">
              <h1 className="text-white font-sentic-text-bold font-bold text-11 2k:text-sm">{t("auto_hide")}</h1>
              <h1 className="text-9 2k:text-xs font-bold text-white/25">{t("desc_autohide")}</h1>
            </div>
          </div>
        </div>
      </div>
      <div className="mt-4 grid grid-cols-5 gap-2 items-center">
        {Bars.map((_bar) => (
          <div key={_bar} className="flex flex-col items-center">
            <button
              onClick={() => handleChangeActiveBar(_bar)}
              className={classNames("w-11 h-11 rounded-md flex items-center justify-center border-2 bg-black/40 transition-colors", activeBar == _bar ? "border-white/70" : "border-white/10")}
            >
              <Icon iconReq={`${_bar}.1`} color={BarsInfo[_bar]?.color || "#ffffff"} size="20px" />
            </button>
            <div className="mt-1.5 w-9 h-1 rounded-full" style={{ backgroundColor: BarsInfo[_bar]?.color || "#ffffff" }} />
            <h1 className="mt-1 text-white text-9 font-bold 2k:text-11 tracking-wider">{t(_bar)}</h1>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Bucket;
