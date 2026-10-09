import {
    CfxTexture,
    LinearFilter,
    Mesh,
    NearestFilter,
    OrthographicCamera,
    PlaneBufferGeometry,
    RGBAFormat,
    Scene,
    ShaderMaterial,
    UnsignedByteType,
    WebGLRenderTarget,
    WebGLRenderer,
} from './threeExports';
import { computeCropRegion, SELFIE_CROP_BIAS_X, type Orientation } from './crop';

// Live game-view renderer, ported from utk_render (citizenfx/screenshot-basic).
// CfxTexture's isCfxTexture flag makes the patched fork's WebGLTextures emit a
// magic texParameterf sequence that FiveM's CEF GPU layer recognises, binding
// the live game backbuffer as the texture at draw time. Heavy (pulls the three
// fork), so only ever load this module via dynamic import — see index.ts.

const VERTEX_SHADER = `
varying vec2 vUv;

void main() {
    vUv = vec2(uv.x, 1.0 - uv.y);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
`;

const FRAGMENT_SHADER = `
varying vec2 vUv;
uniform sampler2D tDiffuse;

void main() {
    gl_FragColor = texture2D(tDiffuse, vUv);
}
`;

// f_phone (performa): pratinjau 30 fps (dulu 60). Perekam video tetap bisa minta fps sendiri
// lewat setTargetFps. Readback GPU->CPU di tiap frame menahan GPU, jadi separuh frame = separuh beban.
const PUMP_MS = 33;
const MIN_FPS = 1;
const MAX_FPS = 60;
// f_phone (performa): yang dirender & dibaca balik hanya potongan yang tampil di HP, dengan sisi
// terpanjang maksimal segini - bukan seukuran monitor penuh (1920x1080 = 8 MB per frame). Foto
// diambil di 720/1280 px, jadi batas ini tidak menurunkan kualitas foto.
const MAX_TARGET_SIDE = 1280;

export type GameViewMode = 'off' | 'probe' | 'force';

const GAME_VIEW_PLUGIN_TYPE = 'application/x-cfx-game-view';
const OVERLAY_HOST_ATTR = 'data-game-view-overlay';
const PROBE_EVERY_FRAMES = 15;
const BLACK_PROBES_BEFORE_OVERLAY = 3;
const PROBE_SAMPLE_COUNT = 64;
const BLACK_BRIGHTNESS_BELOW = 2;

export class GameRender {
    private readonly renderer: WebGLRenderer;
    private readonly material: ShaderMaterial;
    private sceneRTT:  Scene;
    private cameraRTT: OrthographicCamera;
    private rtTexture: WebGLRenderTarget;
    private canvas: HTMLCanvasElement | null = null;
    private animated = false;
    private pump: ReturnType<typeof setInterval> | null = null;
    private pumpMs = PUMP_MS;
    private pixels: Uint8Array | null = null;
    private image: ImageData | null = null;
    private ctx: CanvasRenderingContext2D | null = null;
    private bufW = 0;
    private bufH = 0;
    /** Ukuran render target sekarang (potongan yang tampil, sudah dibatasi MAX_TARGET_SIDE). */
    private targetW = 1;
    private targetH = 1;
    private frames = 0;
    private zoom = 1;
    private orientation: Orientation = 'portrait';
    private selfie = false;
    private aspect: number | undefined;
    private readonly mode: GameViewMode;
    private blackProbes = 0;
    private overlay: HTMLDivElement | null = null;
    private overlayHost: HTMLElement | null = null;
    private view: HTMLObjectElement | null = null;
    private overlayKey = '';

    constructor(mode: GameViewMode = 'off') {
        this.mode = mode;

        const gameTexture = new CfxTexture();
        gameTexture.needsUpdate = true;

        this.material = new ShaderMaterial({
            uniforms: { tDiffuse: { value: gameTexture } },
            vertexShader: VERTEX_SHADER,
            fragmentShader: FRAGMENT_SHADER,
        });

        this.cameraRTT = this.buildCamera(true);
        this.sceneRTT  = this.buildScene();
        this.rtTexture = this.buildTarget();

        this.renderer = new WebGLRenderer();
        this.renderer.setSize(this.targetW, this.targetH);
        this.renderer.autoClear = false;

        const mount = document.createElement('div');
        mount.id = 'three-game-render';
        mount.style.display = 'none';
        mount.appendChild(this.renderer.domElement);
        document.body.append(mount);

        window.addEventListener('resize', () => this.rebuild(!this.animated));
    }

