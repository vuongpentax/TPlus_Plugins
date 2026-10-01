from pathlib import Path
import sys, json, shutil, hashlib
sys.path.insert(0, str(Path(__file__).parent / 'vendor'))
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from shapely import Polygon, GeometryCollection, constrained_delaunay_triangles, make_valid

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'runtime/TPlus_Dim/fonts'
DEST.mkdir(parents=True, exist_ok=True)
FILES = ['UTM-Avo.ttf','UTM-Avobold.ttf','UTM-Avoitalic.ttf','UTM-Avobold-Italic.ttf',
         'Roboto-Regular.ttf','Roboto-Bold.ttf','Roboto-Italic.ttf','Roboto-BoldItalic.ttf',
         'RobotoCondensed-Regular.ttf','RobotoCondensed-Bold.ttf','RobotoCondensed-Italic.ttf','RobotoCondensed-BoldItalic.ttf']

class Flatten(BasePen):
    def __init__(self, glyphs):
        super().__init__(glyphs); self.contours=[]; self.current=[]
    def _moveTo(self, p): self.current=[p]
    def _lineTo(self, p): self.current.append(p)
    def _qCurveToOne(self, p1, p2):
        p0=self._getCurrentPoint()
        for i in range(1,9):
            t=i/8; u=1-t
            self.current.append(tuple(u*u*p0[j]+2*u*t*p1[j]+t*t*p2[j] for j in (0,1)))
    def _curveToOne(self,p1,p2,p3):
        p0=self._getCurrentPoint()
        for i in range(1,13):
            t=i/12; u=1-t
            self.current.append(tuple(u**3*p0[j]+3*u*u*t*p1[j]+3*u*t*t*p2[j]+t**3*p3[j] for j in (0,1)))
    def _closePath(self):
        if len(self.current)>2: self.contours.append(self.current)
        self.current=[]
    def _endPath(self): self._closePath()

report=[]
for name in FILES:
    source=Path('C:/Windows/Fonts')/name
    shutil.copy2(source,DEST/name)
    font=TTFont(source); glyphs=font.getGlyphSet(); cmap=font.getBestCmap()
    cap=getattr(font['OS/2'],'sCapHeight',0) or font['head'].unitsPerEm*.72
    data={'cap':cap,'glyphs':{}}
    supported=[c for c in cmap if c>=32]  # All encoded glyphs, including Vietnamese.
    for code in supported:
        gname=cmap[code]; pen=Flatten(glyphs); glyphs[gname].draw(pen)
        shape=GeometryCollection()
        for contour in pen.contours:
            polygon=make_valid(Polygon(contour))
            shape=shape.symmetric_difference(polygon)
        triangles=constrained_delaunay_triangles(shape)
        area=sum(t.area for t in triangles.geoms)
        assert abs(area-shape.area)<max(1e-4,shape.area*1e-7), (name,code,'triangulation area mismatch')
        vertices=[[[round(x/cap,7),round(y/cap,7)] for x,y in list(t.exterior.coords)[:3]] for t in triangles.geoms]
        data['glyphs'][str(code)]={'advance':round(glyphs[gname].width/cap,7),'triangles':vertices}
    output=DEST/(Path(name).stem+'.json')
    output.write_text(json.dumps(data,separators=(',',':'),ensure_ascii=False),encoding='utf-8')
    report.append({'file':name,'family':font['name'].getDebugName(1),'glyphs':len(supported),
                   'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                   'copyright':font['name'].getDebugName(0),'license':font['name'].getDebugName(13)})
    print(name,len(supported),'glyphs')
(ROOT/'outputs/FONT_PROVENANCE.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
