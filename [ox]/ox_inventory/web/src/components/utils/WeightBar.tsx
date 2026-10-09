import React, { useMemo } from 'react';

const colorChannelMixer = (colorChannelA: number, colorChannelB: number, amountToMix: number) => {
  let channelA = colorChannelA * amountToMix;
  let channelB = colorChannelB * (1 - amountToMix);
  return channelA + channelB;
};

const colorMixer = (rgbA: number[], rgbB: number[], amountToMix: number) => {
  let r = colorChannelMixer(rgbA[0], rgbB[0], amountToMix);
  let g = colorChannelMixer(rgbA[1], rgbB[1], amountToMix);
  let b = colorChannelMixer(rgbA[2], rgbB[2], amountToMix);
  return `rgb(${r}, ${g}, ${b})`;
};

const COLORS = {
  primaryColor: [217, 79, 69], // Low / critical
  secondColor: [243, 179, 84], // Healthy (accent)
  accentColor: [232, 118, 60], // Warning
};

/** Default number of ticks drawn in the segmented weight bar. */
const SEGMENTS = 26;

const SegmentedBar: React.FC<{ percent: number; segments: number }> = ({ percent, segments }) => {
  const filled = useMemo(
    () => Math.round((Math.min(Math.max(percent, 0), 100) / 100) * segments),
    [percent, segments]
  );
  const state = percent >= 95 ? 'is-critical' : percent >= 80 ? 'is-warning' : 'is-normal';

  return (
    <div className={`weight-bar-segmented ${state}`}>
      {Array.from({ length: segments }, (_, index) => (
        <span key={index} className={`weight-bar-segment${index < filled ? ' is-filled' : ''}`} />
      ))}
    </div>
  );
};

const WeightBar: React.FC<{ percent: number; durability?: boolean; segmented?: boolean; segments?: number }> = ({
  percent,
  durability,
  segmented,
  segments = SEGMENTS,
}) => {
  const color = useMemo(
    () =>
      durability
        ? percent < 50
          ? colorMixer(COLORS.accentColor, COLORS.primaryColor, percent / 100)
          : colorMixer(COLORS.secondColor, COLORS.accentColor, percent / 100)
        : percent > 50
          ? colorMixer(COLORS.primaryColor, COLORS.accentColor, percent / 100)
          : colorMixer(COLORS.accentColor, COLORS.secondColor, percent / 50),
    [durability, percent]
  );

  if (segmented) return <SegmentedBar percent={percent} segments={segments} />;

  return (
    <div className={durability ? 'durability-bar' : 'weight-bar'}>
      <div
        style={{
          visibility: percent > 0 ? 'visible' : 'hidden',
          height: '100%',
          width: `${percent}%`,
          backgroundColor: color,
          transition: `background ${0.3}s ease, width ${0.3}s ease`,
        }}
      ></div>
    </div>
  );
};
export default WeightBar;
