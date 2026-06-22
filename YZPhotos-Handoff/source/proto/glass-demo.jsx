/* ═══════════════════════════════════════════════════════════
   YZPhotos — Liquid Glass · démo de direction
   Palette « Optimistic Synergy » · verre translucide réfractif
   Réutilise Icon + PhotoScene de components.jsx
   ═══════════════════════════════════════════════════════════ */
const { useState, useRef, useCallback } = React;

/* ════════ ÉCRAN TRIER — verre liquide ════════ */
function GlassTrier(){
  const deck = [11,7,2,18,5,9];
  const [idx,setIdx] = useState(0);
  const [drag,setDrag] = useState({x:0,active:false});
  const [fly,setFly] = useState(null);
  const start = useRef(null);
  const total = deck.length;
  const card = deck[idx], next = deck[idx+1];

  const commit = useCallback((dir)=>{
    if(idx>=total||fly) return;
    setFly(dir);
    setTimeout(()=>{ setIdx(i=>i+1); setFly(null); setDrag({x:0,active:false}); },300);
  },[idx,total,fly]);

  const onDown=e=>{ if(fly||idx>=total)return; start.current=e.clientX; setDrag({x:0,active:true}); e.currentTarget.setPointerCapture?.(e.pointerId); };
  const onMove=e=>{ if(!drag.active||start.current==null)return; setDrag({x:e.clientX-start.current,active:true}); };
  const onUp=()=>{ if(!drag.active)return; if(drag.x>80)commit('keep'); else if(drag.x<-80)commit('trash'); else setDrag({x:0,active:false}); start.current=null; };

  const dx = fly ? (fly==='keep'?520:-520) : drag.x;
  const rot = dx/20;
  const keepOp = Math.max(0,Math.min(1,dx/110));
  const trashOp = Math.max(0,Math.min(1,-dx/110));
  const done = idx>=total;

  return (
    <div className="g-screen">
      <PhotoScene seed={card!==undefined?card+30:3} style={{filter:'saturate(1.15)'}}/>
      <div className="g-screen-veil"/>

      {/* top glass bar */}
      <div className="g-statusbar"><span>9:41</span><span className="g-sb-r"><Icon n="externaldrive" s={15} w={1.9}/><span>T7 Pro</span></span></div>
      <div className="g-topbar glass">
        <div className="g-top-l"><div className="g-top-title">Trier</div><div className="g-top-sub">{done?'Terminé':`${total-idx} à trier`}</div></div>
        <div className="g-progress"><div className="g-progress-fill" style={{width:`${(idx/total)*100}%`}}/></div>
      </div>

      {/* deck */}
      <div className="g-deck">
        {done ? (
          <div className="g-done glass">
            <div className="g-done-ic glass-circle"><Icon n="checkmark" s={34} w={2.2}/></div>
            <div className="g-done-t">Tout est trié</div>
            <div className="g-done-s">Les écartés filent à la corbeille.</div>
          </div>
        ) : (
          <>
            {next!==undefined && <div className="g-card g-card-behind"><PhotoScene seed={next+30}/></div>}
            <div className={`g-card g-card-front${drag.active?' dragging':''}${fly?' fly':''}`}
              style={{transform:`translateX(${dx}px) rotate(${rot}deg)`}}
              onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
              <PhotoScene seed={card+30}/>
              <div className="g-card-sheen"/>
              {/* verdict glass stamps */}
              <div className="g-stamp g-stamp-keep glass" style={{opacity:keepOp}}>GARDER</div>
              <div className="g-stamp g-stamp-trash glass" style={{opacity:trashOp}}>POUBELLE</div>
              <div className="g-tint g-tint-keep" style={{opacity:keepOp*.5}}/>
              <div className="g-tint g-tint-trash" style={{opacity:trashOp*.5}}/>
              {/* meta glass chip */}
              <div className="g-card-meta glass"><Icon n="photo" s={14} w={1.9}/><span>IMG_482{idx}.HEIC</span><i>·</i><span>4,2 Mo</span></div>
            </div>
          </>
        )}
      </div>

      {/* action rail */}
      {!done && (
        <div className="g-actions">
          <button className="glass-circle g-btn-trash" onClick={()=>commit('trash')}><Icon n="trash" s={26} w={1.9}/></button>
          <button className="glass-circle g-btn-undo" onClick={()=>{ if(idx>0){setIdx(i=>i-1);} }}><Icon n="arrow.uturn.backward" s={20} w={2}/></button>
          <button className="glass-circle g-btn-keep" onClick={()=>commit('keep')}><Icon n="checkmark" s={30} w={2.2}/></button>
        </div>
      )}

      {/* tab bar glass */}
      <div className="g-tabbar glass">
        {[['rectangle.stack',1],['square.on.square',0],['photo.stack',0],['trash',0],['gearshape',0]].map(([n,a],i)=>(
          <button key={i} className={`g-tab${a?' on':''}`}><Icon n={n} s={24} w={a?2.1:1.8}/></button>
        ))}
      </div>
    </div>
  );
}

