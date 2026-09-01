class JsSnifferScripts {
  static const String snifferPayload = r'''
(function() {
  const AD_DOMAINS = [
    'doubleclick.net', 'googleads', 'googlesyndication', 'google-analytics',
    'facebook.com/tr', 'taboola.com', 'outbrain.com', 'criteo.com',
    'scorecardresearch.com', 'quantserve.com', 'adnxs.com', 'amazon-adsystem.com',
    'rubiconproject.com', 'pubmatic.com', 'openx.net', 'casalemedia.com',
    'tracking', 'analytics', 'telemetry', 'beacon', 'adservice'
  ];

  function isAdUrl(url) {
    if (!url || typeof url !== 'string') return true;
    const lower = url.toLowerCase();
    return AD_DOMAINS.some(ad => lower.includes(ad));
  }

  const reportedUrls = new Set();
  window.__dbPickaxeReportedUrls = reportedUrls;
  let globalDomIndex = 0;

  function reportMedia(url, type, extra = {}) {
    if (!url || typeof url !== 'string') return;
    url = url.trim();
    if (url.startsWith('javascript:') || url.startsWith('about:')) return;
    if (url.startsWith('data:') && !extra.allowDataUri) return;
    if (url.startsWith('blob:') && !extra.allowBlob) return;

    try {
      url = new URL(url, window.location.href).href;
    } catch(e) {
      return;
    }

    if (isAdUrl(url)) return;
    if (reportedUrls.has(url)) return;
    reportedUrls.add(url);

    let filename = extra.title || '';
    if (!filename) {
      try {
        const u = new URL(url);
        filename = u.pathname.split('/').pop() || document.title || 'media';
      } catch(e) {
        filename = document.title || 'media';
      }
    }

    const payload = {
      action: 'MEDIA_DETECTED',
      url: url,
      pageUrl: window.location.href,
      type: type,
      title: filename,
      width: extra.width || 0,
      height: extra.height || 0,
      mime: extra.mime || '',
      thumbnailUrl: extra.thumbnailUrl || null,
      domIndex: extra.domIndex !== undefined ? extra.domIndex : (++globalDomIndex),
      timestamp: Date.now()
    };

    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
      window.chrome.webview.postMessage(JSON.stringify(payload));
    }
  }

  function captureVideoThumbnail(videoEl) {
    if (!videoEl) return null;
    if (videoEl.poster) return videoEl.poster;

    try {
      if (videoEl.videoWidth > 0 && videoEl.videoHeight > 0) {
        const canvas = document.createElement('canvas');
        canvas.width = Math.min(videoEl.videoWidth, 320);
        canvas.height = Math.min(videoEl.videoHeight, 180);
        const ctx = canvas.getContext('2d');
        ctx.drawImage(videoEl, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL('image/jpeg', 0.65);
      }
    } catch (e) {}
    return null;
  }

  // 1. Hook window.fetch
  if (!window.__dbPickaxeFetchHooked) {
    window.__dbPickaxeFetchHooked = true;
    const originalFetch = window.fetch;
    window.fetch = async function(...args) {
      const resource = args[0];
      let url = '';
      if (typeof resource === 'string') {
        url = resource;
      } else if (resource && resource.url) {
        url = resource.url;
      }

      if (url) checkAndReportUrl(url);

      try {
        const response = await originalFetch.apply(this, args);
        const clone = response.clone();
        const contentType = clone.headers.get('content-type') || '';

        if (contentType.includes('video/') || contentType.includes('mpegurl') || contentType.includes('image/')) {
          reportMedia(clone.url || url, contentType.includes('video') ? 'video' : contentType.includes('mpegurl') ? 'stream' : 'image', { mime: contentType });
        } else if (contentType.includes('json') || contentType.includes('text/plain')) {
          clone.text().then(text => {
            scanTextForMediaUrls(text, clone.url || url);
          }).catch(() => {});
        }
        return response;
      } catch (e) {
        return originalFetch.apply(this, args);
      }
    };
  }

  // 2. Hook XMLHttpRequest
  if (!window.__dbPickaxeXHRHooked) {
    window.__dbPickaxeXHRHooked = true;
    const originalOpen = XMLHttpRequest.prototype.open;
    const originalSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function(method, url, ...rest) {
      this.__dbPickaxeUrl = url;
      if (url) checkAndReportUrl(url);
      return originalOpen.apply(this, [method, url, ...rest]);
    };

    XMLHttpRequest.prototype.send = function(...args) {
      this.addEventListener('load', function() {
        try {
          const contentType = this.getResponseHeader('content-type') || '';
          if (contentType.includes('video/') || contentType.includes('mpegurl') || contentType.includes('image/')) {
            reportMedia(this.responseURL || this.__dbPickaxeUrl, contentType.includes('video') ? 'video' : contentType.includes('mpegurl') ? 'stream' : 'image', { mime: contentType });
          } else if (contentType.includes('json') || contentType.includes('text/plain')) {
            scanTextForMediaUrls(this.responseText, this.responseURL || this.__dbPickaxeUrl);
          }
        } catch(e) {}
      });
      return originalSend.apply(this, args);
    };
  }

  // 3. Hook URL.createObjectURL for MediaSource & Blobs
  if (!window.__dbPickaxeBlobHooked) {
    window.__dbPickaxeBlobHooked = true;
    const origCreateObjectURL = URL.createObjectURL;
    URL.createObjectURL = function(obj) {
      const blobUrl = origCreateObjectURL.apply(this, arguments);
      if (obj && (obj instanceof MediaSource || (obj.type && obj.type.includes('video')))) {
        if (window.__lastStreamUrl) {
          reportMedia(window.__lastStreamUrl, 'stream', { mime: 'application/x-mpegURL' });
        }
      }
      return blobUrl;
    };
  }

  function scanTextForMediaUrls(text, contextUrl) {
    if (!text || text.length > 5000000) return;
    const regex = /(https?:\/\/[^\s"'<>\\]+?\.(?:m3u8|mp4|webm)(?:\?[^\s"'<>\\]*)?)/gi;
    let match;
    while ((match = regex.exec(text)) !== null) {
      const foundUrl = match[1].replace(/\\u0026/g, '&').replace(/\\/g, '');
      checkAndReportUrl(foundUrl);
    }
  }

  function checkAndReportUrl(url, extra = {}) {
    if (!url || typeof url !== 'string') return;
    if (isAdUrl(url)) return;

    const cleanUrl = url.split('?')[0].toLowerCase();
    if (cleanUrl.endsWith('.m3u8')) {
      window.__lastStreamUrl = url;
      reportMedia(url, 'stream', { mime: 'application/x-mpegURL', ...extra });
    } else if (cleanUrl.endsWith('.mpd')) {
      reportMedia(url, 'stream', { mime: 'application/dash+xml', ...extra });
    } else if (cleanUrl.endsWith('.mp4') || cleanUrl.endsWith('.webm') || cleanUrl.endsWith('.mov') || cleanUrl.endsWith('.mkv')) {
      reportMedia(url, 'video', extra);
    } else if (cleanUrl.endsWith('.jpg') || cleanUrl.endsWith('.jpeg') || cleanUrl.endsWith('.png') || cleanUrl.endsWith('.webp') || cleanUrl.endsWith('.avif') || cleanUrl.endsWith('.gif')) {
      reportMedia(url, 'image', extra);
    } else if (cleanUrl.endsWith('.mp3') || cleanUrl.endsWith('.aac') || cleanUrl.endsWith('.wav') || cleanUrl.endsWith('.ogg') || cleanUrl.endsWith('.m4a')) {
      reportMedia(url, 'audio', extra);
    }
  }

  // 4. Floating "Download Video" IDM-Style Grabber Button on <video>
  function attachFloatingDownloadBar(videoEl) {
    if (videoEl.__dbPickaxeWidgetAttached) return;
    videoEl.__dbPickaxeWidgetAttached = true;

    const wrapper = document.createElement('div');
    wrapper.style.cssText = 'position:absolute; top:12px; right:12px; z-index:2147483647; display:none; cursor:pointer; font-family:system-ui,sans-serif; user-select:none;';
    
    const btn = document.createElement('div');
    btn.style.cssText = 'display:flex; align-items:center; gap:6px; background:linear-gradient(135deg,#6366F1,#06B6D4); color:#FFF; font-size:12px; font-weight:bold; padding:7px 14px; border-radius:6px; box-shadow:0 4px 14px rgba(0,0,0,0.6); border:1px solid rgba(255,255,255,0.35); transition:all 0.15s ease;';
    btn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Download Video';

    btn.onmouseenter = () => { btn.style.transform = 'scale(1.06)'; btn.style.filter = 'brightness(1.15)'; };
    btn.onmouseleave = () => { btn.style.transform = 'scale(1)'; btn.style.filter = 'none'; };

    btn.onclick = (e) => {
      e.stopPropagation();
      e.preventDefault();
      const videoSrc = videoEl.currentSrc || videoEl.src || window.__lastStreamUrl;
      if (videoSrc) {
        const thumb = captureVideoThumbnail(videoEl);
        const directPayload = {
          action: 'DIRECT_DOWNLOAD',
          url: videoSrc,
          pageUrl: window.location.href,
          type: 'video',
          title: document.title || 'Video',
          width: videoEl.videoWidth || 0,
          height: videoEl.videoHeight || 0,
          thumbnailUrl: thumb,
          timestamp: Date.now()
        };
        if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
          window.chrome.webview.postMessage(JSON.stringify(directPayload));
        }
      }
    };

    wrapper.appendChild(btn);

    const parent = videoEl.parentElement || document.body;
    if (getComputedStyle(parent).position === 'static') {
      parent.style.position = 'relative';
    }
    parent.appendChild(wrapper);

    let hideTimer = null;
    const show = () => {
      clearTimeout(hideTimer);
      wrapper.style.display = 'block';
    };
    const hide = () => {
      hideTimer = setTimeout(() => { wrapper.style.display = 'none'; }, 2200);
    };

    videoEl.addEventListener('mouseenter', show);
    videoEl.addEventListener('mousemove', show);
    videoEl.addEventListener('mouseleave', hide);
    wrapper.addEventListener('mouseenter', show);
    wrapper.addEventListener('mouseleave', hide);
  }

  // 5. Deep Scan with DOM order tracking
  function scanDOM(root = document) {
    if (!root) return;

    // Scan Videos
    const videos = root.querySelectorAll ? root.querySelectorAll('video, video source') : [];
    videos.forEach((el, idx) => {
      const video = el.tagName.toLowerCase() === 'video' ? el : el.parentElement;
      const src = el.src || el.currentSrc || el.getAttribute('data-src');
      if (video) {
        attachFloatingDownloadBar(video);
      }
      if (src) {
        const thumb = captureVideoThumbnail(video);
        const w = video ? (video.videoWidth || video.width || video.clientWidth) : 0;
        const h = video ? (video.videoHeight || video.height || video.clientHeight) : 0;
        checkAndReportUrl(src, { width: w, height: h, thumbnailUrl: thumb, domIndex: idx * 10 });
      }
    });

    // Scan Images (Excluding icons < 40px)
    const images = root.querySelectorAll ? root.querySelectorAll('img, picture source') : [];
    images.forEach((img, idx) => {
      const src = img.currentSrc || img.src || img.getAttribute('data-src') || img.getAttribute('data-original');
      if (src) {
        const width = img.naturalWidth || img.width || parseInt(img.getAttribute('width')) || 0;
        const height = img.naturalHeight || img.height || parseInt(img.getAttribute('height')) || 0;
        if (width >= 40 || height >= 40 || (!width && !height)) {
          checkAndReportUrl(src, { width, height, title: img.alt || img.title, domIndex: 1000 + idx });
        }
      }
      if (img.srcset) {
        img.srcset.split(',').forEach(p => {
          const u = p.trim().split(' ')[0];
          if (u) checkAndReportUrl(u, { domIndex: 1000 + idx });
        });
      }
    });

    // Scan Audio
    const audios = root.querySelectorAll ? root.querySelectorAll('audio, audio source') : [];
    audios.forEach((el, idx) => {
      const src = el.src || el.currentSrc;
      if (src) checkAndReportUrl(src, { domIndex: 5000 + idx });
    });

    // Scan Shadow DOMs
    const allElements = root.querySelectorAll ? root.querySelectorAll('*') : [];
    allElements.forEach(el => {
      if (el.shadowRoot) {
        scanDOM(el.shadowRoot);
      }
    });
  }

  // Global Rescan API
  window.__dbPickaxeRescan = function() {
    reportedUrls.clear();
    globalDomIndex = 0;
    scanDOM();
  };

  scanDOM();

  if (!window.__dbPickaxeObserver) {
    window.__dbPickaxeObserver = new MutationObserver(() => {
      scanDOM();
    });
    window.__dbPickaxeObserver.observe(document.body || document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'data-src', 'srcset', 'data-original', 'poster']
    });
  }
})();
''';
}
