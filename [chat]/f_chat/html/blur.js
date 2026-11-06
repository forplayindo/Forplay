/* ==========================================================================
   f_chat · Real "iOS" background blur (same engine as 0r-hud-v3)
   --------------------------------------------------------------------------
   Reads the live game frame through FiveM's WebGL game-view hook, blurs it
   at low resolution and draws it ONLY behind chat surfaces (messages,
   composer, tabs, open popovers). Follows scrolling, clipping of the log,
   the log's top/bottom fade and the chat's idle fade-out.
   GPU only -> 0 impact on Lua resmon. Loop idles when the chat is hidden.
   ========================================================================== */
(function () {
  "use strict";

  var TIERS = {
    high:   { fps: 60, ds: 4, passes: 2, spread: 1.5, scan: 500, cs: 1 },
    medium: { fps: 30, ds: 6, passes: 2, spread: 1.2, scan: 700, cs: 0.75 },
    low:    { fps: 20, ds: 8, passes: 1, spread: 1.5, scan: 900, cs: 0.5 },
  };
  var LOOK = { saturation: 1.3, brightness: 1.0 };
  var START_TIER = "off"; // mati sampai Lua mengirim tier (loading screen tanpa blur)

  var MAX = 32;
  var isGame = !!window.invokeNative;
  var root = document.documentElement;
  if (!isGame && !window.__BLUR_TEST_IMAGE__) return;

  var chat = document.getElementById("chat");
  var log = document.getElementById("log");
  if (!chat || !log) return;

  var canvas = document.createElement("canvas");
  canvas.id = "nx-blur-layer";
  canvas.style.cssText = "position:fixed;inset:0;width:100vw;height:100vh;pointer-events:none;z-index:-1;";
  var gl = canvas.getContext("webgl", { antialias: false, depth: false, stencil: false, alpha: true, premultipliedAlpha: true, desynchronized: true, powerPreference: "low-power", failIfMajorPerformanceCaveat: false });
  if (!gl) return;

  // ---------- shaders (VS and FS never share a uniform name -> no precision mismatch) ----------
  var FS_HEAD = "#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\n";
  var VS_FULL = "attribute vec2 p;varying vec2 uv;void main(){uv=p*0.5+0.5;gl_Position=vec4(p,0.0,1.0);}";
  var VS_RECT = "precision highp float;attribute vec2 p;uniform vec4 r;uniform vec2 res;varying vec2 uv;varying vec2 fp;" +
    "void main(){vec2 q=r.xy+(p*0.5+0.5)*r.zw;fp=q;uv=q/res;gl_Position=vec4(q/res*2.0-1.0,0.0,1.0);}";
  var FS_DOWN = FS_HEAD + "varying vec2 uv;uniform sampler2D t;uniform vec2 px;" +
    "void main(){vec4 c=texture2D(t,uv+vec2(-px.x,-px.y))+texture2D(t,uv+vec2(px.x,-px.y))+texture2D(t,uv+vec2(-px.x,px.y))+texture2D(t,uv+vec2(px.x,px.y));gl_FragColor=vec4(c.rgb*0.25,1.0);}";
  var FS_BLUR = FS_HEAD + "varying vec2 uv;uniform sampler2D t;uniform vec2 d;" +
    "void main(){vec3 c=texture2D(t,uv).rgb*0.2270270270;" +
    "c+=texture2D(t,uv+d*1.3846153846).rgb*0.3162162162;c+=texture2D(t,uv-d*1.3846153846).rgb*0.3162162162;" +
    "c+=texture2D(t,uv+d*3.2307692308).rgb*0.0702702703;c+=texture2D(t,uv-d*3.2307692308).rgb*0.0702702703;" +
    "gl_FragColor=vec4(c,1.0);}";
  // rf = panel rect, c = corner radii, fz = (clipTopY, clipBottomY, fadeTop, fadeBottom) in GL pixels, op = opacity
  var FS_COMP = FS_HEAD + "varying vec2 uv;varying vec2 fp;uniform sampler2D t;uniform vec4 rf;uniform vec4 c;uniform vec4 fz;uniform float op;uniform float sat;uniform float bri;" +
    "float sdb(vec2 p,vec2 b,vec4 k){k.xy=(p.x>0.0)?k.xy:k.zw;k.x=(p.y>0.0)?k.x:k.y;vec2 q=abs(p)-b+k.x;return min(max(q.x,q.y),0.0)+length(max(q,0.0))-k.x;}" +
    "void main(){vec2 h=rf.zw*0.5;float a=clamp(0.5-sdb(fp-(rf.xy+h),h,c),0.0,1.0);" +
    "if(fz.z>0.0)a*=clamp((fz.x-fp.y)/fz.z,0.0,1.0);if(fz.w>0.0)a*=clamp((fp.y-fz.y)/fz.w,0.0,1.0);a*=op;" +
    "if(a<=0.0)discard;vec3 col=texture2D(t,uv).rgb;float g=dot(col,vec3(0.299,0.587,0.114));col=mix(vec3(g),col,sat)*bri;gl_FragColor=vec4(col*a,a);}";

  var broken = false;
  function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); var l = gl.getShaderInfoLog(s); if (l) console.warn("[nx-blur]", l); return s; }
  function prog(vs, fs) {
    var p = gl.createProgram();
    gl.attachShader(p, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs));
    gl.bindAttribLocation(p, 0, "p"); gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) { broken = true; console.warn("[nx-blur] shader link failed -> blur disabled:", gl.getProgramInfoLog(p)); }
    return p;
  }
  var pDown = prog(VS_FULL, FS_DOWN), pBlur = prog(VS_FULL, FS_BLUR), pComp = prog(VS_RECT, FS_COMP);
  if (broken) { root.classList.add("nx-lite"); return; }
  function U(p, n) { return gl.getUniformLocation(p, n); }
  var u = {
    downT: U(pDown, "t"), downPx: U(pDown, "px"), blurT: U(pBlur, "t"), blurD: U(pBlur, "d"),
    compT: U(pComp, "t"), r: U(pComp, "r"), res: U(pComp, "res"), rf: U(pComp, "rf"), c: U(pComp, "c"), fz: U(pComp, "fz"), op: U(pComp, "op"), sat: U(pComp, "sat"), bri: U(pComp, "bri"),
  };

  var vb = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, vb);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

  // ---------- game view texture (FiveM hook) ----------
  var gameTex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, gameTex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  if (isGame) {
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  }
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  if (!isGame) {
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, window.__BLUR_TEST_IMAGE__);
  }

  // ---------- state ----------
  var tier = null, T = null, W = 0, H = 0, lw = 0, lh = 0, fb = [], tx = [];
  var checks = 0, rects = [], count = 0, running = false, rafId = 0, scanTimer = 0, last = 0, frameGap = 0, burstUntil = 0;

  function makeTarget() {
    var t = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, lw, lh, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    var f = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, f);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, t, 0);
    return [f, t];
  }
  function resize() {
    if (!T) return;
    W = Math.max(1, window.innerWidth); H = Math.max(1, window.innerHeight);
    canvas.width = Math.max(1, Math.round(W * T.cs)); canvas.height = Math.max(1, Math.round(H * T.cs)); // kanvas komposit lebih kecil (cs), koordinat tetap px layar
    lw = Math.max(1, Math.round(W / T.ds)); lh = Math.max(1, Math.round(H / T.ds));
    tx.forEach(function (t) { gl.deleteTexture(t); }); fb.forEach(function (f) { gl.deleteFramebuffer(f); });
    var a = makeTarget(), b = makeTarget(); fb = [a[0], b[0]]; tx = [a[1], b[1]];
  }
  window.addEventListener("resize", function () { resize(); burst(200); });

  // ---------- which surfaces get blur ----------
  function rad(v, w, h) { return Math.min(parseFloat(v) || 0, w / 2, h / 2); }
  function push(out, el, clip, fadeTop, fadeBottom, op) {
    var r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return;
    // visible part after clipping (CSS pixels, y-down)
    var L = Math.max(r.left, clip.left, 0), R = Math.min(r.right, clip.right, W);
    var Tp = Math.max(r.top, clip.top, 0), B = Math.min(r.bottom, clip.bottom, H);
    if (R - L < 1 || B - Tp < 1) return;
    var cs = getComputedStyle(el);
    if (cs.visibility === "hidden") return;
    op *= parseFloat(cs.opacity);
    if (op <= 0.01) return;
    var gy = H - r.bottom, M = Math.ceil(T.passes * 6 * T.spread) + 4;
    var cy0 = H - B, cy1 = H - Tp; // clipped box in GL y-up
    out.push({
      r: [r.left, gy, r.width, r.height],
      c: [rad(cs.borderTopRightRadius, r.width, r.height), rad(cs.borderBottomRightRadius, r.width, r.height), rad(cs.borderTopLeftRadius, r.width, r.height), rad(cs.borderBottomLeftRadius, r.width, r.height)],
      fz: [H - clip.top, H - clip.bottom, fadeTop, fadeBottom],
      op: op,
      sc: [Math.floor(L), Math.floor(cy0), Math.ceil(R - L), Math.ceil(cy1 - cy0)], // full-res scissor
      s: (function () { // low-res scissor with margin
        var sx = Math.max(0, Math.floor(L / T.ds) - M), sy = Math.max(0, Math.floor(cy0 / T.ds) - M);
        var ex = Math.min(lw, Math.ceil(R / T.ds) + M), ey = Math.min(lh, Math.ceil(cy1 / T.ds) + M);
        return [sx, sy, Math.max(0, ex - sx), Math.max(0, ey - sy)];
      })(),
    });
  }

  var SCREEN = { left: 0, top: 0, right: 1e5, bottom: 1e5 };
  function scanPanels() {
    var out = [];
    if (T && chat.dataset.hidden !== "true" && chat.dataset.idle !== "true") {
      var op = parseFloat(getComputedStyle(chat).opacity);
      if (op > 0.01) {
        // messages: clipped by the log box + its CSS mask fade
        var lr = log.getBoundingClientRect();
        var fadeTop = log.dataset.scroll === "true" ? 26 : 0, fadeBottom = 22;
        var msgs = log.children;
        for (var i = msgs.length - 1; i >= 0 && out.length < MAX - 8; i--) { // newest first
          var m = msgs[i];
          var mr = m.getBoundingClientRect();
          if (mr.bottom < lr.top) break;       // everything above is scrolled out
          if (mr.top > lr.bottom) continue;
          push(out, m, lr, fadeTop, fadeBottom, op);
        }
        var others = chat.querySelectorAll(".tab-btn, .chip, #composer, .pop[data-on='true']");
        for (var k = 0; k < others.length && out.length < MAX; k++) push(out, others[k], SCREEN, 0, 0, op);
      }
    }
    rects = out; count = out.length;
    if (count === 0) clearCanvas();
  }

  // re-scan right away on anything that moves the chat, then for a short "burst"
  function burst(ms) { burstUntil = Math.max(burstUntil, performance.now() + ms); if (running && T) scanPanels(); }
  log.addEventListener("scroll", function () { burst(120); }, { passive: true });
  new MutationObserver(function () { burst(450); }).observe(chat, {
    subtree: true, childList: true, attributes: true,
    attributeFilter: ["data-open", "data-idle", "data-hidden", "data-on", "data-position", "data-density", "data-corners", "data-scroll", "style"],
  });

  function clearCanvas() {
    if (!W) return;
    gl.disable(gl.SCISSOR_TEST);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
  }
  function eachLowScissor(fn) { for (var i = 0; i < count; i++) { var s = rects[i].s; gl.scissor(s[0], s[1], s[2], s[3]); fn(); } }

  // ---------- render ----------
  function draw(ts) {
    if (!running) return;
    rafId = requestAnimationFrame(draw);
    if (ts - last < frameGap) return;
    last = ts;
    if (ts < burstUntil) scanPanels();  // follow fades / scrolling / new messages smoothly
    if (count === 0) return;

    gl.activeTexture(gl.TEXTURE0);
    gl.enable(gl.SCISSOR_TEST);

    gl.bindFramebuffer(gl.FRAMEBUFFER, fb[0]); gl.viewport(0, 0, lw, lh);
    gl.useProgram(pDown); gl.uniform1i(u.downT, 0); gl.uniform2f(u.downPx, T.ds * 0.25 / W, T.ds * 0.25 / H);
    gl.bindTexture(gl.TEXTURE_2D, gameTex);
    eachLowScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });

    gl.useProgram(pBlur); gl.uniform1i(u.blurT, 0);
    for (var i = 0; i < T.passes; i++) {
      var s = T.spread * (1 + i * 0.5);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fb[1]); gl.bindTexture(gl.TEXTURE_2D, tx[0]); gl.uniform2f(u.blurD, s / lw, 0);
      eachLowScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });
      gl.bindFramebuffer(gl.FRAMEBUFFER, fb[0]); gl.bindTexture(gl.TEXTURE_2D, tx[1]); gl.uniform2f(u.blurD, 0, s / lh);
      eachLowScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });
    }

    gl.disable(gl.SCISSOR_TEST);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.enable(gl.SCISSOR_TEST);
    gl.useProgram(pComp); gl.uniform1i(u.compT, 0); gl.bindTexture(gl.TEXTURE_2D, tx[0]);
    gl.uniform2f(u.res, W, H); gl.uniform1f(u.sat, LOOK.saturation); gl.uniform1f(u.bri, LOOK.brightness);
    if (checks < 5) { checks++; if (gl.getError() !== gl.NO_ERROR) { console.warn("[nx-blur] GL error -> blur disabled"); setTier("off"); return; } }
    for (var k = 0; k < count; k++) {
      var q = rects[k];
      var sk = T.cs; gl.scissor(Math.floor(q.sc[0] * sk), Math.floor(q.sc[1] * sk), Math.ceil(q.sc[2] * sk) + 1, Math.ceil(q.sc[3] * sk) + 1);
      gl.uniform4fv(u.r, q.r); gl.uniform4fv(u.rf, q.r); gl.uniform4fv(u.c, q.c); gl.uniform4fv(u.fz, q.fz); gl.uniform1f(u.op, q.op);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
    gl.disable(gl.SCISSOR_TEST);
  }

  function stop() {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    if (scanTimer) clearInterval(scanTimer);
    rafId = 0; scanTimer = 0; rects = []; count = 0;
    clearCanvas();
  }

  function setTier(name) {
    if (name === tier) return;
    tier = name;
    root.classList.remove("nx-blur-on", "nx-lite");
    if (!TIERS[name]) { stop(); canvas.style.display = "none"; root.classList.add("nx-lite"); return; }
    T = TIERS[name];
    frameGap = 1000 / T.fps - 1;
    canvas.style.display = "";
    root.classList.add("nx-blur-on");
    if (name === "low") root.classList.add("nx-lite");
    resize();
    if (scanTimer) clearInterval(scanTimer);
    scanPanels(); scanTimer = setInterval(scanPanels, T.scan);
    if (!running) { running = true; rafId = requestAnimationFrame(draw); }
  }

  // Lua -> { action: "blurQuality", data: "high" | "medium" | "low" | "off" }
  window.addEventListener("message", function (e) {
    var d = e.data;
    if (d && d.action === "blurQuality") setTier(String(d.data));
  });
  window.__nxBlurSetTier = setTier;

  function start() { document.body.insertBefore(canvas, document.body.firstChild); setTier(START_TIER); }
  document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", start) : start();
})();
