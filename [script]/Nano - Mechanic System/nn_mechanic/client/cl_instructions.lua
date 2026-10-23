local instructionsStateData = {}
local initialEmptyInstructions = {}
instructionsStateData.currentInstructions = initialEmptyInstructions
StateInstructions = instructionsStateData

function OpenInstructions(instructionsToSet)
    if not instructionsToSet then
        instructionsToSet = StateInstructions.currentInstructions
    else
        StateInstructions.currentInstructions = instructionsToSet
    end

    SendNUIMessage({
        action = "setInstructions",
        data = instructionsToSet
    })

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            action = "setVisible",
            page = "instructions"
        }
    })

    State.openPage = "instructions"
end

function CloseInstructions()
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            action = "setVisible",
            page = "instructions"
        }
    })
end

function ShowInstructionsIfExists()
    local currentPage = State.openPage
    if currentPage == "car-lift-control" or currentPage == "menu" or currentPage == "catalog" then
        return
    end

    if InstallFlow and InstallFlow.IsActive then
        if InstallFlow.IsActive() then
            InstallFlow.SyncUI()
            return
        end
    end

    local currentInstructions = StateInstructions.currentInstructions
    if currentInstructions and #currentInstructions > 0 then
        SendNUIMessage({
            action = "setInstructions",
            data = currentInstructions
        })

        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = true,
                action = "setVisible",
                page = "instructions"
            }
        })

        State.openPage = "instructions"
    end
end

function CompleteInstructionStep(stepNumberStr)
    local stepNumber = tonumber(stepNumberStr)
    local currentInstructions = StateInstructions.currentInstructions
    local totalInstructions = #currentInstructions

    if not (stepNumber and stepNumber >= 1 and stepNumber <= totalInstructions) then
        bridge.Notify.SendNotify("Invalid step number. Use /completeinstruction <1-" .. totalInstructions .. ">", "error")
        return
    end

    currentInstructions[stepNumber].completed = true

    SendNUIMessage({
        action = "setInstructions",
        data = currentInstructions
    })

    local allCompleted = true
    for _, instruction in ipairs(currentInstructions) do
        if not instruction.completed then
            allCompleted = false
            break
        end
    end

    if allCompleted then
        bridge.Notify.SendNotify("All instructions completed! Great job!", "success")
        Citizen.CreateThread(function()
            Wait(5000)
            CloseInstructions()
        end)
    end
end

function IsInstructionStepCompleted(stepIndex)
    local currentInstructions = StateInstructions.currentInstructions
    local instructionStep

    if currentInstructions then
        instructionStep = currentInstructions[stepIndex]
        if instructionStep then
            return instructionStep.completed == true
        end
    end

    return false
end