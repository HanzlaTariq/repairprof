import {createHash, randomBytes, timingSafeEqual} from 'node:crypto';
export const statuses = ['Received','Checking','Awaiting Approval','Repairing','Ready for Pickup','Ready for Return','Delivered'] as const;
export type Status = typeof statuses[number];
export type Contact = {kind:'A'|'B'|'C'; number:string; recipient:string; permission:boolean; purpose:string; permissionAt?:string};
export type Line = {description:string; kind:'parts'|'labour'; quantity:number; unitMinor:number};
export type Decision = {value:'approved'|'declined'; at:string; channel:'web'|'phone'|'in_person'; actor:string; verification:string};
export type Quote = {version:number; diagnosis:string; items:Line[]; totalMinor:number; issuedAt:string; decision?:Decision};
export type Shop = {name:string; phone:string; address:string; hours:string; warrantyTerms:string; timezone:string; deleting?:boolean};
export type Event = {type:string; at:string; actor:string; from:Status; to:Status; note:string};
export type Ticket = {
 id:string; number:string; customerName:string; brand:string; model:string; problem:string; condition:string; accessories:string;
 contact:Contact; estimateMinor:number; returnFeeMinor:number; returnFeeAgreement:string; checkInAt:string; acknowledgement:string;
 createdAt:string; updatedAt:string; status:Status; shop:Shop; photoPaths:string[]; quotes:Quote[]; events:Event[];
 communications:{at:string; recipient:string; channel:string; outcome:string; note:string; actor:string}[];
 payments:{id:string; at:string; amountMinor:number; method:string; actor:string}[];
 accessEpoch:{customer:number;family:number}; outcome?:'repaired'|'returned unrepaired';
 final?:{items:Line[]; totalMinor:number; paidMinor:number; balanceMinor:number; collector:string; accessories:string; at:string; verification:string; warranty:null|{start:string;end:string;covered:string;exclusions:string;terms:string}};
};
export class AppError extends Error {constructor(public status:number, message:string){super(message);}}
export function ensure(ok:unknown, message:string, status=409):asserts ok {if(!ok)throw new AppError(status,message);}
export const digest=(value:string)=>createHash('sha256').update(value).digest('hex');
export const secret=()=>randomBytes(32).toString('base64url');
export const collectionCode=()=>randomBytes(9).toString('hex').toUpperCase().match(/.{6}/g)!.join('-');
export const claimHash=(code:string)=>digest(code.toUpperCase().replace(/[^A-Z0-9]/g,''));
export function sameHash(a:string,b:string){return a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));}
export function total(items:Line[]){const n=items.reduce((s,i)=>s+i.quantity*i.unitMinor,0);ensure(Number.isSafeInteger(n)&&n>=0&&n<=100000000,'Quotation total exceeds the limit.',400);return n;}
export const latest=(t:Ticket)=>t.quotes.at(-1);
export const shopDate=(iso:string)=>new Date(new Date(iso).getTime()+5*3600000).toISOString().slice(0,10);
export function event(t:Ticket,type:string,actor:string,at:string,note:string,to:Status=t.status){
 ensure(t.events.length<400,'Ticket audit capacity reached. Export and contact support.');
 t.events.push({type,at,actor,from:t.status,to,note});t.status=to;t.updatedAt=at;
}
export function mutate(original:Ticket, op:string, d:any, actor:string, at:string):Ticket{
 const t=structuredClone(original), q=latest(t);
 if(op==='issueQuote'){
  ensure(t.status==='Checking'||t.status==='Repairing'||t.status==='Awaiting Approval','A quote cannot be issued at this stage.');
  ensure(t.quotes.length<30,'Quote revision limit reached.');
  t.quotes.push({version:t.quotes.length+1,diagnosis:d.diagnosis,items:d.items,totalMinor:total(d.items),issuedAt:at});
  event(t,'quote',actor,at,`Quotation v${t.quotes.length} issued`,'Awaiting Approval');
 }else if(op==='decision'){
  ensure(t.status==='Awaiting Approval'&&q&&q.version===d.version,'Quotation changed. Refresh before deciding.');
  ensure(!q.decision,'This quotation already has a decision.');
  if(d.channel==='phone')ensure(t.contact.kind!=='C','No remote contact is available. Record an in-person decision.');
  q.decision={value:d.value,at,channel:d.channel,actor,verification:d.verification};
  event(t,'decision',actor,at,`Quotation v${q.version} ${d.value}`,d.value==='declined'?'Ready for Return':t.status);
 }else if(op==='transition'){
  if(d.to==='Checking')ensure(t.status==='Received','Only received devices can enter checking.');
  else if(d.to==='Repairing')ensure(t.status==='Awaiting Approval'&&q?.decision?.value==='approved','Approve the current quotation before repair.');
  else if(d.to==='Ready for Pickup')ensure(t.status==='Repairing'&&q?.decision?.value==='approved'&&d.completed&&d.checked,'Complete and check the approved repair first.');
  else if(d.to==='Ready for Return')ensure(['Checking','Repairing'].includes(t.status)&&d.note.trim(),'Record why the device cannot be repaired.');
  else throw new AppError(409,'Use the quotation or collection workflow for this status.');
  event(t,'status',actor,at,d.note,d.to);
 }else if(op==='contact'){
  ensure(t.status!=='Delivered','Delivered tickets are read-only.');
  t.contact={...d.contact,permissionAt:at}; t.accessEpoch.customer++;t.accessEpoch.family++;
  event(t,'contact',actor,at,`Contact route changed with customer permission: ${d.verification}`);
 }else if(op==='communication'){
  ensure(t.contact.kind!=='C','Use the agreed in-person check-in arrangement.');
  ensure(t.communications.length<100,'Communication log limit reached.');
  t.communications.push({at,actor,recipient:t.contact.kind==='B'?t.contact.recipient:t.customerName,channel:d.channel,outcome:d.outcome,note:d.note});
  event(t,'communication',actor,at,'Contact attempt recorded');
 }else if(op==='handover'){
  ensure(['Ready for Pickup','Ready for Return'].includes(t.status),'Device is not ready for handover.');
  ensure(d.deviceMatched&&d.accessoriesChecked&&d.physicalHandover,'Confirm the device, accessories and physical handover.');
  const repaired=t.status==='Ready for Pickup';
  ensure(!repaired||q?.decision?.value==='approved','Current quotation approval is required.');
  const items:Line[]=repaired?q!.items:(t.returnFeeMinor?[{kind:'labour',description:'Previously agreed inspection/return charge',quantity:1,unitMinor:t.returnFeeMinor}]:[]);
  const amount=total(items);ensure(d.paidMinor<=amount,'Payment cannot exceed final charges.',400);
  ensure(repaired||!d.warranty,'An unrepaired return has no new repair warranty.',400);
  if(d.warranty)ensure(d.warranty.end>d.warranty.start&&d.warranty.start===shopDate(at),'Warranty starts on the handover date and ends later.',400);
  t.payments.push({id:d.requestId,amountMinor:d.paidMinor,method:d.paymentMethod,at,actor});
  t.outcome=repaired?'repaired':'returned unrepaired';
  t.final={items,totalMinor:amount,paidMinor:d.paidMinor,balanceMinor:amount-d.paidMinor,collector:d.collector,accessories:d.accessories,at,verification:d.recoveryNote||'Private collection code matched; device and collector checked',warranty:d.warranty?{...d.warranty,terms:t.shop.warrantyTerms}:null};
  event(t,'handover',actor,at,'Physical handover confirmed','Delivered');
 }else if(op==='payment'){
  ensure(t.status==='Delivered'&&t.final,'Final receipt required.');
  ensure(d.amountMinor>0&&d.amountMinor<=t.final.balanceMinor,'Payment must be positive and within outstanding balance.',400);
  t.payments.push({id:d.requestId,at,actor,amountMinor:d.amountMinor,method:d.method});
  t.final.paidMinor+=d.amountMinor;t.final.balanceMinor-=d.amountMinor;
  event(t,'payment',actor,at,'Settlement recorded');
 }else throw new AppError(400,'Unknown command.');
 return t;
}
export function projection(t:Ticket,scope:'customer'|'family',now:string){
 const common={scope,number:t.number,status:t.status,checkInAt:t.checkInAt,shop:{name:t.shop.name,phone:t.shop.phone,address:t.shop.address,hours:t.shop.hours,timezone:t.shop.timezone},refreshedAt:now};
 if(scope==='family')return common;
 const q=latest(t);
 return {...common,device:`${t.brand} ${t.model}`,timeline:t.events.filter(e=>['status','quote','decision','handover','received'].includes(e.type)).map(e=>({at:e.at,status:e.to,label:e.type==='quote'?'Quotation issued':e.type==='decision'?'Quotation decision recorded':e.to})),pendingQuote:t.status==='Awaiting Approval'&&q&&!q.decision?q:null,approvedMinor:q?.decision?.value==='approved'?q.totalMinor:null,outcome:t.outcome||null,receipt:t.final?{items:t.final.items,totalMinor:t.final.totalMinor,paidMinor:t.final.paidMinor,balanceMinor:t.final.balanceMinor,at:t.final.at,warranty:t.final.warranty,warrantyPeriodEnded:t.final.warranty?shopDate(now)>t.final.warranty.end:null}:null};
}
