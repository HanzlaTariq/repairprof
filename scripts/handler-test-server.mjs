// Test-only TCP harness; runs the exact exported function with real emulators.
import {createRequire} from 'node:module';
if(process.env.GCLOUD_PROJECT!=='demo-repairproof'||!process.env.FIRESTORE_EMULATOR_HOST||!process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('This harness is local-demo-only.');
process.env.FUNCTIONS_EMULATOR='true';process.env.STORAGE_BUCKET='demo-repairproof.appspot.com';
const require=createRequire(new URL('../functions/package.json',import.meta.url));
const express=require('express');const {api}=require('../functions/lib/index.js');
const app=express();app.use(express.json({limit:'5mb'}));app.use('/demo-repairproof/us-central1/api',api);
app.use('/api',api);
app.use(express.static('customer_web/dist'));
app.use((req,res)=>res.sendFile(new URL('../customer_web/dist/index.html',import.meta.url).pathname));
app.listen(5501,'127.0.0.1',()=>console.log('Exact API handler test harness on local TCP 5501.'));
