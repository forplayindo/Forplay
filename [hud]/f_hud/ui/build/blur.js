/* ==========================================================================
   0r-hud-v3 · Real "iOS" background blur for FiveM NUI  (performance build)
   --------------------------------------------------------------------------
   Reads the live game frame through FiveM's WebGL game-view hook (same
   technique as citizenfx/screenshot-basic) and blurs it ONLY where HUD
   panels are.  Runs on the GPU inside NUI -> 0 impact on Lua resmon.

   Performance design (for low-end PCs):
   • Every pass is scissored to the panel areas only – pixels outside the
     HUD are never touched (panels cover ~5-8% of the screen).
   • Blur is done at 1/4 – 1/8 resolution.
   • Quality tier is picked by Lua from the REAL game FPS (auto), or by the
     player with /hudblur. Very low FPS -> blur turns itself off.
   • Nothing on screen / HUD hidden / "off" -> render loop fully stopped.
   ========================================================================== */
(function () {
  "use strict";

  // ---------------- quality tiers ----------------
  var TIERS = {
    high:   { fps: 60, ds: 4, passes: 2, spread: 1.5, scan: 250 },
    medium: { fps: 30, ds: 6, passes: 2, spread: 1.2, scan: 400 },
    low:    { fps: 20, ds: 8, passes: 1, spread: 1.5, scan: 600 },
  };
  var LOOK = { saturation: 1.3, brightness: 1.0 };
  var START_TIER = "medium"; // used until Lua sends the real tier
  // ------------------------------------------------

  var SELECTOR = ".gl, #navigation-widget .h-\\[51px\\], [data-blur]";
  var MAX = 24;
  var isGame = !!window.invokeNative;
  var root = document.documentElement;

  if (!isGame && !window.__BLUR_TEST_IMAGE__) return; // plain browser: nothing to blur

  var canvas = document.createElement("canvas");
  canvas.id = "hud-blur-layer";
  canvas.style.cssText = "position:fixed;inset:0;width:100vw;height:100vh;pointer-events:none;z-index:-1;";
  var gl = canvas.getContext("webgl", { antialias: false, depth: false, stencil: false, alpha: true, premultipliedAlpha: true, desynchronized: true, powerPreference: "low-power", failIfMajorPerformanceCaveat: false });
  if (!gl) return;

  // ---------- shaders ----------
  var VS_FULL = "attribute vec2 p;varying vec2 uv;void main(){uv=p*0.5+0.5;gl_Position=vec4(p,0.0,1.0);}";
  // quad covering one panel rect (pixels, GL y-up)
  var VS_RECT = "precision highp float;attribute vec2 p;uniform vec4 r;uniform vec2 res;varying vec2 uv;varying vec2 fp;" +
    "void main(){vec2 q=r.xy+(p*0.5+0.5)*r.zw;fp=q;uv=q/res;gl_Position=vec4(q/res*2.0-1.0,0.0,1.0);}";
  var FS_DOWN = "precision mediump float;varying vec2 uv;uniform sampler2D t;uniform vec2 px;" +
    "void main(){vec4 c=texture2D(t,uv+vec2(-px.x,-px.y))+texture2D(t,uv+vec2(px.x,-px.y))+texture2D(t,uv+vec2(-px.x,px.y))+texture2D(t,uv+vec2(px.x,px.y));gl_FragColor=vec4(c.rgb*0.25,1.0);}";
  var FS_BLUR = "precision mediump float;varying vec2 uv;uniform sampler2D t;uniform vec2 d;" +
    "void main(){vec3 c=texture2D(t,uv).rgb*0.2270270270;" +
    "c+=texture2D(t,uv+d*1.3846153846).rgb*0.3162162162;c+=texture2D(t,uv-d*1.3846153846).rgb*0.3162162162;" +
    "c+=texture2D(t,uv+d*3.2307692308).rgb*0.0702702703;c+=texture2D(t,uv-d*3.2307692308).rgb*0.0702702703;" +
    "gl_FragColor=vec4(c,1.0);}";
  var FS_COMP = "#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\nvarying vec2 uv;varying vec2 fp;uniform sampler2D t;uniform vec4 rf;uniform vec4 c;uniform float sat;uniform float bri;" +
    "float sdb(vec2 p,vec2 b,vec4 k){k.xy=(p.x>0.0)?k.xy:k.zw;k.x=(p.y>0.0)?k.x:k.y;vec2 q=abs(p)-b+k.x;return min(max(q.x,q.y),0.0)+length(max(q,0.0))-k.x;}" +
    "void main(){vec2 h=rf.zw*0.5;float a=clamp(0.5-sdb(fp-(rf.xy+h),h,c),0.0,1.0);if(a<=0.0)discard;" +
    "vec3 col=texture2D(t,uv).rgb;float g=dot(col,vec3(0.299,0.587,0.114));col=mix(vec3(g),col,sat)*bri;gl_FragColor=vec4(col*a,a);}";

  function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); var l = gl.getShaderInfoLog(s); if (l) console.warn("[hud-blur]", l); return s; }
  var broken = false;
  function prog(vs, fs) {
    var p = gl.createProgram();
    gl.attachShader(p, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs));
    gl.bindAttribLocation(p, 0, "p"); gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) { broken = true; console.warn("[hud-blur] shader link failed -> blur disabled:", gl.getProgramInfoLog(p)); }
    return p;
  }
  var pDown = prog(VS_FULL, FS_DOWN), pBlur = prog(VS_FULL, FS_BLUR), pComp = prog(VS_RECT, FS_COMP);
  if (broken) { root.classList.add("hud-lite"); return; } // never draw anything if a shader failed
  function U(p, n) { return gl.getUniformLocation(p, n); }
  var u = {
    downT: U(pDown, "t"), downPx: U(pDown, "px"),
    blurT: U(pBlur, "t"), blurD: U(pBlur, "d"),
    compT: U(pComp, "t"), compR: U(pComp, "r"), compRF: U(pComp, "rf"), compC: U(pComp, "c"), compRes: U(pComp, "res"), sat: U(pComp, "sat"), bri: U(pComp, "bri"),
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
  if (!isGame) { // browser preview only
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, window.__BLUR_TEST_IMAGE__);
  }

  // ---------- state ----------
  var tier = null, T = null, W = 0, H = 0, lw = 0, lh = 0, fb = [], tx = [];
  var checks = 0, rects = [], count = 0, running = false, rafId = 0, scanTimer = 0, last = 0, frameGap = 0;

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
    canvas.width = W; canvas.height = H;
    lw = Math.max(1, Math.round(W / T.ds)); lh = Math.max(1, Math.round(H / T.ds));
    tx.forEach(function (t) { gl.deleteTexture(t); }); fb.forEach(function (f) { gl.deleteFramebuffer(f); });
    var a = makeTarget(), b = makeTarget(); fb = [a[0], b[0]]; tx = [a[1], b[1]];
  }
  window.addEventListener("resize", resize);

  // ---------- panel scan (few times per second, not per frame) ----------
  function rad(v, w, h) { return Math.min(parseFloat(v) || 0, w / 2, h / 2); }
  function scanPanels() {
    var els = document.querySelectorAll(SELECTOR), out = [];
    for (var i = 0; i < els.length && out.length < MAX; i++) {
      var el = els[i], r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2 || r.bottom < 0 || r.top > H || r.right < 0 || r.left > W) continue;
      var cs = getComputedStyle(el);
      if (cs.visibility === "hidden" || parseFloat(cs.opacity) === 0) continue;
      var y = H - r.bottom;
      // low-res scissor box with margin so the blur never samples stale pixels
      var M = Math.ceil(T.passes * 6 * T.spread) + 4;
      var sx = Math.max(0, Math.floor(r.left / T.ds) - M), sy = Math.max(0, Math.floor(y / T.ds) - M);
      var ex = Math.min(lw, Math.ceil(r.right / T.ds) + M), ey = Math.min(lh, Math.ceil((y + r.height) / T.ds) + M);
      out.push({
        r: [r.left, y, r.width, r.height],
        c: [rad(cs.borderTopRightRadius, r.width, r.height), rad(cs.borderBottomRightRadius, r.width, r.height), rad(cs.borderTopLeftRadius, r.width, r.height), rad(cs.borderBottomLeftRadius, r.width, r.height)],
        s: [sx, sy, Math.max(0, ex - sx), Math.max(0, ey - sy)],
      });
    }
    rects = out; count = out.length;
    if (count === 0) clearCanvas();
  }

  function clearCanvas() {
    gl.disable(gl.SCISSOR_TEST);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, W, H);
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
  }

  function eachScissor(fn) {
    for (var i = 0; i < count; i++) { var s = rects[i].s; gl.scissor(s[0], s[1], s[2], s[3]); fn(); }
  }

  // ---------- render ----------
  function draw(ts) {
    if (!running) return;
    rafId = requestAnimationFrame(draw);
    if (ts - last < frameGap || count === 0) return;
    last = ts;
    gl.activeTexture(gl.TEXTURE0);
    gl.enable(gl.SCISSOR_TEST);

    // 1. downsample (panel areas only)
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb[0]); gl.viewport(0, 0, lw, lh);
    gl.useProgram(pDown); gl.uniform1i(u.downT, 0); gl.uniform2f(u.downPx, T.ds * 0.25 / W, T.ds * 0.25 / H);
    gl.bindTexture(gl.TEXTURE_2D, gameTex);
    eachScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });

    // 2. separable blur (panel areas only)
    gl.useProgram(pBlur); gl.uniform1i(u.blurT, 0);
    for (var i = 0; i < T.passes; i++) {
      var s = T.spread * (1 + i * 0.5);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fb[1]); gl.bindTexture(gl.TEXTURE_2D, tx[0]); gl.uniform2f(u.blurD, s / lw, 0);
      eachScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });
      gl.bindFramebuffer(gl.FRAMEBUFFER, fb[0]); gl.bindTexture(gl.TEXTURE_2D, tx[1]); gl.uniform2f(u.blurD, 0, s / lh);
      eachScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });
    }

    // 3. composite: one small quad per panel
    gl.disable(gl.SCISSOR_TEST);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, W, H);
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(pComp); gl.uniform1i(u.compT, 0); gl.bindTexture(gl.TEXTURE_2D, tx[0]);
    gl.uniform2f(u.compRes, W, H); gl.uniform1f(u.sat, LOOK.saturation); gl.uniform1f(u.bri, LOOK.brightness);
    // getError() stalls the GPU, so only check the first frames
    if (checks < 5) { checks++; if (gl.getError() !== gl.NO_ERROR) { console.warn("[hud-blur] GL error -> blur disabled"); setTier("off"); return; } }
    for (var k = 0; k < count; k++) {
      gl.uniform4fv(u.compR, rects[k].r); gl.uniform4fv(u.compRF, rects[k].r); gl.uniform4fv(u.compC, rects[k].c);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
  }

  function stop() {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    if (scanTimer) clearInterval(scanTimer);
    rafId = 0; scanTimer = 0; rects = []; count = 0;
    if (W) clearCanvas();
  }

  function setTier(name) {
    if (name === tier) return;
    tier = name;
    root.classList.remove("hud-blur-on", "hud-lite");
    if (!TIERS[name]) { // "off"
      stop(); canvas.style.display = "none";
      root.classList.add("hud-lite");
      return;
    }
    T = TIERS[name];
    frameGap = 1000 / T.fps - 1;
    canvas.style.display = "";
    root.classList.add("hud-blur-on");
    if (name === "low") root.classList.add("hud-lite");
    resize();
    if (scanTimer) clearInterval(scanTimer);
    scanPanels(); scanTimer = setInterval(scanPanels, T.scan);
    if (!running) { running = true; rafId = requestAnimationFrame(draw); }
  }

  // Lua -> { action: "ui:setBlurQuality", data: "high" | "medium" | "low" | "off" }
  window.addEventListener("message", function (e) {
    var d = e.data;
    if (d && d.action === "ui:setBlurQuality") setTier(String(d.data));
  });
  window.__hudBlurSetTier = setTier; // handy for testing from devtools

  function start() {
    document.body.insertBefore(canvas, document.body.firstChild);
    setTier(START_TIER);
  }
  document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", start) : start();
})();
