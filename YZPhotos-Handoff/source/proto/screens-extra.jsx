/* ═══════════════════════════════════════════════════════════
   YZPhotos — Écrans restants (planche statique)
   Réutilise Icon, gradStyle, Btn, Badge de components.jsx
   ═══════════════════════════════════════════════════════════ */

/* ════════ CHROME PARTAGÉ ════════ */
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
function DriveBar({ compact }) {
  return (
    <div className={`drivebar${compact?' db-compact':''}`}>
      <span className="db-left"><span className="db-dot"/><Icon n="externaldrive" s={compact?15:16} w={1.8}/><span className="db-name">Samsung T7 Pro</span></span>
      {!compact && <span className="db-meta">847 Go / 1 To · 2 847 fichiers</span>}
      <button className="db-eject"><Icon n="eject" s={compact?14:15} w={1.8}/></button>
    </div>
  );
}
const TABS = [
  { id:'trier', label:'Trier', icon:'rectangle.stack' },
  { id:'dossiers', label:'Dossiers', icon:'folder' },
  { id:'photos', label:'Photos', icon:'photo' },
  { id:'doublons', label:'Doublons', icon:'square.on.square' },
  { id:'stats', label:'Stats', icon:'chart.bar' },
];
function PadTabBar({ active }) {
  return (
    <div className="tabbar-float-wrap"><div className="tabbar-float">
      {TABS.map(t=>(<button key={t.id} className={`floatitem${active===t.id?' active':''}`}>
        <Icon n={t.icon} s={19} w={active===t.id?2.1:1.8}/><span>{t.label}</span></button>))}
      <div className="float-sep"/>
      <button className="floatitem floatitem-more"><Icon n="rectangle.stack" s={18} w={1.8}/><span>Plus</span></button>
    </div></div>
  );
}
function PhoneTabBar({ active }) {
  return (
    <div className="tabbar tabbar-bottom">
      {TABS.map(t=>(<button key={t.id} className={`tabitem${active===t.id?' active':''}`}>
        <Icon n={t.icon} s={25} w={active===t.id?2:1.7}/><span>{t.label}</span></button>))}
    </div>
  );
}

/* ════════ FRAME WRAPPER ════════ */
function AppFrame({ device, theme, tab='trier', drive=true, chrome=true, children }) {
  const compact = device === 'iphone';
  const inner = (
    <div className="app-root" data-theme={theme}>
      <StatusBar compact={compact}/>
      {chrome && !compact && <PadTabBar active={tab}/>}
      {drive && <DriveBar compact={compact}/>}
      <div className="app-body">{children}</div>
      {chrome && compact && <PhoneTabBar active={tab}/>}
    </div>
  );
  return compact
    ? <div className="iphone"><div className="iphone-screen">{inner}</div></div>
    : <div className="ipad"><div className="ipad-screen">{inner}</div></div>;
}

/* ════════════════ 1 · CHOIX DU DISQUE ════════════════ */
function DiskScreen({ compact, empty }) {
  return (
    <div className="launch">
      <div className="launch-logo"><Icon n="rectangle.stack" s={40} w={1.6}/></div>
      <div className="launch-title">Quel disque trier ?</div>
      <div className="launch-sub">Branchez votre SSD pour analyser et trier vos photos. Rien n'est copié sur l'appareil.</div>
      {empty ? (
        <div className="launch-empty">
          <Icon n="externaldrive" s={34} w={1.5}/>
          <div style={{marginTop:10,fontWeight:600,color:'var(--t2)'}}>Aucun disque connecté</div>
          <div style={{marginTop:4}}>Branchez un SSD USB-C pour commencer.</div>
        </div>
      ) : (
        <div className="disk-list">
          <button className="disk-card connected">
            <div className="disk-ic"><Icon n="externaldrive" s={24} w={1.7}/></div>
            <div className="disk-info">
              <div className="disk-name">Samsung T7 Pro <span className="dot"/></div>
              <div className="disk-meta">1 To · connecté · analysé il y a 2 min</div>
            </div>
            <div className="disk-chev"><Icon n="chevron.right" s={18}/></div>
          </button>
          <button className="disk-card">
            <div className="disk-ic"><Icon n="externaldrive" s={24} w={1.7}/></div>
            <div className="disk-info">
              <div className="disk-name">Samsung T5</div>
              <div className="disk-meta">500 Go · déconnecté · dernière analyse hier</div>
            </div>
            <div className="disk-chev"><Icon n="chevron.right" s={18}/></div>
          </button>
        </div>
      )}
      <Btn kind="primary" icon="plus" sz="lg">Brancher un disque</Btn>
    </div>
  );
}

