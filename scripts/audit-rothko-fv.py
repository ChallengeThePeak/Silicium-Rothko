#!/usr/bin/env python3
"""Verify real executable FFS membership, not just DSC/APRIORI references.

audit_firmware(bytes, efi_dir=None, extract_dir=None) returns a JSON-safe record.
The CLI returns 0 only when all mandatory modules are present and valid, 1 for
missing/unverified modules, and 2 for invalid containers or invocation errors.
Existing output directories are never reused. This tool performs no device I/O.
"""

import argparse
import hashlib
import json
import lzma
from pathlib import Path
import struct
import sys
import uuid


REQUIRED = {
    'd6a1f3c8-2b47-4e19-9f52-7c3a8d1b6e04': 'RothkoDisplayDxe',
    '79bce177-c3f4-4f57-aed9-c0b2bd5b9a31': 'RothkoWatchdogDxe',
}
APRIORI_DXE = 'fc510ee7-ffdc-11d4-bd41-0080c73c8881'
LZMA_GUID = 'ee4e5898-3914-4259-9d6e-dc7bd79403cf'
MAX_BYTES = 64 * 1024 * 1024
MAX_DECODED = 32 * 1024 * 1024


class FirmwareError(ValueError):
    pass


def require(value, message):
    if not value:
        raise FirmwareError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def u24(data, offset):
    return int.from_bytes(data[offset:offset + 3], 'little')


def guid(data):
    return str(uuid.UUID(bytes_le=data))


def padding(data):
    return not data or data == b'\xff' * len(data) or data == b'\0' * len(data)


def image_info(data):
    if data[:2] == b'VZ':
        require(len(data) >= 40, 'Truncated TE header')
        _, machine, count, _, stripped, entry, _, base = struct.unpack_from('<HHBBHIIQ', data)
        require(40 + count * 40 <= len(data), 'Truncated TE section table')
        return {'format': 'TE', 'machine': hex(machine), 'sections': count,
                'stripped_size': stripped, 'entry_rva': hex(entry), 'image_base': hex(base)}
    require(len(data) >= 64 and data[:2] == b'MZ', 'Executable section has no PE/TE header')
    pe = struct.unpack_from('<I', data, 60)[0]
    require(pe + 24 <= len(data) and data[pe:pe + 4] == b'PE\0\0', 'Invalid PE signature')
    machine, count = struct.unpack_from('<HH', data, pe + 4)
    opt_size = struct.unpack_from('<H', data, pe + 20)[0]
    opt = pe + 24
    require(opt_size >= 112 and opt + opt_size + count * 40 <= len(data), 'Truncated PE tables')
    require(struct.unpack_from('<H', data, opt)[0] == 0x20b, 'Expected PE32+ executable')
    for index in range(count):
        sec = opt + opt_size + index * 40
        raw_size, raw_offset = struct.unpack_from('<II', data, sec + 16)
        require(raw_offset <= len(data) and raw_size <= len(data) - raw_offset,
                'PE section extends beyond payload')
    return {'format': 'PE32+', 'machine': hex(machine), 'sections': count,
            'entry_rva': hex(struct.unpack_from('<I', data, opt + 16)[0]),
            'image_base': hex(struct.unpack_from('<Q', data, opt + 24)[0])}


