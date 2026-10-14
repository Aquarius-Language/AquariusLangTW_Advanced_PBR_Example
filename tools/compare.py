"""Compare actual captures with the reference renderer; requires NumPy and Pillow."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]
results={}
for name,reference in [('aquarius','reference'),('aquarius-lit','reference-lit'),('browser','reference'),('browser-lit','reference-lit')]:
    if not (root/(name+'.png')).exists():continue
    actual=np.asarray(Image.open(root/(name+'.png')))[:,:,:3].astype(float)
    expected=np.asarray(Image.open(root/(reference+'.png')))[:,:,:3].astype(float)
    difference=np.abs(actual-expected)
    results[name]={'meanAbsoluteChannelError':float(difference.mean()),'p99':float(np.quantile(difference,.99)),'fractionWithin5':float((difference<5).mean())}
    assert difference.mean()<1.0,(name,results[name])
(root/'image-comparison.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(json.dumps(results,indent=2))
