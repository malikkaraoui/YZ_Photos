/* ═══════════════════════════════════════════════════════════
   YZPhotos — UI Kit (documentation du design system réel)
   Réutilise Icon / Btn / Badge / ProgressBar de components.jsx
   ═══════════════════════════════════════════════════════════ */
const { useState } = React;

/* ── données ── */
const BRAND = {
  light:[['Accent','#5B5BD6'],['Garder','#28B463'],['Poubelle','#E5484D'],['Alerte','#E08600'],['Accent doux','#ECECFB']],
  dark: [['Accent','#8A88FF'],['Garder','#3DD27F'],['Poubelle','#FF5C61'],['Alerte','#F5A623'],['Accent doux','#22223A']],
  glass:[['Mandarin','#E87B3E'],['Sulphur','#B6D84B'],['Confetti','#F06A8C'],['Carmine','#B23A5D'],['Old Gold','#F0B43E']],
};
const NEUTRAL = {
  light:[['Page','#F7F7F9'],['Fond','#FFFFFF'],['Fond 2','#F4F4F6'],['Fond 3','#ECECEF'],['Séparateur','#E9E9EC']],
  dark: [['Page','#0A0A0C'],['Fond','#0C0C0E'],['Fond 2','#161618'],['Fond 3','#202024'],['Séparateur','#2A2A2E']],
  glass:[['Storm Blue','#244252'],['Verre','rgba(255,255,255,.14)'],['Verre fort','rgba(255,255,255,.22)'],['Bord','rgba(255,255,255,.42)'],['Fond profond','#152D3A']],
};
const LABELS = {
  light:[['Label','#161618'],['Label 2','#6A6A70'],['Label 3','#A0A0A8']],
  dark: [['Label','#F4F4F6'],['Label 2','#9A9AA2'],['Label 3','#5E5E66']],
  glass:[['Label','#FFFFFF'],['Label 2','rgba(255,255,255,.82)'],['Label 3','rgba(255,255,255,.58)']],
};
const TYPE = [
  ['Large Title','34 / 700','34px','700','Trier'],
  ['Title 1','30 / 700','30px','700','Photothèques'],
  ['Title 2','22 / 700','22px','700','Doublons détectés'],
  ['Headline','17 / 600','17px','600','Samsung T7 Pro connecté'],
  ['Body','16 / 450','16px','450','Gardez d’un geste, jetez de l’autre.'],
  ['Subhead','14 / 450','14px','450','3 photothèques · 4 dossiers'],
  ['Footnote','13 / 450','13px','450','Rien n’est supprimé sans confirmation.'],
  ['Caption','11 / 600','11px','600','HEIC · RAW · MOV'],
];
const ICONS = ['rectangle.stack','square.on.square','folder','photo','photo.stack','video','trash','camera.viewfinder','chart.bar','magnifyingglass','gearshape','externaldrive','arrow.up.arrow.down','arrow.counterclockwise','arrow.uturn.backward','checkmark','xmark','plus','chevron.right','chevron.left','star.fill','play.fill','pause','eject','sparkles','info.circle','exclamationmark.triangle'];

function Sw({ n, h }){
  return <div className="sw"><div className="sw-c" style={{background:h}}/><div className="sw-i"><div className="sw-n">{n}</div><div className="sw-h">{h}</div></div></div>;
}
function SwGroup({ label, rows }){
  return <div style={{marginBottom:18}}>
    <div className="k-panel-label">{label}</div>
    <div className="sw-grid">{rows.map(([n,h])=><Sw key={n} n={n} h={h}/>)}</div>
  </div>;
}

