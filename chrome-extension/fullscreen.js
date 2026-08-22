(function () {
  const params = new URLSearchParams(location.search);
  if (params.get("videocorner") !== "1") return;

  // Hide the YouTube page chrome immediately (never needed for a player-only
  // window). Live CSS selectors apply these as elements appear, so there is no
  // raw-page flash while the video loads.
  const chromeStyle = document.createElement("style");
  chromeStyle.textContent = `
    html, body {
      width: 100% !important;
      height: 100% !important;
      margin: 0 !important;
      overflow: hidden !important;
      background: #000 !important;
    }
    #masthead-container, ytd-masthead, #guide, #below, #secondary,
    #comments, ytd-watch-metadata, #info, #meta, #related {
      display: none !important;
    }
    #cinematics, .ytp-ambient-mode {
      display: none !important;
    }
  `;
  document.documentElement.appendChild(chromeStyle);

  // Expansion rules are held back until the player element actually exists, to
  // avoid forcing position:fixed on a not-yet-mounted player. Once appended,
  // live selectors keep applying on any later SPA re-mount.
  const playerStyle = document.createElement("style");
  playerStyle.id = "videocorner-player-style";
  playerStyle.textContent = `
    #player, #player-container-outer, #player-container-inner,
    #movie_player, .html5-video-player {
      position: fixed !important;
      inset: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      min-width: 0 !important;
      min-height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
      z-index: 999999 !important;
    }
    .html5-video-container {
      position: absolute !important;
      inset: 0 !important;
      width: 100% !important;
      height: 100% !important;
    }
    .html5-main-video {
      position: absolute !important;
      inset: 0 !important;
      width: 100% !important;
      height: 100% !important;
      object-fit: contain !important;
      max-width: none !important;
      max-height: none !important;
    }
  `;

  function applyPlayerStyle() {
    if (document.getElementById("videocorner-player-style")) return;
    document.documentElement.appendChild(playerStyle);
  }

  const observer = new MutationObserver(function () {
    if (document.querySelector("#movie_player, .html5-video-player")) {
      applyPlayerStyle();
      observer.disconnect();
    }
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });

  // In case the player is already present by the time the script runs.
  if (document.querySelector("#movie_player, .html5-video-player")) {
    applyPlayerStyle();
    observer.disconnect();
  }
})();
