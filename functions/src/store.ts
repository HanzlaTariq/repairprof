import {initializeApp,getApps} from 'firebase-admin/app';
import {getFirestore,FieldValue} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {getAuth} from 'firebase-admin/auth';
import sharp from 'sharp';
import {AppError,ensure,digest,secret,collectionCode,claimHash,sameHash,Ticket,Shop,event,mutate,projection} from './domain';
if(!getApps().length)initializeApp();
export const db=getFirestore();
export const shopRef=(uid:string)=>db.doc(`shops/${uid}`);
const ticketRef=(uid:string,id:string)=>shopRef(uid).collection('tickets').doc(id);
const bucket=()=>getStorage().bucket(process.env.STORAGE_BUCKET||undefined);
const now=()=>new Date().toISOString();
export async function rateLimit(key:string,limit=100){
 const ref=db.doc(`rateLimits/${digest(key)}`);const time=Date.now(),window=Math.floor(time/60000);
 await db.runTransaction(async tx=>{const s=await tx.get(ref);const d=s.data();const count=d?.window===window?d.count+1:1;ensure(count<=limit,'Too many attempts. Please wait a minute.',429);tx.set(ref,{window,count,expiresAt:new Date(time+86400000)});});
}
export async function getShop(uid:string){const s=await shopRef(uid).get();ensure(s.exists,'Set up your shop to continue.',404);ensure(!s.data()?.deleting,'Account deletion is pending.',403);return s.data() as Shop;}
export async function getTicket(uid:string,id:string){await getShop(uid);const s=await ticketRef(uid,id).get();ensure(s.exists,'Repair record not found.',404);return s.data() as Ticket;}
export async function upload(uid:string,d:any){
 await getShop(uid);const ref=shopRef(uid).collection('uploads').doc(`${d.requestId}_${d.slot}`);
 const hash=digest(d.base64),prev=await ref.get();
 if(prev.exists){ensure(prev.data()!.hash===hash&&!prev.data()!.deleting,'This image slot is already used. Start a new intake or retry the same image.');return {slot:d.slot};}
 const input=Buffer.from(d.base64,'base64');ensure(input.length<=3*1024*1024,'Each image must be at most 3 MB.',400);
 let data:Buffer;try{const metadata=await sharp(input,{limitInputPixels:16000000}).metadata();ensure(['jpeg','png'].includes(metadata.format||''),'Use JPEG or PNG.',400);data=await sharp(input,{limitInputPixels:16000000}).rotate().resize({width:1600,height:1600,fit:'inside',withoutEnlargement:true}).jpeg({quality:80}).toBuffer();}catch{throw new AppError(400,'Use a valid JPEG or PNG exterior-condition photo.');}
 const path=`shops/${uid}/intakes/${d.requestId}/${d.slot}.jpg`;
 await bucket().file(path).save(data,{resumable:false,contentType:'image/jpeg',metadata:{cacheControl:'private, no-store',metadata:{sourceHash:hash}},preconditionOpts:{ifGenerationMatch:0}}).catch(async(e:any)=>{if(e.code!==412)throw e;const [m]=await bucket().file(path).getMetadata();ensure(m.metadata?.sourceHash===hash,'Image slot conflict. Retry the original image or start a new intake.');});
 await db.runTransaction(async tx=>{const p=await tx.get(ref);if(p.exists){ensure(p.data()!.hash===hash,'Image slot conflict.');return;}tx.create(ref,{path,hash,createdAt:now(),consumed:false,deleting:false});});
 return {slot:d.slot};
}
export async function ownerCommand(uid:string,op:string,d:any){
 const shop=shopRef(uid),command=shop.collection('commands').doc(d.requestId);
 const fingerprint=digest(JSON.stringify({op,d})); const at=now();
 const raw=(op==='createTicket'||op==='reissueClaim')?collectionCode():op==='issueAccess'?secret():undefined;
 const result=await db.runTransaction(async tx=>{
  const [ss,cs]=await Promise.all([tx.get(shop),tx.get(command)]);
  if(cs.exists){ensure(cs.data()!.fingerprint===fingerprint,'Retry identifier was used for another command.');return {...cs.data()!.result,replayed:true,secretUnavailable:['createTicket','issueAccess','reissueClaim'].includes(op)};}
  if(op==='onboard'){
   ensure(!ss.exists,'This account already owns a shop.');const {requestId,...profile}=d;
   tx.create(shop,{...profile,createdAt:at});const out={ok:true};tx.create(command,{fingerprint,result:out,at});return out;
  }
  ensure(ss.exists&&!ss.data()!.deleting,'Shop is unavailable.',403);
  if(op==='updateShop'){const {requestId,...profile}=d;tx.update(shop,profile);const out={ok:true};tx.create(command,{fingerprint,result:out,at});return out;}
  if(op==='createTicket'){
   const counter=shop.collection('meta').doc('counter');const count=await tx.get(counter);
   const n=(count.data()?.value||1000)+1;ensure(n<=11000,'This MVP supports 10,000 repair records per shop.');
   const uploads=await Promise.all(d.photoSlots.map((slot:number)=>tx.get(shop.collection('uploads').doc(`${d.requestId}_${slot}`))));
   for(const u of uploads)ensure(u.exists&&!u.data()!.consumed&&!u.data()!.deleting,'A condition photo is not saved. Retry its upload before saving the repair.',400);
   ensure(d.checkInAt>at,'Choose a future completion/check-in time.',400);
   const id=digest(`${uid}:${d.requestId}`).slice(0,32);const ref=ticketRef(uid,id);
   const {requestId,photoSlots,...fields}=d;
   const t:Ticket={...fields,id,number:`RP-${n}`,shop:ss.data() as Shop,contact:{...d.contact,permissionAt:at},photoPaths:uploads.map(u=>u.data()!.path),createdAt:at,updatedAt:at,status:'Received',quotes:[],events:[],communications:[],payments:[],accessEpoch:{customer:0,family:0}};
   event(t,'received',uid,at,'Device received with intake acknowledgement');
   tx.create(ref,t);tx.create(ref.collection('secrets').doc('collection'),{hash:claimHash(raw!),attempts:0,lockedUntil:0});
   tx.set(counter,{value:n});uploads.forEach(u=>tx.update(u.ref,{consumed:true}));
   const out={ticketId:id,number:t.number};tx.create(command,{fingerprint,result:out,at});return {...out,collectionCode:raw};
  }
  const ref=ticketRef(uid,d.ticketId);const ts=await tx.get(ref);ensure(ts.exists,'Repair record not found.',404);let t=ts.data() as Ticket;
  let out:any={ticketId:t.id};
  if(op==='issueAccess'||op==='revokeAccess'){
   if(op==='issueAccess'){
    ensure(d.scope!=='family'||t.contact.kind==='B','Family access requires a permitted family contact.',400);
    ensure(d.scope!=='customer'||t.contact.kind==='A'||d.customerPermission,'Record separate customer permission for this link.',400);
   }
   t.accessEpoch[d.scope as 'customer'|'family']++;
   event(t,op,uid,at,`${d.scope} access ${op==='issueAccess'?'reissued':'revoked'}`);
   if(op==='issueAccess'){
    tx.create(db.doc(`access/${digest(raw!)}`),{uid,ticketId:t.id,scope:d.scope,epoch:t.accessEpoch[d.scope as 'customer'|'family'],expiresAt:new Date(Date.now()+d.days*86400000).toISOString()});
    out={...out,scope:d.scope,expiresAt:new Date(Date.now()+d.days*86400000).toISOString()};
   }
  }else if(op==='reissueClaim'){
   ensure(t.status!=='Delivered','Delivered tickets cannot receive new collection codes.');
   tx.set(ref.collection('secrets').doc('collection'),{hash:claimHash(raw!),attempts:0,lockedUntil:0});event(t,'claim-reissue',uid,at,d.reason);
  }else if(op==='handover'){
   const claimRef=ref.collection('secrets').doc('collection');const cs=await tx.get(claimRef);const claim=cs.data();
   ensure(claim,'Collection credential is unavailable. Reissue it after manual verification.');
   ensure(claim.lockedUntil<Date.now(),'Collection verification is temporarily locked. Try after 15 minutes.',429);
   if(d.code&&!sameHash(claim.hash,claimHash(d.code))){
    const attempts=claim.attempts+1;tx.update(claimRef,{attempts,lockedUntil:attempts%5===0?Date.now()+900000:0});event(t,'proof-failed',uid,at,'Collection proof did not match');tx.set(ref,t);return {error:'Collection proof did not match. Device has not been released.'};
   }
   ensure(d.code||d.recoveryNote.length>=30,'Document manual identity resolution before release.',400);
   t=mutate(t,op,d,uid,at);
  }else t=mutate(t,op,d,uid,at);
  tx.set(ref,t);tx.create(command,{fingerprint,result:out,at});
  if(op==='issueAccess')out={...out,token:raw};if(op==='reissueClaim')out={...out,collectionCode:raw};return out;
 });
 if((result as any).error)throw new AppError(403,(result as any).error);return result;
}
async function scoped(tx:FirebaseFirestore.Transaction,token:string){
 const as=await tx.get(db.doc(`access/${digest(token)}`));const a=as.data();ensure(a&&a.expiresAt>now(),'This private link is unavailable. Ask the shop for a new link.',403);
 const [ss,ts]=await Promise.all([tx.get(shopRef(a.uid)),tx.get(ticketRef(a.uid,a.ticketId))]);const t=ts.data() as Ticket|undefined;
 ensure(ss.exists&&!ss.data()!.deleting&&t&&t.accessEpoch[a.scope as 'customer'|'family']===a.epoch,'This private link is unavailable. Ask the shop for a new link.',403);return {a,t,ref:ts.ref};
}
export async function track(token:string){return db.runTransaction(async tx=>{const {a,t}=await scoped(tx,token);return projection(t,a.scope,now());});}
export async function customerDecision(d:any){
 return db.runTransaction(async tx=>{
  const {a,t,ref}=await scoped(tx,d.token);ensure(a.scope==='customer','This private link does not allow a decision.',403);
  const cmd=shopRef(a.uid).collection('commands').doc(`web_${digest(d.token+':'+d.requestId)}`);const prev=await tx.get(cmd);
  const fingerprint=digest(JSON.stringify({version:d.version,value:d.value,ticketId:t.id}));
  if(prev.exists){ensure(prev.data()!.fingerprint===fingerprint,'Decision retry conflict.');return {ok:true,replayed:true};}
  const updated=mutate(t,'decision',{...d,channel:'web',verification:'Customer-scoped private link; no independent identity verification'},'customer-link',now());
  tx.set(ref,updated);tx.create(cmd,{fingerprint,result:{ok:true},at:now()});return {ok:true};
 });
}
export async function listTickets(uid:string,d:any){
 await getShop(uid);const snap=await shopRef(uid).collection('tickets').orderBy('createdAt','desc').limit(10001).get();
 ensure(snap.size<=10000,'Search limit reached. Contact support for migration.');
 let tickets=snap.docs.map(s=>s.data() as Ticket);const q=(d.query||'').toLowerCase();
 tickets=tickets.filter(t=>(d.history?t.status==='Delivered':t.status!=='Delivered')&&(!d.status||t.status===d.status)&&(!d.from||t.createdAt>=d.from)&&(!d.to||t.createdAt<=d.to)&&(!q||`${t.number} ${t.customerName} ${t.model}`.toLowerCase().includes(q)));
 return {total:tickets.length,page:d.page,pageSize:25,tickets:tickets.slice(d.page*25,(d.page+1)*25).map(t=>({id:t.id,number:t.number,customerName:t.customerName,device:`${t.brand} ${t.model}`,status:t.status,checkInAt:t.checkInAt,createdAt:t.createdAt}))};
}
export async function dashboard(uid:string,d:any){
 await getShop(uid);const snap=await shopRef(uid).collection('tickets').limit(10001).get();ensure(snap.size<=10000,'Dashboard limit reached.');const all=snap.docs.map(s=>s.data() as Ticket);
 const within=(at:string)=>(!d.from||at>=d.from)&&(!d.to||at<=d.to);const records=all.filter(t=>within(t.createdAt));
 return {open:records.filter(t=>t.status!=='Delivered').length,ready:records.filter(t=>t.status==='Ready for Pickup'||t.status==='Ready for Return').length,delivered:all.filter(t=>t.final&&within(t.final.at)).length,paidMinor:all.reduce((s,t)=>s+t.payments.filter(p=>within(p.at)).reduce((a,p)=>a+p.amountMinor,0),0),byStatus:Object.fromEntries(['Received','Checking','Awaiting Approval','Repairing','Ready for Pickup','Ready for Return'].map(s=>[s,records.filter(t=>t.status===s).length]))};
}
export async function photo(uid:string,d:any){const t=await getTicket(uid,d.ticketId);ensure(t.photoPaths[d.slot],'Photo not found.',404);const [data]=await bucket().file(t.photoPaths[d.slot]).download();return {base64:data.toString('base64')};}
export async function deleteAccount(uid:string){
 await db.runTransaction(async tx=>{const ref=shopRef(uid),deletion=db.doc(`deletionRequests/${uid}`);const [s,existing]=await Promise.all([tx.get(ref),tx.get(deletion)]);if(existing.exists)return;if(s.exists)tx.update(ref,{deleting:true});tx.create(deletion,{requestedAt:now(),purgeAfter:new Date(Date.now()+7*86400000).toISOString()});});return {ok:true,message:'Account is disabled in RepairProof. Account and associated shop data will be deleted within 7–8 days.'};
}
export async function maintenance(){
 const requests=await db.collection('deletionRequests').where('purgeAfter','<=',now()).limit(20).get();
 for(const r of requests.docs){const uid=r.id;await bucket().deleteFiles({prefix:`shops/${uid}/`});const a=await db.collection('access').where('uid','==',uid).get();for(const doc of a.docs)await doc.ref.delete();await db.recursiveDelete(shopRef(uid));await getAuth().deleteUser(uid).catch((e:any)=>{if(e.code!=='auth/user-not-found')throw e;});await r.ref.delete();}
 const old=await db.collectionGroup('uploads').where('consumed','==',false).get();
 for(const item of old.docs){if(item.data().createdAt>=new Date(Date.now()-86400000).toISOString())continue;const path=await db.runTransaction(async tx=>{const s=await tx.get(item.ref);if(!s.exists||s.data()!.consumed)return null;tx.update(item.ref,{deleting:true});return s.data()!.path;});if(path){await bucket().file(path).delete({ignoreNotFound:true});await item.ref.delete();}}
 const rates=await db.collection('rateLimits').where('expiresAt','<',new Date()).limit(500).get();const batch=db.batch();rates.docs.forEach(s=>batch.delete(s.ref));await batch.commit();
 const expired=await db.collection('access').where('expiresAt','<',now()).limit(500).get();const b=db.batch();expired.docs.forEach(s=>b.delete(s.ref));await b.commit();
}
