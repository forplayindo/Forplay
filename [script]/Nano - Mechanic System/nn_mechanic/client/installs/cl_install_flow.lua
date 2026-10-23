local L0_1, L1_1, L2_1, L3_1, L4_1, L5_1, L6_1, L7_1, L8_1, L9_1, L10_1, L11_1, L12_1, L13_1, L14_1, L15_1, L16_1, L17_1, L18_1, L19_1, L20_1, L21_1, L22_1, L23_1
L0_1 = InstallFlow
if not L0_1 then
  L0_1 = {}
end
InstallFlow = L0_1
L0_1 = {}
L0_1["car-lift-control"] = true
L0_1.catalog = true
L0_1.tablet = true
L0_1["fluid-minigame"] = true
L0_1["color-mixing"] = true
L0_1["stance-control"] = true
L0_1["lights-control"] = true
L0_1.diagnostic = true
L0_1["product-tag"] = true
L0_1["pressure-gauge"] = true
L0_1["engine-freeing"] = true
L0_1["engine-attaching"] = true
L1_1 = "install_flow_menu"
function L2_1()
  local L0_2, L1_2
  L0_2 = State
  if L0_2 then
    L0_2 = State
    L0_2 = L0_2.activeInstall
    if L0_2 then
      goto lbl_9
    end
  end
  L0_2 = nil
  ::lbl_9::
  return L0_2
end
function L3_1()
  local L0_2, L1_2, L2_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if L0_2 then
    L1_2 = L0_2.steps
    if L1_2 then
      goto lbl_10
    end
  end
  L1_2 = nil
  do return L1_2 end
  ::lbl_10::
  L1_2 = L0_2.steps
  L2_2 = L0_2.currentStep
  L1_2 = L1_2[L2_2]
  return L1_2
end
function L4_1()
  local L0_2, L1_2, L2_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if not L0_2 then
    L1_2 = false
    return L1_2
  end
  L1_2 = L0_2.vehicle
  if L1_2 then
    L1_2 = DoesEntityExist
    L2_2 = L0_2.vehicle
    L1_2 = L1_2(L2_2)
  end
  return L1_2
end
function L5_1()
  local L0_2, L1_2, L2_2
  L0_2 = State
  if not L0_2 then
    return
  end
  L0_2 = State
  L0_2 = L0_2.openPage
  if "menu" == L0_2 then
    L0_2 = State
    L0_2 = L0_2.currentMenuId
    L1_2 = L1_1
    if L0_2 == L1_2 then
      L0_2 = SendNUIMessage
      L1_2 = {}
      L1_2.action = "setVisibility"
      L2_2 = {}
      L2_2.visible = false
      L2_2.page = "menu"
      L1_2.data = L2_2
      L0_2(L1_2)
      L0_2 = State
      L0_2.openPage = nil
      L0_2 = State
      L0_2.currentMenuId = nil
  end
  else
    L0_2 = State
    L0_2 = L0_2.openPage
    if "instructions" == L0_2 then
      L0_2 = CloseInstructions
      L0_2()
      L0_2 = State
      L0_2.openPage = nil
    end
  end
end
function L6_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2
  L1_2 = L2_1
  L1_2 = L1_2()
  if not L1_2 then
    return
  end
  L2_2 = L1_2.heightThreadRunning
  if L2_2 then
    L1_2.heightThreadRunning = false
  end
  L2_2 = L1_2.depositProp
  if L2_2 then
    L2_2 = DoesEntityExist
    L3_2 = L1_2.depositProp
    L2_2 = L2_2(L3_2)
    if L2_2 then
      L2_2 = DeleteEntity
      L3_2 = L1_2.depositProp
      L2_2(L3_2)
    end
  end
  L2_2 = L1_2.cleanupHooks
  if L2_2 then
    L2_2 = ipairs
    L3_2 = L1_2.cleanupHooks
    L2_2, L3_2, L4_2, L5_2 = L2_2(L3_2)
    for L6_2, L7_2 in L2_2, L3_2, L4_2, L5_2 do
      L8_2 = pcall
      L9_2 = L7_2
      L10_2 = A0_2
      L8_2, L9_2 = L8_2(L9_2, L10_2)
      if not L8_2 then
        L10_2 = dprint
        L11_2 = "[InstallFlow] cleanup hook error: "
        L12_2 = tostring
        L13_2 = L9_2
        L12_2 = L12_2(L13_2)
        L11_2 = L11_2 .. L12_2
        L10_2(L11_2)
      end
    end
  end
  L2_2 = State
  if L2_2 then
    L2_2 = State
    L2_2 = L2_2.Ped
    if L2_2 then
      L2_2 = DoesEntityExist
      L3_2 = State
      L3_2 = L3_2.Ped
      L2_2 = L2_2(L3_2)
      if L2_2 then
        L2_2 = ClearPedTasks
        L3_2 = State
        L3_2 = L3_2.Ped
        L2_2(L3_2)
        L2_2 = SetPedCanRagdoll
        L3_2 = State
        L3_2 = L3_2.Ped
        L4_2 = true
        L2_2(L3_2, L4_2)
      end
    end
  end
  L2_2 = L5_1
  L2_2()
  L2_2 = StateInstructions
  if L2_2 then
    L2_2 = StateInstructions
    L3_2 = {}
    L2_2.currentInstructions = L3_2
  end
  L2_2 = L1_2.onComplete
  L3_2 = State
  L3_2.activeInstall = nil
  L3_2 = State
  L3_2.repairInProgress = false
  if L2_2 then
    L3_2 = pcall
    L4_2 = L2_2
    L5_2 = true == A0_2
    L3_2, L4_2 = L3_2(L4_2, L5_2)
    if not L3_2 then
      L5_2 = dprint
      L6_2 = "[InstallFlow] onComplete error: "
      L7_2 = tostring
      L8_2 = L4_2
      L7_2 = L7_2(L8_2)
      L6_2 = L6_2 .. L7_2
      L5_2(L6_2)
    end
  end
end
function L7_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if L0_2 then
    L1_2 = L0_2.steps
    if L1_2 then
      goto lbl_11
    end
  end
  L1_2 = {}
  do return L1_2 end
  ::lbl_11::
  L1_2 = {}
  L2_2 = ipairs
  L3_2 = L0_2.steps
  L2_2, L3_2, L4_2, L5_2 = L2_2(L3_2)
  for L6_2, L7_2 in L2_2, L3_2, L4_2, L5_2 do
    L8_2 = L7_2.title
    if L8_2 then
      L8_2 = #L1_2
      L8_2 = L8_2 + 1
      L9_2 = {}
      L10_2 = L7_2.title
      L9_2.title = L10_2
      L10_2 = L7_2.desc
      if not L10_2 then
        L10_2 = ""
      end
      L9_2.description = L10_2
      L10_2 = L0_2.currentStep
      L10_2 = L6_2 < L10_2
      L9_2.completed = L10_2
      L1_2[L8_2] = L9_2
    end
  end
  return L1_2
