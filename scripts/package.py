"""Package source/evidence without local credentials, dependency caches or build products."""
from pathlib import Path
import zipfile, hashlib, json, os
root=Path(__file__).resolve().parents[1]
out=root.parent/'RepairProof_Full_Project.zip'
files=[]
for current,dirs,names in os.walk(root):
    dirs[:]=[d for d in dirs if d not in {'node_modules','.dart_tool','build','dist','.git','.firebase','__pycache__'} and not (Path(current)==root/'functions' and d=='lib')]
    for name in names:
        p=Path(current)/name;rel=p.relative_to(root)
        if name.endswith(('.log','.pyc','.jks','.keystore')) or name in {'.demo-session.json','local.properties','key.properties','.firebaserc','production.json','PACKAGE_MANIFEST.json'}:continue
        if name.startswith('.env') and name not in {'.env.example','.env.local'}:continue
        files.append(p)
manifest={str(p.relative_to(root)).replace('\\','/'):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)}
manifest_path=root/'PACKAGE_MANIFEST.json';manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in sorted(files)+[manifest_path]:z.write(p,Path('repairproof')/p.relative_to(root))
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert 'repairproof/shopkeeper_app/lib/main.dart' in z.namelist()
    assert 'repairproof/shopkeeper_app/pubspec.lock' in z.namelist()
    assert not any('/node_modules/' in n or n.endswith('.jks') for n in z.namelist())
print(f'{out}\n{len(files)+1} files; {out.stat().st_size} bytes; archive integrity verified')
