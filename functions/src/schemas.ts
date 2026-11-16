import {z} from 'zod';
const text=(n:number)=>z.string().trim().min(1).max(n);
const optionalText=(n:number)=>z.string().trim().max(n).default('');
export const id=z.string().regex(/^[A-Za-z0-9_-]{12,80}$/);
const money=z.number().int().min(0).max(100000000);
export const contact=z.object({kind:z.enum(['A','B','C']),number:optionalText(24),recipient:optionalText(100),permission:z.boolean(),purpose:optionalText(160)}).strict().superRefine((v,c)=>{
 if(v.kind!=='C'&&!/^\+?[0-9 ()-]{7,24}$/.test(v.number))c.addIssue({code:'custom',message:'Enter a reachable alternate contact number.'});
 if(v.kind==='B'&&(!v.permission||!v.recipient||!v.purpose))c.addIssue({code:'custom',message:'Family contact requires recipient, purpose and customer permission.'});
 if(v.kind==='C'&&(v.number||v.recipient))c.addIssue({code:'custom',message:'Case C must not retain a contact number or recipient.'});
});
const request={requestId:id};const ticket={...request,ticketId:id};
const line=z.object({description:text(180),kind:z.enum(['parts','labour']),quantity:z.number().int().min(1).max(100),unitMinor:money}).strict();
const shopFields={name:text(100),phone:text(24),address:text(240),hours:text(120),warrantyTerms:text(1200),timezone:z.literal('Asia/Karachi')};
export const schemas={
 onboard:z.object({...request,...shopFields}).strict(),
 updateShop:z.object({...request,...shopFields}).strict(),
 createTicket:z.object({...request,customerName:text(100),brand:text(60),model:text(80),problem:text(1200),condition:text(800),accessories:optionalText(400),contact,estimateMinor:money,returnFeeMinor:money,returnFeeAgreement:optionalText(300),checkInAt:z.string().datetime(),acknowledgement:text(400),photoSlots:z.array(z.number().int().min(0).max(3)).max(4)}).strict().superRefine((v,c)=>{if(v.returnFeeMinor&&!v.returnFeeAgreement)c.addIssue({code:'custom',message:'A return charge requires prior agreement.'});if(new Set(v.photoSlots).size!==v.photoSlots.length)c.addIssue({code:'custom',message:'Duplicate photo slots.'});}),
 upload:z.object({...request,slot:z.number().int().min(0).max(3),base64:text(4200000)}).strict(),
 getShop:z.object({}).strict(),
 list:z.object({query:optionalText(100),status:optionalText(40),history:z.boolean().default(false),page:z.number().int().min(0).max(500).default(0),from:optionalText(30),to:optionalText(30)}).strict(),
 dashboard:z.object({from:optionalText(30),to:optionalText(30)}).strict(),
 detail:z.object({ticketId:id}).strict(),
 photo:z.object({ticketId:id,slot:z.number().int().min(0).max(3)}).strict(),
 issueQuote:z.object({...ticket,diagnosis:text(1200),items:z.array(line).min(1).max(30)}).strict(),
 decision:z.object({...ticket,version:z.number().int().min(1),value:z.enum(['approved','declined']),channel:z.enum(['phone','in_person']),verification:text(400)}).strict(),
 transition:z.object({...ticket,to:z.enum(['Checking','Repairing','Ready for Pickup','Ready for Return']),note:optionalText(400),completed:z.boolean().default(false),checked:z.boolean().default(false)}).strict(),
 contact:z.object({...ticket,contact,verification:text(400),permission:z.literal(true)}).strict(),
 communication:z.object({...ticket,channel:z.enum(['call','manual_share','in_person']),outcome:z.enum(['no answer','spoke to customer','message passed through family','outcome unknown']),note:optionalText(400)}).strict(),
 issueAccess:z.object({...ticket,scope:z.enum(['customer','family']),days:z.number().int().min(1).max(365).default(30),customerPermission:z.boolean().default(false)}).strict(),
 revokeAccess:z.object({...ticket,scope:z.enum(['customer','family'])}).strict(),
 reissueClaim:z.object({...ticket,reason:text(300)}).strict(),
 handover:z.object({...ticket,code:optionalText(80),recoveryNote:optionalText(500),collector:text(100),deviceMatched:z.literal(true),accessoriesChecked:z.literal(true),physicalHandover:z.literal(true),accessories:optionalText(400),paidMinor:money,paymentMethod:z.enum(['cash','bank transfer','unpaid']),warranty:z.object({start:z.string().regex(/^\d{4}-\d{2}-\d{2}$/),end:z.string().regex(/^\d{4}-\d{2}-\d{2}$/),covered:text(500),exclusions:text(500)}).strict().nullable()}).strict().superRefine((v,c)=>{if(!v.code&&v.recoveryNote.length<30)c.addIssue({code:'custom',message:'Collection proof or a detailed manual resolution is required.'});if(v.paidMinor>0&&v.paymentMethod==='unpaid')c.addIssue({code:'custom',message:'Select the actual payment method.'});}),
 payment:z.object({...ticket,amountMinor:money,method:z.enum(['cash','bank transfer'])}).strict(),
 deleteAccount:z.object({...request,confirmation:z.literal('DELETE MY ACCOUNT')}).strict(),
} as const;
export const tracking=z.object({token:z.string().regex(/^[A-Za-z0-9_-]{43}$/)}).strict();
export const webDecision=tracking.extend({requestId:id,version:z.number().int().min(1),value:z.enum(['approved','declined'])}).strict();
