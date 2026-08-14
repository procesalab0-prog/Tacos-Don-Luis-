const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const REST=r=>{const u=r.request().url();const j=x=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(x)});
  if(u.includes('/branches'))return j([{id:'b1',name:'Punto Cañada',address_line:'X',latitude:21.15,longitude:-101.72}]);
  if(u.includes('/products'))return j([{id:'p1',category_id:'c1',name:'Taco al pastor',description:'x',price:17,image_url:null,is_available:true,is_featured:true,sort_order:1,customization:null}]);
  if(u.includes('/categories'))return j([{id:'c1',name:'Tacos',sort_order:1,is_active:true}]);
  if(u.includes('/business_settings'))return j([{branch_id:'b1',is_open:true,is_saturated:false,accepts_cash:true}]);
  return j([]);};
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium'});
 for(const [nom,resp] of [
   ['pedido inexistente (404)', r=>r.fulfill({status:404,contentType:'application/json',body:JSON.stringify({error:'Order not found'})})],
   ['sin red',                  r=>r.abort('failed')]]){
   const p=await b.newPage({viewport:{width:390,height:900},deviceScaleFactor:2});
   const errs=[]; p.on('pageerror',e=>errs.push(e.message));
   await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
   await p.route(/functions\/v1\/track-order/,resp);
   await p.route(/supabase\.co\/rest/,REST);
   await p.goto('http://localhost:8850/pedir/index.html?pedido='+'a'.repeat(64),{waitUntil:'networkidle'});
   let aviso='(ninguno)';
   for(let i=0;i<30;i++){await p.waitForTimeout(150);
     const t=await p.evaluate(()=>{const d=[...document.querySelectorAll('div')].find(e=>getComputedStyle(e).position==='fixed'&&(e.innerText||'').trim()&&!(e.innerText||'').includes('{{'));return d?d.innerText.trim():null;});
     if(t&&!/Easter/.test(t)){aviso=t.replace(/\n/g,' ');break;}}
   const tok=await p.evaluate(()=>localStorage.getItem('donLuisTrackingToken'));
   console.log(`${nom.padEnd(26)} aviso: ${aviso}`);
   console.log(`${''.padEnd(26)} token: ${tok?'CONSERVADO (seguirá reintentando)':'borrado'} · errores: ${errs.length?errs[0].slice(0,40):0}`);
   await p.close();
 }
 await b.close();})().catch(x=>{console.log('FALLO:',x.message);process.exit(1);});
