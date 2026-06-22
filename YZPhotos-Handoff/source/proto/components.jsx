/* ═══════════════════════════════════════════════════════════
   YZPhotos — Composants partagés (icônes SF, primitives, données)
   ═══════════════════════════════════════════════════════════ */
const { useState, useEffect, useRef, useCallback } = React;

/* ── SF SYMBOLS (trait fin, cohérent) ──────────────────── */
const Icon = ({ n, s = 24, w = 1.7, fill = false }) => {
  const P = { fill: 'none', stroke: 'currentColor', strokeWidth: w,
    strokeLinecap: 'round', strokeLinejoin: 'round' };
  const F = { fill: 'currentColor', stroke: 'none' };
  const paths = {
    'rectangle.stack': <g {...P}><rect x="4" y="8.5" width="16" height="11.5" rx="2.5"/><path d="M6.5 8.5V7a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v1.5M8.5 5V4"/></g>,
    'square.on.square': <g {...P}><rect x="8" y="8" width="12" height="12" rx="2.5"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/></g>,
    'folder': <g {...P}><path d="M3 7.5a2 2 0 0 1 2-2h3.8a2 2 0 0 1 1.5.7l1 1.1a2 2 0 0 0 1.5.7H19a2 2 0 0 1 2 2v6.8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></g>,
    'photo': <g {...P}><rect x="3.5" y="5" width="17" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.6"/><path d="M5 17l4.2-4a1.5 1.5 0 0 1 2 0l3.3 3M13 15l2-1.8a1.5 1.5 0 0 1 2 0l2 1.8"/></g>,
    'video': <g {...P}><rect x="3" y="6.5" width="13" height="11" rx="2.5"/><path d="M16 10.5l4.5-2.6a.8.8 0 0 1 1.2.7v6.8a.8.8 0 0 1-1.2.7L16 13.5z"/></g>,
    'trash': <g {...P}><path d="M5 7h14M10 7V5.5a1.5 1.5 0 0 1 1.5-1.5h1A1.5 1.5 0 0 1 14 5.5V7M6.5 7l.8 11.2a2 2 0 0 0 2 1.8h5.4a2 2 0 0 0 2-1.8L17.5 7"/></g>,
    'camera.viewfinder': <g {...P}><path d="M5 8V6.5A1.5 1.5 0 0 1 6.5 5H8M16 5h1.5A1.5 1.5 0 0 1 19 6.5V8M19 16v1.5a1.5 1.5 0 0 1-1.5 1.5H16M8 19H6.5A1.5 1.5 0 0 1 5 17.5V16"/><circle cx="12" cy="12" r="3.2"/></g>,
    'chart.bar': <g {...F}><rect x="3.5" y="13" width="4" height="7.5" rx="1.2"/><rect x="10" y="9" width="4" height="11.5" rx="1.2"/><rect x="16.5" y="4.5" width="4" height="16" rx="1.2"/></g>,
    'magnifyingglass': <g {...P}><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></g>,
    'gearshape': <g {...P}><circle cx="12" cy="12" r="3"/><path d="M12 3.5l1.2 2.2 2.5-.3 1 2.3 2.2 1.2-.3 2.5 1.5 2-1.5 2 .3 2.5-2.2 1.2-1 2.3-2.5-.3L12 20.5l-1.2-2.2-2.5.3-1-2.3L5.1 15l.3-2.5L3.9 10.5l1.5-2L5.1 6l2.2-1.2 1-2.3 2.5.3z" strokeWidth={w*0.85}/></g>,
    'externaldrive': <g {...P}><rect x="3" y="7.5" width="18" height="11" rx="2.5"/><path d="M6 14.5h4M17.5 14.5h.01" strokeWidth={w*1.3}/></g>,
    'arrow.up.arrow.down': <g {...P}><path d="M7 4.5v15M7 4.5L4.5 7M7 4.5L9.5 7M17 19.5v-15M17 19.5L14.5 17M17 19.5L19.5 17"/></g>,
    'xmark': <g {...P}><path d="M6 6l12 12M18 6L6 18"/></g>,
    'checkmark': <g {...P}><path d="M5 12.5l4.5 4.5L19 7"/></g>,
    'arrow.uturn.backward': <g {...P}><path d="M9 7L4.5 11.5 9 16M4.5 11.5H15a4.5 4.5 0 0 1 0 9h-2"/></g>,
    'star.fill': <g {...F}><path d="M12 3.5l2.5 5.4 5.9.7-4.4 4 1.2 5.8L12 16.6 6.8 19.4 8 13.6 3.6 9.6l5.9-.7z"/></g>,
    'star': <g {...P}><path d="M12 4l2.4 5.1 5.6.7-4.1 3.8 1.1 5.5L12 16.3 6.9 19.1 8 13.6 3.9 9.8l5.6-.7z"/></g>,
    'chevron.right': <g {...P}><path d="M9 5l7 7-7 7"/></g>,
    'chevron.left': <g {...P}><path d="M15 5l-7 7 7 7"/></g>,
    'arrow.counterclockwise': <g {...P}><path d="M5 7v4h4M5.5 11a7 7 0 1 1-.5 4" /></g>,
    'play.fill': <g {...F}><path d="M7 5.5v13l11-6.5z"/></g>,
    'pause': <g {...P}><path d="M9 5v14M15 5v14" strokeWidth={w*1.4}/></g>,
    'eject': <g {...P}><path d="M12 5l6 9H6zM6 18h12" strokeWidth={w}/></g>,
    'plus': <g {...P}><path d="M12 5v14M5 12h14"/></g>,
    'info.circle': <g {...P}><circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01" strokeWidth={w*1.2}/></g>,
    'exclamationmark.triangle': <g {...P}><path d="M12 4.5L21 19.5H3zM12 10v4M12 17h.01" strokeWidth={w*1.1}/></g>,
    'sparkles': <g {...P}><path d="M12 5l1.4 3.6L17 10l-3.6 1.4L12 15l-1.4-3.6L7 10l3.6-1.4zM18 4l.7 1.8L20.5 6.5l-1.8.7L18 9l-.7-1.8L15.5 6.5l1.8-.7z"/></g>,
    'photo.stack': <g {...P}><rect x="6" y="4.5" width="13" height="10" rx="2"/><path d="M4 8v9.5a2 2 0 0 0 2 2h11"/></g>,
  };
  return <svg width={s} height={s} viewBox="0 0 24 24" style={{display:'block',flexShrink:0}}>{paths[n] || null}</svg>;
};

