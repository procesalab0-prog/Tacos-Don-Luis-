const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const URL='http://localhost:8850/pedir/index.html';
const R=[]; const ok=(n,c,d='')=>R.push(`${(c?'PASA':'FALLA').padEnd(6)} ${n}${d?'   — '+d:''}`);

async function alCheckout(b,resp){
  const p=await b.newPage({viewport:{width:390,height:1100},deviceScaleFactor:2});
  p.setDefaultTimeout(9000); p._errs=[]; p._envios=0; p._toasts=[];
  p.on('pageerror',e=>p._errs.push(e.message));
  await p.exposeFunction('__t',m=>p._toasts.push(m));
  await p.addInitScript(()=>{const v=new Set();setInterval(()=>{if(!document.body)return;
    document.querySelectorAll('div').forEach(e=>{if(getComputedStyle(e).position!=='fixed')return;
      const t=(e.innerText||'').trim(); if(t&&t.length<160&&!v.has(t)){v.add(t);window.__t&&window.__t(t);}});},120);});
  await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
  await p.route(/functions\/v1\/create-guest-order/,r=>{p._envios++;resp(r);});
  await p.route(/supabase\.co\/rest/,r=>{
    const u=r.request().url(); const j=x=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(x)});
    if(u.includes('/branches'))return j([{id:'b1',name:'Punto Cañada',address_line:'Blvd. Campestre 2802',latitude:21.1533557,longitude:-101.7273936}]);
    if(u.includes('/products'))return j([{id:'p1',category_id:'c1',name:'Taco al pastor',description:'Cerdo al pastor, cebolla y cilantro',
        price:17,image_url:null,is_available:true,is_featured:true,sort_order:1,customization:null}]);
    if(u.includes('/categories'))return j([{id:'c1',name:'Tacos',sort_order:1,is_active:true}]);
    if(u.includes('/business_settings'))return j([{branch_id:'b1',is_open:true,is_saturated:false,accepts_cash:true,
        accepts_transfer:true,accepts_card_on_delivery:true,minimum_delivery_amount:100}]);
    if(u.includes('/delivery_zones'))return j([{id:'z1',name:'Zona 1',max_km:3,price:25,minimum_order:100,is_active:true}]);
    return j([]);
  });
  await p.goto(URL,{waitUntil:'networkidle'}); await p.waitForTimeout(1700);
  await p.getByText('Menú',{exact:true}).first().click(); await p.waitForTimeout(700);
  await p.getByText('Taco al pastor',{exact:true}).first().click(); await p.waitForTimeout(800);
  await p.getByRole('button',{name:'Con todo',exact:true}).first().click(); await p.waitForTimeout(300);
  await p.getByText('Agregar',{exact:false}).first().click(); await p.waitForTimeout(700);
  await p.locator('.dl-ico-carrito').first().click(); await p.waitForTimeout(800);
  await p.getByRole('button',{name:'Continuar',exact:true}).first().click(); await p.waitForTimeout(1200);
  // nombre y teléfono
  for(const [f,v] of [['nombre','Ana Torres'],['tel','4771234567']]){
    await p.locator(`[data-field="${f}"]`).first().fill(v).catch(()=>{});
  }
  // efectivo: con cuánto paga
  await p.evaluate(()=>{const n=[...document.querySelectorAll('input')].find(i=>/cuánto|cuanto|paga/i.test((i.placeholder||'')+(i.getAttribute('aria-label')||'')))
    ||[...document.querySelectorAll('input[inputmode=decimal],input[type=number]')].pop();
    if(n){n.value='500';n.dispatchEvent(new Event('input',{bubbles:true}));}});
  await p.waitForTimeout(600);
  return p;
}
const enviar=async p=>{await p.getByRole('button',{name:/Hacer pedido/i}).first().click().catch(()=>{});await p.waitForTimeout(1600);};

(async()=>{
const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium'});

// F1 el pedido sí se crea
{const p=await alCheckout(b,r=>r.fulfill({status:200,contentType:'application/json',
   body:JSON.stringify({folio:'1042',trackingToken:'t'.repeat(64),order:{id:'o1',folio:'1042',status:'pending_acceptance'}})}));
 await enviar(p);
 const t=await p.evaluate(()=>document.body.innerText);
 ok('F1 el pedido llega al servidor', p._envios===1, `envíos: ${p._envios} · avisos: ${JSON.stringify(p._toasts.slice(-2))}`);
 ok('F1 muestra confirmación con folio', /1042/.test(t), '');
 await p.close();}

// F2 servidor caído (500)
{const p=await alCheckout(b,r=>r.fulfill({status:500,contentType:'application/json',body:JSON.stringify({error:'boom'})}));
 await enviar(p);
 const t=await p.evaluate(()=>document.body.innerText);
 ok('F2 error 500 avisa', /no se pudo|no pudimos|error|intenta/i.test(p._toasts.join(' ')), JSON.stringify(p._toasts.slice(-2)));
 ok('F2 error 500 no truena', p._errs.length===0, p._errs[0]?.slice(0,60)||'');
 ok('F2 no se pierde el carrito', !/1042/.test(t), '');
 await p.close();}

// F3 sin red
{const p=await alCheckout(b,r=>r.abort('failed'));
 await enviar(p);
 ok('F3 sin red avisa', p._toasts.some(x=>/no se pudo|no pudimos|error|conex|intenta/i.test(x)), JSON.stringify(p._toasts.slice(-2)));
 ok('F3 sin red no truena', p._errs.length===0, p._errs[0]?.slice(0,60)||'');
 await p.close();}

// F4 doble toque en Hacer pedido -> ¿pedido duplicado?
{const p=await alCheckout(b,async r=>{await new Promise(s=>setTimeout(s,900));
   r.fulfill({status:200,contentType:'application/json',body:JSON.stringify({folio:'1042',trackingToken:'t'.repeat(64),order:{id:'o1',folio:'1042',status:'pending_acceptance'}})});});
 const bt=p.getByRole('button',{name:/Hacer pedido/i}).first();
 await bt.click().catch(()=>{}); await p.waitForTimeout(120);
 await bt.click({force:true}).catch(()=>{}); await p.waitForTimeout(120);
 await bt.click({force:true}).catch(()=>{});
 await p.waitForTimeout(2600);
 ok('F4 triple toque NO duplica el pedido', p._envios===1, `envíos al servidor: ${p._envios}`);
 await p.close();}

console.log(R.join('\n'));
await b.close();
})().catch(x=>{console.log('FALLO DEL ARNÉS:',x.message.split('\n')[0]);process.exit(1);});