function Kit(){
  const [theme,setTheme] = useState('glass');
  const t = theme;
  return (
    <div className="kit" data-theme={t}>
      <header className="k-hdr">
        <span className="k-logo"><b>YZ</b>Photos</span>
        <span className="k-pill">UI Kit v1.0</span>
        <span className="k-sp"/>
        <div className="k-toggle">
          <button className={t==='glass'?'on':''} onClick={()=>setTheme('glass')}>◈ Verre</button>
          <button className={t==='light'?'on':''} onClick={()=>setTheme('light')}>☀ Clair</button>
          <button className={t==='dark'?'on':''} onClick={()=>setTheme('dark')}>☾ Sombre</button>
        </div>
      </header>

      <div className="k-body">
        <div className="k-hero">
          <h1>UI Kit</h1>
          <p>Le système visuel de YZPhotos — sobre, léger, pur. Entre la chaleur d’Apple Photos et la rigueur d’un gestionnaire de fichiers. iOS / iPadOS 18.</p>
          <div className="k-principles">
            <div className="k-principle"><div className="pt">Soft</div><div className="pd">Neutres calmes, accent indigo discret, vert/rouge réservés au sens (garder/jeter).</div></div>
            <div className="k-principle"><div className="pt">Léger</div><div className="pd">Beaucoup d’air, ombres douces, hiérarchie portée par la taille du texte, pas par le bruit.</div></div>
            <div className="k-principle"><div className="pt">Pur</div><div className="pd">Une action principale par écran. L’interface s’efface, les photos parlent.</div></div>
          </div>
        </div>

        {/* COULEURS */}
        <section className="k-section">
          <div className="k-tag">Fondation</div>
          <div className="k-h">Couleurs</div>
          <div className="k-sub">La palette s’adapte au thème. Bascule clair/sombre en haut à droite pour voir les deux jeux.</div>
          <div className="k-panel">
            <SwGroup label="Brand & sémantique" rows={BRAND[t]}/>
            <SwGroup label="Neutres / fonds" rows={NEUTRAL[t]}/>
            <SwGroup label="Texte" rows={LABELS[t]}/>
          </div>
        </section>

        {/* TYPO */}
        <section className="k-section">
          <div className="k-tag">Fondation</div>
          <div className="k-h">Typographie</div>
          <div className="k-sub">SF Pro (system-ui). Styles sémantiques iOS — respectent Dynamic Type.</div>
          <div className="k-panel">
            {TYPE.map(([n,m,sz,fw,ex])=>(
              <div className="type-row" key={n}>
                <span className="type-meta">{n} · {m}</span>
                <span style={{fontSize:sz,fontWeight:fw,color:'var(--ink)',lineHeight:1.1}}>{ex}</span>
              </div>
            ))}
          </div>
        </section>

        {/* RADIUS + SHADOW */}
        <section className="k-section">
          <div className="k-tag">Dimension</div>
          <div className="k-h">Rayons, ombres & grille</div>
          <div className="k-sub">Élévation discrète, coins généreux. Espacement sur une base de 4 pt.</div>
          <div className="k-panel">
            <div className="k-panel-label">Corner radius</div>
            <div className="rad-row">
              {[['Chip','6'],['Bouton','12'],['Carte','16'],['Modale','22'],['Pastille','∞']].map(([l,r])=>(
                <div className="rad" key={l}><div className="rad-box" style={{borderRadius:r==='∞'?'50%':r+'px'}}/><div className="rad-l">{l}<br/>{r==='∞'?'rond':r+' pt'}</div></div>
              ))}
            </div>
          </div>
          <div className="k-panel">
            <div className="k-panel-label">Ombres</div>
            <div className="sh-row">
              <div className="sh" style={{boxShadow:'var(--shadow-card)'}}>Card</div>
              <div className="sh" style={{boxShadow:'var(--shadow-float)'}}>Float / overlay</div>
            </div>
          </div>
        </section>

        {/* ICONES */}
        <section className="k-section">
          <div className="k-tag">Système</div>
          <div className="k-h">Icônes</div>
          <div className="k-sub">Jeu d’icônes au trait, calé sur les SF Symbols Apple — cohérent à 1,7 px de graisse.</div>
          <div className="k-panel">
            <div className="ic-grid">
              {ICONS.map(n=>(
                <div className="ic-cell" key={n}><Icon n={n} s={24}/><span className="nm">{n}</span></div>
              ))}
            </div>
          </div>
        </section>

        {/* COMPOSANTS */}
        <section className="k-section">
          <div className="k-tag">Interface</div>
          <div className="k-h">Composants</div>
          <div className="k-sub">Éléments natifs prêts à composer. Interactifs — clique pour tester.</div>
          <div className="cmp-grid">
            <div className="cmp">
              <div className="cmp-l">Boutons</div>
              <div className="cmp-row"><Btn kind="primary">Primaire</Btn><Btn kind="secondary">Secondaire</Btn><Btn kind="destructive" icon="trash">Poubelle</Btn></div>
              <div className="cmp-row"><Btn kind="primary" icon="plus" sz="lg">Brancher un disque</Btn></div>
            </div>
            <div className="cmp">
              <div className="cmp-l">Badges</div>
              <div className="cmp-row">
                <Badge tone="accent" icon="sparkles">Récupérable</Badge>
                <Badge tone="keep" icon="checkmark">Gardée</Badge>
                <Badge tone="warn">En attente</Badge>
                <Badge tone="neutral">Doublon</Badge>
              </div>
              <div className="cmp-row" style={{marginTop:14}}>
                {['HEIC','RAW','MOV','JPEG','PNG','DNG'].map(f=><span key={f} className="fmt-chip">{f}</span>)}
              </div>
            </div>
            <div className="cmp">
              <div className="cmp-l">Interrupteur & segmenté</div>
              <div className="cmp-row" style={{gap:18}}>
                <Toggle/>
                <div className="mini-seg"><span>Système</span><span className="on">Clair</span><span>Sombre</span></div>
              </div>
            </div>
            <div className="cmp">
              <div className="cmp-l">Progression</div>
              <div style={{marginTop:4}}><ProgressBar pct={68} tone="accent"/></div>
              <div style={{marginTop:14}}><ProgressBar pct={42} tone="keep"/></div>
            </div>
            <div className="cmp" style={{gridColumn:'1 / -1'}}>
              <div className="cmp-l">Lignes & cartes</div>
              <div className="demo-list">
                <div className="source-row active" style={{borderRadius:0,background:'var(--accent-soft)'}}>
                  <div className="source-ic lib"><Icon n="photo.stack" s={22} w={1.7}/></div>
                  <div className="source-main">
                    <div className="source-name-row"><span className="source-name">Photothèque principale</span><span className="lib-tag">.photoslibrary</span></div>
                    <div className="source-meta">18 432 photos · 1 240 vidéos</div>
                    <div className="fmt-chips"><span className="fmt-chip">HEIC</span><span className="fmt-chip">RAW</span><span className="fmt-chip">MOV</span></div>
                  </div>
                  <div className="source-check"><Icon n="checkmark" s={14} w={2.6}/></div>
                </div>
                <div className="source-row" style={{borderRadius:0,background:'var(--bg2)'}}>
                  <div className="source-ic fold"><Icon n="folder" s={22} w={1.7}/></div>
                  <div className="source-main">
                    <div className="source-name-row"><span className="source-name">DCIM</span></div>
                    <div className="source-meta">2 847 fichiers · 11,4 Go</div>
                    <div className="fmt-chips"><span className="fmt-chip">JPEG</span><span className="fmt-chip">MOV</span></div>
                  </div>
                  <div className="source-go"><Icon n="chevron.right" s={18}/></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* BRAND / ICONE */}
        <section className="k-section">
          <div className="k-tag">Marque</div>
          <div className="k-h">Icône de l’app</div>
          <div className="k-sub">Faille × Aurora — une photo déchirée entre garder et jeter. Voir le studio dédié pour les variantes iOS 18.</div>
          <div className="k-panel">
            <div className="brand-row">
              <div className="brand-ic"><img src="exports/final/faille-aurora-dark-1024.png" alt="Icône YZPhotos"/></div>
              <div className="brand-ic"><img src="exports/final/faille-aurora-light-1024.png" alt="Icône YZPhotos clair"/></div>
              <div className="brand-txt">
                <h3>Le geste de tri, devenu emblème</h3>
                <p>Mesh aurora vibrant, faille diagonale, pastilles ✕ / ✓. Décliné en Light, Dark et Tinted pour iOS 18.</p>
              </div>
            </div>
          </div>
        </section>

      </div>
    </div>
  );
}

function Toggle(){
  const [on,setOn] = useState(true);
  return <div className={`tog${on?' on':''}`} style={{cursor:'pointer'}} onClick={()=>setOn(!on)}/>;
}

ReactDOM.createRoot(document.getElementById('root')).render(<Kit/>);