    renderToTarget(canvas: HTMLCanvasElement) {
        this.rebuild(false);
        this.canvas = canvas;
        this.animated = true;
        this.bufW = 0;
        this.bufH = 0;
        this.blackProbes = 0;
        this.hideOverlay();
        if (this.mode === 'force') this.showOverlay();
        this.startPump();
    }

    setTargetFps(fps: number) {
        const want = Math.round(Math.min(MAX_FPS, Math.max(MIN_FPS, fps || MAX_FPS)));
        const ms = Math.max(1, Math.round(1000 / want));
        if (ms === this.pumpMs) return;
        this.pumpMs = ms;
        if (this.pump !== null) this.startPump();
    }

    framesRendered() {
        return this.frames;
    }

    private startPump() {
        if (this.pump !== null) clearInterval(this.pump);
        this.pump = setInterval(this.animate, this.pumpMs);
    }

    setZoom(zoom: number) {
        this.zoom = zoom > 0 ? zoom : 1;
        if (this.animated) this.rebuild(false);
    }

    setOrientation(orientation: Orientation) {
        this.orientation = orientation;
        if (this.animated) this.rebuild(false);
    }

    setAspect(aspect: number | undefined) {
        const next = aspect && aspect > 0 && Number.isFinite(aspect) ? aspect : undefined;
        if (next === this.aspect) return;
        this.aspect = next;
        if (this.animated) this.rebuild(false);
    }

    // Front (selfie) camera re-centres the ped; rear camera is already centred.
    setSelfie(on: boolean) {
        this.selfie = on;
        if (this.animated) this.rebuild(false);
    }

    stop() {
        this.animated = false;
        this.aspect = undefined;
        this.canvas = null;
        if (this.pump !== null) { clearInterval(this.pump); this.pump = null; }
        this.hideOverlay();
        this.rebuild(true);
    }

    private buildCamera(fullScreen: boolean): OrthographicCamera {
        const w = window.innerWidth;
        const h = window.innerHeight;
        const camera = new OrthographicCamera(w / -2, w / 2, h / 2, h / -2, -10000, 10000);
        camera.position.z = 0;
        if (fullScreen) {
            camera.setViewOffset(w, h, 0, 0, w, h);
        } else {
            const biasX = this.selfie ? SELFIE_CROP_BIAS_X : 0;
            const crop  = computeCropRegion(w, h, this.zoom, this.orientation, biasX, this.aspect);
            camera.setViewOffset(w, h, crop.offsetX, crop.offsetY, crop.width, crop.height);
        }
        return camera;
    }

    private buildScene(): Scene {
        const scene = new Scene();
        const quad = new Mesh(new PlaneBufferGeometry(window.innerWidth, window.innerHeight), this.material);
        quad.position.z = -100;
        scene.add(quad);
        return scene;
    }

    private buildTarget(): WebGLRenderTarget {
        return new WebGLRenderTarget(this.targetW, this.targetH, {
            minFilter: LinearFilter,
            magFilter: NearestFilter,
            format:    RGBAFormat,
            type:      UnsignedByteType,
        });
    }

    /** f_phone: ukuran target = potongan yang tampil, dibatasi MAX_TARGET_SIDE. Idle = 1x1. */
    private sizeTarget(fullScreen: boolean) {
        if (fullScreen) {
            this.targetW = 1;
            this.targetH = 1;
            return;
        }
        const w = Math.max(1, window.innerWidth);
        const h = Math.max(1, window.innerHeight);
        const biasX = this.selfie ? SELFIE_CROP_BIAS_X : 0;
        const crop  = computeCropRegion(w, h, this.zoom, this.orientation, biasX, this.aspect);
        const cw = Math.max(1, crop.width);
        const ch = Math.max(1, crop.height);
        const s  = Math.min(1, MAX_TARGET_SIDE / Math.max(cw, ch));
        this.targetW = Math.max(1, Math.round(cw * s));
        this.targetH = Math.max(1, Math.round(ch * s));
    }

    private rebuild(fullScreen: boolean) {
        this.rtTexture?.dispose();
        this.sizeTarget(fullScreen);
        this.cameraRTT = this.buildCamera(fullScreen);
        this.sceneRTT  = this.buildScene();
        this.rtTexture = this.buildTarget();
        this.renderer.setSize(this.targetW, this.targetH);
    }

