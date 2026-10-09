/* ==========================================================================
   f_patch · ox_lib NUI (tampilan redesign)
   1. Lajur bawah tengah: notifikasi selalu di atas teks [E] & progress bar.
   2. Blur "kaca" asli di belakang panel ox_lib, teknik sama dengan f_hud:
      - panel kaca dideteksi otomatis (latar gradasi 158deg milik redesign)
        + kartu notifikasi, dicari ulang hanya saat ada elemen masuk/keluar;
      - posisi & transparansi panel diikuti tiap frame yang digambar, jadi blur
        ikut animasi muncul/hilang dengan halus;
      - hanya area panel, resolusi 1/4-1/8, ikut /hudblur f_hud, mati sendiri
        kalau FPS rendah, dan berhenti total saat tidak ada panel.
   3. Semua font @font-face dibaca di awal, bukan saat pertama tampil.
   ========================================================================== */
(function () {
  "use strict";
  var root = document.documentElement;

  // ---------------- 1. lajur bawah tengah ----------------
  var GAP = 10, BASE = 28;
  var LANE_SELECTOR = [".f-textui", ".f-progress", ".wrapper-progressCircle"];
  var lastBottom = -1;

  function syncLanes() {
    var H = window.innerHeight, top = BASE;
    for (var i = 0; i < LANE_SELECTOR.length; i++) {
      var el = document.querySelector(LANE_SELECTOR[i]);
      if (!el) continue;
      var r = el.getBoundingClientRect();
      if (r.height > 0 && r.top > H * 0.55) top = Math.max(top, H - r.top + GAP);
    }
    top = Math.round(top);
    if (top !== lastBottom) {
      lastBottom = top;
      root.style.setProperty("--f-notify-bottom", top + "px");
    }
  }

  // ---------------- 2. blur ----------------
  var TIERS = {
    high:   { fps: 60, ds: 4, passes: 2, spread: 1.5 },
    medium: { fps: 30, ds: 6, passes: 2, spread: 1.2 },
    low:    { fps: 20, ds: 8, passes: 1, spread: 1.5 },
  };
  var LOOK = { saturation: 1.3, brightness: 1.0 };
  var START_TIER = "off"; // mati sampai f_hud mengirim tier asli (pilih karakter tanpa blur, CPU lemah)
  var EXPLICIT = ".notifications-container > .wrapper";
  var GLASS_MARK = "158deg"; // --glass-sheen redesign
  var SKIP = ".f-radial-menu"; // area yang tidak ikut blur asli
  var MAX = 24, MAX_SCAN = 4000;
  var isGame = !!window.invokeNative;

  var targets = [];
  var wake = function () {};

  function covered(el, list) {
    for (var i = 0; i < list.length; i++) if (list[i] !== el && list[i].contains(el)) return true;
    return false;
  }

  function discover() {
    var found = [];
    var ex = document.querySelectorAll(EXPLICIT);
    for (var i = 0; i < ex.length; i++) found.push(ex[i]);
    var host = document.getElementById("root") || document.body;
    var all = host.getElementsByTagName("*");
    // radial tidak di-blur: 9 tombol berputar + animasi = ukur ulang tiap frame -> berat saat dibuka
    var skip = host.querySelector(SKIP);
    for (var j = 0; j < all.length && j < MAX_SCAN; j++) {
      var el = all[j];
      if (found.indexOf(el) !== -1) continue;
      if (skip && skip.contains(el)) continue;
      if (getComputedStyle(el).backgroundImage.indexOf(GLASS_MARK) !== -1) found.push(el);
    }
    var out = [];
    for (var k = 0; k < found.length && out.length < MAX; k++) if (!covered(found[k], found)) out.push(found[k]);
    targets = out;
  }

  // dipanggil saat elemen masuk/keluar DOM (bukan tiap perubahan teks)
  var discoverTimer = 0, lastDiscover = 0;
  function onMutate(records) {
    var structural = false;
    for (var i = 0; i < records.length && !structural; i++) {
      var r = records[i], n, k;
      for (k = 0; k < r.addedNodes.length; k++) { n = r.addedNodes[k]; if (n.nodeType === 1) { structural = true; break; } }
      for (k = 0; !structural && k < r.removedNodes.length; k++) { n = r.removedNodes[k]; if (n.nodeType === 1) { structural = true; break; } }
    }
    if (!structural) return;
    syncLanes();
    if (discoverTimer) return;
    var wait = Math.max(0, 120 - (Date.now() - lastDiscover)); // maksimal ~8x per detik
    discoverTimer = setTimeout(function () {
      discoverTimer = 0; lastDiscover = Date.now();
      discover();
      wake();
    }, wait);
  }

  function startBlur() {
    if (!isGame) return;

    var canvas = document.createElement("canvas");
    canvas.id = "f-blur-layer";
    canvas.style.cssText = "position:fixed;inset:0;width:100vw;height:100vh;pointer-events:none;z-index:-1;";
    var gl = canvas.getContext("webgl", { antialias: false, depth: false, stencil: false, alpha: true, premultipliedAlpha: true, desynchronized: true, powerPreference: "low-power", failIfMajorPerformanceCaveat: false });
    if (!gl) return;

    var VS_FULL = "attribute vec2 p;varying vec2 uv;void main(){uv=p*0.5+0.5;gl_Position=vec4(p,0.0,1.0);}";
    var VS_RECT = "precision highp float;attribute vec2 p;uniform vec4 r;uniform vec2 res;varying vec2 uv;varying vec2 fp;" +
      "void main(){vec2 q=r.xy+(p*0.5+0.5)*r.zw;fp=q;uv=q/res;gl_Position=vec4(q/res*2.0-1.0,0.0,1.0);}";
    var FS_DOWN = "precision mediump float;varying vec2 uv;uniform sampler2D t;uniform vec2 px;" +
      "void main(){vec4 c=texture2D(t,uv+vec2(-px.x,-px.y))+texture2D(t,uv+vec2(px.x,-px.y))+texture2D(t,uv+vec2(-px.x,px.y))+texture2D(t,uv+vec2(px.x,px.y));gl_FragColor=vec4(c.rgb*0.25,1.0);}";
    var FS_BLUR = "precision mediump float;varying vec2 uv;uniform sampler2D t;uniform vec2 d;" +
      "void main(){vec3 c=texture2D(t,uv).rgb*0.2270270270;" +
      "c+=texture2D(t,uv+d*1.3846153846).rgb*0.3162162162;c+=texture2D(t,uv-d*1.3846153846).rgb*0.3162162162;" +
      "c+=texture2D(t,uv+d*3.2307692308).rgb*0.0702702703;c+=texture2D(t,uv-d*3.2307692308).rgb*0.0702702703;" +
      "gl_FragColor=vec4(c,1.0);}";
    var FS_COMP = "#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\nvarying vec2 uv;varying vec2 fp;uniform sampler2D t;uniform vec4 rf;uniform vec4 c;uniform float sat;uniform float bri;uniform float op;" +
      "float sdb(vec2 p,vec2 b,vec4 k){k.xy=(p.x>0.0)?k.xy:k.zw;k.x=(p.y>0.0)?k.x:k.y;vec2 q=abs(p)-b+k.x;return min(max(q.x,q.y),0.0)+length(max(q,0.0))-k.x;}" +
      "void main(){vec2 h=rf.zw*0.5;float a=clamp(0.5-sdb(fp-(rf.xy+h),h,c),0.0,1.0)*op;if(a<=0.0)discard;" +
      "vec3 col=texture2D(t,uv).rgb;float g=dot(col,vec3(0.299,0.587,0.114));col=mix(vec3(g),col,sat)*bri;gl_FragColor=vec4(col*a,a);}";

    var broken = false;
    function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; }
    function prog(vs, fs) {
      var p = gl.createProgram();
      gl.attachShader(p, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs));
      gl.bindAttribLocation(p, 0, "p"); gl.linkProgram(p);
      if (!gl.getProgramParameter(p, gl.LINK_STATUS)) broken = true;
      return p;
    }
    var pDown = prog(VS_FULL, FS_DOWN), pBlur = prog(VS_FULL, FS_BLUR), pComp = prog(VS_RECT, FS_COMP);
    if (broken) { root.classList.add("hud-lite"); return; }
    function U(p, n) { return gl.getUniformLocation(p, n); }
    var u = {
      downT: U(pDown, "t"), downPx: U(pDown, "px"),
      blurT: U(pBlur, "t"), blurD: U(pBlur, "d"),
      compT: U(pComp, "t"), compR: U(pComp, "r"), compRF: U(pComp, "rf"), compC: U(pComp, "c"), compRes: U(pComp, "res"),
      sat: U(pComp, "sat"), bri: U(pComp, "bri"), op: U(pComp, "op"),
    };

    var vb = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vb);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

    // tekstur tampilan game (hook WebGL FiveM, sama seperti screenshot-basic)
    var gameTex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, gameTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    var tier = null, T = null, W = 0, H = 0, lw = 0, lh = 0, fb = [], tx = [];
    var checks = 0, rects = [], count = 0, enabled = false, rafId = 0, last = 0, frameGap = 0, drawn = false;

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
    window.addEventListener("resize", function () { resize(); syncLanes(); });

    // radius sudut, termasuk nilai persen (border-radius: 50% = lingkaran)
    function rad(v, w, h) {
      var n = parseFloat(v) || 0;
      if (String(v).indexOf("%") !== -1) n = n / 100 * Math.min(w, h);
      return Math.min(n, w / 2, h / 2);
    }
    // transparansi efektif: elemen + beberapa induk (animasi framer-motion ada di induk)
    function opacityOf(el) {
      var op = 1, depth = 0;
      while (el && el !== document.body && depth < 6) {
        op *= parseFloat(getComputedStyle(el).opacity);
        if (op < 0.01) return 0;
        el = el.parentElement; depth++;
      }
      return op;
    }

    function measure() {
      var out = [], alive = [];
      var M = Math.ceil(T.passes * 6 * T.spread) + 4;
      for (var i = 0; i < targets.length; i++) {
        var el = targets[i];
        if (!el.isConnected) continue;
        alive.push(el);
        var r = el.getBoundingClientRect();
        if (r.width < 2 || r.height < 2 || r.bottom < 0 || r.top > H || r.right < 0 || r.left > W) continue;
        var cs = getComputedStyle(el);
        if (cs.visibility === "hidden") continue;
        var op = opacityOf(el);
        if (op <= 0) continue;
        var y = H - r.bottom;
        var sx = Math.max(0, Math.floor(r.left / T.ds) - M), sy = Math.max(0, Math.floor(y / T.ds) - M);
        var ex = Math.min(lw, Math.ceil(r.right / T.ds) + M), ey = Math.min(lh, Math.ceil((y + r.height) / T.ds) + M);
        out.push({
          r: [r.left, y, r.width, r.height],
          c: [rad(cs.borderTopRightRadius, r.width, r.height), rad(cs.borderBottomRightRadius, r.width, r.height), rad(cs.borderTopLeftRadius, r.width, r.height), rad(cs.borderBottomLeftRadius, r.width, r.height)],
          s: [sx, sy, Math.max(0, ex - sx), Math.max(0, ey - sy)],
          op: op,
        });
      }
      targets = alive;
      rects = out; count = out.length;
    }

    function clearCanvas() {
      gl.disable(gl.SCISSOR_TEST);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, W, H);
      gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
    }
    function eachScissor(fn) {
      for (var i = 0; i < count; i++) { var s = rects[i].s; gl.scissor(s[0], s[1], s[2], s[3]); fn(); }
    }

    function draw(ts) {
      rafId = 0;
      if (!enabled) return;
      if (!targets.length) { // tidak ada panel: hapus sisa blur lalu berhenti total
        if (drawn) { clearCanvas(); drawn = false; }
        return;
      }
      rafId = requestAnimationFrame(draw);
      if (ts - last < frameGap) return;
      last = ts;

      measure();
      syncLanes();
      if (count === 0) { if (drawn) { clearCanvas(); drawn = false; } return; }

      gl.activeTexture(gl.TEXTURE0);
      gl.enable(gl.SCISSOR_TEST);

      gl.bindFramebuffer(gl.FRAMEBUFFER, fb[0]); gl.viewport(0, 0, lw, lh);
      gl.useProgram(pDown); gl.uniform1i(u.downT, 0); gl.uniform2f(u.downPx, T.ds * 0.25 / W, T.ds * 0.25 / H);
      gl.bindTexture(gl.TEXTURE_2D, gameTex);
      eachScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });

      gl.useProgram(pBlur); gl.uniform1i(u.blurT, 0);
      for (var i = 0; i < T.passes; i++) {
        var s = T.spread * (1 + i * 0.5);
        gl.bindFramebuffer(gl.FRAMEBUFFER, fb[1]); gl.bindTexture(gl.TEXTURE_2D, tx[0]); gl.uniform2f(u.blurD, s / lw, 0);
        eachScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });
        gl.bindFramebuffer(gl.FRAMEBUFFER, fb[0]); gl.bindTexture(gl.TEXTURE_2D, tx[1]); gl.uniform2f(u.blurD, 0, s / lh);
        eachScissor(function () { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); });
      }

      gl.disable(gl.SCISSOR_TEST);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, W, H);
      gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
      gl.useProgram(pComp); gl.uniform1i(u.compT, 0); gl.bindTexture(gl.TEXTURE_2D, tx[0]);
      gl.uniform2f(u.compRes, W, H); gl.uniform1f(u.sat, LOOK.saturation); gl.uniform1f(u.bri, LOOK.brightness);
      if (checks < 5) { checks++; if (gl.getError() !== gl.NO_ERROR) { setTier("off"); return; } }
      for (var k = 0; k < count; k++) {
        gl.uniform4fv(u.compR, rects[k].r); gl.uniform4fv(u.compRF, rects[k].r); gl.uniform4fv(u.compC, rects[k].c);
        gl.uniform1f(u.op, rects[k].op);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      }
      drawn = true;
    }

    wake = function () {
      if (enabled && !rafId && targets.length) rafId = requestAnimationFrame(draw);
    };

    function setTier(name) {
      if (name === tier) return;
      tier = name;
      root.classList.remove("hud-blur-on", "hud-lite");
      if (!TIERS[name]) { // "off"
        enabled = false;
        if (rafId) cancelAnimationFrame(rafId);
        rafId = 0;
        if (W) clearCanvas();
        drawn = false;
        canvas.style.display = "none";
        root.classList.add("hud-lite");
        return;
      }
      T = TIERS[name];
      frameGap = 1000 / T.fps - 1;
      canvas.style.display = "";
      root.classList.add("hud-blur-on");
      resize();
      enabled = true;
      wake();
    }

    // Lua (resource/interface/client/f_blur.lua) -> { action: "ui:setBlurQuality", data: "high" | "medium" | "low" | "off" }
    window.addEventListener("message", function (e) {
      var d = e.data;
      if (d && d.action === "ui:setBlurQuality") setTier(String(d.data));
    });

    document.body.insertBefore(canvas, document.body.firstChild);
    setTier(START_TIER);
  }

  // ---------------- 3. font siap sejak awal ----------------
  // @font-face redesign memakai font-display:block dan baru dibaca saat pertama dipakai,
  // jadi radial/notifikasi pertama sempat tertahan (teks disembunyikan) saat NUI masih sibuk join.
  function preloadFonts() {
    if (!document.fonts) return;
    document.fonts.forEach(function (face) {
      if (face.status === "unloaded") face.load().catch(function () {});
    });
  }

  function start() {
    preloadFonts();
    window.addEventListener("load", preloadFonts); // stylesheet modul bisa terpasang setelah start()
    startBlur();
    new MutationObserver(onMutate).observe(document.body, { childList: true, subtree: true });
    discover();
    syncLanes();
    wake();
  }
  document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", start) : start();
})();
