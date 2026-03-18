--@name BODYCAM
--@shared
--@owneronly


if SERVER then
    --[[
    ---@type Player
    local OWNER = owner()
    OWNER:setWalkSpeed(150)
    OWNER:setRunSpeed(300)

    hook.add("Think", "", function()
        local velo = OWNER:getVelocity():setZ(0)
        if OWNER:isOnGround() then
            OWNER:setVelocity(velo / 40)
        end
    end)]]
else
    ---@type Player
    local OWNER = player()
    enableHud(nil, true)
    local current = OWNER:getEyeAngles()
    local slopeOnMove = 0
    local targetOffset = Angle()
    local currentOffset = Angle()
    local velocityZ = 0
    local walkAnimation = Angle()
    local walkAnimationStep = 0
    local walkAnimationMultiplier = 1

    timer.create("randomAngles", 0.6, 0, function()
        local random = function() return math.rand(-20, 20) end
        targetOffset = Angle(random(), random(), random())
    end)

    local function walkAnimationFunc()
        local isCrouching = OWNER:isCrouching() and 1.5 or 1
        local isOnFloor = OWNER:isOnGround() and 1 or 0.1
        local length = OWNER:getVelocity():getLength() * isCrouching * isOnFloor
        if length > 5 then
            local delta = game.getTickInterval()
            walkAnimation = Angle(
               math.cos(math.rad(walkAnimationStep * (180 + math.rand(-5, 5)))),
               math.sin(math.rad(walkAnimationStep * (90 + math.rand(-5, 5)))),
               math.sin(math.rad(walkAnimationStep * (-90 + math.rand(-5, 5))))
            ) * (length / 5 * delta)
            walkAnimationStep = walkAnimationStep + 0.2 * walkAnimationMultiplier * (length / 20 * delta)
            if walkAnimationStep >= 1 or walkAnimationStep <= -1 then
                walkAnimationMultiplier = -walkAnimationMultiplier
            end
        end
    end


    local function pushMask(mask)
        render.clearStencil()
        render.setStencilEnable(true)

        render.setStencilWriteMask(1)
        render.setStencilTestMask(1)

        render.setStencilFailOperation(STENCIL.REPLACE)
        render.setStencilPassOperation(STENCIL.ZERO)
        render.setStencilZFailOperation(STENCIL.ZERO)
        render.setStencilCompareFunction(STENCIL.NEVER)
        render.setStencilReferenceValue(1)

        mask()

        render.setStencilFailOperation(STENCIL.ZERO)
        render.setStencilPassOperation(STENCIL.REPLACE)
        render.setStencilZFailOperation(STENCIL.ZERO)
        render.setStencilCompareFunction(STENCIL.EQUAL)
        render.setStencilReferenceValue(0)
    end

    local function popMask()
        render.setStencilEnable(false)
        render.clearStencil()
    end

    render.createRenderTarget("vignette")
    render.createRenderTarget("dirtylens")
    -- render.createRenderTarget("sharpen")

    -- local sharpness = material.load("pp/sharpen")
    local dirtylens = material.create("gmodscreenspace")
    dirtylens:setTextureURL("$basetexture", "https://raw.githubusercontent.com/AstricUnion/BODYCAM/refs/heads/main/dlens03.png")
    local screenspace = material.load("models/screenspace")
    if !screenspace then return end
    local fisheye = material.create("Refract_DX90")
    fisheye:setTexture("$basetexture", "_rt_fullframefb")
    -- fisheye:setTextureRenderTarget("$basetexture", "sharpen")
    fisheye:setTexture("$dudvmap", "models/effects/fisheyelens_dudv")
    fisheye:setTexture("$normalmap", "models/effects/fisheyelens_normal")
    fisheye:setFloat("$refractamount", -0.07)
    fisheye:setFloat("$model", 1)
    fisheye:setFloat("$nodecal", 1)
    fisheye:setFloat("$envmap", 0)
    fisheye:setFloat("$envmapint", 0)
    fisheye:setFloat("$ignorez", 1)
    fisheye:setFloat("$flags", 256)


    local sw, sh

    local function renderTargets()
        render.selectRenderTarget("dirtylens")
        do
            render.clear(Color(0, 0, 0, 0))
            render.setMaterialEffectDownsample(fisheye, 0.3, 2)
            render.setMaterialEffectBloom(fisheye, 1, 1, 1, 2)
            render.drawTexturedRect(-200, -200, 1424, 1424)
            render.drawBlurEffect(20, 20, 2)
            render.setMaterialEffectSub(dirtylens)
            render.drawTexturedRect(0, 0, 1024, 1024)
        end
        render.selectRenderTarget("vignette")
        do
            render.clear(Color(0, 0, 0, 0))

            -- Blur on corners
            pushMask(function()
                render.drawFilledCircle(512, 512, 250)
            end)
            render.setMaterial(fisheye)
            render.drawTexturedRect(100, 100, 824, 824)
            popMask()
            render.drawBlurEffect(10, 10, 5)

            -- Vignette
            pushMask(function()
                render.drawFilledCircle(512, 512, 360)
            end)
            render.setColor(Color(0, 0, 0))
            render.drawRect(0, 0, 1024, 1024)
            popMask()
            render.drawBlurEffect(5, 5, 5)
        end
        render.selectRenderTarget()
    end

    local holo = hologram.create(Vector(), Angle(), OWNER:getModel(), Vector(1.1, 1.1, 1.1))
    if !holo then return end
    local function preprocess(side)
        holo:manipulateBoneScale(holo:lookupBone("ValveBiped.Bip01_" .. side .. "_Clavicle"), Vector(0))
        holo:manipulateBoneScale(holo:lookupBone("ValveBiped.Bip01_" .. side .. "_UpperArm"), Vector(0))
        holo:manipulateBoneScale(holo:lookupBone("ValveBiped.Bip01_" .. side .. "_Forearm"), Vector(0))
        holo:manipulateBoneScale(holo:lookupBone("ValveBiped.Bip01_" .. side .. "_Hand"), Vector(0))
    end

    preprocess("L")
    preprocess("R")
    holo:manipulateBoneScale(holo:lookupBone("ValveBiped.Bip01_Head1"), Vector(0))

    hook.add("RenderOffscreen", "legs", function()
        local pos = OWNER:getPos()
        holo:setClip(0, true, render.getEyePos(), Vector(0, 0, -1))
        local ang = OWNER:getAngles():setP(0):setR(0)
        holo:setPos(pos - Vector(27, 0, 0):getRotated(ang))
        holo:setAngles(ang)
        holo:setPose("move_x", (OWNER:getPose("move_x") * 2) - 1)
        holo:setPose("move_y", (OWNER:getPose("move_y") * 2) - 1)
        holo:setPose("move_yaw", (OWNER:getPose("move_yaw") * 180) - 90)
        holo:setPose("aim_yaw", (OWNER:getPose("head_yaw") * 180) - 90)
        holo:setPose("aim_pitch", (OWNER:getPose("head_pitch") * 180) - 90)
        holo:setPose("head_yaw", (OWNER:getPose("aim_yaw") * 180) - 90)
        holo:setPose("head_pitch", (OWNER:getPose("aim_pitch") * 180) - 90)
        holo:setAnimation(OWNER:getSequence())
        holo:setModel(OWNER:getModel())
        holo:setPlayerColor(OWNER:getPlayerColor())
    end)

    hook.add("RenderOffscreen", "renderTargets", function()
        sw, sh = render.getGameResolution()
        renderTargets()
    end)

    local censorMat = material.create("UnlitGeneric")
    local function drawCensor()
        local players = find.byClass("player")
        local npcs = find.byClass("npc_*")
        table.add(players, npcs)
        local pos = render.getEyePos()
        for _, v in ipairs(players) do
            if v == OWNER then goto cont end
            ---@cast v Entity
            local aPos = v:getBonePosition(v:lookupBone("ValveBiped.Bip01_Head1"))
            if !aPos then goto cont end
            local tr = trace.line(pos, aPos, {OWNER, v}, MASK_SOLID)
            if tr.Hit then goto cont end
            local ang = (aPos - pos):getAngle()
            local m = Matrix(ang + Angle(90, 0, 0), aPos - ang:getForward() * 10)
            m:rotate(Angle(0, -90, 0))
            render.pushMatrix(m)
            do
                render.enableDepth(false)
                render.setColor(Color(0, 0, 0))
                render.setMaterial(censorMat)
                render.drawTexturedRect(-8, -8, 16, 16)
            end
            render.popMatrix()
            ::cont::
        end
    end

    local function drawCrosshair()
        ---@type TraceResult
        local tr = OWNER:getEyeTrace()
        if !tr then return end
        local pos = render.getEyePos()
        local ang = (tr.HitPos - pos):getAngle()
        local m = Matrix(ang + Angle(90, 0, 0), tr.HitPos - ang:getForward() * 10)
        m:rotate(Angle(0, -90, 0))
        render.pushMatrix(m)
        do
            render.enableDepth(false)
            render.setColor(Color(255, 0, 0))
            render.setMaterial(censorMat)
            render.drawTexturedRect(-1, -1, 2, 2)
        end
        render.popMatrix()
    end

    hook.add("PostDrawTranslucentRenderables", "censor", function()
        drawCensor()
        drawCrosshair()
    end)


    local lastEyeAng = Angle()

    local fontRobotoBold32 = render.createFont("Monospace",24,500,false,false,false,false,0,false,0)
    hook.add("PostDrawHUD", "", function()
        local currentEyeAng = render.getAngles()
        local diffNotNorm = (lastEyeAng - currentEyeAng) * 4
        local diff = Angle(
            math.normalizeAngle(diffNotNorm.p),
            math.normalizeAngle(diffNotNorm.y),
            math.normalizeAngle(diffNotNorm.r)
        )
        render.setMaterial(fisheye)
        render.drawTexturedRect(-diff.y - 200, -diff.p - 200, sw + 400, sh + 400)
        render.setMaterialEffectAdd("dirtylens")
        render.drawTexturedRect(0, 0, sw, sh)
        render.setRenderTargetTexture("vignette")
        render.drawTexturedRect(math.clamp(-diff.y, -50, 50) - 400, -diff.p - 350, sw + 800, sh + 700)
        lastEyeAng = math.lerpAngle(0.3, lastEyeAng, currentEyeAng)
        lastEyeAng = Angle(
            math.normalizeAngle(lastEyeAng.p),
            math.normalizeAngle(lastEyeAng.y),
            math.normalizeAngle(lastEyeAng.r)
        )
        render.setFont(fontRobotoBold32)
        render.drawText(30, 30, "RECORD " .. os.date("%d.%m.%Y %X"))
        render.drawText(30, 54, OWNER:getHealth() .. " HP, " .. OWNER:getArmor() .. " ARMOR")
    end)


    local lastOffset = Vector()
    local function getViewmodelOffset(origin, angles)
        local viewmodel = OWNER:getViewModel()
        local viewmodelOffset = Vector()
        local boneCount = viewmodel:getBoneCount()
        for i=0, boneCount do
            local mat = viewmodel:getBoneMatrix(i)
            if !mat then goto cont end
            local pos, ang = worldToLocal(mat:getTranslation(), mat:getAngles(), origin, angles)
            viewmodelOffset = viewmodelOffset + pos + ang:setR(ang.r / 4) / 2
            ::cont::
        end
        local offset = viewmodelOffset / boneCount / 3
        ---@cast offset Vector
        if offset:getLength() > 100 then return lastOffset end
        lastOffset = math.lerpVector(0.5, lastOffset, offset)
        return lastOffset
    end

    ---@return ViewData
    hook.add("CalcView", "", function(origin, angles)
        -- If player dead
        local deathRagdoll = OWNER:getDeathRagdoll()
        if deathRagdoll and isValid(deathRagdoll) then
            local pos, ang = deathRagdoll:getAttachment(3)
            origin = pos
            angles = ang
        else
            walkAnimationFunc()
        end
        local velocity = OWNER:getLocalVelocity()
        slopeOnMove = math.lerp(0.1, slopeOnMove, velocity.x) - ((slopeOnMove / 22) * math.rand(-1, 1))
        velocityZ = math.lerp(0.1, velocityZ, velocity.z) - ((velocityZ / 20) * math.rand(-1, 1))
        currentOffset = math.lerpAngle(0.0005, currentOffset, targetOffset)
        local slope = velocity.y / 40 - ((velocity.y / 500) * math.rand(-1, 1))
        local currentShake = ((angles - current) / 300 + Angle(0.03, 0.03, 0.03)) * Angle(math.rand(-1, 1), math.rand(-1, 1), math.rand(-1, 1))
        local vmOffset = getViewmodelOffset(origin, angles)
        current = math.lerpAngle(0.2, current, angles + Angle(0, 0, 2 * -slope) + currentOffset - vmOffset) + currentShake
        ---@class obj: ViewData
        local obj = {
            origin = origin + (angles:getRight() * 5) + Vector(0, 0, -2) + Vector(2, 0, 0):getRotated(Angle(0, angles.y, 0)) + (angles:getForward() * 5),
            angles = current + Angle(velocityZ / 50 + slopeOnMove / 30, 0, 0) + walkAnimation + OWNER:getViewPunchAngles() * math.rand(-1, 1) / 2,
            fov = 140,
        }
        return obj
    end)

end


