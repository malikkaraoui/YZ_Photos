/* ═══════════════════════════════════════════════════════════
   YZPhotos — Storyboard du teaser (planche de plans-clés)
   6 plans · format 9:16 · notes de mouvement + assets
   ═══════════════════════════════════════════════════════════ */
function ApplePhotos({ s=44 }){
  const cols=['#FBC02D','#F7902F','#F5402F','#EC2C8E','#9C28B1','#3F51C5','#1CA9E2','#3FBF63'];
  return (<svg width={s} height={s} viewBox="0 0 100 100" style={{display:'block'}}>
    <g style={{mixBlendMode:'multiply'}}>{cols.map((c,i)=>(<ellipse key={i} cx="50" cy="31" rx="12.5" ry="21" fill={c} opacity="0.9" transform={`rotate(${i*45} 50 50)`}/>))}</g>
    <circle cx="50" cy="50" r="9" fill="#fff"/></svg>);
}
const fglass={background:'rgba(255,255,255,.15)',backdropFilter:'blur(16px) saturate(160%)',WebkitBackdropFilter:'blur(16px) saturate(160%)',border:'.5px solid rgba(255,255,255,.42)',boxShadow:'inset 0 .5px .5px rgba(255,255,255,.85), 0 6px 18px rgba(8,28,38,.34)'};
const KEEP='#B6D84B', TRASH='#F06A8C';