    private animate = () => {
        if (!this.animated || !this.canvas) return;

        const w = this.targetW;
        const h = this.targetH;
        if (w <= 1 || h <= 1) return;

        if (this.bufW !== w || this.bufH !== h || !this.pixels || !this.image || !this.ctx) {
            this.bufW = w;
            this.bufH = h;
            const buffer = new ArrayBuffer(w * h * 4);
            this.pixels = new Uint8Array(buffer);
            this.image = new ImageData(new Uint8ClampedArray(buffer), w, h);
            this.canvas.width = w;
            this.canvas.height = h;
            this.ctx = this.canvas.getContext('2d');
            if (!this.ctx) return;
        }

        this.renderer.clear();
        this.renderer.render(this.sceneRTT, this.cameraRTT, this.rtTexture, true);
        this.renderer.readRenderTargetPixels(this.rtTexture, 0, 0, w, h, this.pixels);
        this.ctx.putImageData(this.image, 0, 0);
        this.frames += 1;

        if (this.mode === 'probe' && this.frames % PROBE_EVERY_FRAMES === 0) this.probeFeed(w * h);
        if (this.overlay) this.layoutOverlay();
    };

    private probeFeed(pixelCount: number) {
        if (!this.pixels) return;
        if (!this.readbackIsBlack(this.pixels, pixelCount)) {
            this.blackProbes = 0;
            this.hideOverlay();
            return;
        }
        this.blackProbes += 1;
        if (this.blackProbes >= BLACK_PROBES_BEFORE_OVERLAY) this.showOverlay();
    }

    private readbackIsBlack(pixels: Uint8Array, pixelCount: number): boolean {
        const stride = Math.max(1, Math.floor(pixelCount / PROBE_SAMPLE_COUNT));
        let sum = 0;
        let count = 0;
        for (let i = 0; i < pixelCount && count < PROBE_SAMPLE_COUNT; i += stride) {
            const at = i * 4;
            sum += (pixels[at] + pixels[at + 1] + pixels[at + 2]) / 3;
            count += 1;
        }
        return count > 0 && sum / count < BLACK_BRIGHTNESS_BELOW;
    }

    private showOverlay() {
        if (this.overlay || !this.canvas || !this.canvas.isConnected) return;
        const overlay = document.createElement('div');
        const view = document.createElement('object');
        view.type = GAME_VIEW_PLUGIN_TYPE;
        overlay.appendChild(view);
        this.canvas.after(overlay);
        this.overlayHost = this.canvas.parentElement;
        this.overlayHost?.setAttribute(OVERLAY_HOST_ATTR, '');
        this.overlay = overlay;
        this.view = view;
        this.overlayKey = '';
        this.layoutOverlay();
    }

    private hideOverlay() {
        this.overlay?.remove();
        this.overlayHost?.removeAttribute(OVERLAY_HOST_ATTR);
        this.overlayHost = null;
        this.overlay = null;
        this.view = null;
        this.overlayKey = '';
    }

    private layoutOverlay() {
        const { canvas, overlay, view } = this;
        if (!canvas || !overlay || !view) return;

        const w = window.innerWidth;
        const h = window.innerHeight;
        const biasX = this.selfie ? SELFIE_CROP_BIAS_X : 0;
        const crop = computeCropRegion(w, h, this.zoom, this.orientation, biasX, this.aspect);
        if (crop.width <= 0 || crop.height <= 0) return;

        const key = [canvas.className, canvas.style.cssText, crop.offsetX, crop.offsetY, crop.width, crop.height].join('|');
        if (key === this.overlayKey) return;
        this.overlayKey = key;

        overlay.className = canvas.className;
        overlay.style.cssText = canvas.style.cssText;
        overlay.style.filter = 'none';
        overlay.style.overflow = 'hidden';
        overlay.style.pointerEvents = 'none';

        view.style.cssText = [
            'position:absolute',
            'display:block',
            'pointer-events:none',
            'left:0',
            'top:0',
            'width:100%',
            'height:100%',
            'transform-origin:0 0',
            `transform:translate(${(-crop.offsetX / crop.width) * 100}%,${(-crop.offsetY / crop.height) * 100}%) scale(${w / crop.width},${h / crop.height})`,
        ].join(';');
    }
}
