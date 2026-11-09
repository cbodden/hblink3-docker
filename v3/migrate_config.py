#!/usr/bin/env python3
## converts an lz5pn-era hblink.cfg + rules.py to the n0mjs710/hblink3 v3 format
##
## usage: migrate_config.py <old hblink.cfg> <old rules.py> <new hblink.cfg> <new rules.py>
##
## hblink.cfg:
##   MODE: MASTER  -> SERVER    (MAX_PEERS -> MAX_REPEATERS)
##   MODE: PEER    -> OUTBOUND  (MASTER_IP / MASTER_PORT -> SERVER_IP / SERVER_PORT)
##   MODE: XLXPEER -> OUTBOUND  + XLXMODULE: 40NN -> XLX_MODULE: <letter>, empty OPTIONS
##   empty IP -> 0.0.0.0 (also OPENBRIDGE)
##   EXPORT_AMBE / XLXOPTIONS / BOTH_SLOTS dropped
## rules.py:
##   XLX members move out of BRIDGES into XLX_BRIDGES = {system: bridge}
##   UNIT = [] added when missing (v3 requires it)
##
## v3 silently skips a stanza with an unknown MODE, so the output is checked for leftovers.
## comments and layout are kept; passphrases are never printed.

import configparser
import re
import sys

MODE_MAP = {'MASTER': 'SERVER', 'PEER': 'OUTBOUND', 'CLIENT': 'OUTBOUND', 'XLXPEER': 'OUTBOUND'}
KEY_MAP = {'MAX_PEERS': 'MAX_REPEATERS', 'MASTER_IP': 'SERVER_IP', 'MASTER_PORT': 'SERVER_PORT'}
DROP_KEYS = {'EXPORT_AMBE', 'XLXOPTIONS', 'BOTH_SLOTS'}
XLX_RADIO_ID_MAX = 16777215

SECTION_RE = re.compile(r'^\[([^\]]+)\]\s*$')
KEY_RE = re.compile(r'^([A-Z_0-9]+)\s*:\s*(.*)$')


def die(msg):
    sys.exit('ERROR: ' + msg)


def split_sections(lines):
    ## [(name or None for the preamble, [lines])]
    blocks = [(None, [])]
    for line in lines:
        m = SECTION_RE.match(line)
        if m:
            blocks.append((m.group(1), [line]))
        else:
            blocks[-1][1].append(line)
    return blocks


def convert_block(name, lines, report):
    keys = {}
    for line in lines:
        m = KEY_RE.match(line)
        if m:
            keys[m.group(1)] = m.group(2).strip()
    mode = keys.get('MODE')
    if mode not in MODE_MAP and mode != 'OPENBRIDGE':
        return lines, None
    new_mode = MODE_MAP.get(mode, mode)
    is_xlx = mode == 'XLXPEER' or 'XLXMODULE' in keys

    out = []
    for line in lines:
        m = KEY_RE.match(line)
        if not m:
            out.append(line)
            continue
        key, val = m.group(1), m.group(2).strip()
        if key in DROP_KEYS:
            continue
        if key == 'MODE':
            out.append('MODE: {}\n'.format(new_mode))
        elif key == 'IP' and not val:
            ## v3 runs getaddrinfo() on IP, which fails on an empty string
            out.append('IP: 0.0.0.0\n')
        elif key == 'XLXMODULE':
            num = int(val) - 4000
            if not 1 <= num <= 26:
                die('[{}] XLXMODULE {} is not 4001-4026'.format(name, val))
            out.append('XLX_MODULE: {}\n'.format(chr(64 + num)))
        elif key == 'OPTIONS' and is_xlx:
            out.append('OPTIONS:\n')
        elif key in KEY_MAP:
            out.append('{}: {}\n'.format(KEY_MAP[key], val))
        else:
            out.append(line)

    ## v3 OUTBOUND requires OPTIONS - the old xlx stanzas only had XLXOPTIONS
    if new_mode == 'OUTBOUND' and 'OPTIONS' not in keys:
        idx = max(i for i, l in enumerate(out) if KEY_RE.match(l)) + 1
        out.insert(idx, 'OPTIONS:\n')

    report.append('[{}] {} -> {}{}'.format(
        name, mode, new_mode,
        ' (XLX module {})'.format(chr(64 + int(keys['XLXMODULE']) - 4000)) if 'XLXMODULE' in keys else ''))
    return out, (name if is_xlx else None)