/* ════════ RAIL DE COMPOSANTS VERRE ════════ */
function GlassSampler(){
  const [seg,setSeg] = useState(1);
  const [tog,setTog] = useState(true);
  const swatches = [['Carmine','#B23A5D'],['Storm Blue','#3D5A6C'],['Old Gold','#D2A53F'],['Confetti','#E88AA0'],['Sulphur','#C3D24A'],['Mandarin','#E87B3E']];
  return (
    <div className="sampler">
      <div className="sampler-veil"/>
      <div className="sampler-inner">
        <div className="smp-tag">Liquid Glass · Optimistic Synergy</div>
        <h2 className="smp-h">Composants verre</h2>

        <div className="smp-sec">Palette</div>
        <div className="smp-swatches">
          {swatches.map(([n,c])=>(<div key={n} className="smp-sw"><div className="smp-sw-c" style={{background:c}}/><span>{n}</span></div>))}
        </div>

        <div className="smp-sec">Boutons</div>
        <div className="smp-row">
          <button className="glass g-pill g-pill-accent">Garder</button>
          <button className="glass g-pill">Annuler</button>
          <button className="glass-circle smp-fab"><Icon n="plus" s={22} w={2}/></button>
        </div>

        <div className="smp-sec">Segmenté</div>
        <div className="glass g-segment">
          {['Système','Clair','Sombre'].map((l,i)=>(<button key={l} className={seg===i?'on':''} onClick={()=>setSeg(i)}>{l}</button>))}
        </div>

        <div className="smp-sec">Interrupteur &amp; curseur</div>
        <div className="smp-row" style={{gap:20,alignItems:'center'}}>
          <button className={`glass g-switch${tog?' on':''}`} onClick={()=>setTog(!tog)}><span className="g-knob"/></button>
          <div className="glass g-slider"><div className="g-slider-fill" style={{width:'62%'}}><span className="g-slider-knob"/></div></div>
        </div>

        <div className="smp-sec">Carte source</div>
        <div className="glass g-source">
          <div className="g-source-ic glass-circle"><Icon n="photo.stack" s={22} w={1.7}/></div>
          <div className="g-source-main">
            <div className="g-source-name">Photothèque principale <span className="g-lib-tag">.photoslibrary</span></div>
            <div className="g-source-meta">18 432 photos · 1 240 vidéos</div>
          </div>
          <div className="g-source-check glass-circle"><Icon n="checkmark" s={14} w={2.6}/></div>
        </div>

        <div className="smp-sec">Badges</div>
        <div className="smp-row">
          <span className="glass g-badge"><Icon n="sparkles" s={12} w={2}/>38 Go récupérables</span>
          <span className="glass g-badge g-badge-keep"><Icon n="checkmark" s={12} w={2.4}/>Gardée</span>
          <span className="glass g-badge g-badge-trash"><Icon n="trash" s={12} w={2}/>Poubelle</span>
        </div>
      </div>
    </div>
  );
}

function GlassDemo(){
  return (
    <div className="glass-stage">
      <div className="bg-blobs"/>
      <div className="demo-head">
        <span className="demo-logo"><b>YZ</b>Photos</span>
        <span className="demo-pill">Direction · Liquid Glass</span>
      </div>
      <div className="demo-cols">
        <div className="phone-glass">
          <div className="phone-glass-screen"><GlassTrier/></div>
        </div>
        <GlassSampler/>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<GlassDemo/>);
