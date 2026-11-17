#!/bin/bash
STREAM_KEY="${1:-p87m-e4ff-4cv7-xmrs-2epm}"

# 1. Kill any leftover background FFmpeg processes
pkill -9 -f "rtmp.youtube.com" 2>/dev/null

# 2. Ensure Display :99 is running
if ! pgrep -x "Xvfb" > /dev/null; then
  Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &
  sleep 1
fi
export DISPLAY=:99

# 3. Ensure x11vnc stays running so noVNC stays connected
pgrep -x "x11vnc" > /dev/null || x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -noxdamage -wait 50 -defer 50 -bg -quiet

# 4. Start PulseAudio and ensure VirtualSpeaker is active and unmuted
pulseaudio --start --exit-idle-time=-1 2>/dev/null || pulseaudio -D --exit-idle-time=-1
if ! pactl list short sinks | grep -q "VirtualSpeaker"; then
  pactl load-module module-null-sink sink_name=VirtualSpeaker > /dev/null
fi
pactl set-default-sink VirtualSpeaker
pactl set-sink-mute VirtualSpeaker 0
pactl set-sink-volume VirtualSpeaker 100%

# 5. Route active Chrome/Zoom audio into VirtualSpeaker
for id in $(pactl list short sink-inputs | awk '{print $1}'); do
  pactl move-sink-input "$id" VirtualSpeaker 2>/dev/null
done

# 6. Continuous FIFO Stream with 600-Packet Buffer
while true; do
  echo "🚀 Continuous FIFO Streaming to YouTube [Key: $STREAM_KEY] (Press Ctrl+C to stop)..."
  ffmpeg -loglevel warning -stats \
    -thread_queue_size 4096 -probesize 10M -analyzeduration 2M \
    -f x11grab -draw_mouse 0 -framerate 12 -video_size 1280x720 -i :99.0+0,0 \
    -thread_queue_size 4096 -f pulse -ac 2 -i VirtualSpeaker.monitor \
    -map 0:v -map 1:a \
    -c:v libx264 -preset ultrafast -tune zerolatency -threads 0 \
    -x264-params "ref=1:subme=0:me=dia:trellis=0:rc-lookahead=0:sync-lookahead=0" \
    -b:v 900k -maxrate 900k -bufsize 2700k -pix_fmt yuv420p -g 24 -bf 0 -fps_mode cfr \
    -af "aresample=async=1:first_pts=0" -c:a aac -b:a 128k -ar 44100 \
    -flags +global_header \
    -f fifo -fifo_format flv -queue_size 600 \
    -drop_pkts_on_overflow 1 -attempt_recovery 1 -recovery_wait_time 1 -recover_any_error 1 \
    -format_opts flvflags=no_duration_filesize:rw_timeout=5000000 \
    "rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

  echo "⚠️ Process exited. Restarting in 2 seconds..."
  sleep 2
done
