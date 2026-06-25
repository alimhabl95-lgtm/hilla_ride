import math
import os
import shutil
import struct
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..")


def write_tone(path: str, duration_sec: float, freq: float = 880, volume: float = 0.4) -> None:
    sample_rate = 44100
    n_samples = int(sample_rate * duration_sec)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        frames = bytearray()
        for i in range(n_samples):
            t = i / sample_rate
            env = 1.0
            if t < 0.02:
                env = t / 0.02
            elif t > duration_sec - 0.02:
                env = max(0.0, (duration_sec - t) / 0.02)
            pulse = 0.5 * (1 + math.sin(2 * math.pi * 3 * t))
            val = int(32767 * volume * env * pulse * math.sin(2 * math.pi * freq * t))
            frames.extend(struct.pack("<h", val))
        handle.writeframes(frames)


def main() -> None:
    assets = os.path.join(ROOT, "assets", "sounds")
    driver_asset = os.path.join(assets, "driver_ride_request.wav")
    customer_asset = os.path.join(assets, "customer_ride_accepted.wav")
    write_tone(driver_asset, 4.0, freq=920, volume=0.45)
    write_tone(customer_asset, 2.0, freq=740, volume=0.4)
    chat_asset = os.path.join(assets, "chat_message.wav")
    write_tone(chat_asset, 1.5, freq=660, volume=0.35)

    raw_dir = os.path.join(ROOT, "android", "app", "src", "main", "res", "raw")
    os.makedirs(raw_dir, exist_ok=True)
    shutil.copy2(driver_asset, os.path.join(raw_dir, "driver_ride_request.wav"))
    shutil.copy2(customer_asset, os.path.join(raw_dir, "customer_ride_accepted.wav"))
    shutil.copy2(chat_asset, os.path.join(raw_dir, "chat_message.wav"))

    ios_runner = os.path.join(ROOT, "ios", "Runner")
    shutil.copy2(driver_asset, os.path.join(ios_runner, "driver_ride_request.wav"))
    shutil.copy2(customer_asset, os.path.join(ios_runner, "customer_ride_accepted.wav"))
    print("Generated and copied alert sound files")


if __name__ == "__main__":
    main()
