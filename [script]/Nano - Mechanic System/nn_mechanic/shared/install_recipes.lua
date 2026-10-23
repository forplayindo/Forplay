-- =====================================================================
--  Install Recipes
-- =====================================================================
-- Declarative step descriptions consumed by InstallFlow (cl_install_flow.lua).
-- Each recipe is a function taking an opts table and returning:
--   {
--      id        = 'recipe_id',          -- machine-readable id
--      partName  = 'exhaust',            -- inventory part name (for use_part)
--      modId     = 4,                    -- vehicle mod id (optional)
--      modIndex  = N,                    -- vehicle mod index (optional)
--      steps     = { ... },              -- ordered step descriptors
--      cleanup   = function(success) end -- optional global cleanup hook
--   }
--
-- Step types:
--   { type='attach_lift',  title, desc }
--   { type='lift_height',  title, desc, target='player_z'|'min',
--                          targetOffset = number (optional, vs player Z) }
--   { type='menu_action',  title, desc, label, icon,
--                          run  = { type='progress', ... } | function | apply_mod step,
--                          notify = string,
--                          minigame = function(active) end (optional),
--                          items = { -- for multi-action menus
--                              { label, icon, run, notify }, ...
--                          } }
--   { type='progress',     duration, label, anim={dict,clip,flag} }
--   { type='use_part',     partName, captureModIndex=true|false,
--                          consume=true|false, notify }
--   { type='apply_mod',    modId?, modIndex?, customTires?, saveProps=true|false,
--                          notify }
--   { type='deposit',      title, desc, propAttach={prop,bone,coords,rotation},
--                          carryAnim=true }
--   { type='minigame',     run = function(active) -> bool }
--   { type='cleanup',      run = function(active) end }
-- =====================================================================

InstallRecipes = InstallRecipes or {}

-- ---------------------------------------------------------------------
--  Service-point ctx helper (brake / oil / wheel use this)
-- ---------------------------------------------------------------------

local function getCtx(active)
    if not active or not active.ctxIndex then return nil end
    if not State or not State.servicePointsCtx then return nil end
    return State.servicePointsCtx[active.ctxIndex]
end

-- ---------------------------------------------------------------------
--  Exhaust (modId 4)
-- ---------------------------------------------------------------------
InstallRecipes.exhaust = function(opts)
    opts = opts or {}
    local mechAnim = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer',
        flag = 1
    }

    return {
        id       = 'exhaust',
        partName = 'exhaust',
        modId    = 4,
        steps    = {
            {
                type  = 'attach_lift',
                title = (t and t('attach_vehicle')) or 'Attach Vehicle',
                desc  = (t and t('exhaust_instruction_attach_vehicle_desc'))
                    or 'Attach the vehicle to a lift.'
            },
            {
                type   = 'lift_height',
                target = 'player_z',
                title  = (t and t('exhaust_instruction_lift_vehicle')) or 'Lift the Vehicle',
                desc   = (t and t('exhaust_instruction_lift_vehicle_desc'))
                    or 'Use the lift control to raise the vehicle.'
            },
            {
                type  = 'menu_action',
                title = (t and t('exhaust_instruction_remove_exhaust')) or 'Remove Exhaust',
                desc  = (t and t('exhaust_instruction_remove_exhaust_desc'))
                    or 'Remove the existing exhaust.',
                label = (t and t('remove_exhaust')) or 'Remove Exhaust',
                icon  = 'fas fa-wrench',
                run   = {
                    type     = 'progress',
                    duration = 7000,
                    label    = (t and t('removing_exhaust')) or 'Removing exhaust...',
                    anim     = mechAnim
                }
            },
            {
                type            = 'use_part',
                partName        = 'exhaust',
                captureModIndex = true,
                title           = (t and t('exhaust_instruction_install_exhaust')) or 'Install New Exhaust',
                desc            = (t and t('exhaust_instruction_install_exhaust_desc'))
                    or 'Use the new exhaust item from your inventory.',
                notify          = (t and t('use_exhaust_item_to_install'))
                    or 'Use a new exhaust item from your inventory to install it'
            },
            {
                type     = 'progress',
                duration = 8000,
                label    = (t and t('installing_exhaust')) or 'Installing exhaust...',
                anim     = mechAnim
            },
            {
               type   = 'apply_mod',
                modId  = 4,
                notify = (t and t('exhaust_installed')) or 'Exhaust installed'
            }
        }
    }