end
function L8_1()
  local L0_2, L1_2, L2_2
  L0_2 = L7_1
  L0_2 = L0_2()
  if L0_2 then
    L1_2 = #L0_2
    if 0 ~= L1_2 then
      goto lbl_9
    end
  end
  do return end
  ::lbl_9::
  L1_2 = StateInstructions
  L1_2.currentInstructions = L0_2
  L1_2 = SendNUIMessage
  L2_2 = {}
  L2_2.action = "setInstructions"
  L2_2.data = L0_2
  L1_2(L2_2)
end
function L9_1()
  local L0_2, L1_2, L2_2
  L0_2 = L8_1
  L0_2()
  L0_2 = StateInstructions
  L0_2 = L0_2.currentInstructions
  if L0_2 then
    L0_2 = StateInstructions
    L0_2 = L0_2.currentInstructions
    L0_2 = #L0_2
    if 0 ~= L0_2 then
      goto lbl_13
    end
  end
  do return end
  ::lbl_13::
  L0_2 = SendNUIMessage
  L1_2 = {}
  L1_2.action = "setVisibility"
  L2_2 = {}
  L2_2.visible = true
  L2_2.action = "setVisible"
  L2_2.page = "instructions"
  L1_2.data = L2_2
  L0_2(L1_2)
  L0_2 = State
  L0_2.openPage = "instructions"
end
function L10_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2
  if A0_2 then
    L1_2 = #A0_2
    if 0 ~= L1_2 then
      goto lbl_10
    end
  end
  L1_2 = dprint
  L2_2 = "[InstallFlow] pushMenu skipped: empty items"
  L1_2(L2_2)
  do return end
  ::lbl_10::
  L1_2 = dprint
  L2_2 = "[InstallFlow] pushMenu items=%d openPage(before)=%s"
  L3_2 = L2_2
  L2_2 = L2_2.format
  L4_2 = #A0_2
  L5_2 = tostring
  L6_2 = State
  L6_2 = L6_2.openPage
  L5_2, L6_2 = L5_2(L6_2)
  L2_2, L3_2, L4_2, L5_2, L6_2 = L2_2(L3_2, L4_2, L5_2, L6_2)
  L1_2(L2_2, L3_2, L4_2, L5_2, L6_2)
  L1_2 = SetNuiFocus
  L2_2 = false
  L3_2 = false
  L1_2(L2_2, L3_2)
  L1_2 = SendNUIMessage
  L2_2 = {}
  L2_2.action = "setMenuData"
  L3_2 = {}
  L4_2 = L1_1
  L3_2.menuId = L4_2
  L3_2.items = A0_2
  L2_2.data = L3_2
  L1_2(L2_2)
  L1_2 = SendNUIMessage
  L2_2 = {}
  L2_2.action = "setVisibility"
  L3_2 = {}
  L3_2.visible = true
  L3_2.page = "menu"
  L2_2.data = L3_2
  L1_2(L2_2)
  L1_2 = State
  L1_2.openPage = "menu"
  L1_2 = State
  L2_2 = L1_1
  L1_2.currentMenuId = L2_2
  L1_2 = StartMenuControlsThread
  if L1_2 then
    L1_2 = StartMenuControlsThread
    L1_2()
  end
end
function L11_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2
  L1_2 = {}
  L2_2 = A0_2.type
  if "dynamic_menu" == L2_2 then
    L2_2 = type
    L3_2 = A0_2.getItems
    L2_2 = L2_2(L3_2)
    if "function" == L2_2 then
      L2_2 = L2_1
      L2_2 = L2_2()
      L3_2 = pcall
      L4_2 = A0_2.getItems
      L5_2 = L2_2
      L3_2, L4_2 = L3_2(L4_2, L5_2)
      if L3_2 then
        L5_2 = type
        L6_2 = L4_2
        L5_2 = L5_2(L6_2)
        if "table" == L5_2 then
          return L4_2
        end
      end
      L5_2 = {}
      return L5_2
    end
  end
  L2_2 = nil
  L3_2 = A0_2.items
  if L3_2 then
    L2_2 = A0_2.items
  else
    L3_2 = {}
    L4_2 = {}
    L5_2 = A0_2.label
    if not L5_2 then
      L5_2 = "Action"
    end
    L4_2.label = L5_2
    L5_2 = A0_2.icon
    if not L5_2 then
      L5_2 = "fas fa-wrench"
    end
    L4_2.icon = L5_2
    L4_2.stepData = A0_2
    L3_2[1] = L4_2
    L2_2 = L3_2
  end
  L3_2 = ipairs
  L4_2 = L2_2
  L3_2, L4_2, L5_2, L6_2 = L3_2(L4_2)
  for L7_2, L8_2 in L3_2, L4_2, L5_2, L6_2 do
    L9_2 = #L1_2
    L9_2 = L9_2 + 1
    L10_2 = {}
    L11_2 = L8_2.label
    L10_2.label = L11_2
    L11_2 = L8_2.icon
    if not L11_2 then
      L11_2 = "fas fa-wrench"
    end
    L10_2.icon = L11_2
    L10_2.nuiCallback = "installFlowAction"
    L11_2 = {}
    L11_2.actionId = L7_2
    L10_2.callbackData = L11_2
    L1_2[L9_2] = L10_2
  end
  return L1_2
