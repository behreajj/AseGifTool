local ditherOptions <const> = { "BAYER", "FLOYD_STEINBERG", "NONE" }
local fitOptions <const> = { "CIE_LAB", "CIE_XYZ", "LINEAR_RGB", "GAMMA_RGB" }

local defaults <const> = {
    scale = 1,
    fit = "CIE_LAB",
    dither = "FLOYD_STEINBERG",
    dithFac100 = 100,
    useInterlace = false,
    useLoop = true,
    force332 = false,
    applyPixelRatio = true,
}

local dlg <const> = Dialog { title = "Gif Export" }

dlg:file {
    id = "filePath",
    label = "File:",
    focus = true,
    save = true,
    filetypes = { "gif" },
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Scale:",
    value = defaults.scale,
    min = 1,
    max = 10,
    focus = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "dither",
    label = "Dither:",
    option = defaults.dither,
    options = ditherOptions,
    focus = false,
}

dlg:newrow { always = false }

dlg:combobox {
    id = "fit",
    label = "Fit:",
    option = defaults.fit,
    options = fitOptions,
    focus = false,
}

dlg:newrow { always = false }

dlg:slider {
    id = "dithFac100",
    label = "Factor:",
    value = defaults.dithFac100,
    min = 0,
    max = 100,
    focus = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "useInterlace",
    label = "Options:",
    text = "Interlace",
    selected = defaults.useInterlace,
    focus = false,
}

dlg:check {
    id = "useLoop",
    text = "Loop",
    selected = defaults.useLoop,
    focus = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "applyPixelRatio",
    label = "Apply:",
    text = "Pixel Ratio",
    selected = defaults.applyPixelRatio,
    focus = false,
}

dlg:newrow { always = false }

