class JsSnifferScripts {
  static String get snifferPayload => getSnifferPayload();

  static String getSnifferPayload({
    bool enableAutoScroll = false,
    bool enableAutoVideoTrigger = false,
  }) {
    return '''
window.__dbPickaxeEnableAutoScroll = $enableAutoScroll;
window.__dbPickaxeEnableAutoVideoTrigger = $enableAutoVideoTrigger;
$snifferScriptBody''';
  }

  static const String snifferScriptBody = r"""
(function() {
  if (window.__dbPickaxeSnifferLoaded) return;
  window.__dbPickaxeSnifferLoaded = true;

  const reportedUrls = new Set();
  let mediaBatchQueue = [];
  let batchTimer = null;
  let currentTrackedUrl = window.location.href;
  let globalDomIndex = 0;
  let __autoScrollDone = false;
  const observedShadowRoots = new WeakSet();

  function sendToHost(payloadObj) {
    try {
      const jsonStr = typeof payloadObj === 'string' ? payloadObj : JSON.stringify(payloadObj);
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('SnifferChannel', jsonStr);
      }
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(jsonStr);
      }
    } catch (_) {}
  }

  function isAdUrl(url) {
    if (!url || typeof url !== 'string') return true;
    const lower = url.toLowerCase();
    const adKeywords = [
      'doubleclick.net', 'googleads', 'googlesyndication', 'adservice',
      'pagead', 'adnxs.com', 'analytics', 'telemetry', 'beacon',
      '/ads/', '/ad/', '_ad_', '-ad-', 'taboola.com', 'outbrain.com',
      'facebook.com/tr/', 'pixel.gif', '1x1.png', 'empty.gif',
      'favicon.ico', 'adsafeprotected', 'scorecardresearch'
    ];
    return adKeywords.some(keyword => lower.includes(keyword));
  }

  function flushMediaBatch() {
    if (batchTimer) {
      clearTimeout(batchTimer);
      batchTimer = null;
    }
    if (mediaBatchQueue.length === 0) return;
    const batch = mediaBatchQueue;
    mediaBatchQueue = [];
    sendToHost({
      action: 'MEDIA_BATCH_DETECTED',
      items: batch,
      timestamp: Date.now()
    });
  }

  function scheduleBatchFlush() {
    if (!batchTimer) {
      batchTimer = setTimeout(() => {
        batchTimer = null;
        flushMediaBatch();
      }, 150);
    }
  }

  function syncCookies() {
    try {
      if (document.cookie) {
        sendToHost({
          action: 'COOKIE_SYNC',
          url: window.location.href,
          cookies: document.cookie,
          timestamp: Date.now()
        });
      }
    } catch (_) {}
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
    syncCookies();
  }

  function notifyPageUrlChanged(newUrl) {
    if (newUrl && newUrl !== currentTrackedUrl) {
      currentTrackedUrl = newUrl;
      flushMediaBatch();
      reportedUrls.clear();
      globalDomIndex = 0;
      __autoScrollDone = false;
      window.__dbPickaxeAutoScrollDone = false;
      sendToHost({
        action: 'PAGE_URL_CHANGED',
        newUrl: newUrl,
        cookies: document.cookie || '',
        timestamp: Date.now()
      });
      syncCookies();
      setTimeout(() => { scanDOM(); setTimeout(autoScrollReveal, 1200); }, 200);
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

  // 1b. Hook Element.prototype.attachShadow for Web Components / Shadow DOM
  if (!window.__dbPickaxeShadowHooked && typeof Element !== 'undefined' && Element.prototype.attachShadow) {
    window.__dbPickaxeShadowHooked = true;
    const origAttachShadow = Element.prototype.attachShadow;
    Element.prototype.attachShadow = function(init) {
      const shadowRoot = origAttachShadow.apply(this, arguments);
      try {
        if (shadowRoot && !observedShadowRoots.has(shadowRoot)) {
          observedShadowRoots.add(shadowRoot);
          setTimeout(() => scanDOM(shadowRoot), 300);
          if (typeof MutationObserver !== 'undefined') {
            const shadowObs = new MutationObserver(() => {
              scanDOM(shadowRoot);
            });
            shadowObs.observe(shadowRoot, { childList: true, subtree: true, attributes: true });
          }
        }
      } catch (_) {}
      return shadowRoot;
    };
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
    } catch (e) {
      if (e && e.name === 'SecurityError') {
        if (videoEl.poster && videoEl.poster.trim().length > 0) return videoEl.poster;
        return null;
      }
    }

    // Tier 5: og:image or twitter:image from document head
    try {
      const ogImg = document.querySelector('meta[property="og:image"], meta[name="twitter:image"]');
      if (ogImg && ogImg.content) return ogImg.content;
    } catch (_) {}

    return null;
  }

  // 3. srcset parser
  function parseBestSrcset(srcsetStr) {
    if (!srcsetStr || typeof srcsetStr !== 'string') return null;
    const rawParts = srcsetStr.split(',');
    const wCandidates = [];
    const xCandidates = [];

    for (let i = 0; i < rawParts.length; i++) {
      const entry = rawParts[i].trim();
      if (!entry) continue;
      const tokens = entry.split(/\s+/).filter(Boolean);
      const url = tokens[0];
      if (!url) continue;
      if (tokens.length === 1) {
        xCandidates.push({ url, score: 1 });
        continue;
      }
      const desc = tokens[1].toLowerCase();
      if (desc.endsWith('w')) {
        const w = parseInt(desc.slice(0, -1), 10);
        if (!isNaN(w) && w > 0) wCandidates.push({ url, score: w });
      } else if (desc.endsWith('x')) {
        const x = parseFloat(desc.slice(0, -1));
        if (!isNaN(x) && x > 0) xCandidates.push({ url, score: x });
      } else {
        xCandidates.push({ url, score: 1 });
      }
    }

    if (wCandidates.length > 0) {
      wCandidates.sort((a, b) => b.score - a.score);
      return wCandidates[0].url;
    }
    if (xCandidates.length > 0) {
      xCandidates.sort((a, b) => b.score - a.score);
      return xCandidates[0].url;
    }
    return null;
  }

  function getBestSrcForImg(img) {
    if (img.currentSrc && img.currentSrc.trim()) return img.currentSrc;
    if (img.srcset) {
      const best = parseBestSrcset(img.srcset);
      if (best) return best;
    }
    return img.src || img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-highres') || null;
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

  // 5. Hook window.fetch
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
        let clone;
        try {
          clone = response.clone();
        } catch (_) {
          return response;
        }
        const contentType = (clone.headers.get('content-type') || '').toLowerCase();
        const contentLength = parseInt(clone.headers.get('content-length') || '0', 10);

        if (contentType.includes('mpegurl') || contentType.includes('vnd.apple.mpegurl') || contentType.includes('dash+xml')) {
          reportMedia(clone.url || url, 'stream', { mime: contentType });
          clone.text().then(t => {
            if (t && t.trim().startsWith('#EXTM3U')) reportM3u8Variants(t, clone.url || url);
          }).catch(() => {});
        } else if (contentType.includes('video/')) {
          reportMedia(clone.url || url, 'video', { mime: contentType });
        } else if (contentType.includes('image/')) {
          reportMedia(clone.url || url, 'image', { mime: contentType });
        } else if (contentType.includes('audio/')) {
          reportMedia(clone.url || url, 'audio', { mime: contentType });
        } else if (contentType.includes('json') || contentType.includes('text/plain') || contentType.includes('javascript')) {
          if (contentLength > 0 && contentLength > 200 * 1024) {
            return response;
          }
          clone.text().then(txt => {
            if (txt && txt.length < 200 * 1024) {
              scanTextForMediaUrls(txt, clone.url || url);
            }
          }).catch(() => {});
        }
        return response;
      } catch (err) {
        throw err;
      }
    };
  }

  // 6. Hook XMLHttpRequest
  if (!window.__dbPickaxeXhrHooked) {
    window.__dbPickaxeXhrHooked = true;
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
          const contentLength = parseInt(this.getResponseHeader('content-length') || '0', 10);
          const targetUrl = this.responseURL || this.__dbPickaxeUrl;

          if (contentType.includes('mpegurl') || contentType.includes('vnd.apple.mpegurl') || contentType.includes('dash+xml')) {
            reportMedia(targetUrl, 'stream', { mime: contentType });
            const txt = this.responseText;
            if (txt && txt.trim().startsWith('#EXTM3U')) reportM3u8Variants(txt, targetUrl);
          } else if (contentType.includes('video/')) {
            reportMedia(targetUrl, 'video', { mime: contentType });
          } else if (contentType.includes('image/')) {
            reportMedia(targetUrl, 'image', { mime: contentType });
          } else if (contentType.includes('audio/')) {
            reportMedia(targetUrl, 'audio', { mime: contentType });
          } else if (contentType.includes('json') || contentType.includes('text/plain') || contentType.includes('javascript')) {
            if (contentLength > 0 && contentLength > 200 * 1024) return;
            const txt = this.responseText;
            if (!txt || txt.length > 200 * 1024) return;
            scanTextForMediaUrls(txt, targetUrl);
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
      try {
        const isVideoBlob = obj && (obj instanceof MediaSource || (obj.type && obj.type.includes('video')));
        if (isVideoBlob) {
          if (window.__lastStreamUrl) {
            reportMedia(window.__lastStreamUrl, 'stream', { mime: 'application/x-mpegURL' });
          }
          if (blobUrl && blobUrl.startsWith('blob:')) {
            reportMedia(blobUrl, 'video', { allowBlob: true });
          }
        }
      } catch (_) {}
      return blobUrl;
    };
  }

  // 8. HLS master parser
  function reportM3u8Variants(manifestText, baseUrl) {
    const lines = manifestText.split('\n');
    let found = 0;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      let w = 0, h = 0;
      const resMatch = /RESOLUTION=(\d+)x(\d+)/i.exec(line);
      if (resMatch) { w = parseInt(resMatch[1], 10) || 0; h = parseInt(resMatch[2], 10) || 0; }
      const urlLine = (lines[i + 1] || '').trim();
      if (urlLine && !urlLine.startsWith('#')) {
        try {
          const abs = new URL(urlLine, baseUrl).href;
          reportMedia(abs, 'stream', { width: w, height: h, mime: 'application/x-mpegURL' });
          found++;
        } catch (_) {}
      }
    }
    if (found === 0) {
      reportMedia(baseUrl, 'stream', { mime: 'application/x-mpegURL' });
    } else {
      reportMedia(baseUrl, 'stream', { mime: 'application/x-mpegURL' });
    }
  }

  // 8b. Escaped JSON Slashes Regex & #EXTM3U Text Scanning
  function scanTextForMediaUrls(text, contextUrl) {
    if (!text || typeof text !== 'string' || text.length > 1000000) return;

    if (text.trim().startsWith('#EXTM3U')) {
      reportM3u8Variants(text, contextUrl);
      return;
    }

    const lower = text.toLowerCase();
    if (lower.indexOf('.m3u8') === -1 && lower.indexOf('.mpd') === -1 && lower.indexOf('.mp4') === -1 && lower.indexOf('.webm') === -1 && lower.indexOf('.m4a') === -1 && lower.indexOf('.mp3') === -1 && lower.indexOf('video') === -1) {
      return;
    }

    const regex = /(https?(?::\\\/\\\/|:\/\/)[^\s"'<>]+?\.(?:m3u8|mpd|mp4|webm|m4a|mp3)(?:\?[^\s"'<>]*)?)/gi;
    let match;
    while ((match = regex.exec(text)) !== null) {
      let foundUrl = match[1].replace(/\\u0026/g, '&').replace(/\\\//g, '/').replace(/\\/g, '');
      checkAndReportUrl(foundUrl);
    }
  }

  function isJunkStreamSegment(u) {
    if (!u || typeof u !== 'string') return true;
    const clean = u.split('?')[0].toLowerCase();
    if (clean.endsWith('.m4s') ||
        clean.endsWith('.mp4frag') ||
        clean.endsWith('.cmfv') ||
        clean.endsWith('.cmfa') ||
        clean.endsWith('.init') ||
        clean.endsWith('.m4f')) {
      return true;
    }
    if (clean.endsWith('.ts') && /[-_0-9/](seg|segment|chunk|frag|part|video|audio)?[0-9]+\.ts$/.test(clean)) {
      return true;
    }
    return false;
  }

  function checkAndReportUrl(url, extra = {}) {
    if (!url || typeof url !== 'string' || isJunkStreamSegment(url)) return;
    if (isAdUrl(url)) return;

    if (url.startsWith('blob:')) {
      if (extra.allowBlob || window.__lastStreamUrl) {
        reportMedia(url, 'video', { ...extra, allowBlob: true });
      }
      return;
    }

    const cleanUrl = url.split('?')[0].toLowerCase();
    const fullLower = url.toLowerCase();
    const isImageHint = extra.type === 'image' || extra.isImg ||
        (extra.mime && extra.mime.startsWith('image/')) ||
        cleanUrl.endsWith('.jpg') || cleanUrl.endsWith('.jpeg') || cleanUrl.endsWith('.png') ||
        cleanUrl.endsWith('.webp') || cleanUrl.endsWith('.avif') || cleanUrl.endsWith('.gif') ||
        fullLower.includes('images.unsplash.com') || fullLower.includes('format=') || fullLower.includes('/photo-') ||
        fullLower.includes('images.pexels.com') || fullLower.includes('cdn.pixabay.com') || fullLower.includes('i.imgur.com') ||
        fullLower.includes('rule34') || fullLower.includes('donmai') || fullLower.includes('gelbooru') || fullLower.includes('safe.booru');

    if (cleanUrl.endsWith('.m3u8')) {
      window.__lastStreamUrl = url;
      reportMedia(url, 'stream', { mime: 'application/x-mpegURL', ...extra });
    } else if (cleanUrl.endsWith('.mpd')) {
      reportMedia(url, 'stream', { mime: 'application/dash+xml', ...extra });
    } else if (cleanUrl.endsWith('.mp4') || cleanUrl.endsWith('.webm') || cleanUrl.endsWith('.mov') || cleanUrl.endsWith('.mkv')) {
      reportMedia(url, 'video', extra);
    } else if (isImageHint) {
      reportMedia(url, 'image', { ...extra, mime: extra.mime || 'image/jpeg' });
    } else if (cleanUrl.endsWith('.mp3') || cleanUrl.endsWith('.aac') || cleanUrl.endsWith('.wav') || cleanUrl.endsWith('.ogg') || cleanUrl.endsWith('.m4a')) {
      reportMedia(url, 'audio', extra);
    }
  }

  // 9. Hover Download Badge & Hotkey Shift+D Logic
  if (typeof window.__dbPickaxeHoverBadgeEnabled === 'undefined') {
    window.__dbPickaxeHoverBadgeEnabled = false;
  }
  window.__dbPickaxeSetHoverBadgeEnabled = function(enabled) {
    window.__dbPickaxeHoverBadgeEnabled = !!enabled;
    if (enabled) scanDOM();
  };
  window.__dbPickaxeActiveHoverTarget = null;

  function attachHoverTracker(el) {
    if (!el || el.__dbPickaxeHoverTracked) return;
    el.__dbPickaxeHoverTracked = true;
    el.addEventListener('mouseenter', () => { window.__dbPickaxeActiveHoverTarget = el; });
    el.addEventListener('mouseleave', () => {
      if (window.__dbPickaxeActiveHoverTarget === el) window.__dbPickaxeActiveHoverTarget = null;
    });
  }

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
        sendToHost(directPayload);
      }
    } else if (isImg) {
      const imgSrc = getBestSrcForImg(targetEl) || targetEl.getAttribute('data-src') || targetEl.getAttribute('data-original');
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
        sendToHost(directPayload);
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
    if (!window.__dbPickaxeHoverBadgeEnabled) return;
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

  // 10. Comprehensive DOM Scanning with Shadow DOM & iFrame Traversal
  function scanDOM(root = document) {
    if (!root) return;

    // Scan Videos & Video Elements
    const videos = root.querySelectorAll ? root.querySelectorAll('video, video source') : [];
    for (let idx = 0; idx < videos.length; idx++) {
      const el = videos[idx];
      const video = el.tagName.toLowerCase() === 'video' ? el : el.parentElement;
      const src = el.src || el.currentSrc || el.getAttribute('data-src') || (video ? (video.src || video.currentSrc) : null);
      if (video) {
        attachHoverTracker(video);
        attachHoverBadge(video, true);
        maybeObserveForReveal(video);
      }
      if (src) {
        const thumb = captureVideoThumbnail(video);
        const w = video ? (video.videoWidth || video.width || video.clientWidth) : 0;
        const h = video ? (video.videoHeight || video.height || video.clientHeight) : 0;
        const isBlob = typeof src === 'string' && src.startsWith('blob:');
        checkAndReportUrl(src, { width: w, height: h, thumbnailUrl: thumb, domIndex: idx * 10, allowBlob: isBlob });
      }
    }

    // Scan Custom Video Tags / Web Components
    const customPlayers = root.querySelectorAll ? root.querySelectorAll('video-js, media-player, amp-video, [data-video-url], [data-stream-url], [data-hls-url]') : [];
    for (let idx = 0; idx < customPlayers.length; idx++) {
      const cp = customPlayers[idx];
      const videoUrl = cp.getAttribute('data-video-url') || cp.getAttribute('data-stream-url') || cp.getAttribute('data-hls-url') || cp.getAttribute('src');
      if (videoUrl) {
        checkAndReportUrl(videoUrl, { domIndex: 50 + idx });
      }
    }

    // Scan Images (srcset with w/x parsing, data-src, data-original, data-highres)
    const images = root.querySelectorAll ? root.querySelectorAll('img, picture source') : [];
    for (let idx = 0; idx < images.length; idx++) {
      const img = images[idx];
      const src = getBestSrcForImg(img) || img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-highres') || img.getAttribute('data-full-url');

      if (src) {
        const width = img.naturalWidth || img.width || parseInt(img.getAttribute('width')) || 0;
        const height = img.naturalHeight || img.height || parseInt(img.getAttribute('height')) || 0;
        if (width >= 40 || height >= 40 || (!width && !height)) {
          checkAndReportUrl(src, { width, height, title: img.alt || img.title, type: 'image', isImg: true, domIndex: 1000 + idx });
          attachHoverTracker(img);
          maybeObserveForReveal(img);
          if (width >= 120 || height >= 120) {
            attachHoverBadge(img, false);
          }
        } else {
          maybeObserveForReveal(img);
        }
      }
    }

    // Scan Background Images
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

    // Scan Audio
    const audios = root.querySelectorAll ? root.querySelectorAll('audio, audio source') : [];
    for (let idx = 0; idx < audios.length; idx++) {
      const el = audios[idx];
      const src = el.src || el.currentSrc;
      if (src) checkAndReportUrl(src, { domIndex: 5000 + idx });
    }

    // Traverse Shadow Roots of elements inside this root
    const allElements = root.querySelectorAll ? root.querySelectorAll('*') : [];
    for (let idx = 0; idx < allElements.length; idx++) {
      const elem = allElements[idx];
      if (elem.shadowRoot && !observedShadowRoots.has(elem.shadowRoot)) {
        observedShadowRoots.add(elem.shadowRoot);
        scanDOM(elem.shadowRoot);
      }
    }

    // Traverse Same-Origin iFrames
    const iframes = root.querySelectorAll ? root.querySelectorAll('iframe') : [];
    for (let idx = 0; idx < iframes.length; idx++) {
      const frame = iframes[idx];
      try {
        if (frame.contentDocument) {
          scanDOM(frame.contentDocument);
        }
      } catch (_) {}
    }
  }

  // 10b. Auto-reveal
  const __revealAttempted = new WeakSet();
  const __revealHoldTimers = new WeakMap();
  const __revealRetryTimers = new WeakMap();
  let __revealObserver = null;
  if (typeof IntersectionObserver !== 'undefined') {
    __revealObserver = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        const el = entry.target;
        if (entry.isIntersecting && entry.intersectionRatio >= 0.35) {
          if (__revealAttempted.has(el) || __revealHoldTimers.has(el)) continue;
          const hold = setTimeout(() => {
            __revealHoldTimers.delete(el);
            if (!document.contains(el)) return;
            const r = el.getBoundingClientRect();
            if (r.width < 40 || r.height < 40) return;
            if (el.tagName === 'A' && el.href) return;
            if (el.closest && el.closest('a[href^="http"]')) {
              try { el.dispatchEvent(new MouseEvent('mouseover', { bubbles: true })); } catch (_) {}
              __revealAttempted.add(el);
              scanDOM();
              return;
            }
            const needsClick = el.hasAttribute('data-src') || el.hasAttribute('data-original') || el.hasAttribute('data-poster')
              || (el.getAttribute('role') === 'button') || el.classList.contains('lightbox') || el.closest('[data-lightbox]');
            if (!needsClick) {
              try { el.dispatchEvent(new MouseEvent('mouseover', { bubbles: true })); } catch (_) {}
              __revealAttempted.add(el);
              const retry = setTimeout(() => {
                __revealRetryTimers.delete(el);
                if (!document.contains(el)) return;
                if (el.hasAttribute('data-src') || el.hasAttribute('data-original')) {
                  try { el.dispatchEvent(new MouseEvent('mouseover', { bubbles: true })); } catch (_) {}
                  scanDOM();
                }
              }, 1500);
              __revealRetryTimers.set(el, retry);
              scanDOM();
              return;
            }
            __revealAttempted.add(el);
            try { el.dispatchEvent(new MouseEvent('mouseover', { bubbles: true })); } catch (_) {}
            try { el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true })); } catch (_) {}
            try { el.click(); } catch (_) {}
            scanDOM();
            const retry2 = setTimeout(() => {
              __revealRetryTimers.delete(el);
              if (!document.contains(el)) return;
              const stillUnresolved = el.hasAttribute('data-src') || el.hasAttribute('data-original') || !el.src;
              if (stillUnresolved) {
                try { el.click(); } catch (_) {}
                scanDOM();
              }
            }, 1500);
            __revealRetryTimers.set(el, retry2);
          }, 1000);
          __revealHoldTimers.set(el, hold);
        } else {
          const h = __revealHoldTimers.get(el);
          if (h) { clearTimeout(h); __revealHoldTimers.delete(el); }
        }
      }
    }, { threshold: [0.35], rootMargin: '120px 0px' });
    window.__dbPickaxeRevealObserver = __revealObserver;
  }

  function maybeObserveForReveal(el) {
    if (!__revealObserver || !el || el.__dbRevealObserved) return;
    const isCandidate = el.tagName === 'VIDEO' || el.tagName === 'IMG'
      || el.hasAttribute('data-src') || el.hasAttribute('data-original')
      || el.hasAttribute('onclick') || el.getAttribute('role') === 'button';
    if (!isCandidate) return;
    try { __revealObserver.observe(el); el.__dbRevealObserved = true; } catch (_) {}
  }

  function autoScrollReveal() {
    if (!window.__dbPickaxeEnableAutoScroll) return;
    if (__autoScrollDone) return;
    if (document.body.scrollHeight <= window.innerHeight + 120) return;
    if (window.__dbPickaxeHoverBadgeEnabled) return;
    __autoScrollDone = true;
    window.__dbPickaxeAutoScrollDone = true;
    const startY = window.scrollY;
    let step = 0;
    const maxSteps = 3;
    function doStep() {
      if (step >= maxSteps || !document.body) {
        try { window.scrollTo({ top: startY, behavior: 'instant' }); } catch (_) { window.scrollTo(0, startY); }
        scanDOM();
        flushMediaBatch();
        return;
      }
      try { window.scrollBy({ top: 680, behavior: 'instant' }); } catch (_) { window.scrollBy(0, 680); }
      scanDOM();
      step++;
      setTimeout(doStep, 380);
    }
    setTimeout(doStep, 900);
  }

  window.__dbPickaxeRescan = function() {
    flushMediaBatch();
    reportedUrls.clear();
    globalDomIndex = 0;
    __autoScrollDone = false;
    window.__dbPickaxeAutoScrollDone = false;
    scanDOM();
    flushMediaBatch();
    syncCookies();
    autoScrollReveal();
  };

  scanDOM();
  flushMediaBatch();
  syncCookies();
  setTimeout(autoScrollReveal, 1200);

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
""";
}