/* ── PHOTOS PLACEHOLDER (dégradés abstraits, calmes) ───── */
const GRADS = [
  ['#AEC6D9','#7E9BB8','land'], ['#E8C9B0','#C99B7E','land'], ['#C2D4C0','#8FB08C','land'],
  ['#D8C4DE','#A48BB5','port'], ['#B9C8DC','#8295B0','port'], ['#E3CDBE','#BFA08C','port'],
  ['#C9D6DE','#9CADBA','land'], ['#DCD2C0','#B8A988','land'], ['#BFD0D0','#8FAAAA','sub'],
  ['#D6C7C0','#AE9389','sub'], ['#C5CFE0','#94A2C0','land'], ['#DDD0D8','#B299A8','port'],
  ['#CBD8D0','#9DB3A5','sub'], ['#E0D2C2','#C2A887','land'], ['#C0C9D6','#929EB2','port'],
  ['#D9CAD2','#AC93A0','sub'], ['#BACBD2','#8AA3AC','land'], ['#E2D4C8','#C0A38F','sub'],
];
function gradStyle(i) {
  const [a, b, kind] = GRADS[i % GRADS.length];
  if (kind === 'land') return { background:`linear-gradient(180deg, ${a} 0%, ${a} 52%, ${b} 53%, ${b} 100%)` };
  if (kind === 'port') return { background:`radial-gradient(120% 90% at 50% 38%, ${a} 0%, ${b} 100%)` };
  return { background:`linear-gradient(135deg, ${a}, ${b})` };
}

