#!/bin/bash
sudo mount -o remount,size=4G /dev/shm
sudo apt-get update -qq
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get install -y -qq xvfb openbox pulseaudio pulseaudio-utils ffmpeg x11vnc novnc python3-websockify x11-xserver-utils ./google-chrome-stable_current_amd64.deb
rm -f google-chrome-stable_current_amd64.deb
chmod +x go.sh stream.sh 2>/dev/null
echo "✅ Setup complete!"
