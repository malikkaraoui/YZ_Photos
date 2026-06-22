/* ═══════════════════════════════════════════════════════════
   YZPhotos — Widgets écran d'accueil (Liquid Glass)
   Small · Medium · Large · Lock screen — réutilise Icon + PhotoScene
   ═══════════════════════════════════════════════════════════ */
const { useState } = React;

function Ring({ pct, size=58, sw=7, col='#B6D84B' }){
  const r=(size-sw)/2, c=2*Math.PI*r, off=c*(1-pct);
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="rgba(255,255,255,.22)" strokeWidth={sw}/>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={col} strokeWidth={sw} strokeLinecap="round"
        strokeDasharray={c} strokeDashoffset={off} transform={`rotate(-90 ${size/2} ${size/2})`}/>
    </svg>
  );
}

/* petit — à trier */
function WSmall(){
  return (
    <div className="wg wg-s glass-w">
      <div className="wg-top"><div className="wg-appic"><ApplePhotosMini/></div><span className="wg-name">YZPhotos</span></div>
      <div className="wg-big">1 284</div>
      <div className="wg-lbl">photos à trier</div>
      <div className="wg-foot"><span className="wg-dot"/>Samsung T7</div>
    </div>
  );
}
/* petit — espace récupérable (ring) */
function WSmallRing(){
  return (
    <div className="wg wg-s glass-w wg-center">
      <div className="wg-ringwrap"><Ring pct={.62}/><div className="wg-ring-tx">38<small>Go</small></div></div>
      <div className="wg-lbl">récupérables</div>
    </div>
  );
}
/* moyen — résumé disque */
function WMedium(){
  return (
    <div className="wg wg-m glass-w">
      <div className="wg-m-l">
        <div className="wg-top"><div className="wg-appic"><ApplePhotosMini/></div><span className="wg-name">Samsung T7 Pro</span></div>
        <div className="wg-m-stats">
          <div><b>1 284</b><span>à trier</span></div>
          <div><b>14</b><span>doublons</span></div>
          <div><b>38 Go</b><span>récup.</span></div>
        </div>
        <div className="wg-bar"><span style={{width:'64%'}}/></div>
        <div className="wg-sub">847 Go / 1 To utilisés</div>
      </div>
      <div className="wg-m-r">
        <div className="wg-thumbs">
          {[3,7,1,9].map((s,i)=>(<div key={i} className="wg-th"><PhotoScene seed={s}/></div>))}
        </div>
        <div className="wg-cta">Trier ›</div>
      </div>
    </div>
  );
}
/* lock screen — inline + circulaire */
function WLock(){
  return (
    <div className="wg-lock">
      <div className="wg-lock-circ"><Ring pct={.62} size={52} sw={6}/><div className="wg-lock-ic"><Icon n="rectangle.stack" s={18} w={1.9}/></div></div>
      <div className="wg-lock-inline glass-w"><Icon n="trash" s={15} w={1.9}/><span>1 284 à trier · 38 Go récup.</span></div>
    </div>
  );
}

function ApplePhotosMini(){
  const cols=['#FBC02D','#F7902F','#F5402F','#EC2C8E','#9C28B1','#3F51C5','#1CA9E2','#3FBF63'];
  return (
    <svg width="18" height="18" viewBox="0 0 100 100"><g style={{mixBlendMode:'multiply'}}>
      {cols.map((c,i)=>(<ellipse key={i} cx="50" cy="31" rx="13" ry="21" fill={c} opacity="0.9" transform={`rotate(${i*45} 50 50)`}/>))}
    </g><circle cx="50" cy="50" r="9" fill="#fff"/></svg>
  );
}

function WidgetsStage(){
  return (
    <div className="wgs-stage">
      <div className="wgs-blobs"/>
      <div className="wgs-head"><span className="wgs-logo"><b>YZ</b>Photos</span><span className="wgs-pill">Bonus · Widgets</span></div>

      <div className="wgs-grid">
        <div className="wgs-col">
          <div className="wgs-cap">Verrouillage</div>
          <WLock/>
        </div>
        <div className="wgs-col">
          <div className="wgs-cap">Petit · 2×2</div>
          <div className="wgs-row"><WSmall/><WSmallRing/></div>
        </div>
        <div className="wgs-col">
          <div className="wgs-cap">Moyen · 4×2</div>
          <WMedium/>
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<WidgetsStage/>);