/* ════════════════ 2 · ANALYSE / SCAN ════════════════ */
function ScanScreen({ compact }) {
  return (
    <div className="scr">
      <div className="scr-head"><div><div className="scr-title">Analyse</div>
        <div className="scr-sub">Samsung T7 Pro · 2 passes</div></div></div>
      <div className="scan">
        <div className="scan-passes">
          <div className="pass done"><div className="pass-step"><Icon n="checkmark" s={14} w={2.4}/>Passe 1</div>
            <div className="pass-name">Métadonnées</div><div className="pass-desc">Terminée · 2 847 fichiers</div></div>
          <div className="pass active"><div className="pass-step"><Icon n="sparkles" s={14} w={1.9}/>Passe 2</div>
            <div className="pass-name">Empreintes &amp; miniatures</div><div className="pass-desc">En cours…</div></div>
        </div>
        <div className="scan-center">
          <div className="scan-pct">68 %</div>
          <div className="scan-label">Génération des empreintes visuelles</div>
        </div>
        <div className="scan-bar"><div className="prog prog-lg"><div className="prog-fill prog-accent" style={{width:'68%'}}/></div></div>
        <div className="scan-counts">
          <div className="count-card"><div className="count-num">1 936</div><div className="count-lbl">fichiers analysés</div></div>
          <div className="count-card"><div className="count-num">911</div><div className="count-lbl">restants</div></div>
          <div className="count-card"><div className="count-num">14</div><div className="count-lbl">doublons trouvés</div></div>
        </div>
        <div className="scan-controls">
          <Btn kind="secondary" icon="pause" sz="lg">Pause</Btn>
          <Btn kind="secondary" sz="lg">Arrêter</Btn>
        </div>
        <div className="scan-note"><Icon n="info.circle" s={15} w={1.8}/>Reprise gratuite si vous débranchez le disque.</div>
      </div>
    </div>
  );
}

/* ════════════════ 3 · BIBLIOTHÈQUE ════════════════ */
function LibraryScreen({ compact }) {
  const sel = { 2:true, 5:true, 9:true };
  const n = compact ? 16 : 30;
  return (
    <div className="scr">
      <div className="scr-head"><div><div className="scr-title">Photos</div>
        <div className="scr-sub">2 461 photos · 3 sélectionnées</div></div>
        <Badge tone="accent" icon="checkmark">Sélection</Badge></div>
      <div className="lib-toolbar">
        <span className="lib-sort"><Icon n="arrow.up.arrow.down" s={15} w={1.8}/>Date ↓</span>
        <span className="lib-sort"><Icon n="square.on.square" s={15} w={1.7}/>Tout sélectionner</span>
      </div>
      <div className="lib-grid">
        {Array.from({length:n}).map((_,i)=>(
          <div key={i} className={`lib-cell${sel[i]?' sel':''}`}>
            <PhotoScene seed={i}/>
            {sel[i] && <div className="lib-check on"><Icon n="checkmark" s={13} w={2.6}/></div>}
          </div>
        ))}
      </div>
    </div>
  );
}

/* aperçu plein écran */
function PreviewScreen({ compact }) {
  return (
    <div className="scr">
      <div className="scr-head" style={{paddingBottom:6}}>
        <button className="restore-btn" style={{border:'none',padding:'6px 0',background:'transparent'}}><Icon n="chevron.left" s={18}/><span>Photos</span></button>
      </div>
      <div className="preview-sheet">
        <div className="pv-photo"><PhotoScene seed={4}/></div>
        <div className="pv-meta">
          <div className="pv-name">IMG_4821.HEIC</div>
          <div className="pv-rows">
            <div className="pv-row"><span className="k">Dimensions</span><span className="v">4032 × 3024</span></div>
            <div className="pv-row"><span className="k">Taille</span><span className="v">4,2 Mo</span></div>
            <div className="pv-row"><span className="k">Date</span><span className="v">14 mars 2026 · 14:32</span></div>
            <div className="pv-row"><span className="k">Dossier</span><span className="v">/DCIM/2026/Mars</span></div>
          </div>
        </div>
        <div className="pv-actions">
          <Btn kind="secondary" icon="square.on.square" sz="lg" full>Voir doublons</Btn>
          <Btn kind="destructive" icon="trash" sz="lg" full>Poubelle</Btn>
        </div>
      </div>
    </div>
  );
}

