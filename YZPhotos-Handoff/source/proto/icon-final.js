/* ═══════════════════════════════════════════════════════════
   YZPhotos — Icône finale : FAILLE × AURORA
   Photo aurora déchirée en deux · ✕ poubelle / ✓ garder
   drawIcon(ctx, W, H, variant)  variant: 'dark'|'light'|'tinted'
   ═══════════════════════════════════════════════════════════ */
(function () {
  function check(ctx,cx,cy,s,col,lw){
    ctx.save();ctx.strokeStyle=col;ctx.lineWidth=lw;ctx.lineCap='round';ctx.lineJoin='round';
    ctx.beginPath();
    ctx.moveTo(cx-s*0.46,cy+s*0.04);ctx.lineTo(cx-s*0.12,cy+s*0.40);ctx.lineTo(cx+s*0.52,cy-s*0.42);
    ctx.stroke();ctx.restore();
  }
  function cross(ctx,cx,cy,s,col,lw){
    ctx.save();ctx.strokeStyle=col;ctx.lineWidth=lw;ctx.lineCap='round';
    ctx.beginPath();ctx.moveTo(cx-s,cy-s);ctx.lineTo(cx+s,cy+s);ctx.moveTo(cx+s,cy-s);ctx.lineTo(cx-s,cy+s);ctx.stroke();ctx.restore();
  }

  const THEMES = {
    dark: {
      base:['#3A1B5E','#10122E'],
      blobs:[
        [0.16,0.14,0.78,'rgba(255,82,138,.95)'],
        [0.90,0.20,0.62,'rgba(255,168,70,.9)'],
        [0.86,0.90,0.82,'rgba(43,212,196,.9)'],
        [0.10,0.92,0.66,'rgba(123,91,255,.85)'],
        [0.52,0.50,0.34,'rgba(255,255,255,.20)'],
      ],
      orb:'rgba(255,246,220,.92)', orbGlow:'rgba(255,230,180,.5)',
      gap:['#0C0A1A','#070610'],
      tintTrash:'rgba(229,72,77,.5)', tintKeep:'rgba(36,200,120,.46)',
      badge:'#fff', xCol:'#E5484D', vCol:'#22B866',
    },
    light: {
      base:['#FBEFFA','#EAE4FB'],
      blobs:[
        [0.16,0.14,0.78,'rgba(255,140,180,.85)'],
        [0.90,0.20,0.62,'rgba(255,200,130,.85)'],
        [0.86,0.90,0.82,'rgba(120,230,220,.85)'],
        [0.10,0.92,0.66,'rgba(170,150,255,.8)'],
        [0.52,0.46,0.34,'rgba(255,255,255,.5)'],
      ],
      orb:'rgba(255,250,235,.95)', orbGlow:'rgba(255,235,200,.6)',
      gap:['#FFFFFF','#F0ECF8'],
      tintTrash:'rgba(229,72,77,.4)', tintKeep:'rgba(36,190,110,.38)',
      badge:'#fff', xCol:'#E5484D', vCol:'#1FA85C',
    },
    tinted: {
      base:['#1A1A20','#0A0A0E'], mono:true,
      blobs:[
        [0.16,0.14,0.78,'rgba(210,210,225,.5)'],
        [0.90,0.20,0.62,'rgba(180,180,195,.45)'],
        [0.86,0.90,0.82,'rgba(200,200,215,.5)'],
        [0.10,0.92,0.66,'rgba(150,150,170,.45)'],
        [0.52,0.50,0.34,'rgba(255,255,255,.22)'],
      ],
      orb:'rgba(245,245,250,.85)', orbGlow:'rgba(220,220,235,.4)',
      gap:['#0A0A0E','#050507'],
      tintTrash:'rgba(120,120,130,.45)', tintKeep:'rgba(180,180,195,.4)',
      badge:'#F4F4F6', xCol:'#5A5A64', vCol:'#8A8A96',
    },
  };

  function paintAurora(ctx,W,H,T){
    const g=ctx.createLinearGradient(0,0,W*0.5,H);
    g.addColorStop(0,T.base[0]);g.addColorStop(1,T.base[1]);
    ctx.fillStyle=g;ctx.fillRect(-200,-200,W+400,H+400);
    for(const [x,y,r,col] of T.blobs){
      const rg=ctx.createRadialGradient(W*x,H*y,0,W*x,H*y,W*r);
      rg.addColorStop(0,col);rg.addColorStop(1,'rgba(0,0,0,0)');
      ctx.fillStyle=rg;ctx.fillRect(-200,-200,W+400,H+400);
    }
    // glowing orb straddling the tear
    const ox=W*0.5,oy=H*0.40,orad=W*0.135;
    const og=ctx.createRadialGradient(ox,oy,0,ox,oy,orad*2.4);
    og.addColorStop(0,T.orbGlow);og.addColorStop(1,'rgba(0,0,0,0)');
    ctx.fillStyle=og;ctx.fillRect(ox-orad*3,oy-orad*3,orad*6,orad*6);
    ctx.fillStyle=T.orb;ctx.beginPath();ctx.arc(ox,oy,orad,0,7);ctx.fill();
  }

  function drawIcon(ctx,W,H,variant){
    const T=THEMES[variant]||THEMES.dark;
    const S=W/1024;
    ctx.clearRect(0,0,W,H);
    // gap backdrop (visible in the tear)
    const bg=ctx.createLinearGradient(0,0,0,H);
    bg.addColorStop(0,T.gap[0]);bg.addColorStop(1,T.gap[1]);
    ctx.fillStyle=bg;ctx.fillRect(0,0,W,H);

    const mx=W/2, slant=H*0.13, gap=13*S, push=30*S;

    const half=(side)=>{
      ctx.save();
      ctx.translate(side*push,0);ctx.rotate(side*0.018);
      ctx.beginPath();
      if(side<0){ ctx.moveTo(-200,-200);ctx.lineTo(mx-gap-slant,-200);ctx.lineTo(mx-gap+slant,H+200);ctx.lineTo(-200,H+200);}
      else{ ctx.moveTo(mx+gap-slant,-200);ctx.lineTo(W+200,-200);ctx.lineTo(W+200,H+200);ctx.lineTo(mx+gap+slant,H+200);}
      ctx.closePath();
      // drop shadow of the lifted half onto the gap
      ctx.save();ctx.shadowColor='rgba(0,0,0,.5)';ctx.shadowBlur=44*S;ctx.shadowOffsetX=side*-16*S;
      ctx.fillStyle='#000';ctx.fill();ctx.restore();
      ctx.clip();
      paintAurora(ctx,W,H,T);
      // verdict tint, strongest at the torn edge
      const edge = side<0 ? mx : mx;
      const far  = side<0 ? mx-W*0.55 : mx+W*0.55;
      const tg=ctx.createLinearGradient(edge,0,far,0);
      tg.addColorStop(0, side<0?T.tintTrash:T.tintKeep);
      tg.addColorStop(1,'rgba(0,0,0,0)');
      ctx.fillStyle=tg;ctx.fillRect(-200,-200,W+400,H+400);
      ctx.restore();
    };
    half(-1);half(1);

    // verdict badges
    const bShadow=()=>{ctx.save();ctx.shadowColor='rgba(0,0,0,.4)';ctx.shadowBlur=22*S;ctx.shadowOffsetY=7*S;};
    bShadow();
    ctx.beginPath();ctx.arc(W*0.235,H*0.235,60*S,0,7);ctx.fillStyle=T.badge;ctx.fill();ctx.restore();
    bShadow();
    ctx.beginPath();ctx.arc(W*0.765,H*0.765,60*S,0,7);ctx.fillStyle=T.badge;ctx.fill();ctx.restore();
    cross(ctx,W*0.235,H*0.235,23*S,T.xCol,16*S);
    check(ctx,W*0.765,H*0.765,74*S,T.vCol,15*S);
  }

  window.YZFinal = { drawIcon, THEMES };
})();