end
L12_1 = nil
L13_1 = nil
function L14_1()
  local L0_2, L1_2, L2_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if L0_2 then
    L1_2 = L0_2.heightThreadRunning
    if not L1_2 then
      goto lbl_9
    end
  end
  do return end
  ::lbl_9::
  L0_2.heightThreadRunning = true
  L1_2 = Citizen
  L1_2 = L1_2.CreateThread
  function L2_2()
    local L0_3, L1_3, L2_3, L3_3, L4_3, L5_3, L6_3, L7_3, L8_3
    while true do
      L0_3 = L2_1
      L0_3 = L0_3()
      if not L0_3 then
        break
      end
      L1_3 = L0_3.heightThreadRunning
      if not L1_3 then
        break
      end
      L1_3 = L3_1
      L1_3 = L1_3()
      if not L1_3 then
        break
      end
      L2_3 = L1_3.type
      if "lift_height" ~= L2_3 then
        break
      end
      L2_3 = L4_1
      L2_3 = L2_3()
      if not L2_3 then
        L2_3 = L6_1
        L3_3 = false
        L2_3(L3_3)
        break
      end
      L2_3 = L0_3.liftIndex
      if L2_3 then
        L3_3 = State
        L3_3 = L3_3.liftStates
        if L3_3 then
          L3_3 = State
          L3_3 = L3_3.liftStates
          L3_3 = L3_3[L2_3]
        end
        L4_3 = GetEntityCoords
        L5_3 = L0_3.vehicle
        L4_3 = L4_3(L5_3)
        L4_3 = L4_3.z
        L5_3 = false
        L6_3 = L1_3.target
        if "min" == L6_3 then
          if L3_3 then
            L6_3 = L3_3.position
            if "min" == L6_3 then
              L5_3 = true
            end
          end
        else
          L6_3 = GetEntityCoords
          L7_3 = PlayerPedId
          L7_3, L8_3 = L7_3()
          L6_3 = L6_3(L7_3, L8_3)
          L6_3 = L6_3.z
          L7_3 = L1_3.targetOffset
          if not L7_3 then
            L7_3 = 0.0
          end
          L8_3 = L6_3 + L7_3
          if L4_3 >= L8_3 then
            L5_3 = true
          end
        end
        if L5_3 then
          L6_3 = State
          L7_3 = L6_3.openPage
          L6_3 = L0_1
          L6_3 = L6_3[L7_3]
          if not L6_3 then
            L0_3.heightThreadRunning = false
            L6_3 = L13_1
            L6_3()
            break
          end
        end
      end
      L3_3 = Citizen
      L3_3 = L3_3.Wait
      L4_3 = 300
      L3_3(L4_3)
    end
    L0_3 = L2_1
    L0_3 = L0_3()
    if L0_3 then
      L0_3.heightThreadRunning = false
    end
  end
  L1_2(L2_2)
end
function L15_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2
  L1_2 = L2_1
  L1_2 = L1_2()
  if L1_2 then
    L2_2 = A0_2.propAttach
    if L2_2 then
      goto lbl_9
    end
  end
  do return end
  ::lbl_9::
  L2_2 = GetHashKey
  L3_2 = A0_2.propAttach
  L3_2 = L3_2.prop
  L2_2 = L2_2(L3_2)
  L3_2 = RequestModel
  L4_2 = L2_2
  L3_2(L4_2)
  L3_2 = GetGameTimer
  L3_2 = L3_2()
  L3_2 = L3_2 + 3000
  while true do
    L4_2 = HasModelLoaded
    L5_2 = L2_2
    L4_2 = L4_2(L5_2)
    if L4_2 then
      break
    end
    L4_2 = GetGameTimer
    L4_2 = L4_2()
    if not (L3_2 > L4_2) then
      break
    end
    L4_2 = Wait
    L5_2 = 50
    L4_2(L5_2)
  end
  L4_2 = HasModelLoaded
  L5_2 = L2_2
  L4_2 = L4_2(L5_2)
  if not L4_2 then
    return
  end
  L4_2 = PlayerPedId
  L4_2 = L4_2()
  L5_2 = GetEntityCoords
  L6_2 = L4_2
  L5_2 = L5_2(L6_2)
  L6_2 = CreateObject
  L7_2 = L2_2
  L8_2 = L5_2.x
  L9_2 = L5_2.y
  L10_2 = L5_2.z
  L10_2 = L10_2 + 0.2
  L11_2 = false
  L12_2 = false
  L13_2 = false
  L6_2 = L6_2(L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2)
  L7_2 = A0_2.propAttach
  L7_2 = L7_2.bone
  if not L7_2 then
    L7_2 = 60309
  end
  L8_2 = A0_2.propAttach
  L8_2 = L8_2.coords
  if not L8_2 then
    L8_2 = {}
    L8_2.x = 0.0
    L8_2.y = 0.0
    L8_2.z = 0.0
  end
  L9_2 = A0_2.propAttach
  L9_2 = L9_2.rotation
  if not L9_2 then
    L9_2 = {}
    L9_2.x = 0.0
    L9_2.y = 0.0
    L9_2.z = 0.0
  end
  L10_2 = AttachEntityToEntity
  L11_2 = L6_2
  L12_2 = L4_2
  L13_2 = GetPedBoneIndex
  L14_2 = L4_2
  L15_2 = L7_2
  L13_2 = L13_2(L14_2, L15_2)
  L14_2 = L8_2.x
  L15_2 = L8_2.y
  L16_2 = L8_2.z
  L17_2 = L9_2.x
  L18_2 = L9_2.y
  L19_2 = L9_2.z
  L20_2 = true
  L21_2 = true
  L22_2 = false
  L23_2 = true
  L24_2 = 1
  L25_2 = true
  L10_2(L11_2, L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2, L23_2, L24_2, L25_2)
  L10_2 = A0_2.carryAnim
  if false ~= L10_2 then
    L10_2 = RequestAnimDict
    L11_2 = "anim@heists@box_carry@"
    L10_2(L11_2)
    L10_2 = GetGameTimer
    L10_2 = L10_2()
    L10_2 = L10_2 + 1500
    while true do
      L11_2 = HasAnimDictLoaded
      L12_2 = "anim@heists@box_carry@"
      L11_2 = L11_2(L12_2)
      if L11_2 then
        break
      end
      L11_2 = GetGameTimer
      L11_2 = L11_2()
      if not (L10_2 > L11_2) then
        break
      end
      L11_2 = Wait
      L12_2 = 20
      L11_2(L12_2)
    end
    L11_2 = TaskPlayAnim
    L12_2 = L4_2
    L13_2 = "anim@heists@box_carry@"
    L14_2 = "idle"
    L15_2 = 8.0
    L16_2 = -8.0
    L17_2 = -1
    L18_2 = 51
    L19_2 = 0
    L20_2 = false
    L21_2 = false
    L22_2 = false
    L11_2(L12_2, L13_2, L14_2, L15_2, L16_2, L17_2, L18_2, L19_2, L20_2, L21_2, L22_2)
  end
  L1_2.depositProp = L6_2
