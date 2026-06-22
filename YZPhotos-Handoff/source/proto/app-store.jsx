/* ═══════════════════════════════════════════════════════════
   YZPhotos — Posters App Store (clair · rapidité du tri)
   ═══════════════════════════════════════════════════════════ */

/* fonds clairs avec un voile aurora doux */
const BGS = {
  blush: 'radial-gradient(85% 60% at 12% 0%, rgba(255,150,185,.40), transparent 60%), radial-gradient(80% 60% at 100% 100%, rgba(150,130,255,.28), transparent 60%), linear-gradient(165deg,#FFF7FA,#F4EEFB)',
  sky:   'radial-gradient(85% 60% at 88% 0%, rgba(120,180,255,.38), transparent 60%), radial-gradient(80% 60% at 0% 100%, rgba(120,220,210,.30), transparent 60%), linear-gradient(165deg,#F4F9FF,#EAF4F6)',
  mint:  'radial-gradient(85% 60% at 15% 4%, rgba(110,210,150,.38), transparent 60%), radial-gradient(80% 60% at 100% 100%, rgba(120,200,255,.26), transparent 60%), linear-gradient(165deg,#F3FBF5,#EAF6F3)',
  lilac: 'radial-gradient(85% 60% at 85% 0%, rgba(170,140,255,.38), transparent 60%), radial-gradient(80% 60% at 0% 100%, rgba(255,150,200,.26), transparent 60%), linear-gradient(165deg,#F7F3FF,#F1ECFA)',
  peach: 'radial-gradient(85% 60% at 14% 0%, rgba(255,170,130,.40), transparent 60%), radial-gradient(80% 60% at 100% 100%, rgba(255,140,180,.26), transparent 60%), linear-gradient(165deg,#FFF6EF,#FBEEF1)',
};

/* device dans une boîte à la taille réduite réelle (scale ne réduit pas la boîte de layout) */
function Device({ device, theme, tab, scale, children }) {
  const W = device==='ipad' ? 1180 : 402;
  const H = device==='ipad' ? 838  : 842;
  return (
    <div className="poster-device" style={{ width:W*scale, height:H*scale }}>
      <div style={{ width:W, height:H, transform:`scale(${scale})`, transformOrigin:'top left' }}>
        <AppFrame device={device} theme={theme} tab={tab}>{children}</AppFrame>
      </div>
    </div>
  );
}

/* iPhone — portrait : titre haut, device dessous (entièrement visible) */
function PhonePoster({ bg, kicker, headline, sub, tab, scale=1.06, children }) {
  return (
    <div className="poster poster-phone" style={{ background: BGS[bg] }}>
      <div className="poster-copy">
        {kicker && <div className="poster-kicker">{kicker}</div>}
        <h2 className="poster-h">{headline}</h2>
        {sub && <p className="poster-sub">{sub}</p>}
      </div>
      <div className="poster-stage">
        <Device device="iphone" theme="glass" tab={tab} scale={scale}>{children}</Device>
      </div>
    </div>
  );
}

/* iPad — paysage : titre à gauche, device à droite qui bleed sur le bord */
function PadPoster({ bg, kicker, headline, sub, tab, children }) {
  return (
    <div className="poster poster-pad" style={{ background: BGS[bg] }}>
      <div className="poster-pad-copy">
        {kicker && <div className="poster-kicker">{kicker}</div>}
        <h2 className="poster-h poster-h-pad">{headline}</h2>
        {sub && <p className="poster-sub poster-sub-pad">{sub}</p>}
      </div>
      <div className="poster-pad-stage">
        <Device device="ipad" theme="glass" tab={tab} scale={0.74}>{children}</Device>
      </div>
    </div>
  );
}

