/* ═══════════════════════════════════════════════════════════
   YZPhotos — Écrans clés : Trier · Doublons · Corbeille
   ═══════════════════════════════════════════════════════════ */

/* ════════════════════ TRIER (deck façon Tinder) ════════════════════ */
function TrierScreen({ compact }) {
  const [idx, setIdx] = useState(0);
  const [history, setHistory] = useState([]);   // {id, dir}
  const [drag, setDrag] = useState({ x:0, y:0, active:false });
  const [flyOut, setFlyOut] = useState(null);     // 'keep' | 'trash'
  const startRef = useRef(null);

  const total = DECK.length;
  const done = history.length;
  const card = DECK[idx];
  const next = DECK[idx+1];

  const commit = useCallback((dir) => {
    if (!card || flyOut) return;
    setFlyOut(dir);
    setTimeout(() => {
      setHistory(h => [...h, { id: card.id, dir }]);
      setIdx(i => i+1);
      setFlyOut(null);
      setDrag({ x:0, y:0, active:false });
    }, 280);
  }, [card, flyOut]);

  const undo = () => {
    if (!history.length) return;
    setHistory(h => h.slice(0,-1));
    setIdx(i => Math.max(0, i-1));
  };

  // Pointer drag
  const onDown = (e) => {
    if (flyOut || !card) return;
    startRef.current = { x: e.clientX, y: e.clientY };
    setDrag(d => ({ ...d, active:true }));
    e.currentTarget.setPointerCapture?.(e.pointerId);
  };
  const onMove = (e) => {
    if (!drag.active || !startRef.current) return;
    setDrag({ x: e.clientX-startRef.current.x, y: e.clientY-startRef.current.y, active:true });
  };
  const onUp = () => {
    if (!drag.active) return;
    const TH = compact ? 90 : 130;
    if (drag.x > TH) commit('keep');
    else if (drag.x < -TH) commit('trash');
    else setDrag({ x:0, y:0, active:false });
    startRef.current = null;
  };

  const dx = flyOut ? (flyOut==='keep' ? 600 : -600) : drag.x;
  const rot = dx / 18;
  const keepOp = Math.max(0, Math.min(1, dx/120));
  const trashOp = Math.max(0, Math.min(1, -dx/120));

  const finished = idx >= total;

  return (
    <div className="scr trier">
      <div className="scr-head">
        <div>
          <div className="scr-title">Trier</div>
          <div className="scr-sub">{finished ? 'Terminé pour cette session' : `${done} traités · ${total-done} restants`}</div>
        </div>
        <div className="trier-count">
          <span className="tc-num">{Math.min(done+ (finished?0:1), total)}</span>
          <span className="tc-tot">/ {total}</span>
        </div>
      </div>
      <div className="trier-prog"><ProgressBar pct={(done/total)*100}/></div>

      <div className="deck">
        {finished ? (
          <EmptyState icon="checkmark" title="Tout est trié 🎉" sub="Les éléments écartés sont dans la Corbeille, restaurables à tout moment." />
        ) : (
          <>
            {next && (
              <div className="card-photo card-behind">
                <PhotoScene seed={next.g}/>
                <div className="card-grad"/>
              </div>
            )}
            <div
              className={`card-photo card-front${drag.active?' dragging':''}${flyOut?' flyout':''}`}
              style={{ transform:`translate(${dx}px, ${flyOut?-40:drag.y*0.25}px) rotate(${rot}deg)` }}
              onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
            >
              <PhotoScene seed={card.g}/>
              <div className="card-grad"/>
              {/* overlays */}
              <div className="swipe-label sl-keep" style={{opacity:keepOp}}>GARDER</div>
              <div className="swipe-label sl-trash" style={{opacity:trashOp}}>POUBELLE</div>
              {/* tint */}
              <div className="card-tint tint-keep" style={{opacity:keepOp*0.55}}/>
              <div className="card-tint tint-trash" style={{opacity:trashOp*0.55}}/>
              {/* meta */}
              <div className="card-meta">
                <div className="card-type">
                  <Icon n={card.type==='video'?'video':'photo'} s={15} w={1.9}/>
                  <span>{card.name}</span>
                </div>
                <div className="card-info">{card.meta} · {card.size} · {card.date}</div>
              </div>
            </div>
          </>
        )}
      </div>

      {!finished && (
        <div className="trier-actions">
          <button className="round-btn rb-trash" onClick={()=>commit('trash')} aria-label="Poubelle">
            <Icon n="trash" s={compact?24:27} w={1.8}/>
          </button>
          <button className="round-btn rb-undo" onClick={undo} disabled={!history.length} aria-label="Annuler">
            <Icon n="arrow.uturn.backward" s={compact?20:22} w={2}/>
          </button>
          <button className="round-btn rb-keep" onClick={()=>commit('keep')} aria-label="Garder">
            <Icon n="checkmark" s={compact?26:30} w={2.2}/>
          </button>
        </div>
      )}
      {finished && (
        <div className="trier-actions">
          <Btn kind="secondary" icon="arrow.counterclockwise" sz="lg" onClick={()=>{setIdx(0);setHistory([]);}}>Recommencer la session</Btn>
        </div>
      )}
    </div>
  );
}

