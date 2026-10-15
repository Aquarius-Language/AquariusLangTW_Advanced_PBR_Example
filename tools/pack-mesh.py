"""Create the runtime AQM1 mesh from the bake output (standard library only)."""
import argparse
import json
import math
import struct
from pathlib import Path


def pack_mesh(vertices):
    if not vertices or len(vertices) % 3 or len(vertices) > 1_000_000:
        raise ValueError('Expected a triangle list with at most one million vertices')
    result = bytearray(struct.pack('<4sIII', b'AQM1', len(vertices), 8, 0))
    for vertex in vertices:
        if len(vertex) != 8 or not all(math.isfinite(v) for v in vertex):
            raise ValueError('Expected eight finite position/normal/UV components')
        result.extend(struct.pack('<8f', *vertex))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, nargs='?', default=Path(__file__).resolve().parents[1] / 'assets/baked/mesh.json')
    parser.add_argument('output', type=Path, nargs='?')
    args = parser.parse_args()
    output = args.output or args.source.with_suffix('.aqmesh')
    output.write_bytes(pack_mesh(json.loads(args.source.read_text(encoding='utf-8'))))
    print(f'{output}: {output.stat().st_size:,} bytes')
