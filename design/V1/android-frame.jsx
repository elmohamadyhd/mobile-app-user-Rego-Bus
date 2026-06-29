// @ds-adherence-ignore -- device frame scaffold (raw elements/hex/px by design)
// Skyline-tuned Android (Material) device frame.
// A thin bezel + status bar that OVERLAYS the screen content (so an immersive
// hero gradient can run all the way to the top edge) + a gesture nav pill.
// Exports (to window): AndroidDevice
//
// Usage:
//   <AndroidDevice statusLight>      // white status icons (over blue hero)
//     ...screen content...           // content draws under the status bar;
//   </AndroidDevice>                 // give non-hero screens paddingTop:44

function SkyStatusBar({ light = false }) {
  const c = light ? '#ffffff' : '#141831';
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 40, zIndex: 20,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 18px', pointerEvents: 'none',
      fontFamily: 'Tajawal, system-ui, sans-serif',
    }}>
      <span style={{ fontSize: 14, fontWeight: 700, letterSpacing: 0.2, color: c }}>9:41</span>
      <div style={{
        position: 'absolute', left: '50%', top: 9, transform: 'translateX(-50%)',
        width: 22, height: 22, borderRadius: 100, background: '#111',
      }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        {/* signal */}
        <svg width="17" height="13" viewBox="0 0 17 13" fill="none">
          <rect x="0" y="9" width="3" height="4" rx="1" fill={c}/>
          <rect x="4.5" y="6" width="3" height="7" rx="1" fill={c}/>
          <rect x="9" y="3" width="3" height="10" rx="1" fill={c}/>
          <rect x="13.5" y="0" width="3" height="13" rx="1" fill={c}/>
        </svg>
        {/* wifi */}
        <svg width="16" height="13" viewBox="0 0 16 13" fill="none">
          <path d="M8 12.2l-2.1-2.6a3.3 3.3 0 014.2 0L8 12.2z" fill={c}/>
          <path d="M8 6.1a7 7 0 015.4 2.5l1.4-1.7a9.2 9.2 0 00-13.6 0l1.4 1.7A7 7 0 018 6.1z" fill={c} opacity="0.9"/>
        </svg>
        {/* battery */}
        <svg width="24" height="13" viewBox="0 0 24 13" fill="none">
          <rect x="0.5" y="1" width="20" height="11" rx="3" stroke={c} opacity="0.5"/>
          <rect x="2.5" y="3" width="14" height="7" rx="1.5" fill={c}/>
          <rect x="22" y="4.5" width="1.5" height="4" rx="0.75" fill={c} opacity="0.5"/>
        </svg>
      </div>
    </div>
  );
}

function AndroidDevice({
  children, width = 390, height = 844, bg = '#F4F6FB',
  statusLight = false, nav = true,
}) {
  return (
    <div style={{
      width, height, borderRadius: 44, overflow: 'hidden',
      background: bg, position: 'relative',
      border: '10px solid #14161f',
      boxShadow: '0 40px 90px -30px rgba(14,80,199,0.45), 0 8px 24px rgba(0,0,0,0.12)',
      boxSizing: 'content-box',
      fontFamily: 'Tajawal, system-ui, sans-serif',
    }}>
      <SkyStatusBar light={statusLight} />
      <div style={{
        position: 'absolute', inset: 0, overflow: 'auto',
        WebkitOverflowScrolling: 'touch',
      }}>
        {children}
      </div>
      {nav && (
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, height: 22, zIndex: 20,
          display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none',
        }}>
          <div style={{ width: 120, height: 5, borderRadius: 3, background: '#141831', opacity: 0.25 }} />
        </div>
      )}
    </div>
  );
}

Object.assign(window, { AndroidDevice });
