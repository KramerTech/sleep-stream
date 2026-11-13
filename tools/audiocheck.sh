#!/bin/sh
# Print the box's audio/media signals once
adb -s "${BOX:-192.168.0.61:5555}" shell '
echo "focus: $(dumpsys window | grep mCurrentFocus | sed "s/.*u0 //;s/}//")"
echo "players started (media):"; dumpsys audio | grep -E "AudioPlaybackConfiguration" | grep "state:started" | grep -o -E "u/pid:[0-9/]+|usage=[A-Z_]+|content=[A-Z_]+" | paste - - - | sed "s/^/  /"
echo "flinger outputs:"; dumpsys media.audio_flinger | grep -E "^Output thread|Standby:|Tracks of thread|^  [0-9]+ Tracks|Track handle|  Active" | grep -E "Output thread|Standby|active|Active" | head -8 | sed "s/^/  /"
echo "media sessions:"; dumpsys media_session | grep -E "^ +package=|state=PlaybackState" | sed "s/PlaybackState {state=//;s/, position.*//" | paste - - | grep -v bluetooth | sed "s/^/  /"
'