dlg:check {
    id = "force332",
    label = "Palette:",
    text = "RGB332",
    selected = defaults.force332,
    focus = false,
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = false,
    onclick = function()
        local startTime <const> = os.clock()

        local site <const> = app.site
        local srcSprite <const> = site.sprite
        if not srcSprite then return end

        local args <const> = dlg.data
        local filePath <const> = args.filePath --[[@as string]]
        local scale <const> = args.scale
            or defaults.scale --[[@as integer]]
        local dither <const> = args.dither
            or defaults.dither --[[@as string]]
        local fit <const> = args.fit
            or defaults.fit --[[@as string]]
        local dithFac100 <const> = args.dithFac100
            or defaults.dithFac100 --[[@as integer]]
        local useInterlace <const> = args.useInterlace --[[@as boolean]]
        local useLoop <const> = args.useLoop --[[@as boolean]]
        local force332 <const> = args.force332 --[[@as boolean]]
        local applyPixelRatio <const> = args.applyPixelRatio --[[@as boolean]]

        local fileExt <const> = app.fs.fileExtension(filePath):lower()
        if fileExt ~= "gif" then
            app.alert {
                title = "Error",
                text = "Extension is not gif."
            }
            return
        end

        local appPrefs <const> = app.preferences
        local gifPrefs <const> = appPrefs.gif
        local quantizePrefs <const> = appPrefs.quantization

        local oldTool <const> = app.tool
        if oldTool.id == "slice"
            or oldTool.id == "text" then
            app.tool = "hand"
        end

        local pixelRatio <const> = srcSprite.pixelRatio
        local wPixel <const> = math.max(1, math.abs(pixelRatio.w))
        local hPixel <const> = math.max(1, math.abs(pixelRatio.h))

        app.command.DeselectMask()
        local trgSprite <const> = Sprite(srcSprite)
        trgSprite.pixelRatio = Size(1, 1)
        app.sprite = trgSprite
        app.command.DeselectMask()

        local force332Verif <const> = force332
            and trgSprite.colorMode == ColorMode.RGB

        app.command.ChangePixelFormat { ui = false, format = "rgb" }
        app.command.FlattenLayers { visibleOnly = true }
        app.command.LayerFromBackground()

        app.transaction("Set Palette", function()
            if force332Verif then
                local palette <const> = trgSprite.palettes[1]
                palette:resize(256)
                local floor <const> = math.floor

                local k = 0
                while k < 256 do
                    local h <const> = k // 64
                    local m <const> = k - h * 64
                    local i <const> = m // 8
                    local j <const> = m % 8

                    local r <const> = floor((j / 7) * 255 + 0.5)
                    local g <const> = floor((i / 7) * 255 + 0.5)
                    local b <const> = floor((h / 3) * 255 + 0.5)

                    palette:setColor(k, Color { r = r, g = g, b = b, a = 255 })
                    k = k + 1
                end

                palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
            else
                local oldWithAlpha <const> = quantizePrefs.with_alpha
                local oldRgbMapAlg <const> = quantizePrefs.rgbmap_algorithm
                local oldFitCriteria <const> = quantizePrefs.fit_criteria

                quantizePrefs.with_alpha = false
                quantizePrefs.rgbmap_algorithm = 1 -- Table
                quantizePrefs.fit_criteria = 4     -- CIE LAB

                app.command.ColorQuantization {
                    ui = false,
                    withAlpha = false,
                    maxColors = 256,
                    algorithm = 1
                }

                local palette <const> = trgSprite.palettes[1]
                local firstColor <const> = palette:getColor(0)
                if firstColor.rgbaPixel ~= 0 then
                    app.command.ColorQuantization {
                        ui = false,
                        withAlpha = false,
                        maxColors = 255,
                        algorithm = 1
                    }

                    local swatchCount <const> = #palette + 1
                    palette:resize(swatchCount)
                    local i = swatchCount
                    while i > 1 do
                        i = i - 1
                        palette:setColor(i, palette:getColor(i - 1))
                    end
                    palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
                end

                quantizePrefs.with_alpha = oldWithAlpha
                quantizePrefs.rgbmap_algorithm = oldRgbMapAlg
                quantizePrefs.fit_criteria = oldFitCriteria
            end
        end)

        local ditherStr = "none"
        if dither == "BAYER" then
            ditherStr = "ordered"
        elseif dither == "FLOYD_STEINBERG" then
            ditherStr = "error-diffusion"
        end

        local fitStr = "default"
        if fit == "CIE_LAB" then
            fitStr = "cielab"
        elseif fit == "CIE_XYZ" then
            fitStr = "ciexyz"
        elseif fit == "LINEAR_RGB" then
            fitStr = "linearizedRGB"
        elseif fit == "GAMMA_RGB" then
            fitStr = "rgb"
        end

        if applyPixelRatio then
            app.command.SpriteSize {
                ui = false,
                method = "nearest",
                scaleX = wPixel,
                scaleY = hPixel,
            }
        end

        app.command.ChangePixelFormat {
            ui = false,
            fitCriteria = fitStr,
            format = "indexed",
            dithering = ditherStr,
            ditheringFactor = dithFac100 * 0.01,
            rgbmap = "octree",
        }

        app.command.SpriteSize {
            ui = false,
            method = "nearest",
            lockRatio = true,
            scale = scale
        }

        local docPrefs <const> = appPrefs.document(trgSprite)
        local saveCopyPrefs <const> = docPrefs.save_copy
        saveCopyPrefs.apply_pixel_ratio = false
        saveCopyPrefs.for_twitter = false

        local oldShowAlert <const> = gifPrefs.show_alert
        local oldInterlaced <const> = gifPrefs.interlaced
        local oldLoop <const> = gifPrefs.loop
        local oldPreserveOrder <const> = gifPrefs.preserve_palette_order

        gifPrefs.show_alert = false
        gifPrefs.interlaced = useInterlace
        gifPrefs.loop = useLoop
        gifPrefs.preserve_palette_order = false

        local saveSuccess = false
        saveSuccess = trgSprite:saveCopyAs(filePath)

        gifPrefs.show_alert = oldShowAlert
        gifPrefs.interlaced = oldInterlaced
        gifPrefs.loop = oldLoop
        gifPrefs.preserve_palette_order = oldPreserveOrder

        trgSprite:close()
        app.sprite = srcSprite
        app.tool = oldTool

        if saveSuccess then
            local file <const>, err <const> = io.open(filePath, "r+b")
            if err then
                print(err)
                return
            end

            -- Reopen and replace the 87 header with 89.
            -- https://www.w3.org/Graphics/GIF/spec-gif89a.txt
            if file then
                file:write("GIF89a")
                file:close()
            end

            local endTime <const> = os.clock()
            local elapsed <const> = endTime - startTime
            app.alert {
                title = "Success",
                text = {
                    "File saved.",
                    string.format("Elapsed: %.6f", elapsed)
                }
            }
        end
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }