const banner = document.getElementById('banner')
const minleft = document.getElementById('minleft')

// skala sama dengan panel info f_hud (tinggi layar / 1080, 0.85–2)
function rescale() {
    const sc = Math.min(2, Math.max(0.85, window.innerHeight / 1080))
    document.documentElement.style.setProperty('--sc', sc)
}
rescale()
window.addEventListener('resize', rescale)

window.addEventListener('message', (event) => {
    const data = event.data

    switch (data.type) {
        case 'show':
            banner.classList.toggle('show', !!data.show)
            break

        case 'update':
            minleft.textContent = data.minleft
            break

        case 'pause':
            banner.style.visibility = data.paused ? 'hidden' : ''
            break
    }
})
