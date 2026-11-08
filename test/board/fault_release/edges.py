# OUT0 (D4) and OUT2 (D6) in fault.sr: OUT0 must be high, then fall once and stay low;
# OUT2 must keep toggling after that fall.
import sys
import numpy as np
sys.path.insert(0, "demo")
import sigrok
rate, _, raw = sigrok.read(sys.argv[1])
s = np.frombuffer(raw, dtype=np.uint8)
d4, d6 = (s >> 4) & 1, (s >> 6) & 1
e4 = np.flatnonzero(np.diff(d4)) + 1
e6 = np.flatnonzero(np.diff(d6)) + 1
print("rate %d Hz, %.3f s" % (rate, len(s) / rate))
print("OUT0 edges %d at %s us" % (len(e4), [round(i / rate * 1e6, 3) for i in e4[:6]]))
rises = [i for i in e4 if d4[i]]
falls = [i for i in e4 if not d4[i]]
ok = len(rises) == 1 and len(falls) == 1 and falls[0] > rises[0] and not d4[-1]
if falls:
    after = e6[e6 > falls[0]]
    print("OUT2 edges %d in all, %d after OUT0's fall, last at %.3f us" % (
        len(e6), len(after), (after[-1] if len(after) else 0) / rate * 1e6))
    ok = ok and len(after) > 1000
print("PASS" if ok else "FAIL")
