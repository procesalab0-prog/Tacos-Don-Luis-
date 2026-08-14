const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const PORTALES=[['/','Inicio'],['/pedir/','Cliente'],['/admin/','Admin'],['/repartidor/','Repartidor']];
const ANCHOS=[320,390,430];
(async()=>{
  const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium'});
  const hallazgos=[];
  for(const [ruta,nom] of PORTALES){
    for(const w of ANCHOS){
      const p=await b.newPage({viewport:{width:w,height:800},deviceScaleFactor:2});
      const errs=[],r404=[];
      p.on('pageerror',x=>errs.push(x.message));
      p.on('response',r=>{const u=r.url();if(r.status()>=400&&!u.includes('supabase')&&!u.includes('fonts.'))r404.push(r.status()+' '+u.split('/').pop());});
      await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
      await p.goto('http://localhost:8850'+ruta,{waitUntil:'networkidle'}).catch(()=>{});
      await p.waitForTimeout(2200);
      const d=await p.evaluate(()=>{
        const W=document.documentElement.clientWidth;
        const desb=[];
        document.querySelectorAll('*').forEach(e=>{const r=e.getBoundingClientRect();
          if(r.width>0&&r.right>W+1)desb.push({t:(e.innerText||e.tagName).trim().slice(0,34),w:Math.round(r.width),der:Math.round(r.right)});});
        // objetivos táctiles: botones y enlaces visibles
        const chicos=[...document.querySelectorAll('button,a,[role=button],input[type=checkbox]')]
          .filter(e=>{const r=e.getBoundingClientRect();const s=getComputedStyle(e);
            return r.width>0&&r.height>0&&s.visibility!=='hidden'&&s.display!=='none'&&(r.height<44||r.width<44);})
          .map(e=>{const r=e.getBoundingClientRect();
            return {txt:(e.innerText||e.getAttribute('aria-label')||e.tagName).trim().slice(0,26),
                    px:Math.round(r.width)+'x'+Math.round(r.height)};});
        return {scroll:document.documentElement.scrollWidth>W,
                desb:desb.slice(0,3), chicos:chicos.slice(0,8), totalChicos:chicos.length};
      });
      if(d.scroll)hallazgos.push(`${nom} @${w}px — SCROLL HORIZONTAL: ${JSON.stringify(d.desb[0]||{})}`);
      if(d.totalChicos)hallazgos.push(`${nom} @${w}px — ${d.totalChicos} objetivos táctiles <44px: ${d.chicos.map(c=>c.txt+' ('+c.px+')').join(', ')}`);
      if(errs.length)hallazgos.push(`${nom} @${w}px — ERROR JS: ${errs[0].slice(0,90)}`);
      if(r404.length)hallazgos.push(`${nom} @${w}px — recursos fallidos: ${[...new Set(r404)].join(', ')}`);
      await p.close();
    }
  }
  console.log(hallazgos.length?hallazgos.join('\n'):'sin hallazgos');
  await b.close();
})().catch(x=>{console.log('FALLO:',x.message.split('\n')[0]);process.exit(1);});