end
function L16_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2
  if not A0_2 then
    L1_2 = true
    return L1_2
  end
  L1_2 = PlayerPedId
  L1_2 = L1_2()
  L2_2 = A0_2.anim
  if L2_2 then
    L2_2 = A0_2.anim
    L2_2 = L2_2.dict
    if L2_2 then
      L2_2 = RequestAnimDict
      L3_2 = A0_2.anim
      L3_2 = L3_2.dict
      L2_2(L3_2)
      L2_2 = GetGameTimer
      L2_2 = L2_2()
      L2_2 = L2_2 + 2000
      while true do
        L3_2 = HasAnimDictLoaded
        L4_2 = A0_2.anim
        L4_2 = L4_2.dict
        L3_2 = L3_2(L4_2)
        if L3_2 then
          break
        end
        L3_2 = GetGameTimer
        L3_2 = L3_2()
        if not (L2_2 > L3_2) then
          break
        end
        L3_2 = Wait
        L4_2 = 20
        L3_2(L4_2)
      end
    end
  end
  L2_2 = ClearPedTasksImmediately
  L3_2 = L1_2
  L2_2(L3_2)
  L2_2 = SetPedCanRagdoll
  L3_2 = L1_2
  L4_2 = false
  L2_2(L3_2, L4_2)
  L2_2 = {}
  L3_2 = A0_2.duration
  if not L3_2 then
    L3_2 = 5000
  end
  L2_2.duration = L3_2
  L3_2 = A0_2.label
  if not L3_2 then
    L3_2 = "Working..."
  end
  L2_2.label = L3_2
  L3_2 = A0_2.canCancel
  L3_2 = false ~= L3_2
  L2_2.canCancel = L3_2
  L3_2 = A0_2.disable
  if not L3_2 then
    L3_2 = {}
    L3_2.move = true
    L3_2.car = true
    L3_2.combat = true
  end
  L2_2.disable = L3_2
  L3_2 = A0_2.anim
  if L3_2 then
    L3_2 = {}
    L4_2 = A0_2.anim
    L4_2 = L4_2.dict
    L3_2.dict = L4_2
    L4_2 = A0_2.anim
    L4_2 = L4_2.clip
    L3_2.clip = L4_2
    L4_2 = A0_2.anim
    L4_2 = L4_2.flag
    if not L4_2 then
      L4_2 = 1
    end
    L3_2.flag = L4_2
    L2_2.anim = L3_2
  end
  L3_2 = bridge
  L3_2 = L3_2.ProgressBar
  L3_2 = L3_2.Open
  L4_2 = L2_2
  L3_2 = L3_2(L4_2)
  L4_2 = SetPedCanRagdoll
  L5_2 = L1_2
  L6_2 = true
  L4_2(L5_2, L6_2)
  return L3_2
end
function L17_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if L0_2 then
    L1_2 = L0_2.partItem
    if L1_2 then
      goto lbl_9
    end
  end
  do return end
  ::lbl_9::
  L1_2 = TriggerServerEvent
  L2_2 = "nn_mechanic:removePartItem"
  L3_2 = L0_2.partItem
  L3_2 = L3_2.itemName
  L4_2 = L0_2.partItem
  L4_2 = L4_2.slot
  L1_2(L2_2, L3_2, L4_2)
  L0_2.partItem = nil
end
function L18_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
  L1_2 = L2_1
  L1_2 = L1_2()
  if L1_2 then
    L2_2 = L4_1
    L2_2 = L2_2()
    if L2_2 then
      goto lbl_11
    end
  end
  L2_2 = false
  do return L2_2 end
  ::lbl_11::
  L2_2 = L1_2.vehicle
  L3_2 = A0_2.modId
  if not L3_2 then
    L3_2 = L1_2.modId
  end
  L4_2 = A0_2.modIndex
  if not L4_2 then
    L4_2 = L1_2.modIndex
  end
  if nil == L3_2 or nil == L4_2 then
    L5_2 = false
    return L5_2
  end
  L5_2 = SetVehicleModKit
  L6_2 = L2_2
  L7_2 = 0
  L5_2(L6_2, L7_2)
  L5_2 = SetVehicleMod
  L6_2 = L2_2
  L7_2 = L3_2
  L8_2 = L4_2
  L9_2 = A0_2.customTires
  L9_2 = true == L9_2
  L5_2(L6_2, L7_2, L8_2, L9_2)
  L5_2 = A0_2.saveProps
  if false ~= L5_2 then
    L5_2 = getVehicleProperties
    L6_2 = L2_2
    L5_2 = L5_2(L6_2)
    L6_2 = TriggerServerEvent
    L7_2 = "nn_mechanic:saveVehicleProps"
    L8_2 = L5_2
    L6_2(L7_2, L8_2)
    L6_2 = setVehicleProperties
    L7_2 = L2_2
    L8_2 = L5_2
    L6_2(L7_2, L8_2)
  end
  L5_2 = A0_2.consumeStashedPart
  if false ~= L5_2 then
    L5_2 = L17_1
    L5_2()
  end
  L5_2 = true
  return L5_2
end
function L19_1(A0_2)
  local L1_2
  L1_2 = A0_2.type
  L1_2 = "apply_mod" == L1_2
  return L1_2
end
function L20_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2
  L1_2 = A0_2.type
  if "apply_mod" == L1_2 then
    L1_2 = L18_1
    L2_2 = A0_2
    L1_2 = L1_2(L2_2)
    if not L1_2 then
      L2_2 = false
      return L2_2
    end
    L2_2 = A0_2.notify
    if L2_2 then
      L2_2 = bridge
      L2_2 = L2_2.Notify
      L2_2 = L2_2.SendNotify
      L3_2 = A0_2.notify
      L4_2 = "success"
      L2_2(L3_2, L4_2)
    end
    L2_2 = true
    return L2_2
  else
    L1_2 = A0_2.type
    if "cleanup" == L1_2 then
      L1_2 = A0_2.run
      if L1_2 then
        L1_2 = pcall
        L2_2 = A0_2.run
        L3_2 = L2_1
        L3_2, L4_2, L5_2, L6_2 = L3_2()
        L1_2, L2_2 = L1_2(L2_2, L3_2, L4_2, L5_2, L6_2)
        if not L1_2 then
          L3_2 = dprint
          L4_2 = "[InstallFlow] cleanup step error: "
          L5_2 = tostring
          L6_2 = L2_2
          L5_2 = L5_2(L6_2)
          L4_2 = L4_2 .. L5_2
          L3_2(L4_2)
        end
      end
      L1_2 = true
      return L1_2
    else
      L1_2 = A0_2.type
      if "progress" == L1_2 then
        L1_2 = L5_1
        L1_2()
        L1_2 = L16_1
        L2_2 = A0_2
        L1_2 = L1_2(L2_2)
        if not L1_2 then
          L2_2 = false
          return L2_2
        end
        L2_2 = true
        return L2_2
      end
    end
  end
  L1_2 = false
  return L1_2
