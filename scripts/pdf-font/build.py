#!/usr/bin/env python3
# Font PDF untuk laporan berbahasa Hokkien & Korea (jsPDF hanya menerima TrueType):
#   public/fonts/du-pdf-han-{normal,bold}.ttf — Hokkien: Latin Noto Sans + Han Droid Sans Fallback (Apache-2.0)
#   public/fonts/du-pdf-ko-{normal,bold}.ttf  — Korea:   Latin Noto Sans + Hangul Noto Sans CJK KR (SIL OFL 1.1;
#                                               outline CFF diubah ke TrueType dengan cu2qu)
#   Latin, angka & tanda baca: Noto Sans Regular/Bold (SIL OFL 1.1, Google)
# Hanya karakter yang dipakai kamus bahasanya (public/js/locale-<lang>.js, src/i18n/messages.<lang>.json) +
# Latin-1 yang disertakan, jadi file tetap kecil. Jalankan ulang setelah menambah/mengubah terjemahan:
#   python3 -m venv /tmp/fontenv && /tmp/fontenv/bin/pip install fonttools
#   /tmp/fontenv/bin/python scripts/pdf-font/build.py
# test/i18n.test.js memastikan semua karakter kamus ada di scripts/pdf-font/chars.txt (Hokkien) dan
# chars-ko.txt (Korea) — isi font masing-masing.
import json
import os
import sys
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools import subset
from fontTools.merge import Merger, Options as MergeOptions
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
NOTO = os.environ.get('NOTO_DIR', '/usr/share/fonts/truetype/noto')
DROID = os.environ.get('DROID_TTF', '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf')
NOTO_CJK = os.environ.get('NOTO_CJK_DIR', '/usr/share/fonts/opentype/noto')
CJK_KR_INDEX = 1  # NotoSansCJK-*.ttc: 0 JP, 1 KR, 2 SC, 3 TC, 4 HK

# lang: (berkas keluaran, sumber aksara, nama keluarga, berkas daftar karakter, batas kode "aksara lokal")
TARGETS = {
    'nan': ('du-pdf-han', 'droid', 'DU Hokkien PDF', 'chars.txt'),
    'ko': ('du-pdf-ko', 'cjk-kr', 'DU Korean PDF', 'chars-ko.txt'),
}

def dictionary_chars(lang):
    src = open(os.path.join(ROOT, f'public/js/locale-{lang}.js'), encoding='utf8').read()
    data = json.loads(src[src.index('{'):src.rindex('}') + 1])
    def walk(o):
        for v in o.values():
            yield from (walk(v) if isinstance(v, dict) else [v])
    chars = set(''.join(walk(data)))
    msgs = json.load(open(os.path.join(ROOT, f'src/i18n/messages.{lang}.json'), encoding='utf8'))
    for section in ('messages', 'fields'):
        chars |= set(''.join(msgs[section].values()))
    chars |= {chr(c) for c in range(0x20, 0x7f)} | {chr(c) for c in range(0xa0, 0x100)}
    chars |= set('–—…‘’“”•·€，。、：；！？（）「」『』／～＋－＝％《》【】')
    return ''.join(sorted(chars))

def subset_tables(font, chars):
    opt = subset.Options()
    opt.layout_features = []
    opt.hinting = False
    opt.drop_tables += ['DSIG', 'GSUB', 'GPOS', 'GDEF', 'vhea', 'vmtx', 'kern', 'VORG', 'BASE']
    opt.name_IDs = ['*']
    opt.notdef_outline = True
    s = subset.Subsetter(opt)
    s.populate(text=chars)
    s.subset(font)
    return font

def cff_to_glyf(font):
    # Outline kubik (CFF) → kuadratik (glyf), karena jsPDF hanya membaca TrueType.
    order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()
    glyf = newTable('glyf')
    glyf.glyphOrder = order
    glyf.glyphs = {}
    for name in order:
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, 1.0, reverse_direction=True))
        glyf[name] = pen.glyph()
    font['loca'] = newTable('loca')
    font['glyf'] = glyf
    font['head'].glyphDataFormat = 0
    del font['CFF ']
    maxp = font['maxp']
    maxp.tableVersion = 0x00010000
    for attr in ('maxZones', 'maxTwilightPoints', 'maxStorage', 'maxFunctionDefs', 'maxInstructionDefs',
                 'maxStackElements', 'maxSizeOfInstructions', 'maxComponentElements', 'maxComponentDepth'):
        setattr(maxp, attr, 1 if attr == 'maxZones' else 0)
    font['post'].formatType = 3.0
    font.sfntVersion = '\x00\x01\x00\x00'
    return font

def local_font(source, weight, chars, upem, dst):
    if source == 'droid':
        font = subset_tables(TTFont(DROID), chars)
    else:
        font = TTFont(os.path.join(NOTO_CJK, f'NotoSansCJK-{weight}.ttc'), fontNumber=CJK_KR_INDEX)
        font = cff_to_glyf(subset_tables(font, chars))
    if font['head'].unitsPerEm != upem:
        scale_upem(font, upem)
    font.save(dst)

def build(lang):
    prefix, source, family, chars_file = TARGETS[lang]
    text = dictionary_chars(lang)
    latin = ''.join(c for c in text if ord(c) < 0x2e80)
    local = ''.join(c for c in text if ord(c) >= 0x2e80)
    tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'du-pdf-font')
    os.makedirs(tmp, exist_ok=True)
    missing = set()
    for weight, style in (('Regular', 'normal'), ('Bold', 'bold')):
        lat, loc = os.path.join(tmp, f'{lang}-lat-{style}.ttf'), os.path.join(tmp, f'{lang}-loc-{style}.ttf')
        TTFont_lat = subset_tables(TTFont(os.path.join(NOTO, f'NotoSans-{weight}.ttf')), latin)
        TTFont_lat.save(lat)
        local_font(source, weight, local, TTFont(lat)['head'].unitsPerEm, loc)
        font = Merger(options=MergeOptions(drop_tables=['vhea', 'vmtx'])).merge([lat, loc])
        # Nama keluarga baru (bukan "Noto"/"Droid"): ini turunan gabungan, sesuai syarat lisensi OFL.
        for rec in font['name'].names:
            if rec.nameID in (1, 16):
                rec.string = family
            elif rec.nameID == 4:
                rec.string = f'{family} {weight}'
            elif rec.nameID == 6:
                rec.string = f'{family.replace(" ", "")}-{weight}'
        font.save(os.path.join(ROOT, 'public/fonts', f'{prefix}-{style}.ttf'))
        cmap = font.getBestCmap()
        missing |= {c for c in text if ord(c) not in cmap}
    # Karakter yang benar-benar ada di font (tanda tanpa glyph diganti padanan ASCII oleh bo-pdf.mjs).
    covered = ''.join(c for c in text if c not in missing)
    open(os.path.join(os.path.dirname(__file__), chars_file), 'w', encoding='utf8').write(covered)
    print(f'{lang}: {len(covered)} karakter ({sum(ord(c) >= 0x2e80 for c in covered)} aksara lokal); tanpa glyph: {"".join(sorted(missing)) or "-"}')

def main():
    for lang in (sys.argv[1:] or TARGETS):
        build(lang)

if __name__ == '__main__':
    sys.exit(main())