end

-- ---------------------------------------------------------------------
--  Brake Pads (managed-state recipe; ctx-driven)
-- ---------------------------------------------------------------------
-- Brake pads keep their existing service-point ctx + sub-action handlers
-- (removeBrakeWheel, installBrakePads, reinstallBrakeWheel). The recipe
-- exists so InstallFlow can:
--   1. Restore the brake_pad menu after any UI close.
--   2. Detect completion (brakes.inProgress == false) and clean up.
-- The 6-step instruction list is created by `OpenInstructions` in
-- changeBrakePads (legacy path) and InstallFlow leaves it alone because
-- this recipe defines no instruction-bearing steps.
-- ---------------------------------------------------------------------
--  Oil Change (managed-state recipe; ctx-driven, two phases)
-- ---------------------------------------------------------------------
-- Drain phase (lift up): oil_bolt_menu items
-- Refill phase (lift down): refill_oil_menu items
-- The recipe only owns the menu rendering; sub-actions still live in
-- cl_oil.lua and call InstallFlow.SyncUI() to refresh the UI.
InstallRecipes.oil_change = function(opts)
    return {
        id    = 'oil_change',
        steps = {
            {
                type     = 'dynamic_menu',
                getItems = function(active)
                    if GetOilChangeMenuItems then
                        return GetOilChangeMenuItems()
                    end
                    return {}
                end,
                isComplete = function(active)
                    local ctx = getCtx(active)
                    if not ctx or not ctx.repairState or not ctx.repairState.oilChange then
                        return true
                    end
                    return not ctx.repairState.oilChange.inProgress
                end
            }
        }
    }
end

-- ---------------------------------------------------------------------
--  Common Repair (generic remove/deposit/install pipeline)
-- ---------------------------------------------------------------------
-- Uses the legacy commonRepairState machine via the BuildCommonRepairMenuItems /
-- IsCommonRepairActive helpers exposed by client/installs/cl_common.lua. The
-- recipe purely owns the UI scaffolding (instructions / dynamic step menu);
-- all state mutation still lives in cl_common.lua so we can migrate without
-- duplicating the per-step logic.
--
-- opts.requiresLift (boolean): if true, attach_lift + lift_height steps are
-- prepended so the player must raise the vehicle before the repair menu appears.
-- Falls back to Config.RequiresLift[modId] when not explicitly set.
InstallRecipes.common = function(opts)
    opts = opts or {}
    local modId = opts.modId
    local requiresLift = opts.requiresLift
    if requiresLift == nil and Config and Config.RequiresLift then
        requiresLift = Config.RequiresLift[modId] or false
    end

    local steps = {}

    if requiresLift then
        steps[#steps + 1] = {
            type  = 'attach_lift',
            title = (t and t('attach_vehicle')) or 'Attach Vehicle',
            desc  = (t and t('attach_vehicle_to_continue'))
                or 'Attach the vehicle to a lift to continue.'
        }
        steps[#steps + 1] = {
            type   = 'lift_height',
            target = 'player_z',
            title  = (t and t('lift_vehicle')) or 'Lift the Vehicle',
            desc   = (t and t('lift_vehicle_desc'))
                or 'Use the lift control to raise the vehicle.'
        }
    end

    steps[#steps + 1] = {
        type     = 'dynamic_menu',
        getItems = function(active)
            if BuildCommonRepairMenuItems then
                return BuildCommonRepairMenuItems()
            end
            return {}
        end,
        isComplete = function(active)
            if IsCommonRepairActive then
                return not IsCommonRepairActive()
            end
            return true
        end
    }

    return {
        id           = 'common_repair',
        modId        = modId,
        requiresLift = requiresLift,
        steps        = steps
    }
