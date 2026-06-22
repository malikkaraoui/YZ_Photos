/* ═══════════════════════════════════════════════════════════
   YZPhotos — Onboarding (Liquid Glass)
   4 écrans paginés · iPhone · réutilise Icon + PhotoScene
   ═══════════════════════════════════════════════════════════ */
const { useState, useRef, useCallback } = React;

/* ── visuel 1 : icône app héro (faille) ── */
function HeroIcon(){
  return (
    <div className="ob-hero ob-hero-icon">
      <div className="ob-appicon"><img src="exports/final/faille-aurora-dark-1024.png" alt=""/></div>
      <div className="ob-spark s1"/><div className="ob-spark s2"/><div className="ob-spark s3"/>
    </div>
  );
}
/* ── logo Photos d'Apple (pétales en moulinet) ── */
function ApplePhotos({ s=44 }){
  const cols=['#FBC02D','#F7902F','#F5402F','#EC2C8E','#9C28B1','#3F51C5','#1CA9E2','#3FBF63'];
  return (
    <svg width={s} height={s} viewBox="0 0 100 100" style={{display:'block'}}>
      <g style={{mixBlendMode:'multiply'}}>
        {cols.map((c,i)=>(
          <ellipse key={i} cx="50" cy="31" rx="12.5" ry="21" fill={c} opacity="0.9"
            transform={`rotate(${i*45} 50 50)`}/>
        ))}
      </g>
      <circle cx="50" cy="50" r="9" fill="#fff"/>
    </svg>
  );
}

/* ── visuel 2 : sources — câble OU réseau vers l'iPad ── */
function HeroSSD(){
  return (
    <div className="ob-hero ob-hero-ssd">
      {/* l'iPad, central — dashboard simple */}
      <div className="ob-ipad-mini">
        <div className="ob-ipad-screen">
          <div className="ob-dash">
            <div className="ob-dash-head">
              <div className="ob-dash-title"/>
              <div className="ob-dash-drive"><span className="ob-dash-led"/></div>
            </div>
            <div className="ob-dash-stats">
              <div className="ob-dash-stat"><b/><i/></div>
              <div className="ob-dash-stat"><b/><i/></div>
            </div>
            <div className="ob-dash-bar"><span/></div>
          </div>
        </div>
        <div className="ob-ipad-cam"/>
      </div>
      {/* deux façons de l'alimenter */}
      <div className="ob-conn ob-conn-cable glass-o">
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="8" y="3" width="8" height="6" rx="2"/><path d="M12 9v6"/><path d="M9 15h6v3a3 3 0 0 1-3 3 3 3 0 0 1-3-3z"/></svg>
        <span>USB‑C</span>
      </div>
      <div className="ob-conn ob-conn-net glass-o">
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M2.5 9a14 14 0 0 1 19 0"/><path d="M5.5 12.5a9.5 9.5 0 0 1 13 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><circle cx="12" cy="19.5" r="1.2" fill="#fff" stroke="none"/></svg>
        <span>Réseau</span>
      </div>
    </div>
  );
}
/* ── visuel 3 : photothèques Apple ── */
function HeroLibs(){
  const libs=[['Photothèque principale','.photoslibrary',true,'apple'],['Photos 2019–2021','.photoslibrary',false,'apple'],['Dossier DCIM',null,false,'folder']];
  return (
    <div className="ob-hero ob-hero-libs">
      <div className="ob-applogo glass-o"><ApplePhotos s={56}/></div>
      {libs.map(([n,tag,on,kind],i)=>(
        <div key={i} className={`ob-libcard glass-o${on?' on':''}`} style={{'--i':i}}>
          <div className="ob-lib-ic">{kind==='apple'?<ApplePhotos s={26}/>:<Icon n="folder" s={20} w={1.7}/>}</div>
          <div className="ob-lib-tx"><div className="ob-lib-n">{n}</div>{tag&&<div className="ob-lib-tag">{tag}</div>}</div>
          {on&&<div className="ob-lib-ck"><Icon n="checkmark" s={13} w={2.6}/></div>}
        </div>
      ))}
    </div>
  );
}
/* ── visuel 4 : swipe garder/jeter ── */
function HeroSwipe(){
  return (
    <div className="ob-hero ob-hero-swipe">
      <div className="ob-card ob-card-back"><PhotoScene seed={40}/></div>
      <div className="ob-card ob-card-front"><PhotoScene seed={32}/>
        <div className="ob-card-sheen"/>
        <div className="ob-swipe-hint ob-hint-keep glass-o"><Icon n="checkmark" s={22} w={2.4}/></div>
        <div className="ob-swipe-hint ob-hint-trash glass-o"><Icon n="trash" s={20} w={1.9}/></div>
      </div>
    </div>
  );
}

