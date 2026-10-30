local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local HOLD_TIME = 0.5
local USER_FILE_NAME = "krgn_user_animations.json"
local TARGET_FILE_NAME = "krgn_target_animations.json"

local COLORS = {
    Background = Color3.fromRGB(32, 32, 35),
    Secondary = Color3.fromRGB(40, 40, 43),
    Dark = Color3.fromRGB(27, 27, 30),
    Hover = Color3.fromRGB(52, 52, 56),
    Border = Color3.fromRGB(75, 75, 80),
    Text = Color3.fromRGB(220, 220, 220),
    SubText = Color3.fromRGB(145, 145, 150)
}

local PLAY_ICON = "rbxassetid://14834074192"
local STOP_ICON = "rbxassetid://6031075938"
local DELETE_ICON = "rbxassetid://89731451639274"

local ResolveDelay = 0.5
local NoiseLimit = 20
local FocusOnly = true

local Config = {
    CloneHook = false,
    EmitHook = false,
    SendHook = false,
    Debug = true
}

local FocusCharacters = { DarkLord = true, VirusOverlord = true }

local CharacterNames = {
    "DarkLord", "VirusOverlord", "Black", "Jun", "KingOfCurses",
    "Kratos", "MartialArtist", "Shinji"
}

local FocusKeywords = {
    darklord = "DarkLord",
    virusoverlord = "VirusOverlord",
    dark = "DarkLord",
    virus = "VirusOverlord"
}

local IgnoredKeys = {
    W = true, A = true, S = true, D = true,
    Space = true, Unknown = true
}

local function GetAnimationID(Animation)

    if not Animation then
        return nil
    end

    local ID = Animation.AnimationId

    if not ID or ID == "" then
        return nil
    end

    return ID:match("%d+")

end

local RecordEvent
local ResolveMove
local NameFromIndex
local WatchCharacterEvents
local DisconnectBag
local MarkBorn