end

-- ---------------------------------------------------------------------
--  Nitro Install (managed-state recipe; module-local nitroInstallState)
-- ---------------------------------------------------------------------
InstallRecipes.nitro_install = function(opts)
    return {
        id    = 'nitro_install',
        steps = {
            {
                type     = 'dynamic_menu',
                getItems = function(active)
                    if BuildNitroInstallMenu then
                        return BuildNitroInstallMenu()
                    end
                    return {}
                end,
                isComplete = function(active)
                    if IsNitroInstallActive then
                        return not IsNitroInstallActive()
                    end
                    return true
                end
            }
        }
    }
end

-- ---------------------------------------------------------------------
--  Hood Swap (managed-state recipe; State.hoodSwap-driven)
-- ---------------------------------------------------------------------
InstallRecipes.hood_swap = function(opts)
    -- NOTE: no `partName` here. The legacy hood swap owns the use-part
    -- inventory hook (`InstallHoodFromInventory`) directly; declaring a
    -- partName would cause cl_main.lua to route the inventory event to
    -- InstallFlow.OnPartUsed, which has no use_part step to satisfy and
    -- would short-circuit the install with no feedback.
    return {
        id    = 'hood_swap',
        steps = {
            {
                type     = 'dynamic_menu',
                getItems = function(active)
                    if BuildHoodSwapMenuItems then
                        return BuildHoodSwapMenuItems()
                    end
                    return {}
                end,
                isComplete = function(active)
                    if not State or not State.hoodSwap then return true end
                    return not State.hoodSwap.inProgress
                end
            }
        }
    }
end

-- ---------------------------------------------------------------------
--  Engine Swap (managed-state recipe; State.engineSwap-driven)
-- ---------------------------------------------------------------------
-- The engine swap has 12 instruction steps with a per-step menu. The
-- recipe just owns the menu rendering via dynamic_menu and detects
-- completion when State.engineSwap.inProgress flips to false.
InstallRecipes.engine_swap = function(opts)
    -- NOTE: no `partName` here. Engine swap owns its own inventory hook
    -- (`InstallEngineFromInventory`); declaring a partName would route the
    -- engine-item use through InstallFlow.OnPartUsed, which has no
    -- use_part step and would silently swallow the install request.
    return {
        id    = 'engine_swap',
        steps = {
            {
                type     = 'dynamic_menu',
                getItems = function(active)
                    if BuildEngineSwapMenuItems then
                        return BuildEngineSwapMenuItems()
                    end
                    return {}
                end,
                isComplete = function(active)
                    if not State or not State.engineSwap then return true end
                    return not State.engineSwap.inProgress
                end
            }
        }
    }
end

-- ---------------------------------------------------------------------
--  Wheel Swap (manual attach gate)
-- ---------------------------------------------------------------------
-- The wheel swap has its own state machine (State.wheelSwap) and menu
-- rendering. The recipe only handles the manual-attach gate, then hands
-- off via the cleanup step. After the cleanup runs, InstallFlow tears
-- down its activeInstall so the existing wheel-swap flow owns the rest.
InstallRecipes.wheel_swap = function(opts)
    return {
        id    = 'wheel_swap',
        steps = {
            {
                type  = 'attach_lift',
                title = (t and t('attach_vehicle')) or 'Attach Vehicle',
                desc  = (t and t('attach_vehicle_to_continue'))
                    or 'Attach the vehicle to the lift to continue.'
            },
            {
                type   = 'lift_height',
                target = 'player_z',
                title  = (t and t('wheel_instruction_lift_vehicle')) or 'Lift the Vehicle',
                desc   = (t and t('wheel_instruction_lift_vehicle_desc'))
                    or 'Use the lift control to raise the vehicle.'
            },
            {
                type = 'cleanup',
                run  = function(active)
                    -- Defer so the controller's own cleanup (which clears
                    -- State.repairInProgress / State.activeInstall) runs
                    -- before the legacy flow re-acquires the lock.
                    if active and active.extras and active.extras.continue then
                        local fn = active.extras.continue
                        Citizen.SetTimeout(0, function() fn() end)
                    end
                end
            }
        }
    }