/* ════════════════ 4 · DOSSIERS ════════════════ */
function FoldersScreen({ compact }) {
  const folders = [
    { n:'2026', s:'1 284 fichiers · 4,2 Go', h:210 },
    { n:'2025', s:'3 920 fichiers · 14,1 Go', h:265 },
    { n:'Captures d\'écran', s:'612 fichiers · 1,1 Go', h:42 },
    { n:'WhatsApp', s:'2 104 fichiers · 6,8 Go', h:140 },
    { n:'Exports Lightroom', s:'318 fichiers · 9,4 Go', h:24 },
  ];
  const files = [
    { n:'IMG_4821.HEIC', s:'4,2 Mo', g:4, t:'photo' },
    { n:'MOV_0145.MOV', s:'128 Mo', g:2, t:'video' },
    { n:'IMG_4790.HEIC', s:'5,1 Mo', g:6, t:'photo' },
  ];
  return (
    <div className="scr">
      <div className="scr-head"><div><div className="scr-title">Dossiers</div>
        <div className="scr-sub">Samsung T7 Pro</div></div></div>
      <div className="crumb"><span>SSD</span><span className="seg-c"><Icon n="chevron.right" s={13}/></span>
        <span>DCIM</span><span className="seg-c"><Icon n="chevron.right" s={13}/></span><span className="cur">2026</span></div>
      <div className="folder-list">
        {folders.slice(0,compact?3:5).map((f,i)=>(
          <div className="folder-row" key={f.n}>
            <div className="folder-ic" style={{background:`hsl(${(i*47+210)%360} 45% 58%)`}}><Icon n="folder" s={22} w={1.7}/></div>
            <div className="folder-info"><div className="folder-name">{f.n}</div><div className="folder-sub">{f.s}</div></div>
            <div className="folder-chev"><Icon n="chevron.right" s={18}/></div>
          </div>
        ))}
        {files.slice(0,compact?2:3).map(f=>(
          <div className="folder-row" key={f.n}>
            <div className="thumb" style={{width:42,height:42,borderRadius:9,flexShrink:0}}>
              <PhotoScene seed={f.g}/>
              {f.t==='video' && <div className="thumb-badge" style={{width:16,height:16}}><Icon n="play.fill" s={9}/></div>}
            </div>
            <div className="folder-info"><div className="folder-name">{f.n}</div><div className="folder-sub">{f.s}</div></div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ════════════════ 5 · STATS ════════════════ */
function StatsScreen({ compact }) {
  return (
    <div className="scr">
      <div className="scr-head"><div><div className="scr-title">Stats</div>
        <div className="scr-sub">Samsung T7 Pro · 1 To</div></div></div>
      <div className="stats-scroll">
        <div className="stat-grid">
          <div className="stat-card"><div className="stat-ic"><Icon n="photo" s={20} w={1.8}/></div><div className="stat-num">2 461</div><div className="stat-lbl">Photos</div></div>
          <div className="stat-card"><div className="stat-ic"><Icon n="video" s={20} w={1.8}/></div><div className="stat-num">386</div><div className="stat-lbl">Vidéos</div></div>
          <div className="stat-card"><div className="stat-ic"><Icon n="externaldrive" s={20} w={1.8}/></div><div className="stat-num">847 Go</div><div className="stat-lbl">Espace utilisé</div></div>
          <div className="stat-card accent"><div className="stat-ic" style={{color:'var(--accent)'}}><Icon n="sparkles" s={20} w={1.8}/></div><div className="stat-num">38 Go</div><div className="stat-lbl">Récupérable</div></div>
        </div>
        <div className="charts">
          <div className="chart-card">
            <div className="chart-title">Fichiers triés par semaine</div>
            <div className="bars">
              {[40,62,48,80,55,95,70].map((h,i)=>(
                <div className="bar-col" key={i}>
                  <div className={`bar${i%2?' alt':''}`} style={{height:`${h}%`}}/>
                  <div className="bar-lbl">S{i+1}</div>
                </div>
              ))}
            </div>
          </div>
          <div className="chart-card">
            <div className="chart-title">Répartition</div>
            <div className="donut-wrap">
              <svg width="96" height="96" viewBox="0 0 36 36">
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="var(--accent)" strokeWidth="5" strokeDasharray="62 100" transform="rotate(-90 18 18)"/>
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="var(--keep)" strokeWidth="5" strokeDasharray="22 100" strokeDashoffset="-62" transform="rotate(-90 18 18)"/>
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="var(--warn)" strokeWidth="5" strokeDasharray="16 100" strokeDashoffset="-84" transform="rotate(-90 18 18)"/>
              </svg>
              <div className="donut-legend">
                <span className="leg"><span className="sw" style={{background:'var(--accent)'}}/>Photos <b>62 %</b></span>
                <span className="leg"><span className="sw" style={{background:'var(--keep)'}}/>Vidéos <b>22 %</b></span>
                <span className="leg"><span className="sw" style={{background:'var(--warn)'}}/>Captures <b>16 %</b></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ════════════════ 6 · RÉGLAGES ════════════════ */
function SettingsScreen({ compact }) {
  return (
    <div className="scr">
      <div className="scr-head"><div className="scr-title">Réglages</div></div>
      <div className="set-scroll">
        <div className="set-sec-h">Apparence</div>
        <div className="set-card">
          <div className="set-row">
            <div className="set-ic" style={{background:'#5B5BD6'}}><Icon n="rectangle.stack" s={17} w={1.8}/></div>
            <span className="set-label">Thème</span>
            <div className="mini-seg"><span>Système</span><span className="on">Clair</span><span>Sombre</span></div>
          </div>
        </div>
        <div className="set-sec-h">Lecture &amp; affichage</div>
        <div className="set-card">
          <div className="set-row"><div className="set-ic" style={{background:'#28B463'}}><Icon n="play.fill" s={15}/></div>
            <span className="set-label">Lecture auto des vidéos</span><div className="tog on"/></div>
          <div className="set-row"><div className="set-ic" style={{background:'#E08600'}}><Icon n="arrow.up.arrow.down" s={16} w={1.8}/></div>
            <span className="set-label">Ordre de grille par défaut</span><span className="set-val">Date <Icon n="chevron.right" s={15}/></span></div>
        </div>
        <div className="set-sec-h">Disques</div>
        <div className="set-card">
          <div className="set-row"><div className="set-ic" style={{background:'#28B463'}}><Icon n="externaldrive" s={16} w={1.8}/></div>
            <span className="set-label">Samsung T7 Pro</span><button className="eject-btn">Éjecter</button></div>
          <div className="set-row"><div className="set-ic" style={{background:'#A0A0A8'}}><Icon n="externaldrive" s={16} w={1.8}/></div>
            <span className="set-label">Samsung T5</span><button className="del-btn">Supprimer</button></div>
        </div>
        <div className="set-foot">Éjecter arrête l'analyse en cours. Supprimer un disque connu efface seulement son historique dans YZPhotos — aucun fichier n'est touché.</div>
      </div>
    </div>
  );
}

/* ════════════════ 7 · DIALOGUE DESTRUCTIF ════════════════ */
function DeleteDiskScreen({ compact }) {
  return (
    <div className="scr" style={{position:'relative'}}>
      <SettingsScreen compact={compact}/>
      <div className="modal-scrim">
        <div className="modal">
          <div className="modal-icon modal-icon-warn"><Icon n="externaldrive" s={28} w={1.7}/></div>
          <div className="modal-title">Supprimer « Samsung T5 » ?</div>
          <div className="modal-body">
            <p>Son <b>historique d'analyse</b> et ses préférences seront retirés de YZPhotos.</p>
            <p className="modal-reassure"><Icon n="checkmark" s={14} w={2.4}/> Aucune photo ni vidéo du disque n'est supprimée.</p>
          </div>
          <div className="modal-actions">
            <Btn kind="secondary" sz="lg" full>Annuler</Btn>
            <Btn kind="destructive" sz="lg" full>Supprimer</Btn>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ════════════════ 8 · PHOTOTHÈQUES / SOURCES ════════════════ */
const LIBRARIES = [
  { id:'l1', name:'Photothèque principale', items:'18 432 photos · 1 240 vidéos', formats:['HEIC','RAW','MOV'], active:true },
  { id:'l2', name:'Photos 2019–2021',       items:'9 210 photos · 540 vidéos',  formats:['JPEG','HEIC'] },
  { id:'l3', name:'Photothèque de Marie',    items:'4 120 photos · 210 vidéos',  formats:['HEIC','MP4'] },
];
const SRC_FOLDERS = [
  { id:'f1', name:'DCIM',              items:'2 847 fichiers · 11,4 Go', formats:['JPEG','MOV'] },
  { id:'f2', name:'WhatsApp',          items:'2 104 fichiers · 6,8 Go',  formats:['JPEG','MP4'] },
  { id:'f3', name:"Captures d'écran",  items:'612 fichiers · 1,1 Go',    formats:['PNG'] },
  { id:'f4', name:'Exports RAW',       items:'318 fichiers · 9,4 Go',    formats:['DNG','CR2','NEF'] },
];

function SourcesScreen({ compact }) {
  const [active, setActive] = useState('l1');
  const Row = ({ s, kind }) => {
    const on = active === s.id;
    return (
      <div className={`source-row${on?' active':''}`} onClick={()=>setActive(s.id)}>
        <div className={`source-ic ${kind==='lib'?'lib':'fold'}`}>
          <Icon n={kind==='lib'?'photo.stack':'folder'} s={22} w={1.7}/>
        </div>
        <div className="source-main">
          <div className="source-name-row">
            <span className="source-name">{s.name}</span>
            {kind==='lib' && <span className="lib-tag">.photoslibrary</span>}
          </div>
          <div className="source-meta">{s.items}</div>
          <div className="fmt-chips">{s.formats.map(f=><span key={f} className="fmt-chip">{f}</span>)}</div>
        </div>
        {on
          ? <div className="source-check"><Icon n="checkmark" s={14} w={2.6}/></div>
          : <div className="source-go"><Icon n="chevron.right" s={18}/></div>}
      </div>
    );
  };
  return (
    <div className="scr">
      <div className="scr-head">
        <div>
          <div className="scr-title">Photothèques</div>
          <div className="scr-sub">3 photothèques Apple · 4 dossiers sur ce disque</div>
        </div>
        <Badge tone="accent" icon="checkmark">Tout lu directement</Badge>
      </div>
      <div className="src-scroll">
        <div className="src-hero">
          <div className="src-hero-ic"><Icon n="photo.stack" s={22} w={1.7}/></div>
          <div>
            <div className="src-hero-tt">Toutes vos photothèques, réunies</div>
            <div className="src-hero-sub">Vos bibliothèques <b style={{color:'var(--t1)'}}>.photoslibrary</b> Apple et vos dossiers, lus directement depuis le SSD. Fini de jongler entre plusieurs photothèques dans Photos — basculez d'un tap.</div>
          </div>
        </div>

        <div className="src-group-label"><span>Photothèques Apple</span><span style={{textTransform:'none',fontWeight:500,color:'var(--t3)'}}>HEIC · RAW · MOV</span></div>
        <div className="src-list">
          {LIBRARIES.map(l=><Row key={l.id} s={l} kind="lib"/>)}
        </div>

        <div className="src-group-label"><span>Dossiers photos &amp; vidéos</span><span style={{textTransform:'none',fontWeight:500,color:'var(--t3)'}}>JPEG · PNG · DNG · MP4…</span></div>
        <div className="src-list">
          {SRC_FOLDERS.map(f=><Row key={f.id} s={f} kind="fold"/>)}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  AppFrame, DiskScreen, ScanScreen, LibraryScreen, PreviewScreen,
  FoldersScreen, StatsScreen, SettingsScreen, DeleteDiskScreen, SourcesScreen,
});