do
    local ReplicatedFirst = game:GetService("ReplicatedFirst")
    local StarterPlayer = game:GetService("StarterPlayer")
    local StarterPack = game:GetService("StarterPack")
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")

    local EventWindowBefore = 0.8
    local EventWindowAfter = 0.5
    local MaxEvents = 400
    local NoiseSeconds = 2
    local NoiseCooldown = 12
    local NearRadius = 20
    local MaxDepth = 3
    local MaxValues = 40
    local BornGrace = 1.5
    local KindCap = 10
    local DedupeSeconds = 0.1

    local EmitterIndex = {}
    local FocusRoots = {}
    local EmitterClasses = { ParticleEmitter = true, Trail = true, Beam = true }

    local function RootKey(Name)
        return (string.gsub(Name:lower(), "[%s_]", ""))
    end

    for _, Canon in pairs(FocusKeywords) do
        FocusRoots[RootKey(Canon)] = Canon
    end

    for _, Canon in ipairs(CharacterNames) do
        FocusRoots[RootKey(Canon)] = Canon
    end

    local Storage = ReplicatedStorage:FindFirstChild("CharacterStorage", true)

    if Storage then
        for _, Child in ipairs(Storage:GetChildren()) do
            if not FocusRoots[RootKey(Child.Name)] then
                FocusRoots[RootKey(Child.Name)] = Child.Name
            end
        end
    end

    local CloneSource = setmetatable({}, { __mode = "k" })
    local CharacterLock = setmetatable({}, { __mode = "k" })
    local LibNames = {}

    local PhaseCompounds = {
        { "windup", "startup" }, { "startup", "startup" },
        { "anticipation", "startup" }, { "initial", "startup" },
        { "charge", "startup" },
        { "victim", "hit" }, { "impact", "hit" }, { "stun", "hit" },
        { "react", "hit" },
        { "ending", "end" }, { "finish", "end" }
    }

    local PhaseTokens = {
        hit = "hit",
        start = "startup",
        cast = "startup",
        ["end"] = "end",
        land = "end",
        counter = "counter"
    }

    local Events = {}
    local NoiseData = setmetatable({}, { __mode = "k" })
    local Born = setmetatable({}, { __mode = "k" })
    local HookedRemotes = setmetatable({}, { __mode = "k" })
    local LastSeen = {}
    local LastSeenCount = 0
    local NameIndex = {}
    local AnimIndex = {}

    local MoveKeys = {
        "Move", "MoveName", "Skill", "SkillName", "Ability", "Attack",
        "AttackName", "Action", "Type", "Style", "Name", "Combo", "Effect",
        "VFX", "Fx", "Anim", "Animation", "AnimName"
    }

    local MoveKeySet = {}

    for _, Key in ipairs(MoveKeys) do
        MoveKeySet[Key] = true
    end

    local GenericList = {
        "", "animation", "anim", "animationtrack", "animations", "animator",
        "remote", "remoteevent", "remotefunction", "remotes", "event", "events",
        "network", "packet", "packets", "fire", "fx", "vfx", "vfxs", "effect",
        "effects", "handler", "main", "folder", "part", "handle", "mesh",
        "meshpart", "attachment", "emitter", "particleemitter", "particle",
        "particles", "beam", "trail", "sound", "sounds", "model", "workspace",
        "debris", "assets", "asset", "replicatedstorage", "humanoidrootpart",
        "rootpart", "hitbox", "hitboxes", "moves", "skills", "combat", "server",
        "client", "shared", "modules", "module", "script", "localscript",
        "config", "configuration", "value", "values", "state", "status",
        "head", "torso", "left arm", "right arm", "left leg", "right leg",
        "uppertorso", "lowertorso", "health", "stamina", "speed", "walkspeed",
        "jumppower", "position", "cframe", "target", "direction", "origin",
        "damage", "hit", "time", "duration", "size", "color", "highlight",
        "decal", "texture", "smoke", "fire", "sparkles", "explosion",
        "pointlight", "spotlight", "stringvalue", "boolvalue", "intvalue",
        "numbervalue", "objectvalue", "tool", "weapon", "character", "humanoid",
        "camera", "currentcamera", "terrain", "baseplate", "spawnlocation",
        "idle", "walk", "run", "jump", "fall", "climb", "swim", "default",
        "new", "temp", "tmp", "clone", "copy", "template", "none", "nil",
        "true", "false", "unknown", "resources", "resource"
    }

    local Generic = {}

    for _, Name in ipairs(GenericList) do
        Generic[Name] = true
    end

    local Suffixes = {
        "effects", "effect", "particles", "particle", "animation", "hitbox",
        "sound", "anim", "vfx", "sfx", "fx"
    }

    local InterestingClasses = {
        ParticleEmitter = true, Trail = true, Beam = true,
        Model = true, Folder = true
    }

    local LibraryKinds = {
        VFX = 1, Inst = 1, Arg = 0.5
    }

    local function IsGeneric(Name)
        if type(Name) ~= "string" then
            return true
        end

        local Lower = Name:lower()

        if Generic[Lower] then
            return true
        end

        local Stripped = string.gsub(Lower, "[%s_%d]+$", "")

        if Generic[Stripped] then
            return true
        end

        if #Name < 2 or #Name > 40 then
            return true
        end

        if not Name:find("%a") then
            return true
        end

        if Name:match("^%x+%-%x+%-%x+%-%x+") then
            return true
        end

        if Players:FindFirstChild(Name) then
            return true
        end

        return false
    end

    local function StripSuffix(Name)
        local Lower = Name:lower()

        for _, Suffix in ipairs(Suffixes) do
            if #Lower - #Suffix >= 3 and Lower:sub(-#Suffix) == Suffix then
                local Cut = string.gsub(Name:sub(1, #Name - #Suffix), "[%s_%-%.]+$", "")

                if #Cut >= 3 then
                    return Cut
                end
            end
        end

        return Name
    end

    local function NormKey(Name)
        local Raw = string.gsub(Name:lower(), "[^%w]", "")

        if Raw == "" then
            return Name:lower()
        end

        local Stripped = string.gsub(Raw, "%d+$", "")

        if #Stripped >= 3 then
            return Stripped
        end

        return Raw
    end

    local function IsNoisy(Key, Limit)
        local Now = os.clock()
        local Data = NoiseData[Key]

        if not Data then
            NoiseData[Key] = { Start = Now, Count = 1, BlockedUntil = 0 }
            return false
        end

        if Now < Data.BlockedUntil then
            return true
        end

        if Now - Data.Start > NoiseSeconds then
            Data.Start = Now
            Data.Count = 1
            return false
        end

        Data.Count += 1

        if Data.Count > Limit then
            Data.BlockedUntil = Now + NoiseCooldown
            return true
        end

        return false
    end

    RecordEvent = function(Kind, Name, Owner, Position, Weight, Force, Meta)
        if Kind == "Sound" then
            return
        end

        if type(Name) ~= "string" then
            return
        end

        if not Force and IsGeneric(Name) then
            return
        end

        local Now = os.clock()
        local SeenKey = Kind .. "|" .. Name
        local Last = LastSeen[SeenKey]

        if Last and Now - Last < DedupeSeconds then
            return
        end

        LastSeen[SeenKey] = Now
        LastSeenCount += 1

        if LastSeenCount > 600 then
            LastSeen = {}
            LastSeenCount = 0
        end

        Events[#Events + 1] = {
            Time = Now,
            Kind = Kind,
            Name = Name,
            Owner = Owner,
            Position = Position,
            Weight = Weight or 1,
            Meta = Meta
        }

        if #Events > MaxEvents then
            table.remove(Events, 1)
        end
    end

    local function DeriveNames(Inst)
        local Out = {}
        local Current = Inst
        local Depth = 0

        while Current and Current.Parent ~= game and Depth < 10 do
            if Current:IsA("Model") and Current:FindFirstChildOfClass("Humanoid") then
                break
            end

            if not IsGeneric(Current.Name) then
                Out[#Out + 1] = { Name = Current.Name, Depth = Depth }
            end

            Current = Current.Parent
            Depth += 1
        end

        return Out
    end

    local function GetPosition(Inst)
        local Current = Inst
        local Depth = 0

        while Current and Current ~= Workspace and Current ~= game and Depth < 6 do
            if Current:IsA("BasePart") then
                return Current.Position
            end

            if Current:IsA("Attachment") then
                return Current.WorldPosition
            end

            if Current:IsA("Model") then
                local Ok, Pivot = pcall(function()
                    return Current:GetPivot().Position
                end)

                if Ok then
                    return Pivot
                end
            end

            Current = Current.Parent
            Depth += 1
        end

        return nil
    end

    local function GetCharacterOf(Inst)
        local Current = Inst
        local Depth = 0

        while Current and Current ~= Workspace and Current ~= game and Depth < 15 do
            if Current:IsA("Model") and Current:FindFirstChildOfClass("Humanoid") then
                return Current
            end

            Current = Current.Parent
            Depth += 1
        end

        return nil
    end

    local function PathUnderFocus(Inst)
        local Chain = {}
        local Current = Inst
        local Depth = 0

        while Current and Current ~= game and Depth < 14 do
            Chain[#Chain + 1] = Current

            local Root = FocusRoots[RootKey(Current.Name)]

            if Root then
                local Names = {}

                for Index = #Chain - 1, 1, -1 do
                    local Item = Chain[Index]
                    local Keep = Item:IsA("Folder") or Item:IsA("Model") or Item:IsA("Configuration") or Item:IsA("ModuleScript") or not IsGeneric(Item.Name)

                    if Item.Name:lower() == "resources" then
                        Keep = false
                    end

                    if Keep then
                        Names[#Names + 1] = Item.Name
                    end
                end

                local Below = Chain[#Chain - 1]
                local MoveInst = nil

                if Below and Below.Name == Names[1] then
                    MoveInst = Below
                end

                return { Root = Root, Move = Names[1], Sub = Names[2], MoveInst = MoveInst }
            end

            Current = Current.Parent
            Depth += 1
        end

        return nil
    end

    local function PhaseOf(Text)
        local Lower = Text:lower()

        for _, Pair in ipairs(PhaseCompounds) do
            if Lower:find(Pair[1], 1, true) then
                return Pair[2]
            end
        end

        local Spaced = string.gsub(Text, "(%l)(%u)", "%1 %2")
        Spaced = string.gsub(Spaced, "[_%d]+", " ")

        for Token in Spaced:lower():gmatch("%a+") do
            local Found = PhaseTokens[Token]

            if Found then
                return Found
            end
        end

        return nil
    end

    local FreqCache = setmetatable({}, { __mode = "k" })
    local SigCache = setmetatable({}, { __mode = "k" })

    local function MoveSignature(MoveInst)
        if not MoveInst or not MoveInst.Parent then
            return nil
        end

        local Cached = SigCache[MoveInst]

        if Cached ~= nil then
            return Cached or nil
        end

        local Parent = MoveInst.Parent
        local Counts = FreqCache[Parent]

        if not Counts then
            Counts = {}

            for _, Sibling in ipairs(Parent:GetChildren()) do
                local SeenNames = {}

                for _, Desc in ipairs(Sibling:GetDescendants()) do
                    if not SeenNames[Desc.Name] then
                        SeenNames[Desc.Name] = true
                        Counts[Desc.Name] = (Counts[Desc.Name] or 0) + 1
                    end
                end
            end

            FreqCache[Parent] = Counts
        end

        local Mine = {}
        local Seen = {}

        for _, Desc in ipairs(MoveInst:GetDescendants()) do
            local Name = Desc.Name

            if not Seen[Name] and Name:sub(1, 1) ~= "#" and Name:find("%a") and #Name >= 4 and (Counts[Name] or 0) <= 2 then
                Seen[Name] = true
                Mine[#Mine + 1] = { Name = Name, Count = Counts[Name] or 1 }
            end
        end

        table.sort(Mine, function(A, B)
            if A.Count ~= B.Count then
                return A.Count < B.Count
            end

            return #A.Name > #B.Name
        end)

        local Out = {}

        for Index = 1, math.min(#Mine, 3) do
            Out[#Out + 1] = Mine[Index].Name
        end

        local Text = #Out > 0 and table.concat(Out, ", ") or false

        SigCache[MoveInst] = Text

        return Text or nil
    end

    local function FindCloneSource(Inst)
        local Current = Inst
        local Depth = 0

        while Current and Current ~= Workspace and Depth < 8 do
            local Source = CloneSource[Current]

            if Source then
                return Source
            end

            Current = Current.Parent
            Depth += 1
        end

        return nil
    end

    local function MatchEmitter(Inst, Char)
        local Key = Inst.Parent.Name .. "|" .. Inst.Name
        local List = EmitterIndex[Key]

        if not List then
            return
        end

        if IsNoisy("emit|" .. Key, 80) then
            return
        end

        local Found = {}
        local BestScore = 0

        for _, Cand in ipairs(List) do
            if Cand.Parent then
                local Info = PathUnderFocus(Cand)

                if Info then
                    local Score = 1
                    local A = Inst.Parent.Parent
                    local B = Cand.Parent.Parent
                    local Level = 0

                    while A and B and A.Name == B.Name and Level < 4 do
                        Score += 1
                        A = A.Parent
                        B = B.Parent
                        Level += 1
                    end

                    if Score > BestScore then
                        BestScore = Score
                        Found = {}
                    end

                    if Score == BestScore then
                        Found[#Found + 1] = Info
                    end
                end
            end
        end

        if #Found == 0 then
            return
        end

        local Position = GetPosition(Inst)
        local Share = math.min(1, 2 / #Found)
        local Count = 0

        for _, Info in ipairs(Found) do
            Count += 1

            if Count > 4 then
                break
            end

            RecordEvent("Emitter", Info.Root .. "/" .. (Info.Move or ""), Char, Position, (8 + BestScore) * Share, true, Info)
        end
    end

    local function CollectArgs(Value, Out, Depth, State)
        if #Out >= MaxValues then
            return
        end

        local Kind = typeof(Value)

        if Kind == "string" then
            if #Value > 0 and #Value <= 40 then
                Out[#Out + 1] = { Name = Value, Priority = 1 }
            end
        elseif Kind == "Instance" then
            Out[#Out + 1] = { Instance = Value }
        elseif Kind == "Vector3" then
            State.Position = State.Position or Value
        elseif Kind == "CFrame" then
            State.Position = State.Position or Value.Position
        elseif Kind == "table" then
            if Depth > MaxDepth or State.Seen[Value] then
                return
            end

            State.Seen[Value] = true

            for _, Key in ipairs(MoveKeys) do
                local Found = Value[Key]

                if type(Found) == "string" and #Found > 0 and #Found <= 40 then
                    Out[#Out + 1] = { Name = Found, Priority = 2 }
                end
            end

            local Checked = 0

            for Key, Found in pairs(Value) do
                Checked += 1

                if Checked > 25 then
                    break
                end

                if type(Key) == "string" and Found == true then
                    Out[#Out + 1] = { Name = Key, Priority = 1 }
                end

                if not (type(Key) == "string" and MoveKeySet[Key] and type(Found) == "string") then
                    CollectArgs(Found, Out, Depth + 1, State)
                end
            end
        end
    end

    local function AnalyzeArgs(Args)
        local Items = {}
        local State = { Seen = {}, Position = nil }
        local Owner = nil

        for Index = 1, math.min(Args.n or #Args, 8) do
            CollectArgs(Args[Index], Items, 1, State)
        end

        local Clean = {}

        for _, Item in ipairs(Items) do
            if Item.Instance then
                local Inst = Item.Instance

                if Inst:IsA("Player") then
                    Owner = Owner or Inst.Character
                else
                    local Char = GetCharacterOf(Inst)

                    if Char then
                        Owner = Owner or Char
                    else
                        Clean[#Clean + 1] = Item
                    end
                end
            else
                Clean[#Clean + 1] = Item
            end
        end

        return Owner, Clean, State.Position
    end

    local function EmitRemote(Remote, Args, DefaultOwner)
        local Ok, Owner, Items, Position = pcall(AnalyzeArgs, Args)

        if not Ok then
            Owner = nil
            Items = {}
            Position = nil
        end

        Owner = Owner or DefaultOwner

        for _, Item in ipairs(Items) do
            if Item.Name then
                RecordEvent("Arg", Item.Name, Owner, Position, Item.Priority == 2 and 6 or 4)
            elseif Item.Instance then
                for Index, Entry in ipairs(DeriveNames(Item.Instance)) do
                    if Index > 4 then
                        break
                    end

                    RecordEvent("Inst", Entry.Name, Owner, Position, 3)
                end
            end
        end

        for Index, Entry in ipairs(DeriveNames(Remote)) do
            if Index > 3 then
                break
            end

            RecordEvent("Remote", Entry.Name, Owner, Position, 2.5)
        end
    end

    local RequestMap = {}
    local DebugBudget = 12

    local function Req(Key, Root, Move, Phase, Label)
        RequestMap[Key] = { Req = Key, Root = Root, Move = Move, Phase = Phase, Label = Label }
    end

    Req("ATH", "DarkLord", "AntiTeam", "hit", "AntiTeam hit")
    Req("ATD", "DarkLord", "AntiTeam", "use", "AntiTeam dash")
    Req("ATMark", "DarkLord", "AntiTeam", "startup", "AntiTeam mark")

    Req("CRI", "DarkLord", "CrypticRushdown", "startup", "Cryptic Rushdown windup")
    Req("CRF", "DarkLord", "CrypticRushdown", "use", "Cryptic Rushdown spin dash")
    Req("CRH", "DarkLord", "CrypticRushdown", "use", "Cryptic Rushdown double slash")
    Req("CRH2", "DarkLord", "CrypticRushdown", "use", "Cryptic Rushdown double slash 2")
    Req("VCR", "DarkLord", "CrypticRushdown", "hit", "Cryptic Rushdown victim hit")

    Req("DLCInit", "DarkLord", "Counter", "startup", "Counter cast")
    Req("DLCBack", "DarkLord", "Counter", "use", "Counter stepback")
    Req("DLCBackG", "DarkLord", "Counter", "use", "Counter stepback glint")
    Req("DLCTP", "DarkLord", "Counter", "use", "Counter teleport strike")
    Req("DLCRelease", "DarkLord", "Counter", "end", "Counter release")
    Req("DLCSlide", "DarkLord", "Counter", "use", "Counter slide")
    Req("DLCHit", "DarkLord", "Counter", "hit", "Counter hit")
    Req("DLCMiss", "DarkLord", "Counter", "end", "Counter miss")

    Req("DLAwkI", "DarkLord", "AwakenInitial", "startup", "Awakening init")
    Req("DLAwkI2", "DarkLord", "AwakenInitial", "startup", "Awakening windup")
    Req("DLAwkS", "DarkLord", "AwakenInitial", "use", "Awakening slash")
    Req("DLAwk", "DarkLord", "Awaken", "use", "Awakening cutscene")
    Req("DLAwkSlash", "DarkLord", "Awaken", "end", "Awakening end double slash")

    Req("SSSFX", "DarkLord", "SearingShot", "startup", "Searing Shot cast")
    Req("SSB", "DarkLord", "SearingShot", "use", "Searing Shot spin backstep")
    Req("SSH", "DarkLord", "SearingShot", "hit", "Searing Shot hit")
    Req("DL1Start", "DarkLord", "SearingShot", "startup", "Skill1 start backstep")
    Req("DL1Flip", "DarkLord", "SearingShot", "use", "Skill1 flip")
    Req("DL1Roll", "DarkLord", "SearingShot", "use", "Skill1 roll")

    Req("DL1AS", "DarkLord", "SearingShotAir", "startup", "Searing Shot Air cast")
    Req("DL1ASI", "DarkLord", "SearingShotAir", "startup", "Searing Shot Air spin")
    Req("DL1ASB", "DarkLord", "SearingShotAir", "use", "Searing Shot Air backstep")
    Req("DL1AU", "DarkLord", "SearingShotAir", "use", "Searing Shot Air up launch")

    Req("VRP", "DarkLord", "ViralCut", "use", "Viral Cut slash")

    Req("DL2Z", "DarkLord", "2", "startup", "Skill2 flame anticipate")
    Req("DL2FB", "DarkLord", "2", "use", "Skill2 flame breath")
    Req("DL2Up", "DarkLord", "2", "use", "Skill2 float up")
    Req("DL2Antic", "DarkLord", "2", "startup", "Skill2 throw anticipate")
    Req("DL2Throw", "DarkLord", "2", "use", "Skill2 throw")
    Req("DL2I", "DarkLord", "2", "startup", "Skill2 init")
    Req("DL2S", "DarkLord", "2", "use", "Skill2 grab")
    Req("DL2Swipe", "DarkLord", "2", "use", "Skill2 swipe")
    Req("DL2Blitz", "DarkLord", "2", "use", "Skill2 blitz dive")
    Req("DL2Charge", "DarkLord", "2", "startup", "Skill2 charge")

    Req("SSU2I", "DarkLord", "SearingShotUseTwice", "startup", "Searing Shot use twice init")
    Req("SSU2B", "DarkLord", "SearingShotUseTwice", "use", "Searing Shot use twice dash")
    Req("SSU2H", "DarkLord", "SearingShotUseTwice", "use", "Searing Shot use twice stab")
    Req("SSU2R", "DarkLord", "SearingShotUseTwice", "end", "Searing Shot use twice kick end")

    Req("DL2U2I", "DarkLord", "BlazingDownfallUseTwice", "startup", "Blazing Downfall use twice startup")
    Req("DL2U2B", "DarkLord", "BlazingDownfallUseTwice", "use", "Blazing Downfall use twice blitz")
    Req("DL2U2HS", "DarkLord", "BlazingDownfallUseTwice", "end", "Blazing Downfall use twice explosion")

    Req("DL3D", "DarkLord", "3", "startup", "Skill3 windup")
    Req("DL3D3", "DarkLord", "3", "use", "Skill3 stab")
    Req("DL3Throw", "DarkLord", "3", "use", "Skill3 throw")
    Req("DL3VT", "DarkLord", "3", "hit", "Skill3 victim trail")
    Req("DL3Barrage", "DarkLord", "3", "use", "Skill3 barrage")
    Req("DL3Slash", "DarkLord", "3", "end", "Skill3 final slash")

    Req("DL4", "DarkLord", "4", "startup", "Skill4 laser cast")
    Req("DL4M", "DarkLord", "4", "use", "Skill4 laser eyes")
    Req("DL4Miss", "DarkLord", "4", "end", "Skill4 laser miss")
    Req("DL4Release", "DarkLord", "4", "end", "Skill4 laser release")
    Req("DL4Grab", "DarkLord", "4", "use", "Skill4 laser grab")

    Req("DL42MI", "DarkLord", "4_2", "startup", "Skill4 stop time cast")
    Req("DL42M", "DarkLord", "4_2", "use", "Skill4 stop time move")
    Req("DL42W", "DarkLord", "4_2", "use", "Skill4 stop time whiff slash")
    Req("DL42R", "DarkLord", "4_2", "end", "Skill4 stop time release slash")
    Req("DL42H", "DarkLord", "4_2", "hit", "Skill4 stop time hit")

    Req("DLFDSM", "DarkLord", "FrontDash", "use", "FrontDash miss single")
    Req("DLFDDM", "DarkLord", "FrontDash", "use", "FrontDash miss twin")
    Req("DLFrontDashHit", "DarkLord", "FrontDash", "hit", "FrontDash hit")
    Req("DLMTick", "DarkLord", "Status", "hit", "Status tick")

    Req("VORS", "VirusOverlord", "CorruptedSpikes", "startup", "Corrupted Spikes start")
    Req("VORU", "VirusOverlord", "CorruptedSpikes", "use", "Corrupted Spikes use")
    Req("VORH", "VirusOverlord", "CorruptedSpikes", "hit", "Corrupted Spikes hit")
    Req("VORB", "VirusOverlord", "CorruptedSpikes", "use", "Corrupted Spikes back jump")

    Req("VORFDS", "VirusOverlord", "FrontDash", "use", "FrontDash swing")
    Req("VODFDS", "VirusOverlord", "FrontDash", "use", "FrontDash double swing")
    Req("VOFrontDashEffects", "VirusOverlord", "FrontDash", "use", "FrontDash dash")

    Req("VOTBUpper", "VirusOverlord", "M1", "hit", "Twin blade uppercut")

    for Step = 1, 6 do
        Req("VOS" .. Step, "VirusOverlord", "M1", "use", "M1 swing " .. Step)
    end

    for Step = 1, 4 do
        Req("VOBS" .. Step, "VirusOverlord", "M1", "use", "Blade M1 swing " .. Step)
        Req("VOM1S" .. Step, "VirusOverlord", "M1", "use", "M1 single " .. Step)
    end

    for Step = 1, 5 do
        Req("VOTBS" .. Step, "VirusOverlord", "M1", "use", "Twin blade M1 swing " .. Step)
        Req("VOM1TS" .. Step, "VirusOverlord", "M1", "use", "M1 twin " .. Step)
    end

    local function DataCharacter(Value)
        if typeof(Value) ~= "Instance" then
            return nil
        end

        if Value:IsA("Player") then
            return Value.Character
        end

        if Value:IsA("Model") then
            return Value
        end

        return nil
    end

    local function RecordRequest(Key, Data)
        local Info = RequestMap[Key]

        if not Info then
            return false
        end

        local User = nil
        local Victim = nil

        if type(Data) == "table" then
            User = DataCharacter(Data.U)
            Victim = DataCharacter(Data.T)
        end

        local Owner = User or Victim
        local Position = nil

        if Owner then
            local Root = Owner:FindFirstChild("HumanoidRootPart")

            Position = Root and Root.Position
        end

        local Meta = Info

        if not User and Victim and Info.Phase ~= "hit" then
            Meta = setmetatable({ Phase = "hit" }, { __index = Info })
        end

        if Config.Debug then
            print("[KRGN] request", Key, Owner and Owner.Name or "nil")
        end

        RecordEvent("Request", Key .. "@" .. (Owner and Owner.Name or ""), Owner, Position, 20, true, Meta)

        return true
    end

    local function HandleRequests(Args)
        local Found = false

        for Index = 1, math.min(Args.n or #Args, 4) do
            local Value = Args[Index]

            if type(Value) == "string" then
                if RequestMap[Value] then
                    Found = RecordRequest(Value, Args[Index + 1]) or Found
                end
            elseif type(Value) == "table" then
                local Key = Value.Request

                if type(Key) == "string" then
                    Found = RecordRequest(Key, Value) or Found
                else
                    for Item = 1, math.min(#Value, 12) do
                        local Entry = Value[Item]

                        if type(Entry) == "table" and type(Entry.Request) == "string" then
                            Found = RecordRequest(Entry.Request, Entry) or Found
                        end
                    end
                end
            end
        end

        return Found
    end

    local function HookRemote(Remote)
        if HookedRemotes[Remote] then
            return
        end

        if not (Remote:IsA("RemoteEvent") or Remote:IsA("UnreliableRemoteEvent")) then
            return
        end

        HookedRemotes[Remote] = true

        Remote.OnClientEvent:Connect(function(...)
            local Args = table.pack(...)

            if HandleRequests(Args) then
                return
            end

            if Config.Debug and DebugBudget > 0 and Remote.Name:lower():find("render") then
                DebugBudget -= 1

                local First = Args[1]
                local Shape = typeof(First)

                if type(First) == "table" then
                    local Keys = {}

                    for Key in pairs(First) do
                        Keys[#Keys + 1] = tostring(Key)

                        if #Keys >= 8 then
                            break
                        end
                    end

                    Shape = "table{" .. table.concat(Keys, ",") .. "}"
                elseif type(First) == "string" then
                    Shape = "string " .. First
                end

                print("[KRGN] remote", Remote:GetFullName(), Shape, typeof(Args[2]))
            end

            if IsNoisy(Remote, NoiseLimit) then
                return
            end

            EmitRemote(Remote, Args, nil)
        end)
    end

    local function IndexInstance(Inst, Full)
        if Full and EmitterClasses[Inst.ClassName] and Inst.Parent and PathUnderFocus(Inst) then
            local EmitterKey = Inst.Parent.Name .. "|" .. Inst.Name
            local EmitterList = EmitterIndex[EmitterKey]

            if not EmitterList then
                EmitterList = {}
                EmitterIndex[EmitterKey] = EmitterList
            end

            if #EmitterList < 40 then
                EmitterList[#EmitterList + 1] = Inst
            end
        end

        if Full and (Inst:IsA("BasePart") or Inst:IsA("Attachment")) and not LibNames[Inst.Name] and PathUnderFocus(Inst) then
            LibNames[Inst.Name] = true
        end

        if Inst:IsA("Animation") then
            local ID = GetAnimationID(Inst)

            if ID then
                local List = AnimIndex[ID]

                if not List then
                    List = {}
                    AnimIndex[ID] = List
                end

                if #List < 12 then
                    List[#List + 1] = Inst
                end
            end
        end

        if Inst:IsA("RemoteEvent") or Inst:IsA("UnreliableRemoteEvent") then
            HookRemote(Inst)
        end

        if Full then
            local Name = Inst.Name

            if not IsGeneric(Name) then
                local List = NameIndex[Name]

                if not List then
                    List = {}
                    NameIndex[Name] = List
                end

                if #List < 25 then
                    List[#List + 1] = Inst
                end
            end
        end
    end

    local IndexJobs = {}

    local function IndexRoot(Root, Full)
        local Ok, List = pcall(function()
            return Root:GetDescendants()
        end)

        if Ok then
            IndexJobs[#IndexJobs + 1] = { List = List, Count = #List, Index = 1, Full = Full }
        end

        Root.DescendantAdded:Connect(function(Inst)
            IndexInstance(Inst, Full)
        end)
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        local Job = IndexJobs[1]

        if not Job then
            return
        end

        local Start = os.clock()

        while Job.Index <= Job.Count and os.clock() - Start < 0.003 do
            local Inst = Job.List[Job.Index]

            Job.List[Job.Index] = false
            Job.Index += 1

            if Inst and Inst.Parent then
                IndexInstance(Inst, Job.Full)
            end
        end

        if Job.Index > Job.Count then
            table.remove(IndexJobs, 1)
        end
    end)

    local ScanBudget = 0.0015
    local ScanQueue = {}
    local ScanHead = 1
    local ScanTail = 0

    local function ScanPush(Inst, Focus)
        ScanTail += 1
        ScanQueue[ScanTail] = { Inst = Inst, Focus = Focus, Children = nil, Index = 1 }
    end

    for _, Root in ipairs({ ReplicatedStorage, ReplicatedFirst, StarterPlayer, StarterPack }) do
        ScanPush(Root, false)
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        local Start = os.clock()

        while ScanHead <= ScanTail and os.clock() - Start < ScanBudget do
            local Item = ScanQueue[ScanHead]

            if not Item.Children then
                local Ok, Children = pcall(Item.Inst.GetChildren, Item.Inst)

                Item.Children = Ok and Children or {}
            end

            local Children = Item.Children
            local Total = #Children

            while Item.Index <= Total and os.clock() - Start < ScanBudget do
                local Child = Children[Item.Index]

                Children[Item.Index] = false
                Item.Index += 1

                if Child and Child.Parent then
                    local Class = Child.ClassName
                    local ChildFocus = Item.Focus

                    if not ChildFocus and FocusRoots[RootKey(Child.Name)] and (Class == "Folder" or Class == "Model" or Class == "Configuration") then
                        ChildFocus = true

                        Child.DescendantAdded:Connect(function(Inst)
                            IndexInstance(Inst, true)
                        end)
                    end

                    if ChildFocus then
                        IndexInstance(Child, true)
                    elseif Class == "Animation" then
                        IndexInstance(Child, false)
                    elseif Class == "RemoteEvent" or Class == "UnreliableRemoteEvent" then
                        HookRemote(Child)
                    end

                    if ChildFocus or Class == "Folder" or Class == "Configuration" then
                        ScanPush(Child, ChildFocus)
                    end
                end
            end

            if Item.Index > Total then
                ScanQueue[ScanHead] = false
                ScanHead += 1
            end
        end

        if ScanHead > ScanTail then
            ScanQueue = {}
            ScanHead = 1
            ScanTail = 0
        end
    end)

    ReplicatedStorage.DescendantAdded:Connect(function(Inst)
        if Inst:IsA("RemoteEvent") or Inst:IsA("UnreliableRemoteEvent") then
            HookRemote(Inst)
        end
    end)

    Workspace.DescendantAdded:Connect(function(Inst)
        if Inst.ClassName == "Animation" then
            IndexInstance(Inst, false)
        end
    end)

    local function LookupAnim(ID)
        local Found = {}
        local List = AnimIndex[ID]

        if not List then
            return Found
        end

        for _, Anim in ipairs(List) do
            if Anim.Parent then
                for Index, Entry in ipairs(DeriveNames(Anim)) do
                    if Index > 4 then
                        break
                    end

                    Found[#Found + 1] = { Name = Entry.Name, Weight = Index == 1 and 6 or 5 }
                end

                for _, AttrValue in pairs(Anim:GetAttributes()) do
                    if type(AttrValue) == "string" and not IsGeneric(AttrValue) then
                        Found[#Found + 1] = { Name = AttrValue, Weight = 5 }
                    end
                end
            end
        end

        return Found
    end

    local function LookupLibrary(Name)
        local Found = {}
        local List = NameIndex[Name]

        if not List then
            return Found
        end

        local Scale = math.min(1, 3 / #List)

        for _, Inst in ipairs(List) do
            if Inst.Parent then
                for Index, Entry in ipairs(DeriveNames(Inst)) do
                    if Index > 1 and Index <= 4 then
                        Found[#Found + 1] = { Name = Entry.Name, Weight = 4 * Scale }
                    end
                end
            end
        end

        return Found
    end

    NameFromIndex = function(ID)
        local BestName = nil
        local BestWeight = 0

        for _, Entry in ipairs(LookupAnim(ID)) do
            if Entry.Weight > BestWeight then
                BestName = Entry.Name
                BestWeight = Entry.Weight
            end
        end

        return BestName
    end

    local function IsInteresting(Inst)
        return InterestingClasses[Inst.ClassName] == true or LibNames[Inst.Name] == true or CloneSource[Inst] ~= nil
    end

    local function ProcessInstance(Inst)
        if not Inst.Parent or not IsInteresting(Inst) then
            return
        end

        local Char = GetCharacterOf(Inst)

        if Char then
            local BornAt = Born[Char]

            if BornAt and os.clock() - BornAt < BornGrace then
                return
            end

            if Inst.Parent == Char then
                return
            end

            if Inst:FindFirstAncestorOfClass("Accessory") then
                return
            end

            if Inst:IsA("Attachment") and Inst.Parent and Inst.Parent.Parent == Char then
                return
            end
        end

        local Source = FindCloneSource(Inst)

        if Source then
            local SourceInfo = PathUnderFocus(Source)

            if SourceInfo then
                RecordEvent("Clone", SourceInfo.Root .. "/" .. (SourceInfo.Move or ""), Char, GetPosition(Inst), 14, true, SourceInfo)
            end
        end

        if EmitterClasses[Inst.ClassName] and Inst.Parent then
            MatchEmitter(Inst, Char)
        end

        local Entries = DeriveNames(Inst)

        if not Entries[1] then
            return
        end

        if IsNoisy(Entries[1].Name, 60) then
            return
        end

        local Position = GetPosition(Inst)
        local Kind = Inst:IsA("Sound") and "Sound" or "VFX"

        for Index, Entry in ipairs(Entries) do
            if Index > 4 then
                break
            end

            RecordEvent(Kind, Entry.Name, Char, Position, Index == 1 and 3 or 4)
        end
    end

    local Pending = {}
    local PendingHead = 1
    local PendingTail = 0

    Workspace.DescendantAdded:Connect(function(Inst)
        if not (InterestingClasses[Inst.ClassName] or LibNames[Inst.Name] or CloneSource[Inst]) then
            return
        end

        if PendingTail - PendingHead > 600 then
            return
        end

        PendingTail += 1
        Pending[PendingTail] = Inst
    end)

    game:GetService("RunService").Heartbeat:Connect(function()
        local Start = os.clock()

        while PendingHead <= PendingTail and os.clock() - Start < 0.002 do
            local Inst = Pending[PendingHead]

            Pending[PendingHead] = nil
            PendingHead += 1

            ProcessInstance(Inst)
        end

        if PendingHead > PendingTail then
            PendingHead = 1
            PendingTail = 0
        end
    end)

    DisconnectBag = function(Bag)
        if not Bag then
            return
        end

        for _, Connection in ipairs(Bag) do
            pcall(function()
                Connection:Disconnect()
            end)
        end
    end

    MarkBorn = function(Character)
        Born[Character] = os.clock()
    end

    WatchCharacterEvents = function(Character, Bag)
        local Targets = { Character }
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local Root = Character:FindFirstChild("HumanoidRootPart")
        local OwnerPlayer = Players:GetPlayerFromCharacter(Character)

        if Humanoid then
            Targets[#Targets + 1] = Humanoid
        end

        if Root then
            Targets[#Targets + 1] = Root
        end

        if OwnerPlayer then
            Targets[#Targets + 1] = OwnerPlayer
        end

        for _, Target in ipairs(Targets) do
            Bag[#Bag + 1] = Target.AttributeChanged:Connect(function(Name)
                if IsNoisy("attr|" .. Name, 25) then
                    return
                end

                local Value = Target:GetAttribute(Name)
                local Kind = type(Value)

                if Kind == "string" then
                    if #Value > 0 and #Value <= 40 then
                        RecordEvent("Attr", Value, Character, nil, 6)
                        RecordEvent("Attr", Name, Character, nil, 2)
                    end
                elseif Value == true then
                    RecordEvent("Attr", Name, Character, nil, 4)
                elseif Kind == "number" then
                    RecordEvent("Attr", Name, Character, nil, 1.5)
                end
            end)
        end

        local Count = 0

        local function Hook(Inst)
            if Count > 80 then
                return
            end

            if Inst:IsA("ValueBase") then
                Count += 1

                Bag[#Bag + 1] = Inst.Changed:Connect(function(Value)
                    if IsNoisy(Inst, 20) then
                        return
                    end

                    if type(Value) == "string" and #Value > 0 and #Value <= 40 then
                        RecordEvent("Value", Value, Character, nil, 5)
                        RecordEvent("Value", Inst.Name, Character, nil, 2)
                    elseif Value == true then
                        RecordEvent("Value", Inst.Name, Character, nil, 3)
                    end
                end)
            end
        end

        for _, Inst in ipairs(Character:GetDescendants()) do
            Hook(Inst)
        end

        Bag[#Bag + 1] = Character.DescendantAdded:Connect(Hook)
    end

    local function KindText(Entry)
        local Kinds = {}

        for Kind in pairs(Entry.Kinds) do
            Kinds[#Kinds + 1] = Kind
        end

        table.sort(Kinds)

        return table.concat(Kinds, "+")
    end

    ResolveMove = function(Animation, Character, At, Track)
        local Scores = {}
        local LibraryCache = {}
        local Votes = {}
        local FocusCache = {}
        local PhaseTexts = {}

        local function Vote(Root, Move, Sub, Weight, Kind, Foreign, MoveInst, Req)
            local Key = Move and (Root .. "/" .. Move) or Root
            local Entry = Votes[Key]

            if not Entry then
                Entry = { Key = Key, Root = Root, Move = Move, Score = 0, Foreign = 0, Subs = {}, KindScore = {} }
                Votes[Key] = Entry
            end

            if MoveInst and not Entry.MoveInst then
                Entry.MoveInst = MoveInst
            end

            if Req then
                Entry.Reqs = Entry.Reqs or {}

                local Slot = Entry.Reqs[Req.Req]

                if not Slot then
                    Slot = { Info = Req, Score = 0, Foreign = 0 }
                    Entry.Reqs[Req.Req] = Slot
                end

                Slot.Score += Weight

                if Foreign then
                    Slot.Foreign += Weight
                end
            end

            if MoveInst and not (MoveInst:IsA("Folder") or MoveInst:IsA("Model") or MoveInst:IsA("Configuration")) then
                Weight = Weight * 0.3
            end

            local Used = Entry.KindScore[Kind] or 0
            local Room = KindCap - Used

            if Room <= 0 then
                return
            end

            if Weight > Room then
                Weight = Room
            end

            Entry.KindScore[Kind] = Used + Weight
            Entry.Score += Weight

            if Foreign then
                Entry.Foreign += Weight
            end

            if Sub then
                Entry.Subs[Sub] = (Entry.Subs[Sub] or 0) + Weight
            end
        end

        local function VoteName(Name, Kind, Weight, Foreign)
            local Lower = Name:lower()
            local BestKeyword = nil
            local BestCanon = nil

            for Keyword, Canon in pairs(FocusKeywords) do
                if Lower:find(Keyword, 1, true) and (not BestKeyword or #Keyword > #BestKeyword) then
                    BestKeyword = Keyword
                    BestCanon = Canon
                end
            end

            if BestCanon then
                Vote(BestCanon, nil, nil, Weight * 0.6, Kind, Foreign)
            end

            local Infos = FocusCache[Name]

            if not Infos then
                Infos = {}

                local List = NameIndex[Name]

                if List then
                    for _, Inst in ipairs(List) do
                        if Inst.Parent then
                            local Info = PathUnderFocus(Inst)

                            if Info then
                                Infos[#Infos + 1] = Info
                            end
                        end
                    end
                end

                FocusCache[Name] = Infos
            end

            if #Infos > 0 then
                local Unique = {}
                local UniqueCount = 0

                for _, Info in ipairs(Infos) do
                    local UniqueKey = Info.Root .. "/" .. (Info.Move or "")

                    if not Unique[UniqueKey] then
                        Unique[UniqueKey] = Info
                        UniqueCount += 1
                    end
                end

                local Share = UniqueCount == 1 and 1.3 or math.min(1, 2 / UniqueCount)

                for _, Info in pairs(Unique) do
                    Vote(Info.Root, Info.Move, Info.Sub, Weight * 0.8 * Share, Kind, Foreign, Info.MoveInst)
                end
            end
        end

        local function Add(Name, Kind, Weight, FocusScale)
            if type(Name) ~= "string" then
                return
            end

            if Kind ~= "Key" and Kind ~= "Snap" and Kind ~= "Tool" then
                VoteName(Name, Kind, Weight * (FocusScale or 1), false)
            end

            Name = StripSuffix(Name)

            if IsGeneric(Name) then
                return
            end

            local Key = NormKey(Name)
            local Entry = Scores[Key]

            if not Entry then
                Entry = {
                    Key = Key,
                    Best = Name,
                    BestWeight = 0,
                    Kinds = {},
                    KindScore = {},
                    KindCount = 0,
                    Score = 0,
                    Support = 0,
                    Final = 0
                }

                Scores[Key] = Entry
            end

            local Used = Entry.KindScore[Kind] or 0
            local Room = KindCap - Used

            if Room <= 0 then
                return
            end

            if Weight > Room then
                Weight = Room
            end

            Entry.KindScore[Kind] = Used + Weight
            Entry.Score += Weight

            if not Entry.Kinds[Kind] then
                Entry.Kinds[Kind] = true
                Entry.KindCount += 1
            end

            if Weight > Entry.BestWeight then
                Entry.Best = Name
                Entry.BestWeight = Weight
            end
        end

        local RootPosition = nil
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root then
            RootPosition = Root.Position
        end

        for _, Event in ipairs(Events) do
            local Diff = Event.Time - At

            if Diff >= -EventWindowBefore and Diff <= EventWindowAfter then
                local Scale = nil
                local Foreign = false
                local Weak = false

                if Event.Owner ~= nil then
                    if Event.Owner == Character then
                        Scale = 1.3
                    elseif Event.Meta and Event.Position and RootPosition and (Event.Position - RootPosition).Magnitude <= NearRadius then
                        Scale = 0.5
                        Foreign = true
                    end
                elseif Event.Position and RootPosition then
                    local Distance = (Event.Position - RootPosition).Magnitude

                    if Distance <= NearRadius then
                        Scale = math.max(0.2, 1 - Distance / (NearRadius * 1.3))
                    end
                elseif Event.Meta then
                    Scale = nil
                else
                    Scale = 0.6
                    Weak = true
                end

                if Scale then
                    local Closeness = math.max(0.3, 1 - math.abs(Diff) / 1.2)
                    local Factor = Scale * Closeness

                    if Event.Meta then
                        Vote(Event.Meta.Root, Event.Meta.Move, Event.Meta.Sub, Event.Weight * Factor, Event.Kind, Foreign, Event.Meta.MoveInst, Event.Kind == "Request" and Event.Meta or nil)
                    else
                        Add(Event.Name, Event.Kind, Event.Weight * Factor, Weak and 0.3 or 1)
                    end

                    local LibraryScale = LibraryKinds[Event.Kind]

                    if LibraryScale then
                        local Found = LibraryCache[Event.Name]

                        if not Found then
                            Found = LookupLibrary(Event.Name)
                            LibraryCache[Event.Name] = Found
                        end

                        for _, Entry in ipairs(Found) do
                            Add(Entry.Name, "Folder", Entry.Weight * Factor * LibraryScale)
                        end
                    end
                end
            end
        end

        Add(Animation.Name, "Anim", 5)

        if Track and Track.Name ~= Animation.Name then
            Add(Track.Name, "Anim", 4)
        end

        local ID = GetAnimationID(Animation)

        if ID then
            for _, Entry in ipairs(LookupAnim(ID)) do
                Add(Entry.Name, "Anim", Entry.Weight)
            end
        end

        PhaseTexts[#PhaseTexts + 1] = Animation.Name

        if Track then
            PhaseTexts[#PhaseTexts + 1] = Track.Name
        end

        if ID then
            for _, Anim in ipairs(AnimIndex[ID] or {}) do
                if Anim.Parent then
                    PhaseTexts[#PhaseTexts + 1] = Anim.Name

                    local Info = PathUnderFocus(Anim)

                    if Info then
                        Vote(Info.Root, Info.Move, Info.Sub, 14, "Anim", false, Info.MoveInst)
                    end
                end
            end
        end

        for _, AttrValue in pairs(Animation:GetAttributes()) do
            if type(AttrValue) == "string" then
                Add(AttrValue, "Anim", 5)
            end
        end

        local Tool = Character and Character:FindFirstChildOfClass("Tool")

        if Character then
            local Holders = { Character }
            local Humanoid = Character:FindFirstChildOfClass("Humanoid")

            if Humanoid then
                Holders[#Holders + 1] = Humanoid
            end

            for _, Holder in ipairs(Holders) do
                for AttrName, AttrValue in pairs(Holder:GetAttributes()) do
                    if type(AttrValue) == "string" and #AttrValue <= 40 then
                        Add(AttrValue, "Snap", 3)
                    elseif AttrValue == true then
                        Add(AttrName, "Snap", 2.5)
                    end
                end
            end

        end

        if Tool then
            Add(Tool.Name, "Tool", 1.5)
        end

        local List = {}

        for _, Entry in pairs(Scores) do
            local Bonus = (Entry.KindCount - 1) * 2
            local Indexed = NameIndex[Entry.Best]

            if Indexed then
                for _, Inst in ipairs(Indexed) do
                    if Inst.Parent and (Inst:IsA("Folder") or Inst:IsA("Model") or Inst:IsA("ModuleScript") or Inst:IsA("Configuration")) then
                        Bonus += 1.5
                        break
                    end
                end
            end

            Entry.Final = Entry.Score + Bonus
            List[#List + 1] = Entry
        end

        for _, A in ipairs(List) do
            for _, B in ipairs(List) do
                if A ~= B and #B.Key >= 4 and A.Key:find(B.Key, 1, true) then
                    A.Support += B.Score * 0.4
                end
            end
        end

        for _, Entry in ipairs(List) do
            Entry.Final += Entry.Support
        end

        table.sort(List, function(A, B)
            return A.Final > B.Final
        end)

        local ToolText = Tool and ("[" .. Tool.Name .. "]") or nil

        local VoteList = {}

        local Lock = Character and CharacterLock[Character]

        for _, Entry in pairs(Votes) do
            if Lock and Entry.Root ~= Lock then
                Entry.Score = Entry.Score * 0.4
            end

            VoteList[#VoteList + 1] = Entry
        end

        table.sort(VoteList, function(A, B)
            return A.Score > B.Score
        end)

        local TopVote = VoteList[1]

        local SecondVote = VoteList[2]
        local HasAnim = TopVote and (TopVote.KindScore.Anim or 0) > 0
        local Strong = TopVote and (HasAnim or (TopVote.KindScore.Emitter or 0) + (TopVote.KindScore.Clone or 0) >= 3 or (TopVote.KindScore.Request or 0) >= 3)
        local Clear = TopVote and (HasAnim or not SecondVote or TopVote.Score >= SecondVote.Score * 1.25)

        if TopVote and Strong and Clear and Character and not CharacterLock[Character] and TopVote.Score >= 10 then
            CharacterLock[Character] = TopVote.Root
        end

        if Config.Debug then
            local Recent = 0

            for _, Event in ipairs(Events) do
                if math.abs(Event.Time - At) <= 1.2 then
                    Recent += 1
                end
            end

            print("[KRGN]", Animation.Name, tostring(ID), "events", Recent, "votes", #VoteList, TopVote and TopVote.Key or "none", TopVote and math.floor(TopVote.Score * 10) / 10 or 0, "anim indexed", AnimIndex[ID or ""] ~= nil)
        end

        local Allowed = TopVote and (not FocusCharacters or FocusCharacters[TopVote.Root])

        if TopVote and Allowed and Strong and Clear and TopVote.Score >= 4 then
            local SubList = {}

            for Sub, SubWeight in pairs(TopVote.Subs) do
                SubList[#SubList + 1] = { Name = Sub, Weight = SubWeight }
            end

            table.sort(SubList, function(A, B)
                return A.Weight > B.Weight
            end)

            local Phase = nil

            if TopVote.Foreign > TopVote.Score * 0.6 then
                Phase = "hit"
            end

            if not Phase then
                for _, Text in ipairs(PhaseTexts) do
                    Phase = PhaseOf(Text)

                    if Phase then
                        break
                    end
                end
            end

            if not Phase then
                for _, Sub in ipairs(SubList) do
                    Phase = PhaseOf(Sub.Name)

                    if Phase then
                        break
                    end
                end
            end

            if not Phase and TopVote.Move then
                Phase = PhaseOf(TopVote.Move)
            end

            local BestReq = nil

            if TopVote.Reqs then
                for _, Slot in pairs(TopVote.Reqs) do
                    if not BestReq or Slot.Score > BestReq.Score then
                        BestReq = Slot
                    end
                end
            end

            if BestReq and BestReq.Foreign < BestReq.Score * 0.5 and BestReq.Info.Phase then
                Phase = BestReq.Info.Phase
            end

            Phase = Phase or "use"

            local Parts = {}
            local SubNames = {}

            for Index = 1, math.min(#SubList, 3) do
                SubNames[#SubNames + 1] = SubList[Index].Name
            end

            if #SubNames > 0 then
                Parts[#Parts + 1] = table.concat(SubNames, ", ")
            end

            for Index = 2, math.min(#VoteList, 3) do
                Parts[#Parts + 1] = VoteList[Index].Key
            end

            if ToolText then
                Parts[#Parts + 1] = ToolText
            end

            local Via = {}

            for ViaKind in pairs(TopVote.KindScore) do
                Via[#Via + 1] = ViaKind
            end

            table.sort(Via)
            Parts[#Parts + 1] = "via " .. table.concat(Via, "+")

            local Label = TopVote.Key

            if BestReq then
                Label = TopVote.Root .. "/" .. BestReq.Info.Label .. " (" .. BestReq.Info.Req .. ")"
            end

            if not BestReq and TopVote.Move and TopVote.Move:match("^[%d_]+$") then
                local Signature = MoveSignature(TopVote.MoveInst)
                local Slot = "Skill" .. TopVote.Move

                Label = Label .. " (" .. Slot .. (Signature and (": " .. Signature) or "") .. ")"
            end

            return Label .. " [" .. Phase .. "]", table.concat(Parts, " | ")
        end

        if FocusOnly then
            return nil, ""
        end

        if #List == 0 then
            return "Unknown", "ev " .. #Events .. " votes " .. #VoteList .. (ToolText and (" | " .. ToolText) or "")
        end

        local Best = List[1]
        local Main = Best.Best .. " (" .. KindText(Best) .. ")"
        local Others = {}

        for Index = 2, math.min(#List, 4) do
            Others[#Others + 1] = List[Index].Best
        end

        if ToolText then
            Others[#Others + 1] = ToolText
        end

        return Main, table.concat(Others, " | ")
    end

    local EmitSeen = setmetatable({}, { __mode = "k" })
    local EmitQueue = {}

    if hookfunction and Config.CloneHook then
        pcall(function()
            local Probe = Instance.new("Folder")
            local OriginalClone

            local function CloneHook(Self, ...)
                local Result = OriginalClone(Self, ...)

                if typeof(Result) == "Instance" then
                    CloneSource[Result] = Self
                end

                return Result
            end

            OriginalClone = hookfunction(Probe.Clone, newcclosure and newcclosure(CloneHook) or CloneHook)
            Probe:Destroy()
        end)
    end

    if hookfunction and Config.EmitHook then
        pcall(function()
            local Probe = Instance.new("ParticleEmitter")
            local OriginalEmit

            local function EmitHook(Self, ...)
                if typeof(Self) == "Instance" then
                    local Now = os.clock()
                    local Last = EmitSeen[Self]

                    if not Last or Now - Last > 0.6 then
                        EmitSeen[Self] = Now

                        if #EmitQueue < 200 then
                            EmitQueue[#EmitQueue + 1] = Self
                        end
                    end
                end

                return OriginalEmit(Self, ...)
            end

            OriginalEmit = hookfunction(Probe.Emit, newcclosure and newcclosure(EmitHook) or EmitHook)
            Probe:Destroy()
        end)
    end

    if hookfunction and Config.SendHook then
        pcall(function()
            local RemoteProbe = Instance.new("RemoteEvent")
            local FunctionProbe = Instance.new("RemoteFunction")
            local OriginalFire
            local OriginalInvoke

            local function Track(Self, ...)
                if typeof(Self) == "Instance" and not IsNoisy(Self, NoiseLimit) then
                    local Args = table.pack(...)
                    local Owner = Player.Character

                    task.defer(function()
                        EmitRemote(Self, Args, Owner)
                    end)
                end
            end

            local function FireHook(Self, ...)
                Track(Self, ...)

                return OriginalFire(Self, ...)
            end

            local function InvokeHook(Self, ...)
                Track(Self, ...)

                return OriginalInvoke(Self, ...)
            end

            OriginalFire = hookfunction(RemoteProbe.FireServer, newcclosure and newcclosure(FireHook) or FireHook)
            OriginalInvoke = hookfunction(FunctionProbe.InvokeServer, newcclosure and newcclosure(InvokeHook) or InvokeHook)

            RemoteProbe:Destroy()
            FunctionProbe:Destroy()
        end)
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        local Start = os.clock()

        while #EmitQueue > 0 and os.clock() - Start < 0.001 do
            local Emitter = table.remove(EmitQueue, 1)

            if Emitter.Parent and Emitter:IsA("ParticleEmitter") then
                MatchEmitter(Emitter, GetCharacterOf(Emitter))
            end
        end
    end)
end

UserInputService.InputBegan:Connect(function(Input)
    local Name

    if Input.UserInputType == Enum.UserInputType.Keyboard then
        Name = Input.KeyCode.Name

        if IgnoredKeys[Name] then
            return
        end
    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
        Name = "M1"
    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
        Name = "M2"
    else
        return
    end

    RecordEvent("Key", Name, Player.Character, nil, 1, true)
end)

local Old = PlayerGui:FindFirstChild("KRGNScripts")

if Old then
    Old:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "KRGNScripts"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(660, 400)
Main.Position = UDim2.new(0.5, -330, 0.5, -200)
Main.BackgroundColor3 = COLORS.Background
Main.BorderSizePixel = 0
Main.ZIndex = 1
Main.Parent = Gui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = COLORS.Border
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 0, 25)
Title.Position = UDim2.fromOffset(12, 7)
Title.BackgroundTransparency = 1
Title.Text = "KRGN Scripts"
Title.TextColor3 = COLORS.Text
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3
Title.Parent = Main

local Support = Instance.new("TextLabel")
Support.Size = UDim2.new(1, -24, 0, 18)
Support.Position = UDim2.fromOffset(12, 34)
Support.BackgroundTransparency = 1
Support.Text = "follow @hi_guys678000, for support :D"
Support.TextColor3 = COLORS.SubText
Support.TextSize = 10
Support.Font = Enum.Font.Gotham
Support.TextXAlignment = Enum.TextXAlignment.Left
Support.ZIndex = 3
Support.Parent = Main

local function MakeTopButton(Text, Position)

    local Button = Instance.new("TextButton")

    Button.Size = UDim2.fromOffset(28, 28)
    Button.Position = Position

    Button.BackgroundColor3 =
        Color3.fromRGB(45, 45, 48)

    Button.BorderSizePixel = 0

    Button.Text = Text
    Button.TextColor3 = COLORS.Text
    Button.TextSize = 18
    Button.Font = Enum.Font.GothamMedium

    Button.AutoButtonColor = false
    Button.ZIndex = 4
    Button.Parent = Main

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Button

    Button.MouseEnter:Connect(function()

        TweenService:Create(
            Button,
            TweenInfo.new(0.12),
            {
                BackgroundColor3 =
                    Color3.fromRGB(60, 60, 64)
            }
        ):Play()

    end)

    Button.MouseLeave:Connect(function()

        TweenService:Create(
            Button,
            TweenInfo.new(0.12),
            {
                BackgroundColor3 =
                    Color3.fromRGB(45, 45, 48)
            }
        ):Play()

    end)

    return Button
end

local Close =
    MakeTopButton(
        "×",
        UDim2.new(1, -38, 0, 7)
    )

local Minimize =
    MakeTopButton(
        "−",
        UDim2.new(1, -72, 0, 7)
    )

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.fromOffset(12, 62)
Divider.BackgroundColor3 = Color3.fromRGB(65, 65, 68)
Divider.BorderSizePixel = 0
Divider.ZIndex = 2
Divider.Parent = Main

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Size = UDim2.new(0.5, -18, 0, 16)
TargetLabel.Position = UDim2.fromOffset(12, 69)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "Target Player (Blank = You)"
TargetLabel.TextColor3 = COLORS.SubText
TargetLabel.TextSize = 10
TargetLabel.Font = Enum.Font.GothamMedium
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.ZIndex = 2
TargetLabel.Parent = Main

local TargetBox = Instance.new("TextBox")
TargetBox.Size = UDim2.new(0.5, -18, 0, 28)
TargetBox.Position = UDim2.fromOffset(12, 87)
TargetBox.BackgroundColor3 = COLORS.Dark
TargetBox.BorderSizePixel = 0
TargetBox.ClearTextOnFocus = false
TargetBox.PlaceholderText = "Type player username..."
TargetBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 105)
TargetBox.Text = ""
TargetBox.TextColor3 = COLORS.Text
TargetBox.TextSize = 12
TargetBox.Font = Enum.Font.Gotham
TargetBox.ZIndex = 2
TargetBox.Parent = Main

local TargetBoxCorner = Instance.new("UICorner")
TargetBoxCorner.CornerRadius = UDim.new(0, 7)
TargetBoxCorner.Parent = TargetBox

local TargetBoxStroke = Instance.new("UIStroke")
TargetBoxStroke.Color = COLORS.Border
TargetBoxStroke.Thickness = 1
TargetBoxStroke.Parent = TargetBox

local SaveUserButton = Instance.new("TextButton")
SaveUserButton.Size = UDim2.new(0.12, -7, 0, 13)
SaveUserButton.Position = UDim2.new(0.5, 6, 0, 87)
SaveUserButton.BackgroundColor3 = COLORS.Secondary
SaveUserButton.BorderSizePixel = 0
SaveUserButton.Text = "Save Yours"
SaveUserButton.TextColor3 = COLORS.Text
SaveUserButton.TextSize = 9
SaveUserButton.Font = Enum.Font.GothamMedium
SaveUserButton.AutoButtonColor = false
SaveUserButton.ZIndex = 2
SaveUserButton.Parent = Main

local SaveUserCorner = Instance.new("UICorner")
SaveUserCorner.CornerRadius = UDim.new(0, 5)
SaveUserCorner.Parent = SaveUserButton

local LoadUserButton = Instance.new("TextButton")
LoadUserButton.Size = UDim2.new(0.12, -7, 0, 13)
LoadUserButton.Position = UDim2.new(0.5, 6, 0, 102)
LoadUserButton.BackgroundColor3 = COLORS.Secondary
LoadUserButton.BorderSizePixel = 0
LoadUserButton.Text = "Load Yours"
LoadUserButton.TextColor3 = COLORS.Text
LoadUserButton.TextSize = 9
LoadUserButton.Font = Enum.Font.GothamMedium
LoadUserButton.AutoButtonColor = false
LoadUserButton.ZIndex = 2
LoadUserButton.Parent = Main

local LoadUserCorner = Instance.new("UICorner")
LoadUserCorner.CornerRadius = UDim.new(0, 5)
LoadUserCorner.Parent = LoadUserButton

local CopyUserButton = Instance.new("TextButton")
CopyUserButton.Size = UDim2.new(0.12, -7, 0, 28)
CopyUserButton.Position = UDim2.new(0.62, 3, 0, 87)
CopyUserButton.BackgroundColor3 = Color3.fromRGB(50, 70, 50)
CopyUserButton.BorderSizePixel = 0
CopyUserButton.Text = "Copy Yours JSON"
CopyUserButton.TextColor3 = COLORS.Text
CopyUserButton.TextSize = 9
CopyUserButton.Font = Enum.Font.GothamMedium
CopyUserButton.AutoButtonColor = false
CopyUserButton.ZIndex = 2
CopyUserButton.Parent = Main

local CopyUserCorner = Instance.new("UICorner")
CopyUserCorner.CornerRadius = UDim.new(0, 5)
CopyUserCorner.Parent = CopyUserButton

local SaveTargetButton = Instance.new("TextButton")
SaveTargetButton.Size = UDim2.new(0.12, -7, 0, 13)
SaveTargetButton.Position = UDim2.new(0.75, 2, 0, 87)
SaveTargetButton.BackgroundColor3 = COLORS.Secondary
SaveTargetButton.BorderSizePixel = 0
SaveTargetButton.Text = "Save Target"
SaveTargetButton.TextColor3 = COLORS.Text
SaveTargetButton.TextSize = 9
SaveTargetButton.Font = Enum.Font.GothamMedium
SaveTargetButton.AutoButtonColor = false
SaveTargetButton.ZIndex = 2
SaveTargetButton.Parent = Main

local SaveTargetCorner = Instance.new("UICorner")
SaveTargetCorner.CornerRadius = UDim.new(0, 5)
SaveTargetCorner.Parent = SaveTargetButton

local LoadTargetButton = Instance.new("TextButton")
LoadTargetButton.Size = UDim2.new(0.12, -7, 0, 13)
LoadTargetButton.Position = UDim2.new(0.75, 2, 0, 102)
LoadTargetButton.BackgroundColor3 = COLORS.Secondary
LoadTargetButton.BorderSizePixel = 0
LoadTargetButton.Text = "Load Target"
LoadTargetButton.TextColor3 = COLORS.Text
LoadTargetButton.TextSize = 9
LoadTargetButton.Font = Enum.Font.GothamMedium
LoadTargetButton.AutoButtonColor = false
LoadTargetButton.ZIndex = 2
LoadTargetButton.Parent = Main

local LoadTargetCorner = Instance.new("UICorner")
LoadTargetCorner.CornerRadius = UDim.new(0, 5)
LoadTargetCorner.Parent = LoadTargetButton

local CopyTargetButton = Instance.new("TextButton")
CopyTargetButton.Size = UDim2.new(0.12, -7, 0, 28)
CopyTargetButton.Position = UDim2.new(0.87, -1, 0, 87)
CopyTargetButton.BackgroundColor3 = Color3.fromRGB(50, 70, 50)
CopyTargetButton.BorderSizePixel = 0
CopyTargetButton.Text = "Copy Target JSON"
CopyTargetButton.TextColor3 = COLORS.Text
CopyTargetButton.TextSize = 9
CopyTargetButton.Font = Enum.Font.GothamMedium
CopyTargetButton.AutoButtonColor = false
CopyTargetButton.ZIndex = 2
CopyTargetButton.Parent = Main

local CopyTargetCorner = Instance.new("UICorner")
CopyTargetCorner.CornerRadius = UDim.new(0, 5)
CopyTargetCorner.Parent = CopyTargetButton

local Divider2 = Instance.new("Frame")
Divider2.Size = UDim2.new(1, -24, 0, 1)
Divider2.Position = UDim2.fromOffset(12, 125)
Divider2.BackgroundColor3 = Color3.fromRGB(65, 65, 68)
Divider2.BorderSizePixel = 0
Divider2.ZIndex = 2
Divider2.Parent = Main

local LoggerTitle = Instance.new("TextLabel")
LoggerTitle.Size = UDim2.new(0.5, -18, 0, 25)
LoggerTitle.Position = UDim2.fromOffset(12, 132)
LoggerTitle.BackgroundTransparency = 1
LoggerTitle.Text = "Your Logged Animations"
LoggerTitle.TextColor3 = COLORS.Text
LoggerTitle.TextSize = 13
LoggerTitle.Font = Enum.Font.GothamMedium
LoggerTitle.TextXAlignment = Enum.TextXAlignment.Left
LoggerTitle.ZIndex = 2
LoggerTitle.Parent = Main

local LogFrame = Instance.new("ScrollingFrame")
LogFrame.Size = UDim2.new(0.5, -18, 1, -170)
LogFrame.Position = UDim2.fromOffset(12, 160)
LogFrame.BackgroundColor3 = COLORS.Dark
LogFrame.BorderSizePixel = 0
LogFrame.ScrollBarThickness = 3
LogFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 105)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogFrame.CanvasSize = UDim2.new()
LogFrame.ZIndex = 2
LogFrame.Parent = Main

local LogCorner = Instance.new("UICorner")
LogCorner.CornerRadius = UDim.new(0, 8)
LogCorner.Parent = LogFrame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 5)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = LogFrame

local LogPadding = Instance.new("UIPadding")
LogPadding.PaddingTop = UDim.new(0, 7)
LogPadding.PaddingBottom = UDim.new(0, 7)
LogPadding.PaddingLeft = UDim.new(0, 7)
LogPadding.PaddingRight = UDim.new(0, 7)
LogPadding.Parent = LogFrame

local TargetUITitle = Instance.new("TextLabel")
TargetUITitle.Size = UDim2.new(0.5, -18, 0, 25)
TargetUITitle.Position = UDim2.new(0.5, 6, 0, 132)
TargetUITitle.BackgroundTransparency = 1
TargetUITitle.Text = "Target's Active Anims (Select Player)"
TargetUITitle.TextColor3 = COLORS.Text
TargetUITitle.TextSize = 13
TargetUITitle.Font = Enum.Font.GothamMedium
TargetUITitle.TextXAlignment = Enum.TextXAlignment.Left
TargetUITitle.ZIndex = 2
TargetUITitle.Parent = Main

local TargetUIFrame = Instance.new("ScrollingFrame")
TargetUIFrame.Size = UDim2.new(0.5, -18, 1, -170)
TargetUIFrame.Position = UDim2.new(0.5, 6, 0, 160)
TargetUIFrame.BackgroundColor3 = COLORS.Dark
TargetUIFrame.BorderSizePixel = 0
TargetUIFrame.ScrollBarThickness = 3
TargetUIFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 105)
TargetUIFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
TargetUIFrame.CanvasSize = UDim2.new()
TargetUIFrame.ZIndex = 2
TargetUIFrame.Parent = Main

local TargetUICorner2 = Instance.new("UICorner")
TargetUICorner2.CornerRadius = UDim.new(0, 8)
TargetUICorner2.Parent = TargetUIFrame

local TargetUILayout = Instance.new("UIListLayout")
TargetUILayout.Padding = UDim.new(0, 5)
TargetUILayout.SortOrder = Enum.SortOrder.LayoutOrder
TargetUILayout.Parent = TargetUIFrame

local TargetUIPadding = Instance.new("UIPadding")
TargetUIPadding.PaddingTop = UDim.new(0, 7)
TargetUIPadding.PaddingBottom = UDim.new(0, 7)
TargetUIPadding.PaddingLeft = UDim.new(0, 7)
TargetUIPadding.PaddingRight = UDim.new(0, 7)
TargetUIPadding.Parent = TargetUIFrame

local Mini = Instance.new("TextButton")
Mini.Size = UDim2.fromOffset(58, 58)
Mini.Position = UDim2.new(0.5, -29, 0.5, -29)
Mini.BackgroundColor3 = COLORS.Background
Mini.BorderSizePixel = 0
Mini.Text = "KRGN"
Mini.TextColor3 = COLORS.Text
Mini.TextSize = 13
Mini.Font = Enum.Font.GothamBold
Mini.Visible = false
Mini.AutoButtonColor = false
Mini.ZIndex = 200
Mini.Parent = Gui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(1, 0)
MiniCorner.Parent = Mini

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = COLORS.Border
MiniStroke.Thickness = 1
MiniStroke.Parent = Mini

local function MakeDraggable(Object)

    local Dragging = false
    local DragStart
    local StartPosition

    Object.InputBegan:Connect(function(Input)

        if Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch then

            Dragging = true
            DragStart = Input.Position
            StartPosition = Object.Position

        end

    end)

    UserInputService.InputChanged:Connect(function(Input)

        if not Dragging then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.MouseMovement
            and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local Delta =
            Input.Position - DragStart

        Object.Position = UDim2.new(
            StartPosition.X.Scale,
            StartPosition.X.Offset + Delta.X,
            StartPosition.Y.Scale,
            StartPosition.Y.Offset + Delta.Y
        )

    end)

    UserInputService.InputEnded:Connect(function(Input)

        if Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch then

            Dragging = false

        end

    end)

end

MakeDraggable(Main)
MakeDraggable(Mini)

Close.MouseButton1Click:Connect(function()

    Gui:Destroy()

end)

Minimize.MouseButton1Click:Connect(function()

    Mini.Position = UDim2.fromOffset(
        Main.AbsolutePosition.X +
            Main.AbsoluteSize.X / 2 - 29,

        Main.AbsolutePosition.Y +
            Main.AbsoluteSize.Y / 2 - 29
    )

    Main.Visible = false
    Mini.Visible = true

    Mini.Size = UDim2.fromOffset(0, 0)

    TweenService:Create(
        Mini,
        TweenInfo.new(
            0.25,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ),
        {
            Size = UDim2.fromOffset(58, 58)
        }
    ):Play()

end)

Mini.MouseButton1Click:Connect(function()

    Main.Visible = true

    TweenService:Create(
        Mini,
        TweenInfo.new(
            0.15,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        ),
        {
            Size = UDim2.fromOffset(0, 0)
        }
    ):Play()

    task.delay(0.15, function()

        if not Gui.Parent then
            return
        end

        Mini.Visible = false
        Mini.Size = UDim2.fromOffset(58, 58)

    end)

end)

local UserLoggedAnimations = {}
local TargetLoggedAnimations = {}
local UserNames = {}
local TargetNames = {}
local UserRanIDs = {}
local UserRows = {}
local TargetRows = {}
local Gate = { Resolving = {}, Rejected = {} }

local ActiveOptions = nil
local ActiveOptionsID = nil

local function IsUnresolvedName(Name)
    return Name == "Animation" or Name:sub(1, 7) == "Unknown"
end

local function IsUnresolvedRow(Row)
    return Row ~= nil and Row.Parent ~= nil and Row:GetAttribute("Unresolved") == true
end

local function RowText(Name, ID, Extra)
    local Text = Name .. "  " .. ID

    if Extra and Extra ~= "" then
        Text = Text .. "  " .. Extra
    end

    return Text
end

local function CopyID(ID)

    if typeof(setclipboard) == "function" then

        pcall(function()
            setclipboard(ID)
        end)

    end

end

local function PlayAnimation(ID)

    local Character = Player.Character

    if not Character then
        return
    end

    local Humanoid =
        Character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not Humanoid then
        return
    end

    local Animator =
        Humanoid:FindFirstChildOfClass(
            "Animator"
        )

    if not Animator then
        return
    end

    local Animation =
        Instance.new("Animation")

    Animation.AnimationId =
        "rbxassetid://" .. ID

    local Success, Track =
        pcall(function()

            return Animator:LoadAnimation(
                Animation
            )

        end)

    if Success and Track then
        Track:Play()
    end

end

local function StopAnimation(ID)

    local Character = Player.Character

    if not Character then
        return
    end

    local Humanoid =
        Character:FindFirstChildOfClass(
            "Humanoid"
        )

    if not Humanoid then
        return
    end

    local Animator =
        Humanoid:FindFirstChildOfClass(
            "Animator"
        )

    if not Animator then
        return
    end

    for _, Track in
        ipairs(
            Animator:GetPlayingAnimationTracks()
        ) do

        local Animation =
            Track.Animation

        if Animation then

            local TrackID =
                Animation.AnimationId:match("%d+")

            if TrackID == ID then

                pcall(function()
                    Track:Stop()
                end)

            end

        end

    end

end

local function CloseOptions()

    if not ActiveOptions then
        return
    end

    local Old = ActiveOptions

    ActiveOptions = nil
    ActiveOptionsID = nil

    TweenService:Create(
        Old,
        TweenInfo.new(
            0.15,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.In
        ),
        {
            Size = UDim2.fromOffset(180, 0),
            BackgroundTransparency = 1
        }
    ):Play()

    task.delay(0.16, function()

        if Old then
            Old:Destroy()
        end

    end)

end

local function OptionButton(
    Parent,
    Text,
    Icon,
    Y
)

    local Button = Instance.new("TextButton")

    Button.Size =
        UDim2.new(1, -10, 0, 34)

    Button.Position =
        UDim2.fromOffset(5, Y)

    Button.BackgroundColor3 =
        COLORS.Hover

    Button.BackgroundTransparency = 1

    Button.BorderSizePixel = 0

    Button.Text = ""

    Button.AutoButtonColor = false

    Button.ZIndex = 1003

    Button.Parent = Parent

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 7)

    Corner.Parent = Button

    local IconBox =
        Instance.new("Frame")

    IconBox.Size =
        UDim2.fromOffset(25, 25)

    IconBox.Position =
        UDim2.fromOffset(6, 4)

    IconBox.BackgroundColor3 =
        Color3.fromRGB(52, 52, 56)

    IconBox.BorderSizePixel = 0

    IconBox.ZIndex = 1004

    IconBox.Parent = Button

    local IconCorner =
        Instance.new("UICorner")

    IconCorner.CornerRadius =
        UDim.new(0, 6)

    IconCorner.Parent = IconBox

    local Image =
        Instance.new("ImageLabel")

    Image.Size =
        UDim2.fromOffset(15, 15)

    Image.Position =
        UDim2.fromOffset(5, 5)

    Image.BackgroundTransparency = 1

    Image.Image = Icon

    Image.ImageColor3 =
        Color3.fromRGB(215, 215, 215)

    Image.ZIndex = 1005
    Image.Parent = IconBox

    local Label =
        Instance.new("TextLabel")

    Label.Size =
        UDim2.new(1, -45, 1, 0)

    Label.Position =
        UDim2.fromOffset(40, 0)

    Label.BackgroundTransparency = 1

    Label.Text = Text

    Label.TextColor3 =
        COLORS.Text

    Label.TextSize = 11

    Label.Font =
        Enum.Font.GothamMedium

    Label.TextXAlignment =
        Enum.TextXAlignment.Left

    Label.ZIndex = 1005
    Label.Parent = Button

    Button.MouseEnter:Connect(function()

        TweenService:Create(
            Button,
            TweenInfo.new(0.1),
            {
                BackgroundTransparency = 0
            }
        ):Play()

    end)

    Button.MouseLeave:Connect(function()

        TweenService:Create(
            Button,
            TweenInfo.new(0.1),
            {
                BackgroundTransparency = 1
            }
        ):Play()

    end)

    return Button

end

local function OpenOptions(
    Row,
    AnimName,
    ID
)

    if ActiveOptionsID == ID then

        CloseOptions()

        return

    end

    if ActiveOptions then
        CloseOptions()
        task.wait(0.04)
    end

    ActiveOptionsID = ID

    local Options =
        Instance.new("Frame")

    ActiveOptions = Options

    local Position =
        Row.AbsolutePosition

    Options.Size =
        UDim2.fromOffset(180, 0)

    Options.Position =
        UDim2.fromOffset(
            Position.X + 5,
            Position.Y +
                Row.AbsoluteSize.Y +
                5
        )

    Options.BackgroundColor3 =
        Color3.fromRGB(31, 31, 34)

    Options.BackgroundTransparency = 1

    Options.BorderSizePixel = 0

    Options.ZIndex = 1000

    Options.Parent = Gui

    local Shadow =
        Instance.new("Frame")

    Shadow.Size =
        UDim2.new(1, 8, 1, 8)

    Shadow.Position =
        UDim2.fromOffset(-4, 4)

    Shadow.BackgroundColor3 =
        Color3.fromRGB(0, 0, 0)

    Shadow.BackgroundTransparency = 0.75

    Shadow.BorderSizePixel = 0

    Shadow.ZIndex = 999

    Shadow.Parent = Options

    local ShadowCorner =
        Instance.new("UICorner")

    ShadowCorner.CornerRadius =
        UDim.new(0, 10)

    ShadowCorner.Parent = Shadow

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 10)

    Corner.Parent = Options

    local Stroke =
        Instance.new("UIStroke")

    Stroke.Color =
        COLORS.Border

    Stroke.Thickness = 1

    Stroke.Parent = Options

    local Header =
        Instance.new("TextLabel")

    Header.Size =
        UDim2.new(1, -18, 0, 22)

    Header.Position =
        UDim2.fromOffset(9, 5)

    Header.BackgroundTransparency = 1

    Header.Text =
        "Animation Options"

    Header.TextColor3 =
        COLORS.Text

    Header.TextSize = 12

    Header.Font =
        Enum.Font.GothamBold

    Header.TextXAlignment =
        Enum.TextXAlignment.Left

    Header.ZIndex = 1002
    Header.Parent = Options

    local Sub =
        Instance.new("TextLabel")

    Sub.Size =
        UDim2.new(1, -18, 0, 17)

    Sub.Position =
        UDim2.fromOffset(9, 26)

    Sub.BackgroundTransparency = 1

    Sub.Text =
        AnimName

    Sub.TextColor3 =
        COLORS.SubText

    Sub.TextSize = 9

    Sub.Font =
        Enum.Font.Gotham

    Sub.TextXAlignment =
        Enum.TextXAlignment.Left

    Sub.TextTruncate =
        Enum.TextTruncate.AtEnd

    Sub.ZIndex = 1002
    Sub.Parent = Options

    local Divider =
        Instance.new("Frame")

    Divider.Size =
        UDim2.new(1, -18, 0, 1)

    Divider.Position =
        UDim2.fromOffset(9, 47)

    Divider.BackgroundColor3 =
        Color3.fromRGB(65, 65, 70)

    Divider.BorderSizePixel = 0

    Divider.ZIndex = 1002
    Divider.Parent = Options

    local Play =
        OptionButton(
            Options,
            "Play animation",
            PLAY_ICON,
            52
        )

    local Stop =
        OptionButton(
            Options,
            "Stop animation",
            STOP_ICON,
            88
        )

    local Delete =
        OptionButton(
            Options,
            "Delete from log",
            DELETE_ICON,
            124
        )

    TweenService:Create(
        Options,

        TweenInfo.new(
            0.25,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ),

        {
            Size =
                UDim2.fromOffset(
                    180,
                    166
                ),

            BackgroundTransparency = 0
        }

    ):Play()

    Play.MouseButton1Click:Connect(function()

        PlayAnimation(ID)

        CloseOptions()

    end)

    Stop.MouseButton1Click:Connect(function()

        StopAnimation(ID)

        CloseOptions()

    end)

    Delete.MouseButton1Click:Connect(function()

        UserLoggedAnimations[ID] = nil
        UserRanIDs[ID] = nil
        TargetLoggedAnimations[ID] = nil
        UserNames[ID] = nil
        TargetNames[ID] = nil
        UserRows[ID] = nil
        TargetRows[ID] = nil

        CloseOptions()

        TweenService:Create(
            Row,

            TweenInfo.new(
                0.2,
                Enum.EasingStyle.Quart,
                Enum.EasingDirection.In
            ),

            {
                BackgroundTransparency = 1,
                TextTransparency = 1,
                Size =
                    UDim2.new(
                        1,
                        -4,
                        0,
                        0
                    )
            }

        ):Play()

        task.delay(0.2, function()

            if Row then
                Row:Destroy()
            end

        end)

    end)

end

local AddTargetAnimRow
local CreateLog

CreateLog = function(
    AnimName,
    ID,
    Extra
)

    if UserLoggedAnimations[ID] then

        local Existing = UserRows[ID]

        if IsUnresolvedRow(Existing) and not IsUnresolvedName(AnimName) then
            Existing.Text = RowText(AnimName, ID, Extra)
            Existing:SetAttribute("Unresolved", nil)
            UserNames[ID] = AnimName
        end

        return
    end

    UserLoggedAnimations[ID] = true
    UserRanIDs[ID] = true
    UserNames[ID] = AnimName

    local Row =
        Instance.new("TextButton")

    Row.Size =
        UDim2.new(1, -4, 0, 35)

    Row.BackgroundColor3 =
        COLORS.Secondary

    Row.BackgroundTransparency = 1

    Row.BorderSizePixel = 0

    Row.Text = RowText(AnimName, ID, Extra)

    Row.TextColor3 =
        COLORS.Text

    Row.TextTransparency = 1

    Row.TextSize = 12

    Row.Font =
        Enum.Font.Gotham

    Row.TextXAlignment =
        Enum.TextXAlignment.Left

    Row.TextTruncate =
        Enum.TextTruncate.AtEnd

    Row.AutoButtonColor = false

    Row.ZIndex = 10

    Row.Parent = LogFrame

    UserRows[ID] = Row

    if IsUnresolvedName(AnimName) then
        Row:SetAttribute("Unresolved", true)
    end

    local Corner =
        Instance.new("UICorner")

    Corner.CornerRadius =
        UDim.new(0, 6)

    Corner.Parent = Row

    local Padding =
        Instance.new("UIPadding")

    Padding.PaddingLeft =
        UDim.new(0, 10)

    Padding.Parent = Row

    Row.Size =
        UDim2.new(1, -4, 0, 0)

    TweenService:Create(
        Row,

        TweenInfo.new(
            0.25,
            Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out
        ),

        {
            Size =
                UDim2.new(
                    1,
                    -4,
                    0,
                    35
                ),

            BackgroundTransparency = 0,
            TextTransparency = 0
        }

    ):Play()

    local Pressing = false
    local WasHold = false

    Row.MouseButton1Down:Connect(function()

        Pressing = true
        WasHold = false

        task.delay(
            HOLD_TIME,
            function()

                if not Pressing then
                    return
                end

                WasHold = true

                OpenOptions(
                    Row,
                    AnimName,
                    ID
                )

            end
        )

    end)

    Row.MouseButton1Up:Connect(function()

        Pressing = false

    end)

    Row.MouseButton1Click:Connect(function()

        if WasHold then

            WasHold = false

            return

        end

        CopyID(ID)

    end)

end

AddTargetAnimRow = function(Animation, ID, Label, Extra)
    if UserRanIDs[ID] then
        return
    end

    local DisplayName = Label or Animation.Name

    if TargetLoggedAnimations[ID] then
        local Existing = TargetRows[ID]

        if IsUnresolvedRow(Existing) and not IsUnresolvedName(DisplayName) then
            Existing.Text = RowText(DisplayName, ID, Extra)
            Existing:SetAttribute("Unresolved", nil)
            TargetNames[ID] = DisplayName
        end

        return
    end

    TargetLoggedAnimations[ID] = true
    TargetNames[ID] = DisplayName

    local Row = Instance.new("TextButton")
    Row.Size = UDim2.new(1, -4, 0, 35)
    Row.BackgroundColor3 = COLORS.Secondary
    Row.BorderSizePixel = 0
    Row.Text = RowText(DisplayName, ID, Extra)
    Row.TextColor3 = COLORS.Text
    Row.TextSize = 12
    Row.Font = Enum.Font.Gotham
    Row.TextXAlignment = Enum.TextXAlignment.Left
    Row.TextTruncate = Enum.TextTruncate.AtEnd
    Row.AutoButtonColor = false
    Row.ZIndex = 10
    Row.Parent = TargetUIFrame

    TargetRows[ID] = Row

    if IsUnresolvedName(DisplayName) then
        Row:SetAttribute("Unresolved", true)
    end

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Row

    local Padding = Instance.new("UIPadding")
    Padding.PaddingLeft = UDim.new(0, 10)
    Padding.Parent = Row

    Row.MouseButton1Click:Connect(function()
        CopyID(ID)
        CreateLog(DisplayName, ID, Extra)
    end)
end

local function BuildExport(Logged, Names)
    local List = {}

    for ID in pairs(Logged) do
        List[#List + 1] = {
            id = tostring(ID),
            name = Names[ID] or NameFromIndex(ID) or "Animation"
        }
    end

    table.sort(List, function(A, B)
        if A.name ~= B.name then
            return A.name < B.name
        end

        return A.id < B.id
    end)

    return List
end

local function ParseEntries(Decoded)
    local List = {}

    for _, Entry in ipairs(Decoded) do
        if type(Entry) == "table" then
            if Entry.id then
                List[#List + 1] = { Id = tostring(Entry.id), Name = Entry.name }
            end
        elseif Entry ~= nil then
            List[#List + 1] = { Id = tostring(Entry) }
        end
    end

    return List
end

local function SaveUserAnimations()
    if not writefile then return end
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(BuildExport(UserLoggedAnimations, UserNames))
    end)
    if success then
        writefile(USER_FILE_NAME, encoded)
    end
end

local function LoadUserAnimations()
    if not readfile or not isfile then return end
    if isfile(USER_FILE_NAME) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(USER_FILE_NAME))
        end)
        if success and typeof(decoded) == "table" then
            for _, entry in ipairs(ParseEntries(decoded)) do
                if not UserLoggedAnimations[entry.Id] then
                    CreateLog(entry.Name or NameFromIndex(entry.Id) or "Animation", entry.Id)
                end
            end
        end
    end
end

local function SaveTargetAnimations()
    if not writefile then return end
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(BuildExport(TargetLoggedAnimations, TargetNames))
    end)
    if success then
        writefile(TARGET_FILE_NAME, encoded)
    end
end

local function LoadTargetAnimations()
    if not readfile or not isfile then return end
    if isfile(TARGET_FILE_NAME) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(TARGET_FILE_NAME))
        end)
        if success and typeof(decoded) == "table" then
            for _, entry in ipairs(ParseEntries(decoded)) do
                if not TargetLoggedAnimations[entry.Id] then
                    local dummyAnim = { Name = "Animation" }
                    AddTargetAnimRow(dummyAnim, entry.Id, entry.Name or NameFromIndex(entry.Id))
                end
            end
        end
    end
end

local function CopyUserJSON()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(BuildExport(UserLoggedAnimations, UserNames))
    end)
    if success then
        CopyID(encoded)
    end
end

local function CopyTargetJSON()
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(BuildExport(TargetLoggedAnimations, TargetNames))
    end)
    if success then
        CopyID(encoded)
    end
end

SaveUserButton.MouseButton1Click:Connect(function()
    SaveUserAnimations()
end)

LoadUserButton.MouseButton1Click:Connect(function()
    LoadUserAnimations()
end)

CopyUserButton.MouseButton1Click:Connect(function()
    CopyUserJSON()
end)

SaveTargetButton.MouseButton1Click:Connect(function()
    SaveTargetAnimations()
end)

LoadTargetButton.MouseButton1Click:Connect(function()
    LoadTargetAnimations()
end)

CopyTargetButton.MouseButton1Click:Connect(function()
    CopyTargetJSON()
end)

local TargetAnimationConnection = nil
local TargetCharacterConnection = nil
local TargetBag = {}
local TargetToken = 0
local CurrentTargetPlayer = nil

local function WatchTargetCharacter(Character)
    TargetToken += 1
    local Token = TargetToken

    if TargetAnimationConnection then
        TargetAnimationConnection:Disconnect()
        TargetAnimationConnection = nil
    end

    DisconnectBag(TargetBag)
    TargetBag = {}

    MarkBorn(Character)

    local Humanoid = Character:WaitForChild("Humanoid", 10)
    if not Humanoid or Token ~= TargetToken then return end

    local Animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator", 10)
    if not Animator or Token ~= TargetToken then return end

    WatchCharacterEvents(Character, TargetBag)

    TargetAnimationConnection = Animator.AnimationPlayed:Connect(function(Track)
        if not Track then return end
        local Animation = Track.Animation
        if not Animation then return end
        local ID = GetAnimationID(Animation)
        if not ID then return end

        if UserRanIDs[ID] then
            return
        end

        if Track.Looped then
            return
        end

        if Gate.Resolving[ID] or (Gate.Rejected[ID] and os.clock() < Gate.Rejected[ID]) then
            return
        end

        if TargetLoggedAnimations[ID] and not IsUnresolvedRow(TargetRows[ID]) then
            return
        end

        Gate.Resolving[ID] = true

        task.delay(ResolveDelay + 0.05, function()
            Gate.Resolving[ID] = nil
        end)

        local At = os.clock()

        task.spawn(function()
            task.wait(ResolveDelay)

            if UserRanIDs[ID] then
                return
            end

            if TargetLoggedAnimations[ID] and not IsUnresolvedRow(TargetRows[ID]) then
                return
            end

            local MainText, Extra = ResolveMove(Animation, Character, At, Track)

            if MainText then
                AddTargetAnimRow(Animation, ID, MainText, Extra)
            else
                Gate.Rejected[ID] = os.clock() + 10
            end
        end)
    end)
end

local function GetTargetPlayer()
    local text = TargetBox.Text:gsub("%s+", "")
    if text == "" then
        return nil
    end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #text) == text:lower() or p.DisplayName:lower():sub(1, #text) == text:lower() then
            return p
        end
    end
    
    return nil
end

local function SetupTarget()
    TargetToken += 1

    if TargetCharacterConnection then
        TargetCharacterConnection:Disconnect()
        TargetCharacterConnection = nil
    end
    if TargetAnimationConnection then
        TargetAnimationConnection:Disconnect()
        TargetAnimationConnection = nil
    end

    DisconnectBag(TargetBag)
    TargetBag = {}

    local target = GetTargetPlayer()
    
    if TargetBox.Text:gsub("%s+", "") == "" then
        TargetUITitle.Text = "Target's Active Anims (Select Player)"
        for _, child in ipairs(TargetUIFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        TargetLoggedAnimations = {}
        TargetNames = {}
        TargetRows = {}
        CurrentTargetPlayer = nil
        return
    end

    CurrentTargetPlayer = target

    if not target then
        TargetUITitle.Text = "Target: " .. TargetBox.Text .. " (Offline/Not Found)"
        return
    end

    TargetUITitle.Text = "Target: " .. target.Name

    if target.Character then
        task.spawn(WatchTargetCharacter, target.Character)
    end

    TargetCharacterConnection = target.CharacterAdded:Connect(function(Character)
        MarkBorn(Character)
        task.wait(0.5)
        WatchTargetCharacter(Character)
    end)
end

TargetBox:GetPropertyChangedSignal("Text"):Connect(function()
    SetupTarget()
end)

local LocalAnimationConnection
local LocalBag = {}
local LocalToken = 0

local function WatchLocalCharacter(Character)

    LocalToken += 1
    local Token = LocalToken

    if LocalAnimationConnection then
        LocalAnimationConnection:Disconnect()
        LocalAnimationConnection = nil
    end

    DisconnectBag(LocalBag)
    LocalBag = {}

    MarkBorn(Character)

    local Humanoid = Character:WaitForChild("Humanoid", 10)
    if not Humanoid or Token ~= LocalToken then return end

    local Animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator", 10)
    if not Animator or Token ~= LocalToken then return end

    WatchCharacterEvents(Character, LocalBag)

    LocalAnimationConnection = Animator.AnimationPlayed:Connect(function(Track)
        if not Track then return end
        local Animation = Track.Animation
        if not Animation then return end
        local ID = GetAnimationID(Animation)
        if not ID then return end

        if Track.Looped then
            return
        end

        if Gate.Resolving[ID] or (Gate.Rejected[ID] and os.clock() < Gate.Rejected[ID]) then
            return
        end

        if UserLoggedAnimations[ID] and not IsUnresolvedRow(UserRows[ID]) then
            return
        end

        Gate.Resolving[ID] = true

        task.delay(ResolveDelay + 0.05, function()
            Gate.Resolving[ID] = nil
        end)

        local At = os.clock()

        task.spawn(function()
            task.wait(ResolveDelay)

            if UserLoggedAnimations[ID] and not IsUnresolvedRow(UserRows[ID]) then
                return
            end

            local MainText, Extra = ResolveMove(Animation, Character, At, Track)

            if MainText then
                CreateLog(MainText, ID, Extra)
            else
                Gate.Rejected[ID] = os.clock() + 10
            end
        end)
    end)

end

if Player.Character then
    task.spawn(WatchLocalCharacter, Player.Character)
end

Player.CharacterAdded:Connect(function(Character)
    MarkBorn(Character)
    task.wait(0.5)
    WatchLocalCharacter(Character)
end)