/* ════════════════════ DOUBLONS ════════════════════ */
function DoublonsScreen({ compact }) {
  // selected = ids marked for trash. By default, non-best in each group pre-selected.
  const initSel = () => {
    const s = {};
    DUP_GROUPS.forEach(grp => grp.items.forEach(it => { if (!it.best) s[it.id] = true; }));
    return s;
  };
  const [sel, setSel] = useState(initSel);
  const toggle = (id) => setSel(s => ({ ...s, [id]: !s[id] }));

  const parseMo = (str) => {
    const v = parseFloat(str.replace(',','.'));
    return str.includes('Mo') ? v : v; // all Mo here
  };
  let count = 0, recoverable = 0;
  DUP_GROUPS.forEach(g => g.items.forEach(it => { if (sel[it.id]) { count++; recoverable += parseMo(it.size); } }));

  return (
    <div className="scr doublons">
      <div className="scr-head">
        <div>
          <div className="scr-title">Doublons</div>
          <div className="scr-sub">{DUP_GROUPS.length} groupes · {DUP_GROUPS.reduce((a,g)=>a+g.items.length,0)} fichiers similaires</div>
        </div>
        <Badge tone="accent" icon="sparkles">{recoverable.toFixed(1).replace('.',',')} Mo récupérables</Badge>
      </div>

      <div className="dup-scroll">
        {DUP_GROUPS.map(grp => (
          <div className="dup-group" key={grp.id}>
            <div className="dup-group-head">
              <span className="dup-sim"><Icon n="sparkles" s={13} w={1.9}/>{grp.sim} de similarité</span>
              <span className="dup-grp-meta">{grp.items.length} fichiers</span>
            </div>
            <div className={`dup-row${compact?' dup-row-compact':''}`}>
              {grp.items.map(it => {
                const isSel = !!sel[it.id];
                return (
                  <button key={it.id} className={`dup-item${it.best?' is-best':''}${isSel?' is-sel':''}`}
                    onClick={()=>!it.best && toggle(it.id)} disabled={it.best}>
                    <PhotoThumb g={it.g} radius={12}/>
                    {it.best && <div className="best-badge"><Icon n="star.fill" s={12}/><span>Meilleur</span></div>}
                    {!it.best && (
                      <div className={`sel-check${isSel?' on':''}`}>
                        {isSel && <Icon n="checkmark" s={14} w={2.6}/>}
                      </div>
                    )}
                    <div className="dup-item-meta">
                      <span className="dim-size">{it.size}</span>
                      <span className="dim-res">{it.meta}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      <div className="dup-foot">
        <div className="dup-foot-info">
          <span className="dup-foot-count">{count} fichier{count>1?'s':''} sélectionné{count>1?'s':''}</span>
          <span className="dup-foot-size">{recoverable.toFixed(1).replace('.',',')} Mo à libérer</span>
        </div>
        <Btn kind="destructive" icon="trash" sz="lg" disabled={!count}>Mettre à la poubelle</Btn>
      </div>
    </div>
  );
}

/* ════════════════════ CORBEILLE ════════════════════ */
function CorbeilleScreen({ compact }) {
  const [items, setItems] = useState(TRASH_INIT);
  const [modal, setModal] = useState(false);

  const parseSize = (str) => {
    const v = parseFloat(str.replace(',','.'));
    if (str.includes('Go')) return v*1024;
    if (str.includes('Mo')) return v;
    return v;
  };
  const totalMo = items.reduce((a,it)=>a+parseSize(it.size),0);
  const totalLabel = totalMo > 1024 ? `${(totalMo/1024).toFixed(2).replace('.',',')} Go` : `${totalMo.toFixed(0)} Mo`;

  const restore = (id) => setItems(its => its.filter(i=>i.id!==id));
  const empty = () => { setItems([]); setModal(false); };

  return (
    <div className="scr corbeille">
      <div className="scr-head">
        <div>
          <div className="scr-title">Corbeille</div>
          <div className="scr-sub">{items.length ? `${items.length} fichiers · ${totalLabel}` : 'Vide'}</div>
        </div>
        {!!items.length && (
          <Btn kind="destructive" icon="trash" onClick={()=>setModal(true)}>Vider</Btn>
        )}
      </div>

      <div className="trash-banner">
        <Icon n="info.circle" s={18} w={1.8}/>
        <span>Rien n'est supprimé du SSD tant que vous ne videz pas la corbeille. Tout reste restaurable.</span>
      </div>

      {items.length ? (
        <div className="trash-list">
          {items.map(it => (
            <div className="trash-row" key={it.id}>
              <PhotoThumb g={it.g} type={it.type} radius={9}/>
              <div className="trash-info">
                <div className="trash-name">{it.name}</div>
                <div className="trash-sub">{it.size} · {it.when}</div>
              </div>
              <button className="restore-btn" onClick={()=>restore(it.id)}>
                <Icon n="arrow.counterclockwise" s={15} w={2}/><span>Restaurer</span>
              </button>
            </div>
          ))}
        </div>
      ) : (
        <EmptyState icon="trash" title="Corbeille vide" sub="Les fichiers que vous écartez apparaîtront ici avant suppression définitive." />
      )}

      <Modal open={modal} onClose={()=>setModal(false)}
        icon="exclamationmark.triangle" iconTone="danger"
        title="Vider la corbeille ?"
        actions={<>
          <Btn kind="secondary" sz="lg" full onClick={()=>setModal(false)}>Annuler</Btn>
          <Btn kind="destructive" sz="lg" full onClick={empty}>Supprimer {totalLabel}</Btn>
        </>}>
        <p><b>{items.length} fichiers</b> seront définitivement supprimés du SSD et <b>{totalLabel}</b> seront libérés.</p>
        <p className="modal-reassure"><Icon n="checkmark" s={14} w={2.4}/> Aucun autre fichier de votre disque n'est touché.</p>
        <p className="modal-warn">Cette action est irréversible.</p>
      </Modal>
    </div>
  );
}

/* Placeholder pour onglets non câblés */
function ComingSoon({ name, icon }) {
  return (
    <div className="scr">
      <div className="scr-head"><div className="scr-title">{name}</div></div>
      <EmptyState icon={icon} title={`${name}`} sub="Écran inclus dans la planche complète — vague suivante." />
    </div>
  );
}

Object.assign(window, { TrierScreen, DoublonsScreen, CorbeilleScreen, ComingSoon });