class Walker:
    def __init__(self, extract_dir):
        self.extract_dir = extract_dir
        self.volumes = []
        self.files = []
        self.sections = []
        self.executables = []
        self.apriori = []
        self.opaque = []
        self.decoded_bytes = 0
        self.payloads = {}

    def save(self, name, data):
        if self.extract_dir is not None:
            with (self.extract_dir / name).open('xb') as stream:
                stream.write(data)

    def walk_fv(self, data, path, depth):
        require(depth < 12 and len(data) >= 56 and data[40:44] == b'_FVH', f'Invalid FV at {path}')
        length = struct.unpack_from('<Q', data, 32)[0]
        header_size = struct.unpack_from('<H', data, 48)[0]
        require(56 <= header_size <= length <= len(data) <= MAX_BYTES, 'FV length/header bounds')
        require(header_size % 2 == 0, 'Odd FV header length')
        checksum = sum(struct.unpack_from('<' + 'H' * (header_size // 2), data)) & 0xffff
        require(checksum == 0, f'FV header checksum mismatch at {path}')
        require(padding(data[length:]), 'Non-padding data follows declared FV length')
        attrs = struct.unpack_from('<I', data, 44)[0]
        volume = {'container': path, 'size': length, 'header_size': header_size,
                  'sha256': digest(data[:length]), 'header_checksum_valid': True,
                  'filesystem_guid': guid(data[16:32])}
        self.volumes.append(volume)
        if depth:
            self.save(f'decoded-fv-{len(self.volumes):02d}.bin', data[:length])
        pos = (header_size + 7) & ~7
        while pos + 24 <= length:
            header = data[pos:pos + 24]
            if padding(header):
                require(padding(data[pos:length]), f'Non-padding after empty FFS header at {path}:{pos:x}')
                pos = length
                break
            size = u24(data, pos + 20)
            header_bytes = 24
            if size == 0xffffff:
                require(header[19] & 1 and pos + 32 <= length, 'Invalid large FFS header')
                header_bytes = 32
                size = struct.unpack_from('<Q', data, pos + 24)[0]
            require(header_bytes <= size <= length - pos, f'FFS bounds at {path}:{pos:x}')
            check = bytearray(data[pos:pos + header_bytes])
            check[17] = 0
            check[23] = 0
            require(sum(check) & 255 == 0, f'FFS header checksum at {path}:{pos:x}')
            state = header[23] ^ (255 if attrs & 0x800 else 0)
            active = state != 0 and 1 << (state.bit_length() - 1) == 4
            payload = data[pos + header_bytes:pos + size]
            data_checked = bool(header[19] & 0x40)
            if data_checked:
                require((sum(payload) + header[17]) & 255 == 0, 'FFS data checksum mismatch')
            owner = {'container': path, 'offset': hex(pos), 'guid': guid(header[:16]),
                     'type': hex(header[18]), 'size': size, 'active': active,
                     'normalized_state': hex(state), 'header_checksum_valid': True,
                     'data_checksum_checked': data_checked}
            self.files.append(owner)
            if header[18] != 0xf0 and active:
                self.walk_sections(data, pos + header_bytes, pos + size,
                                   f'{path}/ffs:{owner["guid"]}', owner, depth + 1)
            aligned = (pos + size + 7) & ~7
            require(padding(data[pos + size:min(aligned, length)]), 'Non-padding FFS alignment gap')
            pos = aligned
        require(padding(data[min(pos, length):length]), 'Unparsed non-padding FV tail')
        volume['traversal_complete'] = True

    def walk_sections(self, data, start, end, path, owner, depth):
        require(depth < 12, 'Section nesting budget exceeded')
        pos = start
        while pos + 4 <= end:
            if padding(data[pos:pos + 4]):
                require(padding(data[pos:end]), 'Non-padding after empty section header')
                pos = end
                break
            size = u24(data, pos)
            typ = data[pos + 3]
            hs = 4
            if size == 0xffffff:
                require(pos + 8 <= end, 'Truncated extended section')
                hs = 8
                size = struct.unpack_from('<I', data, pos + 4)[0]
            require(hs <= size <= end - pos, f'Section bounds at {path}:{pos:x}')
            payload = data[pos + hs:pos + size]
            rec = {'container': path, 'offset': hex(pos), 'size': size, 'type': hex(typ),
                   'owner_guid': owner['guid']}
            self.sections.append(rec)
            child = f'{path}/section@{pos:x}'
            if typ == 0x02:
                require(size >= hs + 20, 'Truncated GUID-defined section')
                kind = guid(data[pos + hs:pos + hs + 16])
                data_offset, attributes = struct.unpack_from('<HH', data, pos + hs + 16)
                require(hs + 20 <= data_offset <= size, 'Invalid GUID section data offset')
                rec.update({'guid': kind, 'data_offset': data_offset, 'attributes': attributes})
                content = data[pos + data_offset:pos + size]
                if kind == LZMA_GUID:
                    decoder = lzma.LZMADecompressor(format=lzma.FORMAT_AUTO, memlimit=MAX_BYTES)
                    decoded = decoder.decompress(content, max_length=MAX_DECODED + 1)
                    require(len(decoded) <= MAX_DECODED and decoder.eof and not decoder.unused_data,
                            'Incomplete/oversized LZMA stream')
                    self.decoded_bytes += len(decoded)
                    require(self.decoded_bytes <= MAX_BYTES, 'Total decompression budget exceeded')
                    rec.update({'compressed_sha256': digest(content), 'decoded_sha256': digest(decoded),
                                'decoded_size': len(decoded)})
                    self.walk_sections(decoded, 0, len(decoded), child + ':lzma', owner, depth + 1)
                elif not attributes & 1:
                    self.walk_sections(content, 0, len(content), child + ':no-transform', owner, depth + 1)
                else:
                    self.opaque.append({'container': child, 'reason': 'Unknown required GUID transform',
                                        'guid': kind})
            elif typ == 0x17:
                self.walk_fv(payload, child + ':fv', depth + 1)
            elif typ == 0x01:
                require(len(payload) >= 5, 'Truncated compression section')
                uncompressed_size = struct.unpack_from('<I', payload)[0]
                rec['compression_type'] = payload[4]
                if payload[4] == 0:
                    require(len(payload[5:]) == uncompressed_size, 'Uncompressed section length mismatch')
                    self.walk_sections(payload[5:], 0, uncompressed_size, child + ':uncompressed', owner, depth + 1)
                else:
                    self.opaque.append({'container': child, 'reason': 'Unsupported EFI compression',
                                        'compression_type': payload[4]})
            elif typ in (0x10, 0x12):
                metadata = image_info(payload)
                item = {'file_guid': owner['guid'], 'file_type': owner['type'], 'active': owner['active'],
                        'section_container': path, 'section_offset': hex(pos),
                        'payload_offset': hex(pos + hs), 'size': len(payload),
                        'sha256': digest(payload), 'image': metadata}
                self.executables.append(item)
                self.payloads[id(item)] = payload
                if owner['guid'] in REQUIRED or owner['type'] == '0x3':
                    label = REQUIRED.get(owner['guid'], 'Sec')
                    name = f'{label}-{len(self.executables):02d}.bin'
                    self.save(name, payload)
                    item['extracted_name'] = name
            elif owner['guid'] == APRIORI_DXE and typ == 0x19:
                require(len(payload) % 16 == 0, 'APRIORI data is not a GUID array')
                refs = [guid(payload[index:index + 16]) for index in range(0, len(payload), 16)]
                self.apriori.append({'container': path, 'section_offset': hex(pos),
                                     'payload_offset': hex(pos + hs), 'guids': refs})
            aligned = (pos + size + 3) & ~3
            require(padding(data[pos + size:min(aligned, end)]), 'Non-padding section alignment gap')
            pos = aligned
        require(padding(data[min(pos, end):end]), 'Unparsed non-padding section tail')


def audit_firmware(data, efi_dir=None, extract_dir=None):
    """Validate a bounded FD and mandatory executable FFS membership."""
    require(56 <= len(data) <= MAX_BYTES, 'FD size outside audit budget')
    if extract_dir is not None:
        extract_dir = Path(extract_dir)
        extract_dir.mkdir(parents=True, exist_ok=False)
    walker = Walker(extract_dir)
    walker.walk_fv(data, 'fd', 0)
    refs = [ref for table in walker.apriori for ref in table['guids']]
    executable_guids = {item['file_guid'] for item in walker.executables if item['active']}
    memberships = []
    problems = []
    if walker.opaque:
        problems.append('Container traversal has unsupported transforms')
    for key, name in REQUIRED.items():
        found = [item for item in walker.executables
                 if item['file_guid'] == key and item['active'] and item['file_type'] == '0x7']
        entry = {'module': name, 'guid': key, 'apriori_reference': key in refs,
                 'executable_ffs_count': len(found), 'executables': found}
        if len(found) != 1:
            problems.append(f'{name}: expected one executable DRIVER FFS, found {len(found)}')
        elif found[0]['image']['machine'] != '0xaa64':
            problems.append(f'{name}: not AArch64')
        if efi_dir is not None and len(found) == 1:
            flat = Path(efi_dir) / (name + '.efi')
            if not flat.is_file():
                problems.append(f'{name}: explicit flat image missing')
            else:
                original = flat.read_bytes()
                same = original == walker.payloads[id(found[0])]
                entry['flat_comparison'] = {'path': str(flat), 'sha256': digest(original), 'byte_equal': same}
                if not same:
                    problems.append(f'{name}: packaged bytes differ from explicit flat image; investigate rebase/conversion')
        memberships.append(entry)
    dangling = sorted(set(refs) - executable_guids)
    if dangling:
        problems.append('APRIORI contains GUIDs with no active executable FFS')
    return {'schema_version': 1, 'fd_size': len(data), 'fd_sha256': digest(data),
            'verified': not problems, 'problems': problems,
            'traversal_complete': not walker.opaque, 'opaque_sections': walker.opaque,
            'volumes': walker.volumes, 'files': walker.files, 'sections': walker.sections,
            'executables': walker.executables, 'apriori_tables': walker.apriori,
            'dangling_apriori_references': dangling, 'required_modules': memberships,
            'limits': {'max_input_bytes': MAX_BYTES, 'max_decoded_section_bytes': MAX_DECODED},
            'limitations': ['Static image membership, not runtime execution proof',
                            'APRIORI GUIDs are never counted as executable modules',
                            'Explicit flat-byte mismatch is rejected, not silently normalized']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('firmware', type=Path)
    parser.add_argument('--efi-dir', type=Path, help='Explicit flat AARCH64 .efi directory for exact comparison')
    parser.add_argument('--output', required=True, type=Path, help='New evidence directory')
    args = parser.parse_args()
    if args.output.exists() or args.output.is_symlink():
        parser.error('output directory must be new')
    try:
        require(args.firmware.stat().st_size <= MAX_BYTES, 'FD exceeds input budget')
        result = audit_firmware(args.firmware.read_bytes(), args.efi_dir, args.output)
        result['input_path'] = str(args.firmware.resolve())
        result['checker_sha256'] = digest(Path(__file__).read_bytes())
        with (args.output / 'fv-audit.json').open('x') as stream:
            json.dump(result, stream, indent=2)
            stream.write('\n')
        print(json.dumps({key: result[key] for key in ('verified', 'fd_sha256', 'traversal_complete',
              'required_modules', 'dangling_apriori_references', 'problems')}, indent=2))
        return 0 if result['verified'] else 1
    except (FirmwareError, lzma.LZMAError, OSError, struct.error) as error:
        print(f'FV audit rejected: {error}', file=sys.stderr)
        if args.output.is_dir():
            with (args.output / 'audit-error.json').open('x') as stream:
                json.dump({'verified': False, 'error': str(error)}, stream, indent=2)
                stream.write('\n')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