end
function L21_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if not L0_2 then
    return
  end
  L1_2 = L3_1
  L1_2 = L1_2()
  if not L1_2 then
    L2_2 = L6_1
    L3_2 = true
    L2_2(L3_2)
    return
  end
  L2_2 = L19_1
  L3_2 = L1_2
  L2_2 = L2_2(L3_2)
  if L2_2 then
    L2_2 = L20_1
    L3_2 = L1_2
    L2_2 = L2_2(L3_2)
    if L2_2 then
      L3_2 = L13_1
      L3_2()
    else
      L3_2 = L6_1
      L4_2 = false
      L3_2(L4_2)
    end
    return
  end
  L2_2 = L1_2.type
  if "use_part" == L2_2 then
    L2_2 = L1_2.notify
    if L2_2 then
      L2_2 = bridge
      L2_2 = L2_2.Notify
      L2_2 = L2_2.SendNotify
      L3_2 = L1_2.notify
      L4_2 = "info"
      L2_2(L3_2, L4_2)
    else
      L2_2 = L1_2.partName
      if L2_2 then
        L2_2 = bridge
        L2_2 = L2_2.Notify
        L2_2 = L2_2.SendNotify
        L3_2 = t
        L4_2 = "use_part_from_inventory"
        L3_2 = L3_2(L4_2)
        if not L3_2 then
          L3_2 = "Use the part from your inventory"
        end
        L4_2 = "info"
        L2_2(L3_2, L4_2)
      end
    end
  else
    L2_2 = L1_2.type
    if "lift_height" == L2_2 then
      L2_2 = L14_1
      L2_2()
    else
      L2_2 = L1_2.type
      if "deposit" == L2_2 then
        L2_2 = L15_1
        L3_2 = L1_2
        L2_2(L3_2)
        L2_2 = L1_2.notify
        if L2_2 then
          L2_2 = bridge
          L2_2 = L2_2.Notify
          L2_2 = L2_2.SendNotify
          L3_2 = L1_2.notify
          L4_2 = "info"
          L2_2(L3_2, L4_2)
        end
      else
        L2_2 = L1_2.type
        if "minigame" == L2_2 then
          L2_2 = L1_2.run
          if L2_2 then
            L2_2 = L5_1
            L2_2()
            L2_2 = L1_2.run
            L3_2 = L0_2
            L2_2 = L2_2(L3_2)
            L2_2 = false ~= L2_2
            if L2_2 then
              L3_2 = L13_1
              L3_2()
            else
              L3_2 = L6_1
              L4_2 = false
              L3_2(L4_2)
            end
            return
          end
        end
      end
    end
  end
  L2_2 = InstallFlow
  L2_2 = L2_2.SyncUI
  L2_2()
end
L12_1 = L21_1
function L21_1()
  local L0_2, L1_2, L2_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if not L0_2 then
    return
  end
  L1_2 = L0_2.currentStep
  L1_2 = L1_2 + 1
  L0_2.currentStep = L1_2
  L1_2 = L0_2.currentStep
  L2_2 = L0_2.steps
  L2_2 = #L2_2
  if L1_2 > L2_2 then
    L1_2 = L6_1
    L2_2 = true
    L1_2(L2_2)
    return
  end
  L1_2 = L12_1
  L1_2()
end
L13_1 = L21_1
L21_1 = InstallFlow
function L22_1()
  local L0_2, L1_2
  L0_2 = L2_1
  L0_2 = L0_2()
  L1_2 = nil ~= L0_2
  return L1_2
end
L21_1.IsActive = L22_1
L21_1 = InstallFlow
function L22_1()
  local L0_2, L1_2
  L0_2 = L2_1
  return L0_2()
end
L21_1.GetActive = L22_1
L21_1 = InstallFlow
function L22_1(A0_2)
  local L1_2, L2_2, L3_2
  L1_2 = InstallFlow
  L1_2 = L1_2.IsActive
  L1_2 = L1_2()
  if not L1_2 then
    return
  end
  if A0_2 then
    L1_2 = bridge
    L1_2 = L1_2.Notify
    L1_2 = L1_2.SendNotify
    L2_2 = A0_2
    L3_2 = "error"
    L1_2(L2_2, L3_2)
  end
  L1_2 = L6_1
  L2_2 = false
  L1_2(L2_2)
end
L21_1.Cancel = L22_1
L21_1 = InstallFlow
function L22_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L2_2 = InstallFlow
  L2_2 = L2_2.IsActive
  L2_2 = L2_2()
  if not L2_2 then
    L2_2 = State
    if not L2_2 then
      goto lbl_26
    end
    L2_2 = State
    L2_2 = L2_2.repairInProgress
    if not L2_2 then
      goto lbl_26
    end
  end
  L2_2 = bridge
  L2_2 = L2_2.Notify
  L2_2 = L2_2.SendNotify
  L3_2 = t
  L4_2 = "repair_in_progress"
  L3_2 = L3_2(L4_2)
  if not L3_2 then
    L3_2 = "A repair is already in progress"
  end
  L4_2 = "error"
  L2_2(L3_2, L4_2)
  L2_2 = false
  do return L2_2 end
  ::lbl_26::
  L2_2 = type
  L3_2 = A0_2
  L2_2 = L2_2(L3_2)
  if "table" == L2_2 then
    L2_2 = type
    L3_2 = A0_2.steps
    L2_2 = L2_2(L3_2)
    if "table" == L2_2 then
      L2_2 = A0_2.steps
      L2_2 = #L2_2
      if 0 ~= L2_2 then
        goto lbl_48
      end
    end
  end
  L2_2 = bridge
  L2_2 = L2_2.Notify
  L2_2 = L2_2.SendNotify
  L3_2 = "Invalid install recipe"
  L4_2 = "error"
  L2_2(L3_2, L4_2)
  L2_2 = false
  do return L2_2 end
  ::lbl_48::
  if not A1_2 then
    L2_2 = {}
    A1_2 = L2_2
  end
  L2_2 = A1_2.vehicle
  if L2_2 then
    L3_2 = DoesEntityExist
    L4_2 = L2_2
    L3_2 = L3_2(L4_2)
    if L3_2 then
      goto lbl_74
    end
  end
  L3_2 = bridge
  L3_2 = L3_2.Notify
  L3_2 = L3_2.SendNotify
  L4_2 = t
  L5_2 = "no_vehicle_found"
  L4_2 = L4_2(L5_2)
  if not L4_2 then
    L4_2 = "No vehicle found"
  end
  L5_2 = "error"
  L3_2(L4_2, L5_2)
  L3_2 = false
  do return L3_2 end
  ::lbl_74::
  L3_2 = State
  L4_2 = {}
  L5_2 = A0_2.id
  if not L5_2 then
    L5_2 = "install"
  end
  L4_2.id = L5_2
  L5_2 = A0_2.partName
  L4_2.partName = L5_2
  L4_2.vehicle = L2_2
  L5_2 = VehToNet
  L6_2 = L2_2
  L5_2 = L5_2(L6_2)
  L4_2.vehicleNetId = L5_2
  L5_2 = A1_2.modId
  if not L5_2 then
    L5_2 = A0_2.modId
  end
  L4_2.modId = L5_2
  L5_2 = A1_2.modIndex
  if not L5_2 then
    L5_2 = A0_2.modIndex
  end
  L4_2.modIndex = L5_2
  L5_2 = A1_2.expectedRef
  L4_2.expectedRef = L5_2
  L5_2 = A0_2.steps
  L4_2.steps = L5_2
  L4_2.currentStep = 1
  L5_2 = {}
  L4_2.stepData = L5_2
  L5_2 = A1_2.liftIndex
  L4_2.liftIndex = L5_2
  L5_2 = A1_2.onComplete
  L4_2.onComplete = L5_2
  L5_2 = A0_2.cleanup
  if L5_2 then
    L5_2 = {}
    L6_2 = A0_2.cleanup
    L5_2[1] = L6_2
    if L5_2 then
      goto lbl_122
    end
  end
  L5_2 = {}
  ::lbl_122::
  L4_2.cleanupHooks = L5_2
  L4_2.inProgress = true
  L5_2 = A1_2.ctxIndex
  L4_2.ctxIndex = L5_2
  L5_2 = A1_2.extras
  if not L5_2 then
    L5_2 = {}
  end
  L4_2.extras = L5_2
  L3_2.activeInstall = L4_2
  L3_2 = State
  L3_2 = L3_2.activeInstall
  L3_2 = L3_2.liftIndex
  if not L3_2 then
    L3_2 = State
    L3_2 = L3_2.activeInstall
    L3_2 = L3_2.vehicleNetId
    L4_2 = pairs
    L5_2 = State
    L5_2 = L5_2.liftStates
    if not L5_2 then
      L5_2 = {}
    end
    L4_2, L5_2, L6_2, L7_2 = L4_2(L5_2)
    for L8_2, L9_2 in L4_2, L5_2, L6_2, L7_2 do
      if L9_2 then
        L10_2 = L9_2.isAttached
        if L10_2 then
          L10_2 = L9_2.vehicleNetId
          if L10_2 == L3_2 then
            L10_2 = State
            L10_2 = L10_2.activeInstall
            L10_2.liftIndex = L8_2
            break
          end
        end
      end
    end
  end
  L3_2 = State
  L3_2.repairInProgress = true
  L3_2 = State
  L3_2 = L3_2.activeInstall
  L3_2 = L3_2.steps
  L3_2 = L3_2[1]
  if L3_2 then
    L4_2 = L3_2.type
    if "attach_lift" == L4_2 then
      L4_2 = State
      L4_2 = L4_2.activeInstall
      L4_2 = L4_2.liftIndex
      if L4_2 then
        L4_2 = State
        L4_2 = L4_2.activeInstall
        L4_2.currentStep = 2
      end
    end
  end
  L4_2 = L12_1
  L4_2()
  L4_2 = true
  return L4_2
