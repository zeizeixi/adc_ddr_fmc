from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib,json
root=Path(__file__).parent
files=[]
for folder in ['rtl','docs','constraints','reference','sim','reports']:
    files.extend(p for p in (root/folder).rglob('*') if p.is_file() and p.suffix in {'.v','.sv','.md','.h','.xdc','.json','.rpt','.log'})
files.extend(root/n for n in ['README.md','run_tests.ps1','validate_synthesis.tcl'])
files=sorted(set(files))
manifest='\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(root).as_posix() for p in files)+'\n'
(root/'MANIFEST.sha256').write_text(manifest,encoding='utf-8')
archive=root.parent/'adc_trigger_capture_v2_candidate.zip'
with ZipFile(archive,'w',ZIP_DEFLATED) as z:
    for p in files+[root/'MANIFEST.sha256']:
        z.write(p,'adc_trigger_capture/'+p.relative_to(root).as_posix())
with ZipFile(archive) as z:
    assert z.testzip() is None
    for p in files:
        assert z.read('adc_trigger_capture/'+p.relative_to(root).as_posix())==p.read_bytes()
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'files':len(files)+1,'integrity':'verified'},ensure_ascii=False))