/* ── PHOTO SCENES — placeholders façon vraies photos ───── */
let __scN = 0;
function sceneSVG(seed){
  const id = 'sc' + (__scN++);
  const k = ((seed % 8) + 8) % 8;
  const G = (gid,stops,x1,y1,x2,y2)=>`<linearGradient id="${gid}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">`+stops.map(([o,c])=>`<stop offset="${o}" stop-color="${c}"/>`).join('')+`</linearGradient>`;
  const R = (gid,stops,cx,cy,r)=>`<radialGradient id="${gid}" cx="${cx}" cy="${cy}" r="${r}" gradientUnits="userSpaceOnUse">`+stops.map(([o,c])=>`<stop offset="${o}" stop-color="${c}"/>`).join('')+`</radialGradient>`;
  let defs='', body='';
  switch(k){
    case 0: // coucher de soleil sur mer
      defs = G(id+'s',[[0,'#FFE2A6'],[0.5,'#FF9E8A'],[1,'#E1718F']],0,0,0,100)+R(id+'u',[[0,'#FFF6D8'],[1,'#FFCF8A']],50,40,22)+G(id+'w',[[0,'#D98AA6'],[1,'#9B5C86']],0,60,0,100);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><circle cx="50" cy="40" r="15" fill="url(#${id}u)"/><rect y="62" width="100" height="38" fill="url(#${id}w)"/><rect x="44" y="62" width="12" height="38" fill="#FFE9C0" opacity="0.5"/>`;
      break;
    case 1: // montagnes enneigées
      defs = G(id+'s',[[0,'#BFD9EE'],[1,'#E7F1F6']],0,0,0,100);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><polygon points="-5,72 30,28 62,72" fill="#7E9DBE"/><polygon points="30,28 22,42 40,42" fill="#F4FAFF"/><polygon points="40,74 72,34 108,74" fill="#5E80A6"/><polygon points="72,34 64,48 82,48" fill="#EAF4FF"/><rect y="72" width="100" height="28" fill="#86A98E"/>`;
      break;
    case 2: // collines forêt
      defs = G(id+'s',[[0,'#DCEBF0'],[1,'#F2F7EF']],0,0,0,100);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><path d="M-5 64 Q40 48 105 66 L105 100 -5 100 Z" fill="#9CC089"/><path d="M-5 78 Q55 62 105 82 L105 100 -5 100 Z" fill="#6FA063"/><path d="M-5 90 Q45 80 105 94 L105 100 -5 100 Z" fill="#4E7C49"/>`;
      break;
    case 3: // plage tropicale
      defs = G(id+'s',[[0,'#AEE3F0'],[1,'#E8F8F4']],0,0,0,100)+G(id+'w',[[0,'#3FB6C9'],[1,'#7FD9C8']],0,55,0,80);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><circle cx="74" cy="26" r="11" fill="#FFF4CE"/><rect y="55" width="100" height="25" fill="url(#${id}w)"/><path d="M-5 78 Q50 70 105 80 L105 100 -5 100 Z" fill="#F1E2B8"/>`;
      break;
    case 4: // ville de nuit
      defs = G(id+'s',[[0,'#2A2F5E'],[0.6,'#3E3A6B'],[1,'#6A4A78']],0,0,0,100);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><circle cx="72" cy="24" r="9" fill="#FBEFC4"/><g fill="#1E2042"><rect x="8" y="58" width="14" height="42"/><rect x="26" y="48" width="12" height="52"/><rect x="42" y="64" width="16" height="36"/><rect x="62" y="52" width="13" height="48"/><rect x="79" y="60" width="14" height="40"/></g><g fill="#FFD98A" opacity="0.85"><rect x="11" y="62" width="3" height="3"/><rect x="17" y="70" width="3" height="3"/><rect x="30" y="54" width="3" height="3"/><rect x="46" y="70" width="3" height="3"/><rect x="66" y="58" width="3" height="3"/><rect x="83" y="66" width="3" height="3"/></g>`;
      break;
    case 5: // champ de lavande
      defs = G(id+'s',[[0,'#CFE0F2'],[1,'#F3ECF8']],0,0,0,100);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><circle cx="26" cy="24" r="9" fill="#FFF6DA"/><path d="M-5 70 Q50 60 105 72 L105 100 -5 100 Z" fill="#B9A6D8"/><path d="M-5 82 Q50 74 105 86 L105 100 -5 100 Z" fill="#8E76B8"/><path d="M-5 92 Q50 86 105 96 L105 100 -5 100 Z" fill="#6E5896"/>`;
      break;
    case 6: // désert dunes
      defs = G(id+'s',[[0,'#FFE0B0'],[1,'#FBEAD0']],0,0,0,100);
      body = `<rect width="100" height="100" fill="url(#${id}s)"/><circle cx="68" cy="28" r="10" fill="#FFF2CE"/><path d="M-5 66 Q35 54 105 70 L105 100 -5 100 Z" fill="#E8B987"/><path d="M-5 80 Q60 68 105 84 L105 100 -5 100 Z" fill="#CE9A66"/>`;
      break;
    default: // portrait bokeh
      defs = R(id+'b',[[0,'#FFE0C2'],[1,'#E8A2A6']],38,40,70);
      body = `<rect width="100" height="100" fill="url(#${id}b)"/><g fill="#FFFFFF" opacity="0.32"><circle cx="22" cy="26" r="9"/><circle cx="74" cy="20" r="6"/><circle cx="82" cy="58" r="11"/><circle cx="30" cy="70" r="7"/></g><ellipse cx="50" cy="80" rx="22" ry="26" fill="#C77F86" opacity="0.55"/><circle cx="50" cy="48" r="15" fill="#E9AEA0"/>`;
  }
  return `<svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" width="100%" height="100%" style="display:block"><defs>${defs}</defs>${body}</svg>`;
}
const PHOTOS = [
  'assets/photos/p1.jpg', 'assets/photos/p8.jpg', 'assets/photos/p4.jpg',
  'assets/photos/p10.jpg', 'assets/photos/p9.jpg', 'assets/photos/p6.png',
  'assets/photos/p3.jpg', 'assets/photos/screenshot1.png', 'assets/photos/p5.jpg',
  'assets/photos/p2.jpg',
];
/* hash modulaire : multiplicateur premier avec 10 et avec les pas de grille (1,3,4,6),
   pour une répartition variée sans répétition adjacente ni alignement de colonnes */