end
L21_1.Start = L22_1
L21_1 = InstallFlow
function L22_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2
  L2_2 = L2_1
  L2_2 = L2_2()
  if L2_2 then
    L3_2 = L2_2.vehicleNetId
    if L3_2 == A0_2 then
      goto lbl_10
    end
  end
  L3_2 = false
  do return L3_2 end
  ::lbl_10::
  L2_2.liftIndex = A1_2
  L3_2 = L3_1
  L3_2 = L3_2()
  if L3_2 then
    L4_2 = L3_2.type
    if "attach_lift" == L4_2 then
      L4_2 = L13_1
      L4_2()
      L4_2 = true
      return L4_2
    end
  end
  L4_2 = false
  return L4_2
end
L21_1.OnVehicleAttached = L22_1
L21_1 = InstallFlow
function L22_1(A0_2, A1_2)
end
L21_1.OnLiftHeightChanged = L22_1
L21_1 = InstallFlow
function L22_1()
  local L0_2, L1_2
  L0_2 = InstallFlow
  L0_2 = L0_2.IsActive
  L0_2 = L0_2()
  if not L0_2 then
    return
  end
  L0_2 = Citizen
  L0_2 = L0_2.CreateThread
  function L1_2()
    local L0_3, L1_3
    L0_3 = Wait
    L1_3 = 50
    L0_3(L1_3)
    L0_3 = InstallFlow
    L0_3 = L0_3.SyncUI
    L0_3()
  end
  L0_2(L1_2)
end
L21_1.OnUIClosed = L22_1
L21_1 = InstallFlow
function L22_1()
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L0_2 = L2_1
  L0_2 = L0_2()
  if not L0_2 then
    L1_2 = dprint
    L2_2 = "[InstallFlow] SyncUI: no active install, bail"
    L1_2(L2_2)
    return
  end
  L1_2 = L8_1
  L1_2()
  L1_2 = State
  L2_2 = L1_2.openPage
  L1_2 = L0_1
  L1_2 = L1_2[L2_2]
  if L1_2 then
    L1_2 = dprint
    L2_2 = "[InstallFlow] SyncUI: blocked by openPage=%s"
    L3_2 = L2_2
    L2_2 = L2_2.format
    L4_2 = tostring
    L5_2 = State
    L5_2 = L5_2.openPage
    L4_2, L5_2, L6_2, L7_2, L8_2 = L4_2(L5_2)
    L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2 = L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2)
    L1_2(L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2)
    return
  end
  L1_2 = L3_1
  L1_2 = L1_2()
  if not L1_2 then
    L2_2 = dprint
    L3_2 = "[InstallFlow] SyncUI: no currentStep (idx=%s/%d)"
    L4_2 = L3_2
    L3_2 = L3_2.format
    L5_2 = tostring
    L6_2 = L0_2.currentStep
    L5_2 = L5_2(L6_2)
    L6_2 = L0_2.steps
    L6_2 = #L6_2
    L3_2, L4_2, L5_2, L6_2, L7_2, L8_2 = L3_2(L4_2, L5_2, L6_2)
    L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2)
    return
  end
  L2_2 = dprint
  L3_2 = "[InstallFlow] SyncUI: stepIdx=%d type=%s openPage=%s"
  L4_2 = L3_2
  L3_2 = L3_2.format
  L5_2 = L0_2.currentStep
  L6_2 = tostring
  L7_2 = L1_2.type
  L6_2 = L6_2(L7_2)
  L7_2 = tostring
  L8_2 = State
  L8_2 = L8_2.openPage
  L7_2, L8_2 = L7_2(L8_2)
  L3_2, L4_2, L5_2, L6_2, L7_2, L8_2 = L3_2(L4_2, L5_2, L6_2, L7_2, L8_2)
  L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2)
  L2_2 = L1_2.type
  if "dynamic_menu" == L2_2 then
    L2_2 = type
    L3_2 = L1_2.isComplete
    L2_2 = L2_2(L3_2)
    if "function" == L2_2 then
      L2_2 = pcall
      L3_2 = L1_2.isComplete
      L4_2 = L0_2
      L2_2, L3_2 = L2_2(L3_2, L4_2)
      if L2_2 and L3_2 then
        L4_2 = dprint
        L5_2 = "[InstallFlow] SyncUI: dynamic_menu isComplete -> advance"
        L4_2(L5_2)
        L4_2 = L13_1
        L4_2()
        return
      end
    end
    L2_2 = L11_1
    L3_2 = L1_2
    L2_2 = L2_2(L3_2)
    L3_2 = dprint
    L4_2 = "[InstallFlow] SyncUI: dynamic_menu items=%d"
    L5_2 = L4_2
    L4_2 = L4_2.format
    if L2_2 then
      L6_2 = #L2_2
      if L6_2 then
        goto lbl_89
      end
    end
    L6_2 = -1
    ::lbl_89::
    L4_2, L5_2, L6_2, L7_2, L8_2 = L4_2(L5_2, L6_2)
    L3_2(L4_2, L5_2, L6_2, L7_2, L8_2)
    if L2_2 then
      L3_2 = #L2_2
      if 0 ~= L3_2 then
        goto lbl_99
      end
    end
    L3_2 = L9_1
    L3_2()
    do return end
    ::lbl_99::
    L3_2 = State
    L3_2 = L3_2.openPage
    if "instructions" == L3_2 then
      L3_2 = L5_1
      L3_2()
    else
      L3_2 = State
      L3_2 = L3_2.openPage
      if "menu" == L3_2 then
        L3_2 = State
        L3_2 = L3_2.currentMenuId
        L4_2 = L1_1
        if L3_2 ~= L4_2 then
          L3_2 = L5_1
          L3_2()
        end
      end
    end
    L3_2 = L10_1
    L4_2 = L2_2
    L3_2(L4_2)
    return
  end
  L2_2 = L1_2.type
  if "menu_action" == L2_2 then
    L2_2 = State
    L2_2 = L2_2.openPage
    if "instructions" == L2_2 then
      L2_2 = L5_1
      L2_2()
    else
      L2_2 = State
      L2_2 = L2_2.openPage
      if "menu" == L2_2 then
        L2_2 = State
        L2_2 = L2_2.currentMenuId
        L3_2 = L1_1
        if L2_2 ~= L3_2 then
          L2_2 = L5_1
          L2_2()
        end
      end
    end
    L2_2 = L10_1
    L3_2 = L11_1
    L4_2 = L1_2
    L3_2, L4_2, L5_2, L6_2, L7_2, L8_2 = L3_2(L4_2)
    L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2)
  else
    L2_2 = L9_1
    L2_2()
  end
