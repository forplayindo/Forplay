local function domainAllowed(host)
    local list = Config.AllowedDomains
    if #list == 0 then return true end
    for i = 1, #list do
        local d = list[i]
        if host == d or host:sub(-(#d + 1)) == '.' .. d then return true end
    end
    return false
end

local LOCAL_EXT = { png = 'image', jpg = 'image', jpeg = 'image', webp = 'image', gif = 'image', mp4 = 'video', webm = 'video' }

---Deteksi jenis media dari URL (dipakai server untuk validasi & client untuk preview).
---File lokal ditulis `images/nama.png` (file ada di folder html/images resource ini).
---@return 'image'|'video'|'youtube'|nil mediaType
---@return string|nil src URL gambar/video, path lokal, atau ID video YouTube
function DetectMedia(url)
    if type(url) ~= 'string' then return end

    -- nama file hanya huruf/angka/_/- supaya tidak bisa keluar folder (../)
    local name, ext = url:match('^images/([%w_%-]+)%.(%w+)$')
    if name and #name <= 64 then
        local mediaType = LOCAL_EXT[ext:lower()]
        if mediaType then return mediaType, url end
        return
    end

    if #url < 10 or #url > Config.MaxUrlLength then return end
    if not url:match('^https?://') or url:find('[%s"\'<>\\`]') then return end

    local host = url:match('^https?://([^/:%?#]+)')
    if not host then return end
    host = host:lower()
    if not domainAllowed(host) then return end

    if host == 'youtu.be' or host == 'youtube.com' or host:sub(-12) == '.youtube.com' then
        local id = url:match('[%?&]v=([%w_%-]+)')
            or url:match('youtu%.be/([%w_%-]+)')
            or url:match('/shorts/([%w_%-]+)')
            or url:match('/embed/([%w_%-]+)')
            or url:match('/live/([%w_%-]+)')
        if id and #id == 11 then return 'youtube', id end
        return
    end

    local path = url:match('^[^%?#]+'):lower()
    if path:match('%.mp4$') or path:match('%.webm$') then return 'video', url end
    return 'image', url
end