function Board() {
  const IPH = { w:640, h:1320 };
  const IPAD = { w:1500, h:1080 };
  return (
    <DesignCanvas>
      <DCSection id="iphone" title="iPhone — portrait" subtitle="6.9″ · format App Store 1290×2796. Tout l'argumentaire tourne autour d'une promesse : trier vite, sans effort.">
        <DCArtboard id="ph-libs" label="0 · Photothèques" width={IPH.w} height={IPH.h}>
          <PhonePoster bg="lilac" kicker="TOUTES VOS PHOTOTHÈQUES" headline={<>Fini de jongler<br/>entre photothèques.</>}
            sub="YZPhotos lit vos bibliothèques Apple .photoslibrary et vos dossiers, directement sur le SSD. On bascule d'un tap." tab="photos">
            <SourcesScreen compact={true}/>
          </PhonePoster>
        </DCArtboard>
        <DCArtboard id="ph-trier" label="1 · Trier" width={IPH.w} height={IPH.h}>
          <PhonePoster bg="blush" kicker="CONÇU POUR TRIER VITE" headline={<>Gardez. Jetez.<br/>Suivant.</>}
            sub="Un swipe à droite pour garder, à gauche pour jeter. Rien de plus à apprendre." tab="trier">
            <TrierScreen compact={true}/>
          </PhonePoster>
        </DCArtboard>
        <DCArtboard id="ph-doublons" label="2 · Doublons" width={IPH.w} height={IPH.h}>
          <PhonePoster bg="sky" kicker="MOINS DE DÉSORDRE" headline={<>Les doublons,<br/>en un tap.</>}
            sub="Repérés tout seuls, la meilleure version gardée. Vous validez, c'est réglé." tab="doublons">
            <DoublonsScreen compact={true}/>
          </PhonePoster>
        </DCArtboard>
        <DCArtboard id="ph-corbeille" label="3 · Corbeille" width={IPH.w} height={IPH.h}>
          <PhonePoster bg="mint" kicker="TRIEZ SANS STRESS" headline={<>Vite,<br/>sans rien risquer.</>}
            sub="Tout passe par la corbeille. Rien n'est supprimé sans votre feu vert." tab="corbeille">
            <CorbeilleScreen compact={true}/>
          </PhonePoster>
        </DCArtboard>
        <DCArtboard id="ph-stats" label="4 · Stats" width={IPH.w} height={IPH.h}>
          <PhonePoster bg="lilac" kicker="EN UN COUP D'ŒIL" headline={<>Votre SSD,<br/>limpide.</>}
            sub="Ce qui prend de la place, ce que vous pouvez libérer. Immédiatement." tab="stats" scale={1.07}>
            <StatsScreen compact={true}/>
          </PhonePoster>
        </DCArtboard>
        <DCArtboard id="ph-lib" label="5 · Bibliothèque" width={IPH.w} height={IPH.h}>
          <PhonePoster bg="peach" kicker="TOUT EST LÀ" headline={<>Des milliers de photos,<br/>fluides.</>}
            sub="Parcourez et sélectionnez par lot, directement depuis votre SSD." tab="photos">
            <LibraryScreen compact={true}/>
          </PhonePoster>
        </DCArtboard>
      </DCSection>

      <DCSection id="ipad" title="iPad — paysage" subtitle="13″ · format App Store 2732×2048. La promesse de rapidité, en grand.">
        <DCArtboard id="pad-libs" label="0 · Photothèques" width={IPAD.w} height={IPAD.h}>
          <PadPoster bg="lilac" kicker="TOUTES VOS PHOTOTHÈQUES" headline={<>Vos photothèques Apple,<br/>enfin réunies.</>}
            sub="Disques externes, bibliothèques .photoslibrary, dossiers photos et vidéos — tous vos formats au même endroit. Plus besoin de jongler dans Photos." tab="photos">
            <SourcesScreen compact={false}/>
          </PadPoster>
        </DCArtboard>
        <DCArtboard id="pad-trier" label="1 · Trier" width={IPAD.w} height={IPAD.h}>
          <PadPoster bg="blush" kicker="CONÇU POUR TRIER VITE" headline={<>Le tri photo<br/>le plus rapide.</>}
            sub="Une interface pensée pour une seule chose : trier vite. Un geste, une décision, suivant." tab="trier">
            <TrierScreen compact={false}/>
          </PadPoster>
        </DCArtboard>
        <DCArtboard id="pad-doublons" label="2 · Doublons" width={IPAD.w} height={IPAD.h}>
          <PadPoster bg="sky" kicker="RÉCUPÉREZ DE L'ESPACE" headline={<>Zéro doublon,<br/>zéro effort.</>}
            sub="Regroupés par similarité, la meilleure version mise en avant. Validez, libérez." tab="doublons">
            <DoublonsScreen compact={false}/>
          </PadPoster>
        </DCArtboard>
        <DCArtboard id="pad-stats" label="3 · Stats" width={IPAD.w} height={IPAD.h}>
          <PadPoster bg="lilac" kicker="EN UN COUP D'ŒIL" headline={<>Chaque Go,<br/>sous contrôle.</>}
            sub="Répartition, volume trié, espace récupérable — pour vos SSD Samsung T5 / T7." tab="stats">
            <StatsScreen compact={false}/>
          </PadPoster>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Board/>);