end
L21_1.SyncUI = L22_1
L21_1 = InstallFlow
function L22_1(A0_2, A1_2, A2_2, A3_2)
  local L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2
  L4_2 = InstallFlow
  L4_2 = L4_2.IsActive
  L4_2 = L4_2()
  if not L4_2 then
    L4_2 = false
    L5_2 = nil
    return L4_2, L5_2
  end
  L4_2 = L2_1
  L4_2 = L4_2()
  L5_2 = L3_1
  L5_2 = L5_2()
  if L5_2 then
    L6_2 = L5_2.type
    if "use_part" == L6_2 then
      goto lbl_21
    end
  end
  L6_2 = false
  L7_2 = nil
  do return L6_2, L7_2 end
  ::lbl_21::
  L6_2 = L5_2.partName
  if L6_2 then
    L6_2 = L5_2.partName
    if L6_2 ~= A0_2 then
      L6_2 = false
      L7_2 = nil
      return L6_2, L7_2
    end
  end
  L6_2 = L4_2.expectedRef
  if not L6_2 or "" == L6_2 then
    L7_2 = true
    L8_2 = nil
    return L7_2, L8_2
  end
  if A1_2 == L6_2 then
    L7_2 = true
    L8_2 = nil
    return L7_2, L8_2
  end
  L7_2 = L4_2.modId
  if not L7_2 then
    L7_2 = L5_2.modId
  end
  if nil ~= L7_2 and A2_2 then
    L8_2 = IsValidPartItem
    L9_2 = L7_2
    L10_2 = L6_2
    L11_2 = A2_2
    L12_2 = A3_2
    L8_2 = L8_2(L9_2, L10_2, L11_2, L12_2)
    if L8_2 then
      L8_2 = true
      L9_2 = nil
      return L8_2, L9_2
    end
  end
  L8_2 = false
  L9_2 = L6_2
  return L8_2, L9_2
end
L21_1.GetExpectedPartFor = L22_1
L21_1 = InstallFlow
function L22_1(A0_2, A1_2, A2_2, A3_2)
  local L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2
  L4_2 = InstallFlow
  L4_2 = L4_2.IsActive
  L4_2 = L4_2()
  if not L4_2 then
    L4_2 = false
    return L4_2
  end
  L4_2 = L2_1
  L4_2 = L4_2()
  L5_2 = L3_1
  L5_2 = L5_2()
  if L5_2 then
    L6_2 = L5_2.type
    if "use_part" == L6_2 then
      goto lbl_19
    end
  end
  L6_2 = false
  do return L6_2 end
  ::lbl_19::
  L6_2 = L5_2.partName
  if L6_2 then
    L6_2 = L5_2.partName
    if L6_2 ~= A0_2 then
      L6_2 = false
      return L6_2
    end
  end
  L6_2 = L4_1
  L6_2 = L6_2()
  if not L6_2 then
    L6_2 = L6_1
    L7_2 = false
    L6_2(L7_2)
    L6_2 = true
    L7_2 = false
    return L6_2, L7_2
  end
  L6_2 = A1_2 or L6_2
  if A1_2 then
    L6_2 = A1_2.referenceNumber
    if not L6_2 then
      L6_2 = A1_2.reference
    end
  end
  if A3_2 then
    L7_2 = A3_2.name
    if L7_2 then
      goto lbl_52
    end
    L7_2 = A3_2.item
    if L7_2 then
      goto lbl_52
    end
  end
  L7_2 = L5_2.itemName
  ::lbl_52::
  L8_2 = InstallFlow
  L8_2 = L8_2.GetExpectedPartFor
  L9_2 = A0_2
  L10_2 = L6_2
  L11_2 = A1_2
  L12_2 = L7_2
  L8_2 = L8_2(L9_2, L10_2, L11_2, L12_2)
  if not L8_2 then
    L9_2 = bridge
    L9_2 = L9_2.Notify
    L9_2 = L9_2.SendNotify
    L10_2 = t
    L11_2 = "wrong_reference_number"
    L10_2 = L10_2(L11_2)
    if not L10_2 then
      L10_2 = "Wrong reference number"
    end
    L11_2 = "error"
    L9_2(L10_2, L11_2)
    L9_2 = true
    L10_2 = false
    return L9_2, L10_2
  end
  L9_2 = GetEntityCoords
  L10_2 = PlayerPedId
  L10_2, L11_2, L12_2, L13_2, L14_2, L15_2 = L10_2()
  L9_2 = L9_2(L10_2, L11_2, L12_2, L13_2, L14_2, L15_2)
  L10_2 = GetEntityCoords
  L11_2 = L4_2.vehicle
  L10_2 = L10_2(L11_2)
  L11_2 = L5_2.maxDistance
  if not L11_2 then
    L11_2 = 5.0
  end
  L12_2 = L9_2 - L10_2
  L12_2 = #L12_2
  if L11_2 < L12_2 then
    L12_2 = bridge
    L12_2 = L12_2.Notify
    L12_2 = L12_2.SendNotify
    L13_2 = t
    L14_2 = "get_closer_to_vehicle"
    L13_2 = L13_2(L14_2)
    if not L13_2 then
      L13_2 = "Get closer to the vehicle"
    end
    L14_2 = "error"
    L12_2(L13_2, L14_2)
    L12_2 = true
    L13_2 = false
    return L12_2, L13_2
  end
  L12_2 = L5_2.captureModIndex
  if L12_2 and A1_2 then
    L12_2 = A1_2.modIndex
    if nil ~= L12_2 then
      L12_2 = tonumber
      L13_2 = A1_2.modIndex
      L12_2 = L12_2(L13_2)
      L4_2.modIndex = L12_2
    end
  end
  L12_2 = {}
  if A3_2 then
    L13_2 = A3_2.name
    if L13_2 then
      goto lbl_135
    end
    L13_2 = A3_2.item
    if L13_2 then
      goto lbl_135
    end
  end
  L13_2 = L5_2.itemName
  if not L13_2 then
    L13_2 = "mechanic_"
    L14_2 = A0_2 or L14_2
    if not A0_2 then
      L14_2 = "part"
    end
    L13_2 = L13_2 .. L14_2
  end
  ::lbl_135::
  L12_2.itemName = L13_2
  L13_2 = A2_2 or L13_2
  if not A2_2 then
    if A3_2 then
      L13_2 = A3_2.slot
    end
    L13_2 = A1_2 or L13_2
    if not L13_2 and A1_2 then
      L13_2 = A1_2.slot
    end
  end
  L12_2.slot = L13_2
  L4_2.partItem = L12_2
  L12_2 = L5_2.consume
  if "immediate" == L12_2 then
    L12_2 = L4_2.partItem
    if L12_2 then
      L12_2 = TriggerServerEvent
      L13_2 = "nn_mechanic:removePartItem"
      L14_2 = L4_2.partItem
      L14_2 = L14_2.itemName
      L15_2 = L4_2.partItem
      L15_2 = L15_2.slot
      L12_2(L13_2, L14_2, L15_2)
      L4_2.partItem = nil
    end
  end
  L12_2 = L13_1
  L12_2()
  L12_2 = true
  L13_2 = true
  return L12_2, L13_2
