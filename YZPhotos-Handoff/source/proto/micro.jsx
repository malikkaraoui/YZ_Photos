/* ═══════════════════════════════════════════════════════════
   YZPhotos — Micro-interactions : swipe garder/poubelle décortiqué
   Carte draggable réelle + panneau d'états en direct (Liquid Glass)
   ═══════════════════════════════════════════════════════════ */
const { useState, useRef, useCallback, useEffect } = React;

const TH = 110;           // seuil d'engagement
const TH_HINT = 30;       // début de retour visuel

function MicroDemo(){
  const seeds = [3,7,1,9,4,6,2,8,0,5];
  const [idx,setIdx] = useState(0);
  const [drag,setDrag] = useState({x:0,y:0,on:false});
  const [fly,setFly] = useState(null);          // 'keep'|'trash'
  const [history,setHistory] = useState([]);
  const [auto,setAuto] = useState(null);         // démo auto
  const start = useRef(null);
  const vel = useRef({x:0,t:0,last:0});

  const card = seeds[idx % seeds.length];
  const next = seeds[(idx+1) % seeds.length];

  const commit = useCallback((dir)=>{
    if(fly) return;
    setFly(dir);
    setHistory(h=>[...h,{idx,dir}].slice(-6));
    setTimeout(()=>{ setIdx(i=>i+1); setFly(null); setDrag({x:0,y:0,on:false}); },340);
  },[fly,idx]);

  const onDown=e=>{ if(fly)return; start.current={x:e.clientX,y:e.clientY}; vel.current={x:0,t:performance.now(),last:e.clientX}; setDrag({x:0,y:0,on:true}); e.currentTarget.setPointerCapture?.(e.pointerId); };
  const onMove=e=>{ if(!drag.on||!start.current)return;
    const now=performance.now(); vel.current.x=(e.clientX-vel.current.last)/Math.max(1,now-vel.current.t)*16; vel.current.t=now; vel.current.last=e.clientX;
    setDrag({x:e.clientX-start.current.x,y:(e.clientY-start.current.y)*.4,on:true}); };
  const onUp=()=>{ if(!drag.on)return;
    const v=vel.current.x;
    if(drag.x>TH || v>9) commit('keep');
    else if(drag.x<-TH || v<-9) commit('trash');
    else setDrag({x:0,y:0,on:false});
    start.current=null; };

  const undo=()=>{ if(!history.length||fly)return; setHistory(h=>h.slice(0,-1)); setIdx(i=>Math.max(0,i-1)); };

  // démo automatique
  const runAuto = (dir)=>{
    if(fly||drag.on) return;
    setAuto(dir); 
    let x=0; const target=dir==='keep'?1:-1;
    const step=()=>{ x+=target*14; setDrag({x,y:-Math.abs(x)*.06,on:true});
      if(Math.abs(x)<TH+24){ requestAnimationFrame(step); }
      else { setDrag({x,y:0,on:false}); setTimeout(()=>{commit(dir); setAuto(null);},120); } };
    requestAnimationFrame(step);
  };

  const dx = fly ? (fly==='keep'?640:-640) : drag.x;
  const dy = fly ? -60 : drag.y;
  const rot = dx/22;
  const keepP = Math.max(0,Math.min(1,(dx-TH_HINT)/(TH-TH_HINT)));
  const trashP = Math.max(0,Math.min(1,(-dx-TH_HINT)/(TH-TH_HINT)));
  const engaged = Math.abs(dx)>=TH;
  const dir = dx>0?'keep':dx<0?'trash':null;

  // états pour le panneau
  const state = fly ? 'commit' : (drag.on ? (engaged?'engage':'drag') : 'repos');
  const STATES = [
    ['repos','Repos','La carte flotte, prête. Indice de glisse subtil.'],
    ['drag','Glisse','Suit le doigt 1:1, légère rotation. Les tampons fondent en entrée.'],
    ['engage','Seuil franchi','Au-delà de '+TH+' px (ou au flick), le verdict s\u2019arme — halo plein.'],
    ['commit','Validé','La carte s\u2019envole, la suivante remonte. Annulable.'],
  ];

  return (
    <div className="mi-stage">
      <div className="mi-blobs"/>
      <div className="mi-head"><span className="mi-logo"><b>YZ</b>Photos</span><span className="mi-pill">Bonus · Micro-interactions</span></div>

      <div className="mi-cols">
        {/* phone */}
        <div className="mi-phone-wrap">
          <div className="mi-phone"><div className="mi-phone-screen">
            <div className="mi-scr" data-theme="glass">
              <div className="mi-scr-bg"/>
              <div className="mi-statusbar"><span>9:41</span><span className="mi-sb">Trier</span></div>
              <div className="mi-deck">
                <div className="mi-card mi-card-back"><PhotoScene seed={next+20}/></div>
                <div className={`mi-card mi-card-front${drag.on?' grab':''}${fly?' fly':''}`}
                  style={{transform:`translate(${dx}px,${dy}px) rotate(${rot}deg)`, transition: (drag.on||fly)?'none':'transform .42s cubic-bezier(.2,.8,.3,1)'}}
                  onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
                  <PhotoScene seed={card+20}/>
                  <div className="mi-sheen"/>
                  <div className="mi-tint mi-tint-keep" style={{opacity:keepP*.5}}/>
                  <div className="mi-tint mi-tint-trash" style={{opacity:trashP*.5}}/>
                  <div className="mi-stamp mi-stamp-keep" style={{opacity:keepP, transform:`rotate(-8deg) scale(${.8+keepP*.2})`}}>GARDER</div>
                  <div className="mi-stamp mi-stamp-trash" style={{opacity:trashP, transform:`rotate(8deg) scale(${.8+trashP*.2})`}}>POUBELLE</div>
                </div>
              </div>
              <div className="mi-actions">
                <button className="mi-rb mi-rb-trash" onClick={()=>runAuto('trash')}><Icon n="trash" s={25} w={1.9}/></button>
                <button className="mi-rb mi-rb-undo" onClick={undo} disabled={!history.length}><Icon n="arrow.uturn.backward" s={19} w={2}/></button>
                <button className="mi-rb mi-rb-keep" onClick={()=>runAuto('keep')}><Icon n="checkmark" s={28} w={2.2}/></button>
              </div>
            </div>
          </div></div>
          <div className="mi-hint-drag">↔ Glisse la carte, ou utilise les boutons</div>
        </div>

        {/* annotations */}
        <div className="mi-panel">
          <div className="mi-tag">Anatomie du geste</div>
          <h2 className="mi-h">Le swipe, décortiqué</h2>
          <p className="mi-sub">Le geste signature de YZPhotos. Chaque état a son retour visuel — direct, lisible, réversible.</p>

          <div className="mi-states">
            {STATES.map(([k,t,d])=>(
              <div key={k} className={`mi-state${state===k?' on':''}`}>
                <div className="mi-state-dot"/>
                <div className="mi-state-tx"><div className="mi-state-t">{t}</div><div className="mi-state-d">{d}</div></div>
              </div>
            ))}
          </div>

          {/* live readout */}
          <div className="mi-readout glass-m">
            <div className="mi-ro-row">
              <span className="mi-ro-k">Déplacement</span>
              <span className="mi-ro-v">{Math.round(dx)} px</span>
            </div>
            <div className="mi-meter"><div className="mi-meter-mid"/>
              <div className="mi-meter-fill" style={{width:`${Math.min(50,Math.abs(dx)/ (TH*2) *100)}%`, left:dx<0?`${50-Math.min(50,Math.abs(dx)/(TH*2)*100)}%`:'50%', background:dir==='keep'?'var(--mi-keep)':dir==='trash'?'var(--mi-trash)':'rgba(255,255,255,.4)'}}/>
            </div>
            <div className="mi-ro-row">
              <span className="mi-ro-k">Verdict</span>
              <span className={`mi-ro-badge ${engaged?(dir==='keep'?'keep':'trash'):'idle'}`}>
                {engaged?(dir==='keep'?'GARDER ✓':'POUBELLE ✕'):'en attente'}
              </span>
            </div>
          </div>

          <div className="mi-specs">
            <div className="mi-spec glass-m"><b>Seuil</b><span>{TH} px / flick</span></div>
            <div className="mi-spec glass-m"><b>Sortie</b><span>cubic-bezier .2,.8,.3,1</span></div>
            <div className="mi-spec glass-m"><b>Annulation</b><span>↶ jusqu'à 6 cartes</span></div>
            <div className="mi-spec glass-m"><b>Haptique</b><span>léger au seuil</span></div>
          </div>
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<MicroDemo/>);