def validate_cfg(path):
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    cfg.read(path)
    enabled = {}
    for s in cfg.sections():
        if s in ('GLOBAL', 'REPORTS', 'LOGGER', 'ALIASES'):
            continue
        mode = cfg[s].get('MODE', '')
        if mode not in ('SERVER', 'OUTBOUND', 'OPENBRIDGE'):
            die('[{}] MODE {} would be silently skipped by v3'.format(s, mode))
        if cfg[s].getboolean('ENABLED', fallback=False):
            enabled[s] = cfg[s]
        if mode == 'OPENBRIDGE' and len(cfg[s].get('PASSPHRASE', '')) > 80:
            die('[{}] OPENBRIDGE PASSPHRASE is over 80 characters'.format(s))
        if cfg[s].get('XLX_MODULE'):
            if not cfg[s].getboolean('LOOSE', fallback=False):
                die('[{}] XLX system needs LOOSE: True'.format(s))
            if cfg[s].getint('RADIO_ID') > XLX_RADIO_ID_MAX:
                die('[{}] XLX RADIO_ID is over {}'.format(s, XLX_RADIO_ID_MAX))
        if mode == 'OUTBOUND' and not cfg.has_option(s, 'OPTIONS'):
            die('[{}] OUTBOUND is missing OPTIONS'.format(s))
    return enabled


def convert_rules(text, xlx_systems, enabled):
    bridge_re = re.compile(r"^\s*'([^']+)'\s*:\s*\[")
    system_re = re.compile(r"'SYSTEM'\s*:\s*'([^']+)'")
    out, xlx_bridges, members = [], {}, {}
    bridge = None
    for line in text.splitlines(keepends=True):
        live = not line.lstrip().startswith('#')
        m = bridge_re.match(line)
        if m and live:
            bridge = m.group(1)
        s = system_re.search(line)
        if s and live:
            system = s.group(1)
            if system in xlx_systems:
                if system in xlx_bridges:
                    die('{} is on bridges {} and {} - v3 allows one bridge per XLX system'.format(
                        system, xlx_bridges[system], bridge))
                xlx_bridges[system] = bridge
                continue
            members.setdefault(bridge, []).append(system)
        out.append(line)

    for system, bridge in xlx_bridges.items():
        if not members.get(bridge):
            die('XLX system {} would be alone on bridge {}'.format(system, bridge))
    for bridge, systems in members.items():
        for system in systems:
            if system not in enabled:
                die('bridge {} names {}, which is not an enabled system in hblink.cfg'.format(bridge, system))

    new = ''.join(out).rstrip('\n') + '\n'
    if not re.search(r'^XLX_BRIDGES\s*=', new, re.M):
        new += '\n## XLX systems are nailed to one bridge each (v3: not inline in BRIDGES)\nXLX_BRIDGES = {\n'
        for system, bridge in xlx_bridges.items():
            new += "    '{}': '{}',\n".format(system, bridge)
        new += '}\n'
    if not re.search(r'^UNIT\s*=', new, re.M):
        new += '\n## systems allowed to exchange private calls (v3 requires this table)\nUNIT = []\n'
    return new, xlx_bridges


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__ or 'usage: migrate_config.py <old cfg> <old rules> <new cfg> <new rules>')
    old_cfg, old_rules, new_cfg, new_rules = sys.argv[1:]

    with open(old_cfg) as f:
        blocks = split_sections(f.readlines())
    report, xlx_systems, out = [], [], []
    for name, lines in blocks:
        lines, xlx = convert_block(name, lines, report)
        out.extend(lines)
        if xlx:
            xlx_systems.append(xlx)
    with open(new_cfg, 'w') as f:
        f.writelines(out)
    enabled = validate_cfg(new_cfg)

    with open(old_rules) as f:
        rules, xlx_bridges = convert_rules(f.read(), xlx_systems, enabled)
    with open(new_rules, 'w') as f:
        f.write(rules)

    print('\n'.join(report))
    for system, bridge in xlx_bridges.items():
        print('XLX_BRIDGES: {} -> {}'.format(system, bridge))
    print('wrote {} and {}'.format(new_cfg, new_rules))


if __name__ == '__main__':
    main()
