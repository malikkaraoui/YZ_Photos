/* ═══════════════════════════════════════════════════════════
   YZPhotos — Moteur de rendu d'icône (canvas, paramétrable)
   variant: 'dark' | 'light' | 'tinted'
   Concept : photos empilées + geste de tri ←/→ + barre SSD
   Direction : indigo doux #5B5BD6, soft / léger / pur
   ═══════════════════════════════════════════════════════════ */
(function () {
  function rrect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x+r,y); ctx.lineTo(x+w-r,y);
    ctx.arcTo(x+w,y,x+w,y+r,r); ctx.lineTo(x+w,y+h-r);
    ctx.arcTo(x+w,y+h,x+w-r,y+h,r); ctx.lineTo(x+r,y+h);
    ctx.arcTo(x,y+h,x,y+h-r,r); ctx.lineTo(x,y+r);
    ctx.arcTo(x,y,x+r,y,r); ctx.closePath();
  }

  // Palettes par variante ────────────────────────────────
  const THEMES = {
    dark: {
      bgA:'#4B3FA8', bgB:'#5B5BD6', bgC:'#7A6FE0',
      glow:'rgba(150,140,255,.4)',
      cardBack:'rgba(255,255,255,.10)', cardBackBd:'rgba(255,255,255,.22)',
      cardMid:'rgba(255,255,255,.20)', cardMidBd:'rgba(255,255,255,.34)',
      photoSky:['#AFC7E8','#CFE0F2'], photoLand:['#8FB9A6','#6FA88E'],
      mtnFar:'#7E9BC4', mtnNear:'#5E84AD', snow:'rgba(255,255,255,.9)',
      pill:'rgba(255,255,255,.96)', pillDiv:'rgba(0,0,0,.1)',
      keep:'#28B463', trash:'#E5484D',
      ssd:'rgba(255,255,255,.18)', ssdBd:'rgba(255,255,255,.3)', ssdPort:'rgba(255,255,255,.35)',
      star:'rgba(235,240,255,.9)', starGlow:'rgba(190,200,255,.7)',
    },
    light: {
      bgA:'#EEECFB', bgB:'#E3E0FA', bgC:'#D9D5F7',
      glow:'rgba(255,255,255,.7)',
      cardBack:'rgba(91,91,214,.10)', cardBackBd:'rgba(91,91,214,.20)',
      cardMid:'rgba(91,91,214,.16)', cardMidBd:'rgba(91,91,214,.28)',
      photoSky:['#AFC7E8','#CFE0F2'], photoLand:['#9FCBB6','#7FB89E'],
      mtnFar:'#8EA9CE', mtnNear:'#6E94BD', snow:'rgba(255,255,255,.95)',
      pill:'#FFFFFF', pillDiv:'rgba(0,0,0,.08)',
      keep:'#28B463', trash:'#E5484D',
      ssd:'rgba(91,91,214,.14)', ssdBd:'rgba(91,91,214,.26)', ssdPort:'rgba(91,91,214,.4)',
      star:'rgba(91,91,214,.55)', starGlow:'rgba(91,91,214,.3)',
    },
    tinted: {
      bgA:'#0E0E12', bgB:'#17171C', bgC:'#202028',
      glow:'rgba(160,160,180,.18)',
      mono:true,
      cardBack:'rgba(255,255,255,.10)', cardBackBd:'rgba(255,255,255,.20)',
      cardMid:'rgba(255,255,255,.18)', cardMidBd:'rgba(255,255,255,.30)',
      photoSky:['#9A9AA8','#C2C2CE'], photoLand:['#7A7A86','#9A9AA6'],
      mtnFar:'#8A8A96', mtnNear:'#6A6A76', snow:'rgba(255,255,255,.85)',
      pill:'rgba(245,245,250,.95)', pillDiv:'rgba(0,0,0,.12)',
      keep:'#5A5A64', trash:'#3A3A42',
      ssd:'rgba(255,255,255,.16)', ssdBd:'rgba(255,255,255,.28)', ssdPort:'rgba(255,255,255,.32)',
      star:'rgba(235,235,245,.7)', starGlow:'rgba(200,200,215,.4)',
    },
  };

  function drawIcon(canvas, variant) {
    const T = THEMES[variant] || THEMES.dark;
    const ctx = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height, S = W / 1024;
    ctx.clearRect(0,0,W,H);

    // ── BACKGROUND ──
    const bg = ctx.createLinearGradient(0, 0, W*.65, H);
    bg.addColorStop(0, T.bgA); bg.addColorStop(.55, T.bgB); bg.addColorStop(1, T.bgC);
    ctx.fillStyle = bg; ctx.fillRect(0,0,W,H);

    // ambient glow
    const glow = ctx.createRadialGradient(W*.5,H*.40,0, W*.5,H*.40, W*.55);
    glow.addColorStop(0, T.glow); glow.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = glow; ctx.fillRect(0,0,W,H);

    const CX = W*.5, CY = H*.405, CW = 556*S, CH = 417*S, CR = 40*S;

    // ── BACK CARD ──
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.22)'; ctx.shadowBlur=48*S; ctx.shadowOffsetY=18*S;
    ctx.translate(CX-34*S, CY+26*S); ctx.rotate(-9*Math.PI/180);
    rrect(ctx,-CW/2,-CH/2,CW,CH,CR); ctx.fillStyle=T.cardBack; ctx.fill();
    ctx.restore();
    ctx.save(); ctx.translate(CX-34*S, CY+26*S); ctx.rotate(-9*Math.PI/180);
    rrect(ctx,-CW/2,-CH/2,CW,CH,CR); ctx.strokeStyle=T.cardBackBd; ctx.lineWidth=2.4*S; ctx.stroke();
    ctx.restore();

    // ── MIDDLE CARD ──
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.18)'; ctx.shadowBlur=36*S; ctx.shadowOffsetY=13*S;
    ctx.translate(CX-16*S, CY+12*S); ctx.rotate(-4.2*Math.PI/180);
    rrect(ctx,-CW/2,-CH/2,CW,CH,CR); ctx.fillStyle=T.cardMid; ctx.fill();
    ctx.restore();
    ctx.save(); ctx.translate(CX-16*S, CY+12*S); ctx.rotate(-4.2*Math.PI/180);
    rrect(ctx,-CW/2,-CH/2,CW,CH,CR); ctx.strokeStyle=T.cardMidBd; ctx.lineWidth=2.4*S; ctx.stroke();
    ctx.restore();

    // ── FRONT CARD (photo) ──
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.30)'; ctx.shadowBlur=80*S; ctx.shadowOffsetY=34*S;
    rrect(ctx,CX-CW/2,CY-CH/2,CW,CH,CR); ctx.fillStyle='#fff'; ctx.fill();
    ctx.restore();

    ctx.save();
    rrect(ctx,CX-CW/2,CY-CH/2,CW,CH,CR); ctx.clip();
    // sky
    const sky = ctx.createLinearGradient(0,CY-CH/2,0,CY+CH*.12);
    sky.addColorStop(0,T.photoSky[0]); sky.addColorStop(1,T.photoSky[1]);
    ctx.fillStyle=sky; ctx.fillRect(CX-CW/2,CY-CH/2,CW,CH);
    // ground
    const gnd = ctx.createLinearGradient(0,CY+CH*.14,0,CY+CH/2);
    gnd.addColorStop(0,T.photoLand[0]); gnd.addColorStop(1,T.photoLand[1]);
    ctx.fillStyle=gnd; ctx.fillRect(CX-CW/2,CY+CH*.12,CW,CH*.40);
    // far mountain
    ctx.fillStyle=T.mtnFar;
    ctx.beginPath();
    ctx.moveTo(CX-CW*.46,CY+CH*.16); ctx.lineTo(CX-CW*.07,CY-CH*.28);
    ctx.lineTo(CX+CW*.26,CY+CH*.16); ctx.closePath(); ctx.fill();
    // snow cap
    ctx.fillStyle=T.snow;
    ctx.beginPath();
    ctx.moveTo(CX-CW*.07,CY-CH*.28); ctx.lineTo(CX-CW*.155,CY-CH*.10);
    ctx.lineTo(CX+CW*.01,CY-CH*.10); ctx.closePath(); ctx.fill();
    // near mountain
    ctx.fillStyle=T.mtnNear;
    ctx.beginPath();
    ctx.moveTo(CX+CW*.04,CY+CH*.16); ctx.lineTo(CX+CW*.30,CY-CH*.17);
    ctx.lineTo(CX+CW*.5,CY+CH*.16); ctx.closePath(); ctx.fill();
    // sun
    ctx.fillStyle = T.mono ? 'rgba(255,255,255,.6)' : 'rgba(255,244,214,.9)';
    ctx.beginPath(); ctx.arc(CX+CW*.30,CY-CH*.30,30*S,0,Math.PI*2); ctx.fill();
    ctx.restore();

    // card subtle border
    rrect(ctx,CX-CW/2,CY-CH/2,CW,CH,CR);
    ctx.strokeStyle='rgba(0,0,0,.06)'; ctx.lineWidth=1.4*S; ctx.stroke();

    // ── SORT PILL (←/→) ──
    const pW=236*S, pH=58*S, pX=CX-pW/2, pY=CY+CH*.30;
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.22)'; ctx.shadowBlur=22*S; ctx.shadowOffsetY=8*S;
    rrect(ctx,pX,pY,pW,pH,pH/2); ctx.fillStyle=T.pill; ctx.fill();
    ctx.restore();
    // divider
    ctx.save(); ctx.strokeStyle=T.pillDiv; ctx.lineWidth=1.8*S;
    ctx.beginPath(); ctx.moveTo(CX,pY+pH*.22); ctx.lineTo(CX,pY+pH*.78); ctx.stroke(); ctx.restore();

    const aCY=pY+pH/2, aLen=32*S, aHead=13*S, lw=4.4*S;
    // left arrow ←
    ctx.save(); ctx.strokeStyle=T.trash; ctx.lineWidth=lw; ctx.lineCap='round'; ctx.lineJoin='round';
    const lCX=CX-pW*.24;
    ctx.beginPath();
    ctx.moveTo(lCX+aLen,aCY); ctx.lineTo(lCX-aLen,aCY);
    ctx.moveTo(lCX-aLen+aHead,aCY-aHead*.7); ctx.lineTo(lCX-aLen,aCY); ctx.lineTo(lCX-aLen+aHead,aCY+aHead*.7);
    ctx.stroke(); ctx.restore();
    // right arrow →
    ctx.save(); ctx.strokeStyle=T.keep; ctx.lineWidth=lw; ctx.lineCap='round'; ctx.lineJoin='round';
    const rCX=CX+pW*.24;
    ctx.beginPath();
    ctx.moveTo(rCX-aLen,aCY); ctx.lineTo(rCX+aLen,aCY);
    ctx.moveTo(rCX+aLen-aHead,aCY-aHead*.7); ctx.lineTo(rCX+aLen,aCY); ctx.lineTo(rCX+aLen-aHead,aCY+aHead*.7);
    ctx.stroke(); ctx.restore();

    // ── SSD BAR ──
    const sW=276*S, sH=40*S, sX=CX-sW/2, sY=CY+CH/2+48*S;
    ctx.save();
    ctx.shadowColor='rgba(0,0,0,.22)'; ctx.shadowBlur=16*S; ctx.shadowOffsetY=6*S;
    rrect(ctx,sX,sY,sW,sH,sH/2); ctx.fillStyle=T.ssd; ctx.fill();
    ctx.restore();
    rrect(ctx,sX,sY,sW,sH,sH/2); ctx.strokeStyle=T.ssdBd; ctx.lineWidth=2*S; ctx.stroke();
    for(let i=0;i<2;i++){
      rrect(ctx,sX+(18+i*26)*S,sY+sH*.24,14*S,sH*.52,4.5*S);
      ctx.fillStyle=T.ssdPort; ctx.fill();
    }
    // activity dot
    ctx.beginPath(); ctx.arc(sX+sW-28*S,sY+sH/2,6.5*S,0,Math.PI*2);
    ctx.fillStyle=T.keep; ctx.fill();

    // ── STAR PARTICLES ──
    const stars=[[CX-272*S,CY-244*S,3.4*S],[CX+286*S,CY-210*S,2.7*S],
                 [CX-286*S,CY+250*S,2.3*S],[CX+232*S,CY+286*S,3*S]];
    for(const[sx,sy,sr] of stars){
      const sg=ctx.createRadialGradient(sx,sy,0,sx,sy,sr*4);
      sg.addColorStop(0,T.starGlow); sg.addColorStop(1,'rgba(0,0,0,0)');
      ctx.fillStyle=sg; ctx.fillRect(sx-sr*5,sy-sr*5,sr*10,sr*10);
      ctx.fillStyle=T.star;
      ctx.beginPath(); ctx.arc(sx,sy,sr,0,Math.PI*2); ctx.fill();
    }
  }

  window.YZIcon = { drawIcon, rrect, THEMES };
})();
