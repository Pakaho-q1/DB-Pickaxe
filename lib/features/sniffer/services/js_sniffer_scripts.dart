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
  let currentTrackedUrl = window.location.href;

  // Batch IPC Queue to eliminate WebView2 IPC flooding & UI freezing
  let mediaBatchQueue = [];
  let batchTimer = null;

  function flushMediaBatch() {
    if (mediaBatchQueue.length === 0) return;
    const batch = mediaBatchQueue;
    mediaBatchQueue = [];
    if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
      window.chrome.webview.postMessage(JSON.stringify({
        action: 'MEDIA_BATCH_DETECTED',
        items: batch,
        timestamp: Date.now()
      }));
    }
  }

  function scheduleBatchFlush() {
    if (!batchTimer) {
      batchTimer = setTimeout(() => {
        batchTimer = null;
        flushMediaBatch();
      }, 150);
    }
  }

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

    mediaBatchQueue.push(payload);
    scheduleBatchFlush();
  }

  function notifyPageUrlChanged(newUrl) {
    if (newUrl && newUrl !== currentTrackedUrl) {
      currentTrackedUrl = newUrl;
      flushMediaBatch();
      reportedUrls.clear();
      globalDomIndex = 0;
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(JSON.stringify({
          action: 'PAGE_URL_CHANGED',
          newUrl: newUrl,
          timestamp: Date.now()
        }));
      }
      setTimeout(() => scanDOM(), 200);
    }
  }

  // 1. Hook Single Page App (SPA) History Navigation
  if (!window.__dbPickaxeHistoryHooked) {
    window.__dbPickaxeHistoryHooked = true;
    ['pushState', 'replaceState'].forEach(method => {
      const orig = history[method];
      history[method] = function(...args) {
        const res = orig.apply(this, args);
        try {
          notifyPageUrlChanged(window.location.href);
        } catch (_) {}
        return res;
      };
    });
    window.addEventListener('popstate', () => notifyPageUrlChanged(window.location.href));
    window.addEventListener('hashchange', () => notifyPageUrlChanged(window.location.href));
  }

  // 2. Complete 5-Tier Video Thumbnail Fallback Chain
  function captureVideoThumbnail(videoEl) {
    if (!videoEl) return null;

    // Tier 1: poster attribute
    if (videoEl.poster && videoEl.poster.trim().length > 0) return videoEl.poster;

    // Tier 2: data-poster / data-thumb / data-preview
    const dataPoster = videoEl.getAttribute('data-poster') || videoEl.getAttribute('data-thumb') || videoEl.getAttribute('data-preview');
    if (dataPoster && dataPoster.trim().length > 0) return dataPoster;

    // Tier 3: Container / parent nearby <img>
    try {
      const parent = videoEl.parentElement || videoEl.closest('article, [class*="card"], [class*="player"], [class*="video"]');
      if (parent) {
        const companionImg = parent.querySelector('img:not([src*="avatar"]):not([src*="icon"])');
        if (companionImg) {
          const imgSrc = companionImg.currentSrc || companionImg.src || companionImg.getAttribute('data-src');
          if (imgSrc && !isAdUrl(imgSrc)) return imgSrc;
        }
      }
    } catch (_) {}

    // Tier 4: Live Canvas snapshot if video has decoded dimensions
    try {
      if (videoEl.videoWidth > 0 && videoEl.videoHeight > 0) {
        const canvas = document.createElement('canvas');
        canvas.width = Math.min(videoEl.videoWidth, 320);
        canvas.height = Math.min(videoEl.videoHeight, 180);
        const ctx = canvas.getContext('2d');
        ctx.drawImage(videoEl, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL('image/jpeg', 0.60);
      }
    } catch (e) {}

    // Tier 5: og:image or twitter:image from document head
    try {
      const ogImg = document.querySelector('meta[property="og:image"], meta[name="twitter:image"]');
      if (ogImg && ogImg.content) return ogImg.content;
    } catch (_) {}

    return null;
  }

  // 3. Complete srcset descriptor parser (supporting both w and x descriptors)
  function parseBestSrcset(srcsetStr) {
    if (!srcsetStr || typeof srcsetStr !== 'string') return null;
    const candidates = [];
    const parts = srcsetStr.split(/,\s+(?=http|\/|\.)/g);

    for (let i = 0; i < parts.length; i++) {
      const entry = parts[i].trim();
      if (!entry) continue;
      const tokens = entry.split(/\s+/);
      const url = tokens[0];
      let score = 1.0;

      if (tokens.length > 1) {
        const desc = tokens[1].toLowerCase();
        if (desc.endsWith('w')) {
          score = parseFloat(desc.replace('w', '')) || 1.0;
        } else if (desc.endsWith('x')) {
          score = (parseFloat(desc.replace('x', '')) || 1.0) * 1000.0;
        }
      }
      candidates.push({ url, score });
    }

    if (candidates.length === 0) return null;
    candidates.sort((a, b) => b.score - a.score);
    return candidates[0].url;
  }

  // 4. Hook HTMLMediaElement.prototype.play for on-demand stream trigger
  if (!window.__dbPickaxeMediaPlayHooked) {
    window.__dbPickaxeMediaPlayHooked = true;
    const origPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function(...args) {
      try {
        const el = this;
        const src = el.currentSrc || el.src;
        if (src) {
          const isVideo = el.tagName.toLowerCase() === 'video';
          const thumb = isVideo ? captureVideoThumbnail(el) : null;
          const w = isVideo ? (el.videoWidth || el.width || el.clientWidth) : 0;
          const h = isVideo ? (el.videoHeight || el.height || el.clientHeight) : 0;
          checkAndReportUrl(src, { width: w, height: h, thumbnailUrl: thumb, domIndex: 0 });
        }
      } catch (_) {}
      return origPlay.apply(this, args);
    };
  }

  // 5. Hook window.fetch with robust Content-Type and #EXTM3U checks
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
        const lowerType = contentType.toLowerCase();

        if (lowerType.includes('mpegurl') || lowerType.includes('vnd.apple.mpegurl') || lowerType.includes('dash+xml')) {
          reportMedia(clone.url || url, 'stream', { mime: contentType });
        } else if (lowerType.includes('video/')) {
          reportMedia(clone.url || url, 'video', { mime: contentType });
        } else if (lowerType.includes('image/')) {
          reportMedia(clone.url || url, 'image', { mime: contentType });
        } else if (lowerType.includes('audio/')) {
          reportMedia(clone.url || url, 'audio', { mime: contentType });
        } else if (lowerType.includes('json') || lowerType.includes('text/plain') || lowerType.includes('javascript')) {
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

  // 6. Hook XMLHttpRequest with robust Content-Type and #EXTM3U checks
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
          const contentType = (this.getResponseHeader('content-type') || '').toLowerCase();
          const targetUrl = this.responseURL || this.__dbPickaxeUrl;

          if (contentType.includes('mpegurl') || contentType.includes('vnd.apple.mpegurl') || contentType.includes('dash+xml')) {
            reportMedia(targetUrl, 'stream', { mime: contentType });
          } else if (contentType.includes('video/')) {
            reportMedia(targetUrl, 'video', { mime: contentType });
          } else if (contentType.includes('image/')) {
            reportMedia(targetUrl, 'image', { mime: contentType });
          } else if (contentType.includes('audio/')) {
            reportMedia(targetUrl, 'audio', { mime: contentType });
          } else if (contentType.includes('json') || contentType.includes('text/plain') || contentType.includes('javascript')) {
            scanTextForMediaUrls(this.responseText, targetUrl);
          }
        } catch(e) {}
      });
      return originalSend.apply(this, args);
    };
  }

  // 7. Hook URL.createObjectURL for MediaSource & Blobs
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

  // 8. Escaped JSON Slashes Regex & #EXTM3U Text Scanning
  function scanTextForMediaUrls(text, contextUrl) {
    if (!text || typeof text !== 'string' || text.length > 1000000) return;

    if (text.trim().startsWith('#EXTM3U')) {
      reportMedia(contextUrl, 'stream', { mime: 'application/x-mpegURL' });
      return;
    }

    const lower = text.toLowerCase();
    if (lower.indexOf('.m3u8') === -1 && lower.indexOf('.mpd') === -1 && lower.indexOf('.mp4') === -1 && lower.indexOf('.webm') === -1 && lower.indexOf('.m4a') === -1 && lower.indexOf('.mp3') === -1 && lower.indexOf('video') === -1) {
      return;
    }

    // Handles escaped JSON slashes (e.g. https:\/\/...)
    const regex = /(https?(?::\\\/\\\/|:\/\/)[^\s"'<>]+?\.(?:m3u8|mpd|mp4|webm|m4a|mp3)(?:\?[^\s"'<>]*)?)/gi;
    let match;
    while ((match = regex.exec(text)) !== null) {
      let foundUrl = match[1].replace(/\\u0026/g, '&').replace(/\\\//g, '/').replace(/\\/g, '');
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

  // 9. Hover Download Badge & Hotkey Shift+D Logic
  window.__dbPickaxeActiveHoverTarget = null;

  function triggerDirectDownload(targetEl) {
    if (!targetEl) return;

    const isVideo = targetEl.tagName.toLowerCase() === 'video' || targetEl.querySelector('video');
    const isImg = targetEl.tagName.toLowerCase() === 'img';

    if (isVideo) {
      const videoEl = targetEl.tagName.toLowerCase() === 'video' ? targetEl : targetEl.querySelector('video');
      const videoSrc = videoEl.currentSrc || videoEl.src || window.__lastStreamUrl;
      if (videoSrc) {
        const thumb = captureVideoThumbnail(videoEl);
        const directPayload = {
          action: 'DIRECT_DOWNLOAD',
          url: videoSrc,
          pageUrl: window.location.href,
          type: videoSrc.toLowerCase().includes('.m3u8') ? 'stream' : 'video',
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
    } else if (isImg) {
      const bestSrc = targetEl.srcset ? parseBestSrcset(targetEl.srcset) : null;
      const imgSrc = bestSrc || targetEl.currentSrc || targetEl.src || targetEl.getAttribute('data-src') || targetEl.getAttribute('data-original');
      if (imgSrc) {
        const directPayload = {
          action: 'DIRECT_DOWNLOAD',
          url: imgSrc,
          pageUrl: window.location.href,
          type: 'image',
          title: targetEl.alt || targetEl.title || document.title || 'Image',
          width: targetEl.naturalWidth || targetEl.width || 0,
          height: targetEl.naturalHeight || targetEl.height || 0,
          thumbnailUrl: imgSrc,
          timestamp: Date.now()
        };
        if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
          window.chrome.webview.postMessage(JSON.stringify(directPayload));
        }
      }
    }
  }

  window.__dbPickaxeTriggerDownload = triggerDirectDownload;

  if (!window.__dbPickaxeKeyHooked) {
    window.__dbPickaxeKeyHooked = true;
    window.addEventListener('keydown', function(e) {
      if (e.shiftKey && (e.key === 'D' || e.key === 'd')) {
        if (window.__dbPickaxeActiveHoverTarget) {
          e.preventDefault();
          e.stopPropagation();
          triggerDirectDownload(window.__dbPickaxeActiveHoverTarget);
        }
      }
    }, true);
  }

  function attachHoverBadge(element, isVideo) {
    if (element.__dbPickaxeWidgetAttached) return;
    element.__dbPickaxeWidgetAttached = true;

    const wrapper = document.createElement('div');
    wrapper.style.cssText = 'position:absolute; top:8px; right:8px; z-index:2147483647; display:none; cursor:pointer; font-family:system-ui,sans-serif; user-select:none; pointer-events:auto;';

    const btn = document.createElement('div');
    const label = isVideo ? 'Download Video (Shift+D)' : 'Download Image (Shift+D)';
    const bgGradient = isVideo
        ? 'linear-gradient(135deg,#6366F1,#06B6D4)'
        : 'linear-gradient(135deg,#10B981,#06B6D4)';

    btn.style.cssText = `display:flex; align-items:center; gap:5px; background:${bgGradient}; color:#FFF; font-size:11px; font-weight:bold; padding:5px 10px; border-radius:6px; box-shadow:0 4px 12px rgba(0,0,0,0.5); border:1px solid rgba(255,255,255,0.4); transition:all 0.15s ease;`;
    btn.innerHTML = `<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> ${label}`;

    btn.onmouseenter = () => { btn.style.transform = 'scale(1.05)'; btn.style.filter = 'brightness(1.15)'; };
    btn.onmouseleave = () => { btn.style.transform = 'scale(1)'; btn.style.filter = 'none'; };

    btn.onclick = (e) => {
      e.stopPropagation();
      e.preventDefault();
      triggerDirectDownload(element);
    };

    wrapper.appendChild(btn);

    const parent = element.parentElement || document.body;
    if (getComputedStyle(parent).position === 'static') {
      parent.style.position = 'relative';
    }
    parent.appendChild(wrapper);

    let hideTimer = null;
    const show = () => {
      clearTimeout(hideTimer);
      window.__dbPickaxeActiveHoverTarget = element;
      wrapper.style.display = 'block';
    };
    const hide = () => {
      hideTimer = setTimeout(() => {
        wrapper.style.display = 'none';
        if (window.__dbPickaxeActiveHoverTarget === element) {
          window.__dbPickaxeActiveHoverTarget = null;
        }
      }, 1500);
    };

    element.addEventListener('mouseenter', show);
    element.addEventListener('mousemove', show);
    element.addEventListener('mouseleave', hide);
    wrapper.addEventListener('mouseenter', show);
    wrapper.addEventListener('mouseleave', hide);
  }

  // 10. Comprehensive DOM Scanning (Videos, Images, srcset, Lazy-load, Backgrounds)
  function scanDOM(root = document) {
    if (!root) return;

    // Fast Scan Videos
    const videos = root.querySelectorAll ? root.querySelectorAll('video, video source') : [];
    for (let idx = 0; idx < videos.length; idx++) {
      const el = videos[idx];
      const video = el.tagName.toLowerCase() === 'video' ? el : el.parentElement;
      const src = el.src || el.currentSrc || el.getAttribute('data-src') || (video ? (video.src || video.currentSrc) : null);
      if (video) {
        attachHoverBadge(video, true);
      }
      if (src) {
        const thumb = captureVideoThumbnail(video);
        const w = video ? (video.videoWidth || video.width || video.clientWidth) : 0;
        const h = video ? (video.videoHeight || video.height || video.clientHeight) : 0;
        checkAndReportUrl(src, { width: w, height: h, thumbnailUrl: thumb, domIndex: idx * 10 });
      }
    }

    // Fast Scan Images (srcset with w/x parsing, data-src, data-original, data-highres)
    const images = root.querySelectorAll ? root.querySelectorAll('img, picture source') : [];
    for (let idx = 0; idx < images.length; idx++) {
      const img = images[idx];
      const bestSrcset = img.srcset ? parseBestSrcset(img.srcset) : null;
      const src = bestSrcset || img.currentSrc || img.src || img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-highres') || img.getAttribute('data-full-url');

      if (src) {
        const width = img.naturalWidth || img.width || parseInt(img.getAttribute('width')) || 0;
        const height = img.naturalHeight || img.height || parseInt(img.getAttribute('height')) || 0;
        if (width >= 40 || height >= 40 || (!width && !height)) {
          checkAndReportUrl(src, { width, height, title: img.alt || img.title, domIndex: 1000 + idx });
          if (width >= 120 || height >= 120) {
            attachHoverBadge(img, false);
          }
        }
      }
    }

    // Fast Scan Background Images on elements with style
    const bgElements = root.querySelectorAll ? root.querySelectorAll('[style*="background"]') : [];
    for (let idx = 0; idx < bgElements.length; idx++) {
      const el = bgElements[idx];
      const styleBg = el.style.backgroundImage || '';
      if (styleBg.includes('url(')) {
        const match = /url\(['"]?(https?:\/\/[^'"]+)['"]?\)/i.exec(styleBg);
        if (match && match[1]) {
          checkAndReportUrl(match[1], { domIndex: 3000 + idx });
        }
      }
    }

    // Fast Scan Audio
    const audios = root.querySelectorAll ? root.querySelectorAll('audio, audio source') : [];
    for (let idx = 0; idx < audios.length; idx++) {
      const el = audios[idx];
      const src = el.src || el.currentSrc;
      if (src) checkAndReportUrl(src, { domIndex: 5000 + idx });
    }
  }

  // Global Rescan API
  window.__dbPickaxeRescan = function() {
    flushMediaBatch();
    reportedUrls.clear();
    globalDomIndex = 0;
    scanDOM();
    flushMediaBatch();
  };

  scanDOM();
  flushMediaBatch();

  if (!window.__dbPickaxeObserver) {
    let __dbPickaxeScanTimer = null;
    window.__dbPickaxeObserver = new MutationObserver((mutations) => {
      clearTimeout(__dbPickaxeScanTimer);
      __dbPickaxeScanTimer = setTimeout(() => {
        scanDOM();
      }, 350);
    });
    window.__dbPickaxeObserver.observe(document.body || document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'data-src', 'srcset', 'data-original', 'poster', 'data-poster']
    });
  }
})();
''';
}