/* ── plans-clés (rendus dans un mini-écran 9:16) ── */
function FHook(){
  return (
    <div className="kf">
      <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:18,padding:'0 22px',textAlign:'center'}}>
        <div style={{width:96,height:96,borderRadius:22,overflow:'hidden',boxShadow:'0 12px 30px rgba(0,0,0,.5)'}}><img src="exports/final/faille-aurora-dark-1024.png" width="96" height="96" style={{display:'block'}}/></div>
        <div style={{fontSize:25,fontWeight:800,color:'#fff',lineHeight:1.08,letterSpacing:'-.02em'}}>Le tri photo<br/>le plus rapide.</div>
        <div style={{fontSize:14,color:'rgba(255,255,255,.78)',fontWeight:500}}>2&nbsp;847 photos en attente.</div>
      </div>
    </div>
  );
}
function FSources(){
  const rows=[['Photothèque principale',true],['Photos 2019–2021',true],['Dossier DCIM',false]];
  return (
    <div className="kf">
      <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:14,padding:'0 18px'}}>
        <div style={{width:58,height:58,borderRadius:14,background:'#fff',display:'flex',alignItems:'center',justifyContent:'center',boxShadow:'0 8px 20px rgba(0,0,0,.3)'}}><ApplePhotos s={40}/></div>
        <div style={{fontSize:21,fontWeight:800,color:'#fff',textAlign:'center',lineHeight:1.08,letterSpacing:'-.02em'}}>Toutes vos<br/>photothèques.</div>
        <div style={{display:'flex',flexDirection:'column',gap:7,width:'100%'}}>
          {rows.map(([n,on],i)=>(
            <div key={i} style={{...fglass,display:'flex',alignItems:'center',gap:9,padding:'8px 10px',borderRadius:12,...(on?{borderColor:'rgba(182,216,75,.6)'}:{})}}>
              <div style={{width:26,height:26,borderRadius:7,background:'#fff',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>{on?<ApplePhotos s={18}/>:<Icon n="folder" s={15} w={1.7}/>}</div>
              <div style={{flex:1,fontSize:12,fontWeight:700,color:'#fff',whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{n}</div>
              {on&&<div style={{width:18,height:18,borderRadius:'50%',background:'rgba(182,216,75,.7)',display:'flex',alignItems:'center',justifyContent:'center',color:'#fff'}}><Icon n="checkmark" s={11} w={2.6}/></div>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
function FSwipe({ dir }){
  const keep=dir==='keep';
  return (
    <div className="kf">
      <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',position:'relative'}}>
        <div style={{display:'flex',gap:8,marginBottom:18,zIndex:3}}>
          <div style={{...fglass,display:'flex',alignItems:'center',gap:5,padding:'5px 11px',borderRadius:11,background:'rgba(182,216,75,.26)'}}><Icon n="checkmark" s={13} w={2.4}/><b style={{fontSize:14,color:'#fff'}}>{keep?2:1}</b></div>
          <div style={{...fglass,display:'flex',alignItems:'center',gap:5,padding:'5px 11px',borderRadius:11,background:'rgba(240,106,140,.26)'}}><Icon n="trash" s={12} w={1.9}/><b style={{fontSize:14,color:'#fff'}}>{keep?0:1}</b></div>
        </div>
        <div style={{position:'relative',width:168,height:222}}>
          <div style={{position:'absolute',inset:0,borderRadius:20,overflow:'hidden',transform:'scale(.92) translateY(10px)',opacity:.6,border:'.5px solid rgba(255,255,255,.3)'}}><PhotoScene seed={keep?27:33}/></div>
          <div style={{position:'absolute',inset:0,borderRadius:20,overflow:'hidden',transform:`translateX(${keep?70:-70}px) rotate(${keep?9:-9}deg)`,boxShadow:'0 16px 36px rgba(0,0,0,.5)',border:'.5px solid rgba(255,255,255,.35)'}}>
            <PhotoScene seed={keep?23:41}/>
            <div style={{position:'absolute',inset:0,mixBlendMode:'overlay',background:keep?KEEP:TRASH,opacity:.5}}/>
            <div style={{position:'absolute',top:14,[keep?'right':'left']:12,padding:'5px 11px',borderRadius:9,border:'2.5px solid #fff',background:keep?'rgba(182,216,75,.4)':'rgba(240,106,140,.4)',color:'#fff',fontSize:15,fontWeight:800,letterSpacing:'.04em',transform:`rotate(${keep?-8:8}deg)`}}>{keep?'GARDER':'POUBELLE'}</div>
          </div>
          {/* flèche de geste */}
          <div style={{position:'absolute',top:'50%',[keep?'right':'left']:-30,transform:'translateY(-50%)',color:keep?KEEP:TRASH,fontSize:30,fontWeight:800,filter:'drop-shadow(0 2px 6px rgba(0,0,0,.4))'}}>{keep?'→':'←'}</div>
        </div>
      </div>
    </div>
  );
}
function FPayoff(){
  return (
    <div className="kf">
      <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:16,padding:'0 18px'}}>
        <div style={{fontSize:13,fontWeight:700,letterSpacing:'.05em',color:'rgba(255,255,255,.7)',textTransform:'uppercase'}}>Espace libéré</div>
        <div style={{display:'flex',alignItems:'baseline',gap:5,color:KEEP,textShadow:'0 4px 20px rgba(182,216,75,.4)'}}><span style={{fontSize:92,fontWeight:800,letterSpacing:'-.04em',lineHeight:.85}}>38</span><span style={{fontSize:38,fontWeight:800}}>Go</span></div>
        <div style={{...fglass,display:'flex',alignItems:'center',gap:9,padding:'10px 13px',borderRadius:14}}>
          <div style={{width:26,height:26,borderRadius:'50%',background:'rgba(182,216,75,.5)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,color:'#fff'}}><Icon n="checkmark" s={14} w={2.4}/></div>
          <span style={{fontSize:13,color:'#fff',fontWeight:600,lineHeight:1.3}}>Rien n'est supprimé<br/>sans confirmation.</span>
        </div>
      </div>
    </div>
  );
}
function FClose(){
  return (
    <div className="kf">
      <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:18}}>
        <div style={{width:78,height:78,borderRadius:18,overflow:'hidden',boxShadow:'0 12px 30px rgba(0,0,0,.5)'}}><img src="exports/final/faille-aurora-dark-1024.png" width="78" height="78" style={{display:'block'}}/></div>
        <div style={{fontSize:30,fontWeight:800,color:'#fff',letterSpacing:'-.02em'}}>YZ<span style={{color:KEEP}}>Photos</span></div>
        <div style={{...fglass,padding:'9px 18px',borderRadius:100,fontSize:13,fontWeight:700,color:'#fff'}}>Bientôt sur l'App Store</div>
      </div>
    </div>
  );
}

/* ── panneau de storyboard ── */
const PANELS=[
  { n:'01', tc:'0:00 – 0:03.5', Frame:FHook, title:'Accroche', action:"L'icône apparaît, le titre s'installe, le compteur « 2 847 photos » donne l'enjeu.",
    motion:['Icône : scale-in avec léger rebond (easeOutBack)','Titre : monte + fondu','Sous-titre : fondu différé'], assets:['Icône Faille×Aurora','Type display'] },
  { n:'02', tc:'0:03.5 – 0:06.6', Frame:FSources, title:'Sources réunies', action:'Le logo Photos d’Apple, puis les photothèques + dossiers qui s’empilent en cascade.',
    motion:['Logo : pop (easeOutBack)','Cartes : slide-up en cascade (0,12 s d’écart)','Transition sortante : fondu'], assets:['Logo Photos d’Apple','Cartes source verre'] },
  { n:'03', tc:'0:06.6 – 0:10.0', Frame:()=> <FSwipe dir="keep"/>, title:'Swipe — Garder', action:'La carte part à droite, tampon GARDER, teinte verte. Le compteur « gardées » s’incrémente.',
    motion:['Carte : drag → envol à droite (easeInCubic)','Tampon GARDER : opacité 0→1','Compteur : +1 satisfaisant'], assets:['Deck de tri','Photos du pool','Palette Sulphur'] },
  { n:'04', tc:'0:10.0 – 0:14.2', Frame:()=> <FSwipe dir="trash"/>, title:'Swipe — Poubelle', action:'La carte suivante part à gauche, tampon POUBELLE, teinte rose. Rythme alterné, ~6 cartes.',
    motion:['Carte : envol à gauche, rotation inverse','Tampon POUBELLE : opacité 0→1','Alternance G/D, tempo régulier'], assets:['Deck de tri','Palette Confetti'] },
  { n:'05', tc:'0:14.2 – 0:17.8', Frame:FPayoff, title:'Récompense', action:'« 38 Go » compte de 0 à 38, puis la réassurance corbeille monte en dessous.',
    motion:['Nombre : count-up + scale (easeOutBack)','Halo vert','Bandeau réassurance : slide-up'], assets:['Type display','Chip verre','Palette Sulphur'] },
  { n:'06', tc:'0:17.8 – 0:20.0', Frame:FClose, title:'Clôture', action:'Logo + wordmark YZPhotos, puis le CTA « Bientôt sur l’App Store ».',
    motion:['Icône : pop','Wordmark : fondu','CTA : slide-up + fondu'], assets:['Icône Faille×Aurora','Wordmark','CTA verre'] },
];

function Storyboard(){
  return (
    <div className="sb">
      <div className="sb-blobs"/>
      <header className="sb-head">
        <div className="sb-brand"><span className="sb-logo"><b>YZ</b>Photos</span><span className="sb-pill">Storyboard · Teaser</span></div>
        <div className="sb-meta">9:16 · ~20 s · Liquid Glass · pour Hyperframes</div>
      </header>
      <div className="sb-intro">
        <h1>Teaser — « Un swipe. C'est trié. »</h1>
        <p>6 plans, du problème à la promesse. Chaque panneau = un plan-clé avec son timecode, son action et ses notes de mouvement. Les visuels réutilisent les éléments du projet (icône, logo Photos d'Apple, deck de tri, palette Optimistic Synergy).</p>
      </div>
      <div className="sb-grid">
        {PANELS.map((p)=>(
          <div className="sb-panel" key={p.n}>
            <div className="sb-frame">
              <div className="sb-frame-bg"/>
              <div className="sb-num">{p.n}</div>
              <div className="sb-tc">{p.tc}</div>
              <div className="sb-screen"><p.Frame/></div>
            </div>
            <div className="sb-cap">
              <div className="sb-cap-title">{p.title}</div>
              <div className="sb-cap-action">{p.action}</div>
              <div className="sb-cap-sec">Mouvement</div>
              <ul className="sb-motion">{p.motion.map((m,i)=><li key={i}>{m}</li>)}</ul>
              <div className="sb-assets">{p.assets.map((a,i)=><span key={i} className="sb-chip">{a}</span>)}</div>
            </div>
          </div>
        ))}
      </div>
      <footer className="sb-foot">Transitions : fondus enchaînés courts (~0,4 s) entre plans · fond Storm Blue continu, halos qui dérivent · musique : montée rythmée calée sur les swipes.</footer>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Storyboard/>);
