const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const R=[]; const ok=(n,c,d='')=>R.push(`${(c?'PASA':'FALLA').padEnd(6)} ${n}${d?'   — '+d:''}`);
async function pg(b,gotoUrl,authResp){
  const p=await b.newPage({viewport:{width:390,height:900},deviceScaleFactor:2});
  p.setDefaultTimeout(9000); p._errs=[]; p._toasts=[];
  p.on('pageerror',e=>p._errs.push(e.message));
  await p.exposeFunction('__t',m=>p._toasts.push(m));
  await p.addInitScript(()=>{const v=new Set();setInterval(()=>{if(!document.body)return;
    document.querySelectorAll('div,p,span').forEach(e=>{const s=getComputedStyle(e);
      if(s.position!=='fixed'&&!/rgb\(214, 69, 61\)|rgb\(185/.test(s.color))return;
      const t=(e.innerText||'').trim(); if(t&&t.length<200&&!v.has(t)){v.add(t);window.__t&&window.__t(t);}});},150);});
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  if(authResp) await p.route(/auth\/v1\/token/,authResp);
  await p.route(/supabase\.co\/rest/,r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(gotoUrl,{waitUntil:'networkidle'}); await p.waitForTimeout(1800);
  return p;
}
const llenaLogin=async(p,mail,pass)=>{
  const ins=await p.locator('input').all();
  if(ins[0])await ins[0].fill(mail).catch(()=>{});
  if(ins[1])await ins[1].fill(pass).catch(()=>{});
  await p.waitForTimeout(200);
  const b=await p.evaluate(()=>{const x=[...document.querySelectorAll('button')].find(b=>/entrar|iniciar|acceder/i.test(b.innerText));return x?x.innerText.trim():null;});
  if(b) await p.getByRole('button',{name:b,exact:true}).first().click().catch(()=>{});
  await p.waitForTimeout(1800); return b;
};
(async()=>{
const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium'});

for(const [nom,url] of [['Admin','http://localhost:8850/admin/'],['Repartidor','http://localhost:8850/repartidor/']]){
  // contraseña incorrecta: GoTrue responde con 'msg', no 'message'
  const p=await pg(b,url,r=>r.fulfill({status:400,contentType:'application/json',
    body:JSON.stringify({error:'invalid_grant',error_description:'Invalid login credentials',msg:'Invalid login credentials'})}));
  const btn=await llenaLogin(p,'quien@ejemplo.com','malapass');
  const t=await p.evaluate(()=>document.body.innerText);
  const men=(t+' '+p._toasts.join(' '));
  ok(`${nom} · hay pantalla de acceso`, !!btn, btn||'sin botón');
  ok(`${nom} · avisa contraseña incorrecta`, /incorrect|inválid|no coincide|credencial|revisa/i.test(men),
     (men.match(/[^\n]*(incorrect|inválid|credencial|Invalid|error)[^\n]*/i)?.[0]||'SIN MENSAJE').slice(0,80));
  ok(`${nom} · el mensaje está en español`, !/Invalid login credentials|Failed to fetch/i.test(men),
     /Invalid login credentials/i.test(men)?'muestra el texto crudo en inglés':'');
  ok(`${nom} · no truena`, p._errs.length===0, p._errs[0]?.slice(0,60)||'');
  await p.close();
}
console.log(R.join('\n'));
await b.close();
})().catch(x=>{console.log('FALLO DEL ARNÉS:',x.message.split('\n')[0]);process.exit(1);});
