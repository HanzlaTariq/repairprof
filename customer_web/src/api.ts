const base=import.meta.env.VITE_API_BASE||'/api';
export async function post<T>(path:string,data:unknown,bearer?:string):Promise<T>{
 const r=await fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json',...(bearer?{Authorization:`Bearer ${bearer}`}:{})},body:JSON.stringify(data),cache:'no-store',referrerPolicy:'no-referrer',signal:AbortSignal.timeout(15000)});
 let json;try{json=await r.json();}catch{throw Error('Cannot reach the repair service. Please try again.');}
 if(!r.ok)throw Error(json.error||'This request could not be completed.');return json as T;
}
export function takeToken(){const hash=new URLSearchParams(location.hash.slice(1));const token=hash.get('t')||'';if(location.hash)history.replaceState(null,'',location.pathname+location.search);return token;}
