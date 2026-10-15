"""Repack an extracted release after intentional edits: python repack.py RELEASE_ROOT OUTPUT.zip.
Requires the complete original release payload. Does not download dependencies or build DLLs.
"""
from pathlib import Path
import sys,json,hashlib,zipfile
root=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve()
assert root not in out.parents,'Keep output outside the input directory'
packages=list(root.glob('HomeButler-*-Package'));assert len(packages)==1,'Expected exactly one package'
pkg=packages[0];m=json.loads((pkg/'manifest.json').read_text(encoding='utf-8-sig'))
for f in m['Payload']:assert (pkg/f['Source']).is_file(),f['Source']
assert (pkg/m['Offline']['Source']).is_file(),'Offline Unity archive missing'
files=[]
for p in root.rglob('*'):
 assert not p.is_symlink(),'Links unsupported'
 if not p.is_file():continue
 rel=p.relative_to(root)
 assert not set(rel.parts)&{'.state','.safe-backups','.offline-state','interop','obj','bin','HomeButler-containers'},rel
 assert p.name not in {'GameAssembly.dll','HotUpdate.dll','SurvivalLog.exe','LogOutput.log','Player.log','.safe-state.json'},rel
 assert p.suffix.lower()!='.html',rel
 files.append(p)
m['PackageFiles']=[{'Path':p.relative_to(pkg).as_posix(),'SHA256':hashlib.sha256(p.read_bytes()).hexdigest().upper()} for p in sorted(files) if pkg in p.parents and (p.relative_to(pkg).parts[0] in ['payload','defaults','source'] or p.name in ['Setup.ps1','OfflineConfig.ps1','Launch.ps1'])]
(pkg/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
out.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(out,'x',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in sorted(files):z.write(p,p.relative_to(root).as_posix())
with zipfile.ZipFile(out) as z:assert z.testzip() is None
print(hashlib.sha256(out.read_bytes()).hexdigest().upper(),out.name)
print('Repacking is not validation: re-run installer, interface, browser, and in-game checks before publishing.')