function photoSrc(seed){
  const N = PHOTOS.length;        // 10
  const idx = (((seed*3 + 1) % N) + N) % N;
  return PHOTOS[idx];
}
function PhotoScene({ seed=0, style }){
  const src = photoSrc(seed);
  return (
    <div style={{position:'absolute',inset:0,overflow:'hidden',background:'var(--bg3)',...style}}>
      <img src={src} alt="" draggable={false}
        style={{width:'100%',height:'100%',objectFit:'cover',display:'block'}}/>
    </div>
  );
}

/* ── DATA ──────────────────────────────────────────────── */
const DECK = [
  { id:1, g:0, name:'IMG_4821.HEIC', size:'4,2 Mo', date:'14 mars 2026', type:'photo', meta:'4032 × 3024' },
  { id:2, g:1, name:'IMG_4822.HEIC', size:'3,8 Mo', date:'14 mars 2026', type:'photo', meta:'4032 × 3024' },
  { id:3, g:2, name:'MOV_0145.MOV',  size:'128 Mo',  date:'12 mars 2026', type:'video', meta:'0:42 · 4K' },
  { id:4, g:3, name:'IMG_4790.HEIC', size:'5,1 Mo', date:'9 mars 2026',  type:'photo', meta:'4032 × 3024' },
  { id:5, g:4, name:'IMG_4756.HEIC', size:'4,7 Mo', date:'7 mars 2026',  type:'photo', meta:'4032 × 3024' },
  { id:6, g:5, name:'IMG_4711.HEIC', size:'3,3 Mo', date:'2 mars 2026',  type:'photo', meta:'3024 × 4032' },
  { id:7, g:6, name:'IMG_4699.HEIC', size:'6,0 Mo', date:'28 fév 2026',  type:'photo', meta:'4032 × 3024' },
  { id:8, g:7, name:'MOV_0140.MOV',  size:'212 Mo',  date:'25 fév 2026',  type:'video', meta:'1:18 · 4K' },
];

