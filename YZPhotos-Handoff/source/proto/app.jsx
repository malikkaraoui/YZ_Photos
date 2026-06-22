/* ═══════════════════════════════════════════════════════════
   YZPhotos — App : device frame + toggles + tab bar
   ═══════════════════════════════════════════════════════════ */

const TABS = [
  { id:'trier',     label:'Trier',     icon:'rectangle.stack', wired:true },
  { id:'doublons',  label:'Doublons',  icon:'square.on.square', wired:true },
  { id:'corbeille', label:'Corbeille', icon:'trash', wired:true },
  { id:'photos',    label:'Photos',    icon:'photo' },
  { id:'stats',     label:'Stats',     icon:'chart.bar' },
];
const OVERFLOW = ['Dossiers','Vidéos','Captures','Par taille','Analyse','Réglages'];

function Screen({ tab, compact }) {
  switch (tab) {
    case 'trier':     return <TrierScreen compact={compact}/>;
    case 'doublons':  return <DoublonsScreen compact={compact}/>;
    case 'corbeille': return <CorbeilleScreen compact={compact}/>;
    case 'photos':    return <ComingSoon name="Photos" icon="photo"/>;
    case 'stats':     return <ComingSoon name="Stats" icon="chart.bar"/>;
    default:          return null;
  }
}

/* ── iPhone : tab bar en bas ─────────────────────────── */
function PhoneTabBar({ tab, setTab }) {
  return (
    <div className="tabbar tabbar-bottom">
      {TABS.map(t => (
        <button key={t.id} className={`tabitem${tab===t.id?' active':''}`} onClick={()=>setTab(t.id)}>
          <Icon n={t.icon} s={25} w={tab===t.id?2:1.7}/>
          <span>{t.label}</span>
        </button>
      ))}
    </div>
  );
}

/* ── iPad : tab bar flottante en haut (iPadOS 18) ────── */
function PadTabBar({ tab, setTab }) {
  return (
    <div className="tabbar-float-wrap">
      <div className="tabbar-float">
        {TABS.map(t => (
          <button key={t.id} className={`floatitem${tab===t.id?' active':''}`} onClick={()=>setTab(t.id)}>
            <Icon n={t.icon} s={19} w={tab===t.id?2.1:1.8}/>
            <span>{t.label}</span>
          </button>
        ))}
        <div className="float-sep"/>
        <button className="floatitem floatitem-more"><Icon n="rectangle.stack" s={18} w={1.8}/><span>Plus</span></button>
      </div>
    </div>
  );
}

/* ── Barre de statut ─────────────────────────────────── */
function StatusBar({ compact }) {
  return (
    <div className={`statusbar${compact?' sb-compact':''}`}>
      <span className="sb-time">9:41</span>
      {compact && <div className="sb-island"/>}
      <span className="sb-right">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="5" y="4.5" width="3" height="7.5" rx="1"/><rect x="10" y="2" width="3" height="10" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1" opacity="0.35"/></svg>
        <svg width="16" height="12" viewBox="0 0 16 12" fill="none" stroke="currentColor" strokeWidth="1.2"><path d="M1 6a7 7 0 0 1 14 0M3.3 8a4 4 0 0 1 9.4 0M5.7 10a1.6 1.6 0 0 1 4.6 0" strokeLinecap="round"/></svg>
        <svg width="26" height="13" viewBox="0 0 26 13" fill="none"><rect x="1" y="1" width="21" height="11" rx="3" stroke="currentColor" strokeWidth="1" opacity="0.5"/><rect x="2.5" y="2.5" width="16" height="8" rx="1.5" fill="currentColor"/><rect x="23.5" y="4" width="1.6" height="5" rx="0.8" fill="currentColor" opacity="0.5"/></svg>
      </span>
    </div>
  );
}

/* ── Disque branché (barre app) ──────────────────────── */
function DriveBar({ compact }) {
  return (
    <div className={`drivebar${compact?' db-compact':''}`}>
      <span className="db-left">
        <span className="db-dot"/>
        <Icon n="externaldrive" s={compact?15:16} w={1.8}/>
        <span className="db-name">Samsung T7 Pro</span>
      </span>
      {!compact && <span className="db-meta">847 Go / 1 To · 2 847 fichiers</span>}
      <button className="db-eject" aria-label="Éjecter"><Icon n="eject" s={compact?14:15} w={1.8}/></button>
    </div>
  );
}

/* ── Cadre iPhone ────────────────────────────────────── */
function PhoneFrame({ children }) {
  return (
    <div className="iphone">
      <div className="iphone-screen">{children}</div>
    </div>
  );
}
/* ── Cadre iPad ──────────────────────────────────────── */
function PadFrame({ children }) {
  return (
    <div className="ipad">
      <div className="ipad-screen">{children}</div>
    </div>
  );
}

/* ── APP ─────────────────────────────────────────────── */
function App() {
  const [device, setDevice] = useState('ipad');   // 'ipad' | 'iphone'
  const [theme, setTheme]   = useState('glass');   // 'glass' | 'light' | 'dark'
  const [tab, setTab]       = useState('trier');
  const stageRef = useRef(null);
  const frameRef = useRef(null);

  const compact = device === 'iphone';

  // Scale frame to fit stage
  useEffect(() => {
    function fit() {
      const stage = stageRef.current, frame = frameRef.current;
      if (!stage || !frame) return;
      const pad = 48;
      const sw = stage.clientWidth - pad, sh = stage.clientHeight - pad;
      const fw = frame.offsetWidth, fh = frame.offsetHeight;
      const k = Math.min(sw/fw, sh/fh, 1);
      frame.style.transform = `scale(${k})`;
    }
    fit();
    window.addEventListener('resize', fit);
    const t = setTimeout(fit, 60);
    return () => { window.removeEventListener('resize', fit); clearTimeout(t); };
  }, [device]);

  const content = (
    <div className="app-root" data-theme={theme}>
      <StatusBar compact={compact}/>
      {!compact && <PadTabBar tab={tab} setTab={setTab}/>}
      <DriveBar compact={compact}/>
      <div className="app-body">
        <Screen tab={tab} compact={compact}/>
      </div>
      {compact && <PhoneTabBar tab={tab} setTab={setTab}/>}
    </div>
  );

  return (
    <div className="root-wrap" data-theme={theme}>
      {/* Chrome de contrôle */}
      <div className="chrome">
        <div className="chrome-brand">
          <span className="cb-logo">YZ<b>Photos</b></span>
          <span className="cb-tag">Prototype · écrans clés</span>
        </div>
        <div className="chrome-controls">
          <div className="seg2">
            <button className={device==='ipad'?'on':''} onClick={()=>setDevice('ipad')}>iPad 13"</button>
            <button className={device==='iphone'?'on':''} onClick={()=>setDevice('iphone')}>iPhone</button>
          </div>
          <div className="seg2">
            <button className={theme==='glass'?'on':''} onClick={()=>setTheme('glass')}>◈ Verre</button>
            <button className={theme==='light'?'on':''} onClick={()=>setTheme('light')}>☀ Clair</button>
            <button className={theme==='dark'?'on':''} onClick={()=>setTheme('dark')}>☾ Sombre</button>
          </div>
        </div>
      </div>

      {/* Scène */}
      <div className="stage" ref={stageRef} data-theme={theme}>
        <div className="frame-holder" ref={frameRef}>
          {compact ? <PhoneFrame>{content}</PhoneFrame> : <PadFrame>{content}</PadFrame>}
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
