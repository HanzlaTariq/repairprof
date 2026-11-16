import {onRequest} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {getAuth} from 'firebase-admin/auth';
import {ZodError} from 'zod';
import {AppError,ensure,digest} from './domain';
import {schemas,tracking,webDecision} from './schemas';
import * as service from './store';
const emulated=process.env.FUNCTIONS_EMULATOR==='true';
export const api=onRequest({region:'us-central1',maxInstances:5,memory:'512MiB',timeoutSeconds:60,invoker:'public'},async(req,res)=>{
 res.set('Cache-Control','private, no-store, max-age=0').set('Pragma','no-cache').set('Referrer-Policy','no-referrer').set('X-Content-Type-Options','nosniff');
 const origin=req.get('origin');const allowed=(process.env.WEB_ORIGINS||'').split(',');
 if(origin&&(allowed.includes(origin)||(emulated&&/^http:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/.test(origin))))res.set('Access-Control-Allow-Origin',origin).set('Vary','Origin');
 res.set('Access-Control-Allow-Headers','Content-Type, Authorization').set('Access-Control-Allow-Methods','POST, OPTIONS');
 if(req.method==='OPTIONS'){res.status(204).send('');return;}
 try{
  ensure(req.method==='POST','POST is required.',405);ensure(req.is('application/json'),'JSON is required.',415);
  ensure(Buffer.byteLength(JSON.stringify(req.body||{}))<=4400000,'Request too large.',413);
  await service.rateLimit(`ip:${req.ip||req.socket.remoteAddress}`,180);
  const path=req.path.replace(/^\/api/,'');let result:any;
  if(path==='/track'){const d=tracking.parse(req.body);await service.rateLimit(`token:${digest(d.token)}`,60);result=await service.track(d.token);}
  else if(path==='/decision'){const d=webDecision.parse(req.body);await service.rateLimit(`decision:${digest(d.token)}`,10);result=await service.customerDecision(d);}
  else{
   const header=req.get('authorization')||'';ensure(header.startsWith('Bearer '),'Please sign in.',401);
   let auth;try{auth=await getAuth().verifyIdToken(header.slice(7),true);}catch{throw new AppError(401,'Session expired. Please sign in again.');}
   await service.rateLimit(`owner:${auth.uid}`,120);
   const op=path.replace(/^\/owner\//,'') as keyof typeof schemas;ensure(Object.hasOwn(schemas,op),'Unknown operation.',404);const d=schemas[op].parse(req.body);
   if(op==='getShop')result=await service.getShop(auth.uid);
   else if(op==='list')result=await service.listTickets(auth.uid,d);
   else if(op==='dashboard')result=await service.dashboard(auth.uid,d);
   else if(op==='detail')result=await service.getTicket(auth.uid,(d as any).ticketId);
   else if(op==='photo')result=await service.photo(auth.uid,d);
   else if(op==='upload')result=await service.upload(auth.uid,d);
   else if(op==='deleteAccount'){ensure(Date.now()/1000-auth.auth_time<300,'Sign in again before requesting deletion.',401);result=await service.deleteAccount(auth.uid);}
   else result=await service.ownerCommand(auth.uid,op,d);
  }
  res.json(result);
 }catch(e){
  if(e instanceof ZodError){res.status(400).json({error:e.issues.map(i=>i.message).slice(0,3).join(' ')});return;}
  if(e instanceof AppError){res.status(e.status).json({error:e.message});return;}
  // Never log request bodies, bearer credentials, private tokens or customer data.
  console.error('RepairProof operation failed',e instanceof Error?e.name:'UnknownError');
  res.status(500).json({error:'Save could not be confirmed. Check your connection and retry the same action.'});
 }
});
export const dailyMaintenance=onSchedule({schedule:'every 24 hours',region:'us-central1',maxInstances:1},async()=>{await service.maintenance();});
