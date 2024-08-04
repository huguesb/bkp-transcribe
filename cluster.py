#! python3

import os
import subprocess
import sys

from typing import List


def preprocess_dji(names: List[str]) -> List[str]:
  cl = {}
  rest = []
  for n in names:
    d = os.path.dirname(n)
    b = os.path.basename(n)
    if b.startswith('DJI_'):
      if b.endswith('_preproc.wav'):
        continue
      i = b.find('_', 4)
      if i != -1:
        pref = os.path.join(d, b[:i])
        if pref not in cl:
          cl[pref] = []
        cl[pref].append(n)
        continue
    rest.append(n)
  
  for k, l in cl.items():
    l = sorted(l)
    m = k + "_preproc.wav"
    print(f"preprocessing: {l} into {m}", file=sys.stderr)
    if os.path.exists(m):
      os.remove(m)

    # TODO: popen for parallelism?
    p = subprocess.run(
      ['ffmpeg', '-y'] + [
        y for x in (('-i', f) for f in l) for y in x
      ] + [
        "-filter_complex",
        f"{''.join([f'[{n}:0]' for n in range(len(l))])}concat=n={len(l)}:v=0:a=1[out]",
        "-map", "[out]",
        "-ar", "16000",
        "-ac", "1",
        "-c:a", "pcm_s16le",
        m
      ],
      stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT,
    )
    sys.stderr.write(p.stdout.decode('utf-8'))
    p.check_returncode()
    rest.append(m)

  return rest


if __name__ == "__main__":
  print('\n'.join(preprocess_dji((sys.argv))))

