import {spawn} from 'node:child_process';
const server=spawn(process.execPath,['scripts/handler-test-server.mjs'],{stdio:'inherit',env:process.env});
let ready=false;for(let i=0;i<30;i++){try{await fetch('http://127.0.0.1:5501');ready=true;break;}catch{await new Promise(r=>setTimeout(r,200));}}
if(!ready){server.kill();throw Error('Local handler did not start');}
const child=spawn(process.execPath,[process.argv[2]||'scripts/integration.mjs'],{stdio:'inherit',env:{...process.env,RP_API_BASE:'http://127.0.0.1:5501/demo-repairproof/us-central1/api'}});
child.on('exit',code=>{server.kill();process.exitCode=code||0;});