end
L21_1.OnPartUsed = L22_1
L21_1 = RegisterNUICallback
L22_1 = "installFlowAction"
function L23_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
  L2_2 = InstallFlow
  L2_2 = L2_2.IsActive
  L2_2 = L2_2()
  if not L2_2 then
    L2_2 = A1_2
    L3_2 = {}
    L3_2.success = false
    L2_2(L3_2)
    return
  end
  L2_2 = L3_1
  L2_2 = L2_2()
  if L2_2 then
    L3_2 = L2_2.type
    if "menu_action" == L3_2 then
      goto lbl_25
    end
  end
  L3_2 = A1_2
  L4_2 = {}
  L4_2.success = false
  L3_2(L4_2)
  do return end
  ::lbl_25::
  if A0_2 then
    L3_2 = A0_2.actionId
    if L3_2 then
      goto lbl_31
    end
  end
  L3_2 = 1
  ::lbl_31::
  L4_2 = L2_2.items
  if L4_2 then
    L4_2 = L2_2.items
    L4_2 = L4_2[L3_2]
    if L4_2 then
      goto lbl_39
    end
  end
  L4_2 = L2_2
  ::lbl_39::
  L5_2 = L5_1
  L5_2()
  L5_2 = L4_2.minigame
  if L5_2 then
    L5_2 = type
    L6_2 = L4_2.minigame
    L5_2 = L5_2(L6_2)
    if "function" == L5_2 then
      L5_2 = L4_2.minigame
      L6_2 = L2_1
      L6_2, L7_2, L8_2, L9_2 = L6_2()
      L5_2 = L5_2(L6_2, L7_2, L8_2, L9_2)
      L5_2 = false ~= L5_2
      if not L5_2 then
        L6_2 = InstallFlow
        L6_2 = L6_2.SyncUI
        L6_2()
        L6_2 = A1_2
        L7_2 = {}
        L7_2.success = false
        L6_2(L7_2)
        return
      end
    end
  end
  L5_2 = L4_2.run
  L6_2 = true
  if L5_2 then
    L7_2 = type
    L8_2 = L5_2
    L7_2 = L7_2(L8_2)
    if "function" == L7_2 then
      L7_2 = L5_2
      L8_2 = L2_1
      L8_2, L9_2 = L8_2()
      L7_2 = L7_2(L8_2, L9_2)
      L6_2 = false ~= L7_2
    else
      L7_2 = type
      L8_2 = L5_2
      L7_2 = L7_2(L8_2)
      if "table" == L7_2 then
        L7_2 = L5_2.type
        if "progress" == L7_2 then
          L7_2 = L16_1
          L8_2 = L5_2
          L7_2 = L7_2(L8_2)
          L6_2 = true == L7_2
        else
          L7_2 = L5_2.type
          if "apply_mod" == L7_2 then
            L7_2 = L18_1
            L8_2 = L5_2
            L7_2 = L7_2(L8_2)
            L6_2 = L7_2
          end
        end
      end
    end
  end
  if not L6_2 then
    L7_2 = InstallFlow
    L7_2 = L7_2.SyncUI
    L7_2()
    L7_2 = A1_2
    L8_2 = {}
    L8_2.success = false
    L7_2(L8_2)
    return
  end
  L7_2 = L4_2.notify
  if L7_2 then
    L7_2 = bridge
    L7_2 = L7_2.Notify
    L7_2 = L7_2.SendNotify
    L8_2 = L4_2.notify
    L9_2 = "success"
    L7_2(L8_2, L9_2)
  end
  L7_2 = L13_1
  L7_2()
  L7_2 = A1_2
  L8_2 = {}
  L8_2.success = true
  L7_2(L8_2)
end
L21_1(L22_1, L23_1)
L21_1 = AddEventHandler
L22_1 = "onResourceStop"
function L23_1(A0_2)
  local L1_2, L2_2
  L1_2 = GetCurrentResourceName
  L1_2 = L1_2()
  if A0_2 == L1_2 then
    L1_2 = InstallFlow
    L1_2 = L1_2.IsActive
    L1_2 = L1_2()
    if L1_2 then
      L1_2 = L6_1
      L2_2 = false
      L1_2(L2_2)
    end
  end
end
L21_1(L22_1, L23_1)