const DUP_GROUPS = [
  { id:'g1', sim:'99 %', items:[
    { id:'a1', g:8,  size:'5,4 Mo', meta:'4032×3024', best:true },
    { id:'a2', g:8,  size:'5,2 Mo', meta:'4032×3024' },
    { id:'a3', g:9,  size:'2,1 Mo', meta:'2048×1536' },
  ]},
  { id:'g2', sim:'97 %', items:[
    { id:'b1', g:10, size:'4,8 Mo', meta:'4032×3024', best:true },
    { id:'b2', g:10, size:'4,7 Mo', meta:'4032×3024' },
  ]},
  { id:'g3', sim:'94 %', items:[
    { id:'c1', g:11, size:'6,2 Mo', meta:'4032×3024', best:true },
    { id:'c2', g:11, size:'3,1 Mo', meta:'3024×2268' },
    { id:'c3', g:12, size:'2,9 Mo', meta:'3024×2268' },
    { id:'c4', g:13, size:'1,8 Mo', meta:'2048×1536' },
  ]},
];

const TRASH_INIT = [
  { id:'t1', g:14, name:'IMG_4012.HEIC', size:'4,1 Mo', when:'il y a 2 min', type:'photo' },
  { id:'t2', g:15, name:'IMG_3987.HEIC', size:'3,9 Mo', when:'il y a 2 min', type:'photo' },
  { id:'t3', g:16, name:'MOV_0098.MOV',  size:'186 Mo',  when:'il y a 14 min', type:'video' },
  { id:'t4', g:17, name:'IMG_3840.PNG',  size:'2,2 Mo', when:'il y a 1 h',  type:'capture' },
  { id:'t5', g:2,  name:'IMG_3712.HEIC', size:'5,0 Mo', when:'hier',        type:'photo' },
];

/* ── PRIMITIVES ────────────────────────────────────────── */
const Btn = ({ kind='secondary', icon, children, onClick, full, sz='md', disabled }) => (
  <button className={`btn btn-${kind} btn-${sz}${full?' btn-full':''}`} onClick={onClick} disabled={disabled}>
    {icon && <Icon n={icon} s={sz==='lg'?22:18} w={1.9}/>}
    {children && <span>{children}</span>}
  </button>
);

const Badge = ({ children, tone='neutral', icon }) => (
  <span className={`badge badge-${tone}`}>{icon && <Icon n={icon} s={12} w={2}/>}{children}</span>
);

const ProgressBar = ({ pct, tone='accent' }) => (
  <div className="prog"><div className={`prog-fill prog-${tone}`} style={{width:`${pct}%`}}/></div>
);

const Modal = ({ open, onClose, icon, iconTone='danger', title, children, actions }) => {
  if (!open) return null;
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal" onClick={e=>e.stopPropagation()}>
        {icon && <div className={`modal-icon modal-icon-${iconTone}`}><Icon n={icon} s={30} w={1.8}/></div>}
        <div className="modal-title">{title}</div>
        <div className="modal-body">{children}</div>
        <div className="modal-actions">{actions}</div>
      </div>
    </div>
  );
};

const PhotoThumb = ({ g, type, radius=10, children }) => (
  <div className="thumb" style={{ borderRadius:radius }}>
    <PhotoScene seed={g}/>
    {type==='video' && <div className="thumb-badge"><Icon n="play.fill" s={11}/></div>}
    {type==='capture' && <div className="thumb-badge"><Icon n="camera.viewfinder" s={11} w={2}/></div>}
    {children}
  </div>
);

/* Empty state */
const EmptyState = ({ icon, title, sub }) => (
  <div className="empty">
    <div className="empty-icon"><Icon n={icon} s={40} w={1.4}/></div>
    <div className="empty-title">{title}</div>
    {sub && <div className="empty-sub">{sub}</div>}
  </div>
);

Object.assign(window, {
  Icon, gradStyle, GRADS, PhotoScene, sceneSVG, DECK, DUP_GROUPS, TRASH_INIT,
  Btn, Badge, ProgressBar, Modal, PhotoThumb, EmptyState,
});
