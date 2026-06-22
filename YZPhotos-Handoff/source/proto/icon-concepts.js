/* ═══════════════════════════════════════════════════════════
   YZPhotos — 6 concepts d'icône exotiques
   Chaque fonction dessine sur un canvas carré.
   ═══════════════════════════════════════════════════════════ */
(function () {
  function rr(ctx,x,y,w,h,r){
    ctx.beginPath();
    ctx.moveTo(x+r,y);ctx.lineTo(x+w-r,y);ctx.arcTo(x+w,y,x+w,y+r,r);
    ctx.lineTo(x+w,y+h-r);ctx.arcTo(x+w,y+h,x+w-r,y+h,r);
    ctx.lineTo(x+r,y+h);ctx.arcTo(x,y+h,x,y+h-r,r);
    ctx.lineTo(x,y+r);ctx.arcTo(x,y,x+r,y,r);ctx.closePath();
  }
  function fill(ctx,W,H,a,b,ang){
    const g=ctx.createLinearGradient(0,0,W*Math.cos(ang),H*Math.sin(ang));
    g.addColorStop(0,a);g.addColorStop(1,b);ctx.fillStyle=g;ctx.fillRect(0,0,W,H);
  }
  function blob(ctx,W,H,x,y,r,col){
    const g=ctx.createRadialGradient(x,y,0,x,y,r);
    g.addColorStop(0,col);g.addColorStop(1,'rgba(0,0,0,0)');
    ctx.fillStyle=g;ctx.fillRect(0,0,W,H);
  }
  function check(ctx,cx,cy,s,col,lw){
    ctx.save();ctx.strokeStyle=col;ctx.lineWidth=lw;ctx.lineCap='round';ctx.lineJoin='round';
    ctx.beginPath();
    ctx.moveTo(cx-s*0.46,cy+s*0.04);
    ctx.lineTo(cx-s*0.12,cy+s*0.40);
    ctx.lineTo(cx+s*0.52,cy-s*0.42);
    ctx.stroke();ctx.restore();
  }

  /* ── 1 · AURORA — mesh exotique + check ── */
  function aurora(ctx,W,H){
    const S=W/1024;
    fill(ctx,W,H,'#3A1B5E','#10122E',Math.PI*0.35);
    blob(ctx,W,H,W*0.18,H*0.16,W*0.75,'rgba(255,82,138,.95)');
    blob(ctx,W,H,W*0.9,H*0.2,W*0.6,'rgba(255,178,78,.85)');
    blob(ctx,W,H,W*0.85,H*0.9,W*0.8,'rgba(43,212,196,.85)');
    blob(ctx,W,H,W*0.1,H*0.92,W*0.65,'rgba(123,91,255,.8)');
    blob(ctx,W,H,W*0.5,H*0.5,W*0.3,'rgba(255,255,255,.18)');
    // soft glass disc behind check
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.25)';ctx.shadowBlur=60*S;ctx.shadowOffsetY=20*S;
    ctx.beginPath();ctx.arc(W/2,H/2,W*0.255,0,7);ctx.fillStyle='rgba(255,255,255,.16)';ctx.fill();
    ctx.restore();
    ctx.save();ctx.beginPath();ctx.arc(W/2,H/2,W*0.255,0,7);
    ctx.strokeStyle='rgba(255,255,255,.4)';ctx.lineWidth=3*S;ctx.stroke();ctx.restore();
    check(ctx,W/2,H/2,W*0.34,'#fff',46*S);
  }

  /* ── 2 · FAILLE — photo déchirée garder/poubelle ── */
  function faille(ctx,W,H){
    const S=W/1024;
    // deep backdrop
    fill(ctx,W,H,'#1A1130','#0A0712',Math.PI*0.4);
    blob(ctx,W,H,W*0.5,H*0.4,W*0.55,'rgba(120,80,180,.3)');
    const mx=W/2, slant=H*0.14, gap=12*S, push=30*S;
    // shared photo painter
    const paintPhoto=()=>{
      const sky=ctx.createLinearGradient(0,0,0,H);
      sky.addColorStop(0,'#FFC56B');sky.addColorStop(.42,'#FF7E7E');sky.addColorStop(1,'#9B5BD6');
      ctx.fillStyle=sky;ctx.fillRect(-120,-120,W+240,H+240);
      ctx.fillStyle='rgba(255,243,210,.96)';ctx.beginPath();ctx.arc(W*0.5,H*0.40,W*0.135,0,7);ctx.fill();
      ctx.fillStyle='#7A4AA8';ctx.beginPath();ctx.moveTo(-60,H*0.74);ctx.quadraticCurveTo(W*0.5,H*0.58,W+60,H*0.80);ctx.lineTo(W+60,H+60);ctx.lineTo(-60,H+60);ctx.closePath();ctx.fill();
      ctx.fillStyle='#5E3686';ctx.beginPath();ctx.moveTo(-60,H*0.86);ctx.quadraticCurveTo(W*0.55,H*0.72,W+60,H*0.92);ctx.lineTo(W+60,H+60);ctx.lineTo(-60,H+60);ctx.closePath();ctx.fill();
    };
    const half=(side)=>{
      ctx.save();
      ctx.translate(side*push,0);ctx.rotate(side*0.018);
      ctx.beginPath();
      if(side<0){ ctx.moveTo(-200,-200);ctx.lineTo(mx-gap-slant,-200);ctx.lineTo(mx-gap+slant,H+200);ctx.lineTo(-200,H+200);}
      else{ ctx.moveTo(mx+gap-slant,-200);ctx.lineTo(W+200,-200);ctx.lineTo(W+200,H+200);ctx.lineTo(mx+gap+slant,H+200);}
      ctx.closePath();
      // soft shadow under the lifted edge
      ctx.save();ctx.shadowColor='rgba(0,0,0,.45)';ctx.shadowBlur=40*S;ctx.shadowOffsetX=side*-14*S;
      ctx.fillStyle='#000';ctx.fill();ctx.restore();
      ctx.clip();
      paintPhoto();
      // verdict tint (subtle, only near torn edge)
      const tg=ctx.createLinearGradient(side<0?mx:mx,0,side<0?mx-W*0.5:mx+W*0.5,0);
      tg.addColorStop(0, side<0?'rgba(229,72,77,.55)':'rgba(36,200,120,.5)');
      tg.addColorStop(1,'rgba(0,0,0,0)');
      ctx.fillStyle=tg;ctx.fillRect(-200,-200,W+400,H+400);
      ctx.restore();
    };
    half(-1);half(1);
    // verdict badges
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.35)';ctx.shadowBlur=20*S;ctx.shadowOffsetY=6*S;
    ctx.beginPath();ctx.arc(W*0.235,H*0.235,58*S,0,7);ctx.fillStyle='#fff';ctx.fill();
    ctx.beginPath();ctx.arc(W*0.765,H*0.765,58*S,0,7);ctx.fillStyle='#fff';ctx.fill();
    ctx.restore();
    // ✕ red
    ctx.save();ctx.strokeStyle='#E5484D';ctx.lineWidth=16*S;ctx.lineCap='round';
    const xs=22*S,xx=W*0.235,xy=H*0.235;
    ctx.beginPath();ctx.moveTo(xx-xs,xy-xs);ctx.lineTo(xx+xs,xy+xs);ctx.moveTo(xx+xs,xy-xs);ctx.lineTo(xx-xs,xy+xs);ctx.stroke();ctx.restore();
    // ✓ green
    check(ctx,W*0.765,H*0.765,72*S,'#22B866',15*S);
  }

  /* ── 3 · ÉVENTAIL — cartes en éventail ── */
  function eventail(ctx,W,H){
    const S=W/1024;
    fill(ctx,W,H,'#1B2342','#0B0E1E',Math.PI*0.4);
    blob(ctx,W,H,W*0.5,H*0.3,W*0.6,'rgba(90,110,200,.4)');
    const cards=[
      {a:-34,col:['#FF8A5B','#FF5E7E']},
      {a:-12,col:['#FFD166','#FF9F45']},
      {a:10, col:['#4ECDC4','#2B9EB3']},
      {a:32, col:['#9B6DFF','#6C4BD8']},
    ];
    const cw=300*S,ch=380*S;
    cards.forEach((c)=>{
      ctx.save();
      ctx.translate(W/2,H*0.72);
      ctx.rotate(c.a*Math.PI/180);
      ctx.translate(0,-ch*0.72);
      ctx.shadowColor='rgba(0,0,0,.3)';ctx.shadowBlur=34*S;ctx.shadowOffsetY=10*S;
      rr(ctx,-cw/2,-ch/2,cw,ch,38*S);
      const g=ctx.createLinearGradient(-cw/2,-ch/2,cw/2,ch/2);
      g.addColorStop(0,c.col[0]);g.addColorStop(1,c.col[1]);
      ctx.fillStyle=g;ctx.fill();
      ctx.shadowColor='transparent';
      rr(ctx,-cw/2,-ch/2,cw,ch,38*S);
      ctx.strokeStyle='rgba(255,255,255,.3)';ctx.lineWidth=3*S;ctx.stroke();
      // little mountain glyph on each
      ctx.save();rr(ctx,-cw/2,-ch/2,cw,ch,38*S);ctx.clip();
      ctx.fillStyle='rgba(255,255,255,.22)';
      ctx.beginPath();ctx.moveTo(-cw*0.4,ch*0.4);ctx.lineTo(0,-ch*0.05);ctx.lineTo(cw*0.45,ch*0.4);ctx.closePath();ctx.fill();
      ctx.fillStyle='rgba(255,255,255,.7)';ctx.beginPath();ctx.arc(cw*0.22,-ch*0.22,30*S,0,7);ctx.fill();
      ctx.restore();
      ctx.restore();
    });
  }

  /* ── 4 · PRISME — pinwheel aperture ── */
  function prisme(ctx,W,H){
    const S=W/1024;
    fill(ctx,W,H,'#101225','#05060F',Math.PI*0.4);
    blob(ctx,W,H,W*0.5,H*0.5,W*0.55,'rgba(80,90,180,.35)');
    const cx=W/2,cy=H/2,R=W*0.33;
    const cols=['#FF5E8A','#FF9F45','#FFD166','#4ECDC4','#3A86FF','#9B6DFF'];
    const n=6;
    for(let i=0;i<n;i++){
      const a0=(i/n)*Math.PI*2 - Math.PI/2;
      const a1=((i+1)/n)*Math.PI*2 - Math.PI/2;
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(cx,cy);
      // curved blade
      const mid=(a0+a1)/2;
      ctx.lineTo(cx+Math.cos(a0)*R, cy+Math.sin(a0)*R);
      ctx.quadraticCurveTo(cx+Math.cos(mid)*R*1.18, cy+Math.sin(mid)*R*1.18, cx+Math.cos(a1)*R*0.62, cy+Math.sin(a1)*R*0.62);
      ctx.closePath();
      ctx.fillStyle=cols[i];ctx.fill();
      ctx.restore();
    }
    // center
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.4)';ctx.shadowBlur=30*S;
    ctx.beginPath();ctx.arc(cx,cy,W*0.085,0,7);ctx.fillStyle='#fff';ctx.fill();
    ctx.restore();
    ctx.beginPath();ctx.arc(cx,cy,W*0.045,0,7);ctx.fillStyle='#101225';ctx.fill();
  }

  /* ── 5 · ORBE — sphère glossy tropicale ── */
  function orbe(ctx,W,H){
    const S=W/1024;
    fill(ctx,W,H,'#0E1A2E','#060B16',Math.PI*0.4);
    blob(ctx,W,H,W*0.5,H*0.45,W*0.5,'rgba(40,120,200,.3)');
    const cx=W/2,cy=H*0.5,R=W*0.32;
    // sphere
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.5)';ctx.shadowBlur=70*S;ctx.shadowOffsetY=34*S;
    ctx.beginPath();ctx.arc(cx,cy,R,0,7);
    const g=ctx.createLinearGradient(cx-R,cy-R,cx+R,cy+R);
    g.addColorStop(0,'#FF6FB5');g.addColorStop(.5,'#A06BFF');g.addColorStop(1,'#3AC8E0');
    ctx.fillStyle=g;ctx.fill();ctx.restore();
    // inner shading
    ctx.save();ctx.beginPath();ctx.arc(cx,cy,R,0,7);ctx.clip();
    const sh=ctx.createRadialGradient(cx-R*0.4,cy-R*0.5,0,cx-R*0.4,cy-R*0.5,R*1.7);
    sh.addColorStop(0,'rgba(255,255,255,.5)');sh.addColorStop(.4,'rgba(255,255,255,0)');sh.addColorStop(1,'rgba(0,0,0,.4)');
    ctx.fillStyle=sh;ctx.fillRect(cx-R,cy-R,R*2,R*2);
    // swipe arc highlight
    ctx.strokeStyle='rgba(255,255,255,.6)';ctx.lineWidth=10*S;ctx.lineCap='round';
    ctx.beginPath();ctx.arc(cx,cy,R*0.66,-Math.PI*0.9,-Math.PI*0.25);ctx.stroke();
    ctx.restore();
    // specular dot
    ctx.beginPath();ctx.arc(cx-R*0.34,cy-R*0.42,R*0.12,0,7);ctx.fillStyle='rgba(255,255,255,.85)';ctx.fill();
    check(ctx,cx,cy+R*0.04,R*0.66,'rgba(255,255,255,.95)',30*S);
  }

  /* ── 6 · FLUX — ruban de tri ── */
  function flux(ctx,W,H){
    const S=W/1024;
    fill(ctx,W,H,'#0B1F2A','#071019',Math.PI*0.4);
    blob(ctx,W,H,W*0.25,H*0.2,W*0.6,'rgba(43,212,196,.4)');
    blob(ctx,W,H,W*0.8,H*0.85,W*0.6,'rgba(123,91,255,.4)');
    // flowing S ribbon
    const grad=ctx.createLinearGradient(W*0.2,H*0.2,W*0.8,H*0.8);
    grad.addColorStop(0,'#2BD4C4');grad.addColorStop(.5,'#3A86FF');grad.addColorStop(1,'#9B6DFF');
    ctx.save();
    ctx.strokeStyle=grad;ctx.lineWidth=92*S;ctx.lineCap='round';
    ctx.shadowColor='rgba(58,134,255,.5)';ctx.shadowBlur=40*S;
    ctx.beginPath();
    ctx.moveTo(W*0.26,H*0.26);
    ctx.bezierCurveTo(W*0.78,H*0.30, W*0.22,H*0.70, W*0.74,H*0.74);
    ctx.stroke();
    ctx.restore();
    // endpoint nodes: trash (red) at start, keep (green) at end
    ctx.beginPath();ctx.arc(W*0.26,H*0.26,40*S,0,7);ctx.fillStyle='#fff';ctx.fill();
    ctx.beginPath();ctx.arc(W*0.74,H*0.74,40*S,0,7);ctx.fillStyle='#fff';ctx.fill();
    check(ctx,W*0.74,H*0.74,46*S,'#28C878',13*S);
    // x at start
    ctx.save();ctx.strokeStyle='#E5484D';ctx.lineWidth=13*S;ctx.lineCap='round';
    const xs=15*S,xx=W*0.26,xy=H*0.26;
    ctx.beginPath();ctx.moveTo(xx-xs,xy-xs);ctx.lineTo(xx+xs,xy+xs);ctx.moveTo(xx+xs,xy-xs);ctx.lineTo(xx-xs,xy+xs);ctx.stroke();ctx.restore();
  }

  window.YZConcepts = {
    aurora, faille, eventail, prisme, orbe, flux,
    list:[
      ['aurora','Aurora','Mesh exotique tropical + check en pastille verre. Abstrait, premium, zéro skeuomorphisme.'],
      ['faille','Faille','Une photo déchirée en deux : gauche rouge (poubelle), droite verte (garder). Le geste de tri, dramatisé.'],
      ['eventail','Éventail','Cartes photo en éventail, palette corail→violet. Joyeux, dynamique, évoque la bibliothèque.'],
      ['prisme','Prisme','Diaphragme arc-en-ciel en moulinet. Photo + mouvement de tri, géométrique et vif.'],
      ['orbe','Orbe','Sphère glossy tropicale avec arc de swipe et check. Profondeur, effet « liquid glass ».'],
      ['flux','Flux','Ruban fluide du ✕ (poubelle) vers le ✓ (garder). Le flux de tri, minimal et abstrait.'],
    ]
  };
})();
