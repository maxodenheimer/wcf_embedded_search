import { IconPlayerPauseFilled, IconPlayerPlayFilled, IconPlayerSkipBackFilled, IconPlayerSkipForwardFilled } from "@tabler/icons-react";
import { ChangeEvent, FC, useEffect, useRef, useState } from "react";

interface VideoPlayerProps {
  src: string;
  startTime: number;
  width?: string; // Optional video width
  height?: string; // Optional video height
}

export const Player: FC<VideoPlayerProps> = ({ src, startTime, width = '640px', height = '360px' }) => {
  const videoRef = useRef<HTMLVideoElement>(null);

  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(startTime);
  const [duration, setDuration] = useState(0);

  const handlePlay = () => {
    if (!videoRef.current) return;
    setIsPlaying(true);
    videoRef.current.play();
  };

  const handlePause = () => {
    if (!videoRef.current) return;
    setIsPlaying(false);
    videoRef.current.pause();
  };

  const handleTimeUpdate = () => {
    if (!videoRef.current) return;
    setCurrentTime(videoRef.current.currentTime);
    setDuration(videoRef.current.duration);
  };

  const handleSliderChange = (event: ChangeEvent<HTMLInputElement>) => {
    if (!videoRef.current) return;
    videoRef.current.currentTime = +event.target.value;
  };

  const handleSkipBackward = () => {
    if (!videoRef.current) return;
    videoRef.current.currentTime -= 15;
  };

  const handleSkipForward = () => {
    if (!videoRef.current) return;
    videoRef.current.currentTime += 15;
  };

  const formatTime = (time: number) => {
    const minutes = Math.floor(time / 60);
    const seconds = Math.floor(time % 60)
      .toString()
      .padStart(2, "0");
    return `${minutes}:${seconds}`;
  };

  useEffect(() => {
    if (!videoRef.current) return;
    console.log(currentTime);
    videoRef.current.currentTime = currentTime;
    setDuration(videoRef.current.duration);
  }, []);

  return (
    <div className="p-4">
      <video
        ref={videoRef}
        src={src}
        width={width}
        height={height}
        onPlay={handlePlay}
        onPause={handlePause}
        onTimeUpdate={handleTimeUpdate}
        controls // You can remove this if you want custom controls only
      />

      <div className="flex flex-col items-center">
        <div className="mb-4">
          <span>{formatTime(currentTime)}</span>
          <span className="mx-2">/</span>
          <span>215:35</span>
        </div>

        <div
          className="w-full mb-4"
          style={{ display: "flex", alignItems: "center" }}
        >
          <input
            type="range"
            value={currentTime}
            min="0"
            max={`${duration}`}
            step="15"
            onChange={handleSliderChange}
            style={{ flexGrow: 1 }}
          />
        </div>

        <div className="flex align-middle">
          <button
            className="p-2 rounded-full bg-blue-500 text-white mr-3 hover:bg-blue-600"
            onClick={handleSkipBackward}
          >
            <div className="flex items-center">
              <IconPlayerSkipBackFilled size={14} />
              <div className="ml-1 text-sm">15s</div>
            </div>
          </button>

          <button
            className="p-2 rounded-full bg-blue-500 text-white mr-3 hover:bg-blue-600 ml-4"
            onClick={isPlaying ? handlePause : handlePlay}
          >
            {isPlaying ? <IconPlayerPauseFilled size={36} /> : <IconPlayerPlayFilled size={36} />}
          </button>

          <button
            className="ml-4 p-2 rounded-full bg-blue-500 text-white hover:bg-blue-600"
            onClick={handleSkipForward}
          >
            <div className="flex items-center">
              <div className="mr-1 text-sm">15s</div>
              <IconPlayerSkipForwardFilled size={14} />
            </div>
          </button>
        </div>
      </div>
    </div>
  );
};
