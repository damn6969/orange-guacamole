#!/bin/bash
INPUT_URL="$1"

if [ -z "$INPUT_URL" ]; then
  echo "❌ Usage: bash go.sh \"YOUR_ZOOM_LINK\""
  exit 1
fi

pkill -f "rtmp.youtube.com" 2>/dev/null
sudo mount -o remount,size=4G /dev/shm 2>/dev/null

pulseaudio --start --exit-idle-time=-1 2>/dev/null || pulseaudio -D --exit-idle-time=-1
pactl list short sinks | grep -q "VirtualSpeaker" || pactl load-module module-null-sink sink_name=VirtualSpeaker > /dev/null
pactl set-default-sink VirtualSpeaker
pactl set-sink-mute VirtualSpeaker 0
pactl set-sink-volume VirtualSpeaker 100%

pgrep -x "Xvfb" > /dev/null || (Xvfb :99 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 & sleep 1)
export DISPLAY=:99
export PULSE_SINK=VirtualSpeaker

xset s off -dpms 2>/dev/null
xset s noblank 2>/dev/null

pgrep -x "openbox" > /dev/null || (openbox > /dev/null 2>&1 & sleep 1)
pgrep -x "x11vnc" > /dev/null || x11vnc -display :99 -forever -shared -nopw -rfbport 5900 -noxdamage -wait 50 -defer 50 -bg -quiet
pgrep -f "websockify" > /dev/null || (/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5900 > /dev/null 2>&1 &)

WEB_URL=$(echo "$INPUT_URL" | sed -e 's|/j/|/wc/join/|g' -e 's|#success||g')
pkill -f google-chrome 2>/dev/null
rm -rf ~/.config/google-chrome/Singleton*
sleep 1

google-chrome --no-sandbox --disable-gpu --no-first-run --start-maximized --window-size=1280,720 \
  --alsa-output-device=pulse \
  --autoplay-policy=no-user-gesture-required \
  --use-fake-ui-for-media-stream \
  --use-fake-device-for-media-stream \
  "$WEB_URL" > /dev/null 2>&1 &

echo "✅ Open VNC: https://${CODESPACE_NAME}-6080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/vnc.html?autoconnect=true&resize=scale"
echo "✅ Once inside the meeting, run: bash stream.sh"