end

InstallRecipes.brake_pad = function(opts)
    return {
        id    = 'brake_pad',
        steps = {
            {
                type     = 'dynamic_menu',
                getItems = function(active)
                    local ctx = getCtx(active)
                    if BuildBrakePadMenuItems then
                        return BuildBrakePadMenuItems(ctx)
                    end
                    return {}
                end,
                isComplete = function(active)
                    local ctx = getCtx(active)
                    if not ctx or not ctx.repairState or not ctx.repairState.brakes then
                        return true
                    end
                    return not ctx.repairState.brakes.inProgress
                end
            }
        }
    }
end

-- ---------------------------------------------------------------------
--  Livery Install (vinyl wrap)
-- ---------------------------------------------------------------------
-- Liveries are paint, not parts: there's nothing physical to remove or
-- deposit. The recipe owns UI/state via InstallFlow but delegates the
-- actual application to RunVinylWrapMinigame (cl_livery.lua), which uses
-- an aim-and-hold heat-gun loop similar to the spray paint flow but
-- without color matching.
InstallRecipes.livery_install = function(opts)
    opts = opts or {}
    return {
        id    = 'livery_install',
        modId = 48,
        steps = {
            {
                type  = 'menu_action',
                title = (t and t('livery_install_title')) or 'Apply Livery',
                desc  = (t and t('livery_install_desc'))
                    or 'Aim at the vehicle and hold to apply the livery.',
                label = (t and t('start_vinyl_wrap')) or 'Start Vinyl Wrap',
                icon  = 'fas fa-paint-roller',
                run = function(active)
                    if not RunVinylWrapMinigame then return false end
                    local vehicle = active and active.vehicle
                    if not vehicle or not DoesEntityExist(vehicle) then return false end

                    local ok = RunVinylWrapMinigame(vehicle)
                    if not ok then return false end

                    SetVehicleModKit(vehicle, 0)

                    -- Resolve which livery API the vehicle actually uses.
                    -- Some classic vehicles only respond to SetVehicleLivery,
                    -- others use mod slot 48. Trust the explicit hint from
                    -- the order metadata first; otherwise probe at runtime.
                    local newCount    = GetNumVehicleMods(vehicle, 48) or 0
                    local oldCount    = GetVehicleLiveryCount(vehicle) or 0
                    local useOld
                    if opts.liveryOldMethod == true then
                        useOld = true
                    elseif opts.liveryOldMethod == false and newCount > 0 then
                        useOld = false
                    else
                        useOld = (newCount <= 0 and oldCount > 0)
                    end

                    local idx = tonumber(opts.modIndex)
                    if idx == nil then idx = -1 end

                    if useOld then
                        SetVehicleLivery(vehicle, idx >= 0 and idx or 0)
                    else
                        SetVehicleMod(vehicle, 48, idx, false)
                    end

                    if Config and Config.Debug then
                        print(('[livery_install] applied: useOld=%s idx=%d (mod48Count=%d, liveryCount=%d) modAfter=%d liveryAfter=%d')
                            :format(tostring(useOld), idx, newCount, oldCount,
                                    GetVehicleMod(vehicle, 48) or -1,
                                    GetVehicleLivery(vehicle) or -1))
                    end

                    if getVehicleProperties then
                        TriggerServerEvent('nn_mechanic:saveVehicleProps', getVehicleProperties(vehicle))
                    end

                    return true
                end,
            }
        }
    }
end