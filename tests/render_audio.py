"""Render original extracted synth recipes as reusable 44.1 kHz PCM resources."""
import json, math, random, struct, wave
from pathlib import Path
RATE = 44100
ROOT = Path(__file__).resolve().parent.parent

def filtered(samples, frequency, kind, q):
    if frequency <= 0:
        return samples
    omega = 2 * math.pi * min(frequency, RATE * .45) / RATE
    c, s = math.cos(omega), math.sin(omega)
    alpha = s / (2*q)
    if kind == 'highpass':
        b = [(1+c)/2, -(1+c), (1+c)/2]
    elif kind == 'bandpass':
        b = [alpha, 0, -alpha]
    else:
        b = [(1-c)/2, 1-c, (1-c)/2]
    a0, a1, a2 = 1+alpha, -2*c, 1-alpha
    b = [v/a0 for v in b]
    a1, a2 = a1/a0, a2/a0
    x1=x2=y1=y2=0
    result=[]
    for x in samples:
        y=b[0]*x+b[1]*x1+b[2]*x2-a1*y1-a2*y2
        result.append(y)
        x2,x1,y2,y1=x1,x,y1,y
    return result

def render(parts, seed):
    rng=random.Random(seed)
    length=math.ceil((max(p['delay']+p['duration'] for p in parts)+.02)*RATE)
    result=[0.0]*length
    for part in parts:
        duration=part['duration']; n=math.ceil(duration*RATE)
        gain=part['gain']; attack=min(.012 if part['kind']=='tone' else .008,duration*(.22 if part['kind']=='tone' else .15))
        samples=[]; phase=0; prev=0
        first=max(30,part['frequency']*(1+rng.uniform(-.012,.012)))
        last=max(30,part['frequency']+part.get('slide',0))
        for i in range(n):
            t=i/RATE
            if part['kind']=='noise':
                prev=prev*.74+rng.uniform(-1,1)*.26
                value=prev
            else:
                frequency=first*((last/first)**(t/duration))
                phase=(phase+frequency/RATE)%1
                kind=part['type']
                value=math.sin(phase*math.tau) if kind=='sine' else 1-4*abs(phase-.5) if kind=='triangle' else 1 if kind=='square' and phase<.5 else -1 if kind=='square' else 2*phase-1
            samples.append(value)
        frequency=part.get('filter',0) if part['kind']=='tone' else part['frequency']*(1+rng.uniform(-.1,.1))
        samples=filtered(samples,frequency,'lowpass' if part['kind']=='tone' else part['type'],.8 if part['kind']=='tone' else .7)
        offset=round(part['delay']*RATE)
        for i,value in enumerate(samples):
            t=i/RATE
            envelope=.0001+(gain-.0001)*t/attack if t<attack else gain*((.0001/gain)**((t-attack)/(duration-attack)))
            result[offset+i]+=value*envelope
    return result

catalog=json.loads((ROOT/'data/audio_recipes.json').read_text())
for index,(name,parts) in enumerate(catalog['recipes'].items()):
    samples=render(parts,72841+index)
    with wave.open(str(ROOT/'assets/audio'/f'{name}.wav'),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h',round(max(-1,min(1,x))*32767)) for x in samples))
print(f"Rendered {len(catalog['recipes'])} original recipes")