const SLIDES = [
  { key:'welcome', Hero:HeroIcon, kicker:'BIENVENUE', title:<>Le tri photo<br/>le plus rapide.</>,
    body:"YZPhotos range vos photos et vidéos directement depuis votre disque externe. Sans les copier, sans encombrer l'iPad." },
  { key:'ssd', Hero:HeroSSD, kicker:'ÉTAPE 1', title:<>Branchez,<br/>ou connectez.</>,
    body:"Un SSD en USB‑C, ou un disque partagé sur votre réseau — Freebox, NAS… YZPhotos le détecte et l'analyse." },
  { key:'libs', Hero:HeroLibs, kicker:'ÉTAPE 2', title:<>Toutes vos<br/>photothèques.</>,
    body:"Vos bibliothèques Apple .photoslibrary et vos dossiers, réunis. Fini de jongler entre plusieurs photothèques — basculez d'un tap." },
  { key:'sort', Hero:HeroSwipe, kicker:'ÉTAPE 3', title:<>Gardez. Jetez.<br/>Suivant.</>,
    body:"Un swipe à droite pour garder, à gauche pour jeter. Rien n'est supprimé sans confirmation — tout passe par la corbeille." },
];

function Onboarding(){
  const [i,setI] = useState(0);
  const [drag,setDrag] = useState(0);
  const start = useRef(null);
  const last = SLIDES.length-1;

  const go = useCallback((n)=>setI(Math.max(0,Math.min(last,n))),[last]);
  const onDown=e=>{ start.current=e.clientX; };
  const onMove=e=>{ if(start.current==null)return; setDrag(e.clientX-start.current); };
  const onUp=()=>{ if(start.current==null)return; if(drag<-60&&i<last)go(i+1); else if(drag>60&&i>0)go(i-1); setDrag(0); start.current=null; };

  return (
    <div className="ob-root" data-theme="glass">
      <div className="ob-bg"/>
      <div className="ob-statusbar"><span>9:41</span><span className="ob-sb-r">
        <svg width="17" height="11" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="5" y="4.5" width="3" height="7.5" rx="1"/><rect x="10" y="2" width="3" height="10" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1" opacity="0.4"/></svg>
        <svg width="25" height="12" viewBox="0 0 26 13" fill="none"><rect x="1" y="1" width="21" height="11" rx="3" stroke="currentColor" strokeWidth="1" opacity="0.5"/><rect x="2.5" y="2.5" width="16" height="8" rx="1.5" fill="currentColor"/></svg>
      </span></div>

      <button className="ob-skip" onClick={()=>go(last)} style={{opacity:i<last?1:0,pointerEvents:i<last?'auto':'none'}}>Passer</button>

      <div className="ob-track" onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
        style={{width:`${SLIDES.length*100}%`, transform:`translateX(calc(${-i*(100/SLIDES.length)}% + ${drag}px))`, transition:start.current!=null?'none':'transform .45s cubic-bezier(.3,.9,.3,1)'}}>
        {SLIDES.map((s)=>(
          <div className="ob-slide" key={s.key} style={{width:`${100/SLIDES.length}%`}}>
            <s.Hero/>
            <div className="ob-copy">
              <div className="ob-kicker">{s.kicker}</div>
              <h1 className="ob-title">{s.title}</h1>
              <p className="ob-body">{s.body}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="ob-foot">
        <div className="ob-dots">
          {SLIDES.map((_,d)=>(<button key={d} className={`ob-dot${d===i?' on':''}`} onClick={()=>go(d)}/>))}
        </div>
        {i<last
          ? <button className="ob-cta glass-o" onClick={()=>go(i+1)}><span>Continuer</span><Icon n="chevron.right" s={18} w={2.2}/></button>
          : <button className="ob-cta ob-cta-go glass-o" onClick={()=>go(0)}><span>Commencer</span><Icon n="checkmark" s={19} w={2.4}/></button>}
      </div>
    </div>
  );
}

/* Stage : iPhone glass */
function OnbStage(){
  return (
    <div className="onb-stage">
      <div className="onb-blobs"/>
      <div className="onb-head"><span className="onb-logo"><b>YZ</b>Photos</span><span className="onb-pill">Bonus · Onboarding</span></div>
      <div className="onb-phone"><div className="onb-phone-screen"><Onboarding/></div></div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<OnbStage/>);
