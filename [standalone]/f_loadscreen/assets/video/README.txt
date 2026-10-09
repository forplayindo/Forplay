BACKGROUND VIDEO
================================================================================

Two ways to give the loading screen a video, and the difference matters.


1. STREAM IT FROM A URL  (recommended for anything big)
--------------------------------------------------------------------------------

Put the file on any web host — your own web server, a CDN, object storage — and
paste the direct link into config.js:

    video: {
        sources: [ 'https://cdn.example.com/loading.webm' ]
    }

The browser streams it while the loading screen is already on screen: playback
starts on the first buffered seconds, not the last byte. Nothing is added to
the resource, nothing is added to the connect download, and swapping the video
later needs no resource restart.

Any host that serves the file over https with a video/webm or video/mp4 content
type works. It does not have to support byte ranges, though it should if you
want players to be able to seek — a loading screen never seeks.


2. PACK IT INTO THE RESOURCE
--------------------------------------------------------------------------------

Drop the file in this folder and list the path:

    video: { sources: [ 'assets/video/loading.webm' ] }

The manifest already packs .webm, .mp4, .mkv, .m4v and .ogv — no fxmanifest.lua
edit needed. A container the manifest does not pack is not shipped to the
client at all, so the request for it answers 404 and the source is skipped.

Be aware what this costs: a packed file is part of the resource, so every
player downloads ALL of it during the connect handshake, BEFORE the loading
screen they are waiting on can appear. A 30 MB background makes the join 30 MB
heavier for everyone with a cold cache. Fine for a short, small clip; wasteful
for anything else.


FORMAT
--------------------------------------------------------------------------------

Prefer .webm (VP9). Every Chromium build can decode it, including the one
inside FiveM; H.264 in .mp4 depends on how that build was compiled.

.mkv works too. Matroska is the container WebM is a profile of, and the same
demuxer reads both, so an .mkv holding VP8, VP9 or H.264 plays. What decides it
is the codec inside, not the extension: HEVC (H.265), AV1, AC-3 and DTS do not
decode, and an .mkv built around one of those is skipped like any other dead
source. The player then tries the .webm and the .mp4 of the same name, so
keeping a converted copy next to the original costs nothing.

Re-wrapping an .mkv that already holds H.264 is instant and lossless — no
re-encode, so the quality is untouched:

    ffmpeg -i loading.mkv -c copy loading.mp4

Re-encoding to VP9 is the safest possible source, and the slowest:

    ffmpeg -i loading.mkv -c:v libvpx-vp9 -crf 34 -b:v 0 -an loading.webm

Dropping the audio (-an) is worth doing either way: the video is muted, so
every byte of its audio track is downloaded and thrown away.

.avi, .wmv, .flv, .mpg, .mov and .m2ts never play — a source in one of those is
looked up as the .webm and .mp4 of the same name instead.

If a video does not appear, the F8 console names the file and the reason: a
`video source failed` line with a media error code, or `video timed out`.


NOT SHIPPING A VIDEO AT ALL
--------------------------------------------------------------------------------

Fine. The player tries each source in order and falls back to the image layer
and then the gradient background, so an empty folder costs you the video and
nothing else.
