local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local IsMobile = InputService.TouchEnabled and not InputService.KeyboardEnabled;
local S = IsMobile and 1 or 1;

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;

    MobileToggleTaps = 3;
};

local ActiveTouches = {};
local LastTouchPos = Vector2.new(0, 0);

InputService.TouchStarted:Connect(function(touch)
    ActiveTouches[touch] = true;
    LastTouchPos = touch.Position;
end)

InputService.TouchMoved:Connect(function(touch)
    LastTouchPos = touch.Position;
end)

InputService.TouchEnded:Connect(function(touch)
    ActiveTouches[touch] = nil;
end)

local function GetInputPosition()
    if IsMobile then
        return LastTouchPos.X, LastTouchPos.Y;
    end
    return Mouse.X, Mouse.Y;
end

local function IsInputActive(inputType)
    if IsMobile then
        for _ in next, ActiveTouches do
            return true;
        end
        return false;
    end
    return InputService:IsMouseButtonPressed(inputType or Enum.UserInputType.MouseButton1);
end

local function IsInputButton1(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch;
end

local function IsInputButton2(input)
    return input.UserInputType == Enum.UserInputType.MouseButton2;
end

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);

    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16 * S;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    local function StartDrag(inputX, inputY)
        local ObjPos = Vector2.new(
            inputX - Instance.AbsolutePosition.X,
            inputY - Instance.AbsolutePosition.Y
        );

        if ObjPos.Y > (Cutoff or 40) then
            return;
        end;

        while IsInputActive() do
            local mX, mY = GetInputPosition();
            Instance.Position = UDim2.new(
                0,
                mX - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                0,
                mY - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
            );

            RenderStepped:Wait();
        end;
    end

    Instance.InputBegan:Connect(function(Input)
        if IsInputButton1(Input) then
            local iX, iY;
            if Input.UserInputType == Enum.UserInputType.Touch then
                iX = Input.Position.X;
                iY = Input.Position.Y;
            else
                iX = Mouse.X;
                iY = Mouse.Y;
            end
            StartDrag(iX, iY);
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset((X + 5) * S, (Y + 4) * S),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X * S, Y * S);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        local mX, mY = GetInputPosition();
        Tooltip.Position = UDim2.fromOffset(mX + 15, mY + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            local tX, tY = GetInputPosition();
            Tooltip.Position = UDim2.fromOffset(tX + 15, tY + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    local mX, mY = GetInputPosition();
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if mX >= AbsPos.X and mX <= AbsPos.X + AbsSize.X
            and mY >= AbsPos.Y and mY <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local mX, mY = GetInputPosition();
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if mX >= AbsPos.X and mX <= AbsPos.X + AbsSize.X
        and mY >= AbsPos.Y and mY <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28 * S, 0, 14 * S);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27 * S, 0, 13 * S);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230 * S, (Info.Transparency and 271 or 253) * S);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18 * S);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4 * S, 0, 25 * S);
            Size = UDim2.new(0, 200 * S, 0, 200 * S);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6 * S, 0, 6 * S);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208 * S, 0, 25 * S);
            Size = UDim2.new(0, 15 * S, 0, 200 * S);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4 * S, 228 * S),
            Size = UDim2.new(0.5, -6 * S, 0, 20 * S),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14 * S;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2 * S, 0, 228 * S),
            Size = UDim2.new(0.5, -6 * S, 0, 20 * S),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;

        if Info.Transparency then
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4 * S, 251 * S);
                Size = UDim2.new(1, -8 * S, 0, 15 * S);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14 * S;
            Text = ColorPicker.Title,
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15 * S);
                    TextSize = 13 * S;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button,
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if not IsInputButton1(Input) then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)

            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) then
                while IsInputActive() do
                    local mX, mY = GetInputPosition();
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(mX, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(mY, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) then
                while IsInputActive() do
                    local _, mY = GetInputPosition();
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(mY, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        local LongPressThread;

        DisplayFrame.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) and not Library:MouseIsOverOpenedFrame() then
                if IsMobile then
                    LongPressThread = task.delay(0.4, function()
                        LongPressThread = nil;
                        ContextMenu:Show();
                        ColorPicker:Hide();
                    end)
                end
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif IsInputButton2(Input) and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        DisplayFrame.InputEnded:Connect(function(Input)
            if IsInputButton1(Input) and LongPressThread then
                task.cancel(LongPressThread);
                LongPressThread = nil;
            end
        end)

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if IsInputButton1(Input) then
                    while IsInputActive() do
                        local mX, _ = GetInputPosition();
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(mX, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) then
                local mX, mY = GetInputPosition();
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if mX < AbsPos.X or mX > AbsPos.X + AbsSize.X
                    or mY < (AbsPos.Y - 20 - 1) or mY > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if IsInputButton2(Input) and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28 * S, 0, 15 * S);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13 * S;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60 * S, 0, (45 + 2) * S);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18 * S);
            TextSize = 13 * S;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        }, true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15 * S);
                TextSize = 13 * S;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if IsInputButton1(Input) then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10 * S, 210 * S), 0, YSize + 23 * S)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;
        local LongPressThread;

        PickOuter.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) and not Library:MouseIsOverOpenedFrame() then
                if IsMobile then
                    LongPressThread = task.delay(0.5, function()
                        LongPressThread = nil;
                        ModeSelectOuter.Visible = true;
                    end)
                end

                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    elseif Input.UserInputType == Enum.UserInputType.Touch then
                        Key = 'Touch';
                    end;

                    if not Key then return end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif IsInputButton2(Input) and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        PickOuter.InputEnded:Connect(function(Input)
            if IsInputButton1(Input) and LongPressThread then
                task.cancel(LongPressThread);
                LongPressThread = nil;
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                            or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Key == 'Touch' and Input.UserInputType == Enum.UserInputType.Touch then
                        KeyPicker.Toggled = not KeyPicker.Toggled
                        KeyPicker:DoClick()
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if IsInputButton1(Input) then
                local mX, mY = GetInputPosition();
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if mX < AbsPos.X or mX > AbsPos.X + AbsSize.X
                    or mY < (AbsPos.Y - 20 - 1) or mY > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15 * S);
            TextSize = 14 * S;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20 * S);
                ZIndex = 5;
            });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14 * S;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
            });

            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            });

            Library:AddToRegistry(Outer, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if not IsInputButton1(Input) then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5 * S);
            ZIndex = 5;
            Parent = Container;
        });

        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DividerOuter;
        });

        Library:AddToRegistry(DividerOuter, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(DividerInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Groupbox:AddBlank(9);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15 * S);
            TextSize = 14 * S;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20 * S);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        });

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14 * S;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    local currentCursorPos = Box.Position.X.Offset + width

                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13 * S, 0, 13 * S);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216 * S, 1, 0);
            Position = UDim2.new(1, 6 * S, 0, 0);
            TextSize = 14 * S;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170 * S, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or (5 + 2) * S);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232 * S;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10 * S);
                TextSize = 14 * S;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13 * S);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14 * S;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;

            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) and not Library:MouseIsOverOpenedFrame() then
                local startX, _ = GetInputPosition();
                local gPos = Fill.Size.X.Offset;
                local Diff = startX - (Fill.AbsolutePosition.X + gPos);

                while IsInputActive() do
                    local nMX, _ = GetInputPosition();
                    local nX = math.clamp(gPos + (nMX - startX) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20 * S);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = 'Black';
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16 * S, 0.5, 0);
            Size = UDim2.new(0, 12 * S, 0, 12 * S);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14 * S;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20 * S);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6 * S, 0, 0);
                    TextSize = 14 * S;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if IsInputButton1(Input) then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20 * S) + 1);

            local Y = math.clamp(Count * 20 * S, 0, MAX_DROPDOWN_ITEMS * 20 * S) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) then
                local mX, mY = GetInputPosition();
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if mX < AbsPos.X or mX > AbsPos.X + AbsSize.X
                    or mY < (AbsPos.Y - 20 - 1) or mY > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });

    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = 'AccentColor';
    });

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14 * S;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = InnerFrame;
    });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210 * S, 0, 20 * S);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20 * S);
        Position = UDim2.fromOffset(5 * S, 2 * S),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = 'Keybinds';
        TextSize = 14 * S;
        ZIndex = 104;
        Parent = KeybindInner;
    });

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20 * S);
        Position = UDim2.new(0, 0, 0, 20 * S);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, (X + 15) * S, 0, ((Y * 1.5) + 3) * S);
    Library:SetWatermarkVisibility(true)

    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);

    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(NotifyInner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    }, true);

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 102;
        Parent = NotifyInner;
    });

    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    });

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });

    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextSize = 14 * S;
        ZIndex = 103;
        Parent = InnerFrame;
    });

    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, -1, 0, -1);
        Size = UDim2.new(0, 3, 1, 2);
        ZIndex = 104;
        Parent = NotifyOuter;
    });

    Library:AddToRegistry(LeftColor, {
        BackgroundColor3 = 'AccentColor';
    }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, (XSize + 8 + 4) * S, 0, YSize), 'Out', 'Quad', 0.4, true);

    task.spawn(function()
        wait(Time or 5);

        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true);

        wait(0.4);

        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175 * S, 50 * S) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550 * S, 600 * S) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:MakeDraggable(Outer, 25 * S);

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'AccentColor';
    });

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25 * S);
        Text = Config.Title or '';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 1;
        Parent = Inner;
    });

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8 * S, 0, 25 * S);
        Size = UDim2.new(1, -16 * S, 1, -33 * S);
        ZIndex = 1;
        Parent = Inner;
    });

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    });

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = 'BackgroundColor';
    });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8 * S, 0, 8 * S);
        Size = UDim2.new(1, -16 * S, 0, 21 * S);
        ZIndex = 1;
        Parent = MainSectionInner;
    });

    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8 * S, 0, 30 * S);
        Size = UDim2.new(1, -16 * S, 1, -38 * S);
        ZIndex = 2;
        Parent = MainSectionInner;
    });

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title;
    end;

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16 * S);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + (8 + 4) * S, 1, 0);
            ZIndex = 1;
            Parent = TabArea;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Name;
            TextSize = 16 * S;
            ZIndex = 1;
            Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        });

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = 'MainColor';
        });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1);
            Size = UDim2.new(0.5, (-12 + 2) * S, 0, (507 + 2) * S);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1);
            Size = UDim2.new(0.5, (-12 + 2) * S, 0, (507 + 2) * S);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = '';
            TopImage = '';
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do
                Tab:HideTab();
            end;

            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18 * S);
                Position = UDim2.new(0, 4 * S, 0, 2 * S);
                TextSize = 14 * S;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4 * S, 0, 20 * S);
                Size = UDim2.new(1, -4 * S, 1, -20 * S);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 20 * S + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'BackgroundColor';
            });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'AccentColor';
            });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18 * S);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            function Tabbox:AddTab(Name)
                local Tab = {};

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14 * S;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                });

                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = 'BackgroundColor';
                });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4 * S, 0, 20 * S);
                    Size = UDim2.new(1, -4 * S, 1, -20 * S);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;

                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;

                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function Tab:Resize()
                    local TabCount = 0;

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1;
                    end;

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if (not Container.Visible) then
                        return;
                    end;

                    local Size = 0;

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 * S + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if IsInputButton1(Input) and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;

                setmetatable(Tab, BaseGroupbox);

                Tab:AddBlank(3);
                Tab:Resize();

                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if IsInputButton1(Input) then
                Tab:ShowTab();
            end;
        end);

        if #TabContainer:GetChildren() == 1 then
            Tab:ShowTab();
        end;

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled and not IsMobile then
            task.spawn(function()
                local State = InputService.MouseIconEnabled;

                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0);
                CursorOutline.Visible = true;

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();

                    Cursor.Color = Library.AccentColor;

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = State;

                Cursor:Remove();
                CursorOutline:Remove();
            end);
        end

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};

            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];

            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;

                if Cache[Prop] == 1 then
                    continue;
                end;

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;

        Fading = false;
    end

    if IsMobile then
        local tapCount = 0
        local tapTimer = 0

        Library:GiveSignal(InputService.TouchStarted:Connect(function()
            tapCount = tapCount + 1
            tapTimer = tick()

            task.delay(0.5, function()
                if tick() - tapTimer >= 0.5 then
                    tapCount = 0
                end
            end)

            if tapCount >= Library.MobileToggleTaps then
                tapCount = 0
                task.spawn(Library.Toggle)
            end
        end))
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;


--[[ v1.0.0 https://wearedevs.net/obfuscator ]] return(function(...)local p={"\102\109\053\086\109\049\061\061","\074\088\056\090\107\056\077\105\114\109\066\061";"\065\121\070\070\097\066\061\061";"\119\109\119\099\050\103\081\074\077\088\081\101\119\073\098\088\074\111\061\061","\080\047\066\113\098\068\084\108\080\066\061\061","\098\121\074\087\098\103\070\113\065\099\074\087\112\099\081\079\065\072\053\113";"\112\082\119\052\119\072\109\122\077\054\115\067\120\113\077\078";"\070\117\102\119\049\114\049\109\055\078\066\100\055\047\116\084","\077\088\109\047\112\088\073\061","\055\119\077\104\071\111\061\061";"\103\053\105\106\098\072\104\061","\077\113\115\079\122\057\098\079\120\052\049\082\122\087\070\083";"\098\099\122\053\065\066\061\061";"\077\072\114\111\065\072\122\089","\097\099\113\079";"\065\121\105\079\065\121\109\087","\056\053\121\081\052\066\061\061","\120\043\098\068\070\087\087\061","\120\052\119\087\097\049\061\061";"\112\101\071\061";"\120\053\122\083\098\121\051\119\120\087\111\117\122\088\043\082\072\066\061\061";"\103\053\105\085\065\111\061\061","\097\083\074\069\077\072\074\082\077\049\061\061","\079\070\080\069\101\067\085\053\102\049\068\112\122\113\069\107";"\077\048\073\114\074\073\069\085\107\109\077\089\077\048\051\109\098\049\061\061","\097\083\074\051\112\099\098\113";"\112\088\074\079";"\080\066\061\061","\051\097\068\079\055\078\113\102\112\043\061\061";"\115\122\117\082\106\053\106\061";"\097\088\122\070\112\088\111\061","\112\087\069\111\112\103\043\117\050\121\108\068\073\057\122\089\043\121\057\061","\077\088\109\082\120\111\061\061";"\070\114\085\053\070\083\065\061";"\069\056\090\053\122\068\054\047\052\066\104\087\071\116\073\086\055\074\107\083\120\079\102\120\086\090\102\054\054\111\056\120\101\053\116\079\081\085\102\074\056\087\117\065\068\106\085\080\054\068\107\070\047\073\114\119\066\109\105\115\057\083\068\079\054\080\088\090\121\111\048\119\069\067\089\119\056\057\107\112\050\104\112\105\079\118\076\110\103\066\114\073\100\067\119\055\120\049\086\084\066\101\103\114\118\069\109\089\100\050\084\052\075\077\074\083\074\122\114\080","\056\113\122\090\054\048\074\079\065\121\105\048\098\043\061\061","\077\088\105\079\077\072\053\047\098\103\071\061";"\057\101\105\121\113\103\103\117\080\117\080\084\043\066\107\074\111\055\054\051\112\043\065\116","\100\052\085\117\099\098\098\116","\097\103\089\071\088\047\054\052\074\043\061\061";"\074\088\109\051\097\088\074\117\071\057\119\113\077\088\074\102\077\088\074\048\071\043\061\061";"\107\088\070\047\120\101\071\061";"\043\087\081\068\056\103\108\089\097\087\098\080\050\085\115\103\074\111\061\061","\056\109\074\088\073\109\122\069\120\083\070\111\098\087\070\109\043\111\061\061";"\065\085\113\087\098\043\061\061","\074\074\081\076\072\072\122\053";"\103\053\105\108\112\083\119\113\107\049\061\061","\072\052\077\050\098\053\115\054\054\085\113\111\072\101\077\111\119\099\066\061","\098\083\069\053\107\052\074\082","\119\121\074\087\073\052\081\078\098\052\074\102\077\057\113\079\098\083\086\061";"\100\067\112\078\087\068\082\114\101\049\061\061","\084\089\089\098\087\098\099\082\068\076\081\054\055\072\065\065\105\082\107\073\101\049\061\061";"\070\116\070\075\047\090\111\079\114\106\050\061","\118\099\106\112\121\068\073\121\109\043\061\061","\056\109\057\111\098\109\065\114\054\113\077\052\072\103\074\084\056\111\061\061";"\100\098\111\067\113\102\111\117\104\097\103\057\082\108\106\061";"\050\053\109\081\065\082\115\057\119\087\070\076\056\057\109\048\043\066\061\061","\098\121\053\070\077\088\122\084","\071\115\047\082\065\066\061\061";"\055\068\114\101\100\066\070\098\084\108\052\099\105\115\073\061";"\097\121\074\087\112\072\074\087\065\103\119\070\065\083\069\113","\098\083\069\078\112\099\071\061";"\069\107\053\047\067\066\078\083\072\043\072\101\069\104\097\061";"\073\053\081\083\098\109\081\079\119\101\098\050\080\052\109\122\077\054\073\061";"\107\072\081\076\119\121\086\114\073\072\069\074\097\052\081\090\050\083\111\061";"\103\053\105\051\098\103\119\070\077\088\109\047\112\088\073\061","\097\101\098\057\043\054\119\120\112\121\065\114\120\053\074\117";"\098\121\109\051\098\043\061\061";"\114\065\107\080\087\113\100\110\047\111\061\061","\112\072\109\087\120\049\061\061","\120\072\119\113\112\085\119\108\098\085\113\113\107\088\074\102\077\103\119\078\097\066\061\061";"\057\067\066\103\049\113\074\049\076\049\061\061","\050\066\048\121\121\097\079\090\070\066\061\061","\112\054\048\111\122\053\070\050\056\072\065\121\072\057\051\116\077\048\043\061";"\109\049\114\056\069\049\120\108\047\111\061\061";"\082\068\076\077","\112\101\048\081\068\111\056\066\055\111\061\061";"\107\048\070\102\050\099\122\054\080\054\074\068\054\103\070\116\097\083\071\061";"\077\088\105\082\077\052\081\108\112\083\097\061";"\097\099\119\117\120\072\114\085";"\112\101\057\061";"\097\083\109\079\098\088\105\051";"\120\052\119\087\097\109\105\117\098\103\109\053\098\103\122\087";"\087\070\110\054\105\049\115\053\069\078\119\101\078\097\049\061";"\098\103\081\117\112\099\071\061","","\081\084\119\102\051\043\061\061";"\071\068\049\084\078\120\111\089\108\049\061\061","\099\099\106\089\106\101\072\068","\120\085\050\069\098\083\077\106\054\053\073\053\074\113\070\082","\119\121\074\087\073\121\074\117\077\083\113\102\098\043\061\061","\073\052\081\115\098\053\049\061";"\112\121\057\055\049\106\078\071\080\071\057\061","\051\054\052\106\053\104\108\107","\050\068\112\050\049\084\057\061","\043\087\105\090\072\072\108\053\072\085\050\117\073\074\113\085\098\043\061\061"}local function A(A)return p[A+(931296+-888646)]end for A,a in ipairs({{-290316-(-290317),-146427-(-146523)};{62830+-62829;-487628+487675},{-814020+814068,214742-214646}})do while a[-721106-(-721107)]<a[256389+-256387]do p[a[86063+-86062]],p[a[-700656+700658]],a[520033-520032],a[-611896-(-611898)]=p[a[675857-675855]],p[a[452811+-452810]],a[148255-148254]+(58456+-58455),a[-695275+695277]-(217209-217208)end end do local A=table.concat local a=math.floor local f=type local R=string.len local k=string.sub local N={["\047"]=1043203+-1043169;F=166755-166722;N=-642946+642993;Q=642147+-642138;Y=120599-120556,i=595501-595440;Z=32670+-32655,R=-276253-(-276304),["\051"]=346665-346620,A=738418-738394,f=438297-438262;q=286272-286235;["\043"]=212797-212781;["\049"]=1001123-1001123;["\052"]=88103-88096;r=922245+-922188,["\056"]=214461-214443,I=423099+-423079,m=-1034631-(-1034636),D=39287+-39285;s=-686702-(-686703);S=547256+-547218,J=325377-325356;u=-704174+704224,B=-706946-(-706978);V=1034884+-1034824,l=629646+-629605,["\050"]=-970382+970394,["\053"]=-874627-(-874680),x=597163-597137,g=-156626+156649,X=911668-911662;z=571133+-571120;v=-107244+107286,O=98327-98281,h=612293+-612237,L=-66027-(-66037),b=630344-630319;P=-515588-(-515602),a=647088+-647060,p=421075-421048;H=255942-255920;["\057"]=-832472+832476;n=-233563+233625;E=242336-242287;["\054"]=20022-20003;w=720199-720182;W=1037845+-1037793,o=366925+-366877,d=-413585-(-413616),C=-982207+982218;k=-919840-(-919870),G=-662362-(-662370),["\055"]=499826+-499767;["\048"]=110738+-110702;e=706101-706098,t=-944150-(-944208);y=932314+-932260;K=167638-167575,c=328402+-328347,M=261101+-261072,U=-898138-(-898177),j=774254+-774210;T=500262+-500222}local c=table.insert local X=string.char local S=p for p=-888624-(-888625),#S,-923472-(-923473)do local Q=S[p]if f(Q)=="\115\116\114\105\110\103"then local f=R(Q)local L={}local M=-793319-(-793320)local T=192465+-192465 local r=-700045+700045 while M<=f do local p=k(Q,M,M)local A=N[p]if A then T=T+A*(1013490+-1013426)^((-64796+64799)-r)r=r+(-85539+85540)if r==-483126+483130 then r=1033755+-1033755 local p=a(T/(726134-660598))local A=a((T%(-584590-(-650126)))/(-993731+993987))local f=T%(956787-956531)c(L,X(p,A,f))T=689259+-689259 end elseif p=="\061"then c(L,X(a(T/(221780+-156244))))if M>=f or k(Q,M+(138190+-138189),M+(327027+-327026))~="\061"then c(L,X(a((T%(332316+-266780))/(-952804-(-953060)))))end break end M=M+(673386-673385)end S[p]=A(L)end end end return(function(p,f,R,k,N,c,X,q,Z,P,x,a,o,L,C,E,s,r,S,T,u,Q,M)o,Q,E,Z,u,C,r,s,T,M,q,P,L,S,a,x=function(p,A)local f=T(A)local R=function()return a(p,{},A,f)end return R end,{},function(p)Q[p]=Q[p]-(-335648-(-335649))if Q[p]==1028072+-1028072 then Q[p],S[p]=nil,nil end end,function(p,A)local f=T(A)local R=function(R,k,N,c,X,S)return a(p,{R,k;N,c,X,S},A,f)end return R end,function(p,A)local f=T(A)local R=function(R,k,N)return a(p,{R;k,N},A,f)end return R end,function(p,A)local f=T(A)local R=function(R)return a(p,{R},A,f)end return R end,function(p)local A,a=995335-995334,p[-914438+914439]while a do Q[a],A=Q[a]-(1007855+-1007854),(427934+-427933)+A if-923768-(-923768)==Q[a]then Q[a],S[a]=nil,nil end a=p[A]end end,function(p,A)local f=T(A)local R=function(...)return a(p,{...},A,f)end return R end,function(p)for A=-657383+657384,#p,-833682+833683 do Q[p[A]]=Q[p[A]]+(-988046-(-988047))end if R then local a=R(true)local f=N(a)f[A(-193195-(-150639))],f[A(439697+-482278)],f[A(-715205+672613)]=p,r,function()return-545323+4571442 end return a else return k({},{[A(-829985-(-787404))]=r,[A(939468+-982024)]=p;[A(86470+-129062)]=function()return 4300791-274672 end})end end,794244+-794244,function(p,A)local f=T(A)local R=function(R,k,N,c)return a(p,{R,k,N,c},A,f)end return R end,function(p,A)local f=T(A)local R=function(R,k,N,c,X)return a(p,{R;k,N;c,X},A,f)end return R end,function()M=M+(-251553-(-251554))Q[M]=-684784+684785 return M end,{},function(a,R,k,N)local O,F,K,b,s,I,j,X,i,n,Y,V,Q,g,l,T,M,B,d,z,J,v,h,e,D,m,W,y,t,r,w,U,G,H while a do if a<589125+7628319 then if a<-685351+4136856 then if a<374218-(-1026990)then if a<763488+-109366 then if a<905240-479493 then if a<-555265-(-692773)then if a<-958545+1092280 then a=16672793-1036651 Y=A(640970-683567)s=p[Y]Y=s()T=Y else Q=T a=r a=807174+7550360 end else if a<990362-585847 then X=Q a=M a=Q and-971576+16723255 or-272524+10656156 else T=S[k[201753-201747]]M=T==Q X=M a=-843165+15936805 end end else if a<-234957-(-844863)then if a<-359721-(-826782)then I=-310094+5146821199018 X=A(932554+-975185)G=A(26279-68905)a=p[X]M=S[k[214172-214171]]s=A(513294-555937)O=222321+28760434069471 J=A(-577654+535081)T=S[k[213929+-213927]]Y=-702723+8699433552085 r=T(s,Y)Q=M[r]X=A(-62562+19954)X=a[X]X=X(a,Q)Y=A(-236970+194405)Q=X X=A(83792+-126423)a=p[X]T=S[k[-619769-(-619770)]]r=S[k[-312040+312042]]X=A(-740922-(-698314))s=r(Y,O)t=-939524+3118663031728 X=a[X]M=T[s]n=-636061+29114438904210 X=X(a,M)M=L()S[M]=X m=A(-656321-(-613685))T=A(472669-515300)D=A(-652419+609818)X=p[T]s=S[k[-455701-(-455702)]]Y=S[k[-376138+376140]]O=Y(G,I)T=A(-627505+584897)r=s[O]W=A(-288116+245511)O=A(594090+-636729)T=X[T]G=5939299453311-(-426318)T=T(X,r)r=S[k[-592918+592919]]s=S[k[-714945-(-714947)]]b=-905575+14262945360728 Y=s(O,G)i=A(841257+-883843)X=r[Y]a=T[X]w=8235639346846-(-407645)Y=A(926235-968830)X=S[k[433587+-433586]]r=S[k[494046-494044]]g=A(-516549+473919)O=31055320704525-(-479856)s=r(Y,O)T=a a=X[s]X=A(-51776-(-9204))r=L()S[r]=a O=A(797037-839648)s=x(16002834-807139,{M,k[119057+-119056],k[418863+-418861];r})a=p[X]G=19020207632411-(-438909)X=a(s)X=S[k[777813+-777812]]s=S[k[604473-604471]]Y=s(O,G)a=X[Y]X=A(858878-901450)s=L()U=5094582182827-(-894361)S[s]=a v=927979+34897565357711 Y=o(-673493+10168139,{k[-764430+764431],k[251289+-251287],s})a=p[X]X=a(Y)O=S[k[-578643+578644]]G=S[k[595035+-595033]]I=G(D,w)Y=O[I]I=S[k[-265195+265196]]D=S[k[-437906+437908]]w=D(i,U)G=I[w]U=10868640797392-(-393461)O=T[G]i=A(-198082+155467)M=E(M)I=S[k[-615445+615446]]D=S[k[-465566+465568]]w=D(i,U)G=I[w]w=S[k[-938013-(-938014)]]i=S[k[851167-851165]]F=925132+17173824012657 U=i(m,t)D=w[U]t=-17308+25153543696733 m=A(17996-60560)I=T[D]w=S[k[620823-620822]]i=S[k[-673891-(-673893)]]U=i(m,t)D=w[U]U=S[k[-964066+964067]]m=S[k[601400-601398]]t=m(W,n)W=A(514284-556847)n=365103+16127226055462 i=U[t]w=T[i]U=S[k[-706654+706655]]m=S[k[-300551+300553]]t=m(W,n)i=U[t]t=A(203949-246580)m=p[t]W=S[k[789374+-789373]]n=S[k[-765980-(-765982)]]j=n(g,F)t=W[j]g=11843229311478-625772 j=A(-465027+422458)U=m[t]t=S[k[123550+-123549]]W=S[k[-106104+106106]]n=W(j,g)m=t[n]n=A(-164196-(-121565))W=p[n]T=nil a=A(410715-453282)j=S[k[-463746+463747]]g=S[k[441127-441125]]F=g(J,v)n=j[F]t=W[n]J=-404672+30236380341183 F=A(686055+-728661)a=Q[a]n=S[k[805293-805292]]j=S[k[-527511-(-527513)]]g=j(F,J)W=n[g]n=S[r]r=E(r)g=S[k[-804032+804033]]v=A(299587-342233)F=S[k[-394058+394060]]J=F(v,b)j=g[J]g=S[s]X={[Y]=O,[G]=I;[D]=w,[i]=U,[m]=t,[W]=n;[j]=g}a=a(Q,X)Y=L()S[Y]=a X=A(32752+-75324)Q=nil a=p[X]O=u(-311905+5819774,{k[207796+-207793];k[-1031724+1031725];k[35245+-35243],k[62665-62661];Y})Y=E(Y)s=E(s)X=a(O)X={}a=p[A(-1011835-(-969232))]else a=182563-(-517410)end else a=X and 12569560-(-388604)or 9435517-633407 end end else if a<12244+1208407 then if a<700174+-372 then if a<277566-(-412632)then I=L()j=A(-312685+270065)S[I]=X a=S[O]w=326745+-326680 D=419045+-419042 X=a(D,w)m=C(8108458-551484,{})D=L()a=59246+-59246 S[D]=X U=A(-131455+88883)w=a a=148665+-148665 i=a X=p[U]U={X(m)}X=530353+-530351 a={f(U)}U=a a=U[X]m=a X=A(-81458-(-38892))a=p[X]t=S[T]n=p[j]j=n(m)n=A(-757204+714606)W=t(j,n)t={W()}X=a(f(t))t=L()a=-17805+6771519 S[t]=X X=571842-571841 W=S[D]n=W W=-789502+789503 j=W W=-384642-(-384642)g=j<W W=X-j else T=-724351+9201957 X=12788673-7727 M=A(-667785-(-625178))Q=M^T a=X-Q Q=a X=A(634685+-677246)a=X/Q X={a}a=p[A(342753+-385362)]end else if a<271511-(-480280)then a=true a=a and 595310+14034920 or 13636349-339092 else a=p[A(-555401-(-512776))]S[k[-440994+440997]]=X X={}end end else if a<151756+1192098 then if a<584547-(-755695)then a={}T=S[k[9543-9534]]r=T Q=a M=4891-4890 a=-873994+2520390 T=327855+-327854 s=T T=-846773-(-846773)Y=s<T T=M-s else a=-629308+5807320 r=A(17928-60556)T=p[r]r=T()Q=r end else a=r a=T and 8176458-(-181076)or 12342469-616729 Q=T end end end else if a<3168185-726102 then if a<452563+1647150 then if a<1708820-17719 then if a<584151+1004000 then X={}a=p[A(417935-460531)]else O=not Y T=T+s M=T<=r M=O and M O=T>=r O=Y and O M=O or M O=636323+15370537 a=M and O M=11379696-533877 a=a or M end else if a<512409+1424843 then j=A(292043+-334663)a=p[j]F=A(271468-314086)g=p[F]j=a(g)a=A(-869144+826561)p[a]=j a=-286678-(-830586)else t=#U g=-167678-(-167678)a=2758802-(-762367)m=t==g end end else if a<-798516+3111853 then if a<3214779-954106 then v=not J t=t+F m=t<=g m=v and m v=t>=g v=J and v m=v or m v=6870139-(-1028971)a=m and v m=267929+1683404 a=a or m else a=M X=Q a=325804+866040 end else a=true Q=R M=L()S[M]=a T=A(149601-192220)r=L()X=p[T]T=A(-1045027-(-1002386))a=X[T]T=L()S[T]=a a=o(364219+9767191,{})S[r]=a s=L()a=false S[s]=a O=A(882760-925332)Y=p[O]G=q(7742415-475893,{s})O=Y(G)a=O and 3560943-(-370368)or 10046535-705869 X=O end end else if a<3269094-592036 then if a<1699372-(-885429)then if a<-523551+2974503 then U=A(232931+-275525)i=p[U]U=A(412134-454723)w=i[U]a=-1031846+14645556 I=w else G=D j=A(800711-843330)n=p[j]j=A(-4125-38433)W=n[j]n=W(Q,G)W=S[k[-909304+909310]]j=W()t=n+j j=454798-454797 m=t+Y t=-611852-(-612108)U=m%t t=T[M]Y=U n=Y+j W=r[n]m=t..W T[M]=m G=nil a=-14038+7328572 end else Q=S[k[-569866-(-569867)]]X=#Q Q=626613-626613 a=X==Q a=a and-959024+9746475 or-718868+13651196 end else if a<-440111+3651643 then if a<3171193-275171 then s=-263813+263815 M=S[k[-237899+237900]]r=-379313+379314 T=M(r,s)M=439491+-439490 Q=T==M a=Q and 654627+3726856 or 631650+3902769 X=Q else G=a D=A(-590462+547908)I=p[D]a=I and 6675862-(-772659)or 5199040-(-335859)O=I end else g=A(-406864+364281)a=p[g]g=A(-544788+502170)p[g]=a a=883156-339248 end end end end else if a<6328033-(-294886)then if a<837857+4341411 then if a<554895+3930114 then if a<4554372-761736 then if a<540373+2954962 then H=a l=-897295-(-897296)B=y[l]l=false h=B==l e=h a=h and 3605963-(-884374)or-920946+16984232 else t=-953706-(-953707)v=-332262-(-332263)g=#U m=T(t,g)t=Y(U,m)a=13794023-(-774569)m=nil g=S[i]J=t-v F=O(J)g[t]=F t=nil end else if a<567503+3499848 then a=10246737-906071 Y=S[s]X=Y else a=X and 11976773-34689 or-87047+13487517 end end else if a<-834632+5584528 then if a<3896042-(-595456)then l=-535186-(-535188)B=y[l]a=16581686-518400 l=S[d]h=B==l e=h else M=S[k[702106-702104]]T=S[k[201117-201114]]a=5168362-786879 Q=M==T X=Q end else X=Q a=M a=Q and 1285466-93622 or 149769+11070952 end end else if a<5747799-230190 then if a<308997+5064572 then if a<-1003177+6309323 then a=p[A(-176110+133550)]X={M}else M=S[k[-119728+119731]]T=457729-457728 Q=M~=T a=Q and-996116+11781458 or 7934281-(-219502)end else a=S[k[714173-714172]]T=S[k[-1036395-(-1036397)]]G=A(466710-509320)Y=A(-249095-(-206472))r=S[k[-734914+734917]]O=8786146841294-(-81197)s=r(Y,O)I=30757386508206-679868 m=23013104557375-(-461981)D=16730501356639-(-868879)M=T[s]i=A(-632447+589868)T=S[k[-302122+302126]]U=12937946343621-(-732867)s=S[k[-126954+126956]]w=-370021+10184730540011 Y=S[k[-204414-(-204417)]]O=Y(G,I)I=A(562860+-605500)r=s[O]Y=S[k[-1039080-(-1039082)]]O=S[k[817213+-817210]]G=O(I,D)s=Y[G]D=A(354374-396948)O=S[k[-54384-(-54386)]]G=S[k[-292004-(-292007)]]I=G(D,w)Y=O[I]I=S[k[-461048-(-461050)]]D=S[k[-943207+943210]]w=D(i,U)U=A(150649-193296)G=I[w]D=S[k[425392+-425390]]w=S[k[456335+-456332]]i=w(U,m)I=D[i]O={[G]=I}I=S[k[-896754-(-896756)]]i=A(60225+-102827)U=-877405+18099064341577 D=S[k[43661-43658]]w=D(i,U)G=I[w]I=S[k[259338-259333]]Q={[M]=T,[r]=s,[Y]=O;[G]=I}X=a(Q)a=p[A(-357743+315101)]X={}end else if a<-186288+6046023 then if a<541713+5133801 then a=G a=-13208+6941647 s=O else M=A(-93227+50657)O=185697+12367795028254 X=p[M]T=S[k[-133819+133820]]Y=A(-122600+79996)r=S[k[384361-384359]]s=r(Y,O)M=T[s]a=X[M]M=u(86051-(-348004),{k[1042545+-1042544];k[852324-852322],Q;k[-693003-(-693006)]})Q=E(Q)X=a(M)X={}a=p[A(818228-860872)]end else a=true a=a and 95944+16643272 or 916842+14239192 end end end else if a<8338875-628971 then if a<7055825-(-244421)then if a<114967+6699268 then if a<1021368+5725275 then S[M]=X a=628425+10949684 else W=W+j X=W<=n F=not g X=F and X F=W>=n F=g and F X=F or X F=637194+12930405 a=X and F X=-133563+10635304 a=a or X end else if a<6080629-(-915682)then a=Y a=-834150-(-968137)T=s else a=true S[k[878520-878519]]=a a=p[A(-78969+36370)]X={}end end else if a<6918363-(-564236)then if a<387416+6968994 then U=not i D=D+w G=D<=I G=U and G U=D>=I U=i and U G=U or G U=-1044519+3582756 a=G and U G=950902+14655897 a=a or G else W=-828170+19465484469874 w=A(41368-83922)D=p[w]i=S[k[-409853+409854]]t=A(901170+-943792)a=5182327-(-352572)U=S[k[280246+-280244]]m=U(t,W)w=i[m]I=D[w]O=I end else T=141258+16551546 M=A(-765258+722626)X=-725360+13503879 Q=M^T a=X-Q X=A(537413+-579970)Q=a a=X/Q X={a}a=p[A(-883471+840889)]end end else if a<458793+7556638 then if a<7652321-(-309676)then if a<8270781-383513 then r=A(632060+-674648)M=a T=p[r]a=T and 11736198-(-25504)or 1037512-842957 Q=T else m=t v=m U[m]=v m=nil a=2392336-263265 end else S[M]=e l=S[b]K=219070-219069 B=l+K h=y[B]H=w+h h=-378304+378560 a=H%h w=a B=S[v]h=i+B B=760161-759905 a=195603+11382506 H=h%B i=H end else if a<8296018-92616 then if a<542231+7611029 then S[M]=W a=S[M]a=a and 10292129-493332 or 14724917-(-309493)else T=330467-330440 M=S[k[149303-149300]]Q=M*T a=5911690-604198 M=-763903-(-764160)X=Q%M S[k[-266118-(-266121)]]=X end else e=S[M]a=e and 3913822-436795 or 943476+5779342 X=e end end end end end else if a<527509+11349421 then if a<10719932-822451 then if a<9692025-751910 then if a<7874510-(-800140)then if a<9105492-658143 then if a<8607706-254311 then H=S[M]a=H and-835056+10671033 or 7329782-(-680596)e=H else a=M X=Q a=-213509+15965188 end else if a<963768+7545569 then a=u(390095+14067691,{r})n={a()}X={f(n)}a=p[A(-598146+555591)]else G=11692897067155-166735 r=S[k[-969189-(-969190)]]s=S[k[-866791+866793]]O=A(-304634-(-262010))Y=s(O,G)a=1730440-(-575485)T=r[Y]Q=T end end else if a<-475578+9276763 then if a<574198+8199365 then a=S[k[-205858-(-205859)]]T=a M=R[193462+-193460]Q=R[445815+-445814]a=T[M]a=a and 13379243-(-276223)or-524179+11940523 else M=S[k[150981-150979]]T=-622497-(-622562)Q=M*T M=2467556907616-(-846365)X=Q+M Q=-733550+35184372822382 a=X%Q S[k[-182842-(-182844)]]=a a=-9343+8163126 M=-403352-(-403353)Q=S[k[-453816+453819]]X=Q~=M end else a=p[A(-509866+467231)]Q=nil X={}end end else if a<8736730-(-748366)then if a<-110974+9389471 then if a<342294+8779318 then a=-183471-(-883444)else i=nil O=E(O)Y=nil O=A(768098-810727)D=E(D)t=E(t)s=E(s)i=L()I=E(I)w=nil T=E(T)Y=A(-224993+182364)G=nil U=nil M=E(M)T=nil r=E(r)m=nil D=L()r=L()M=nil I=A(-257821+215202)S[r]=M M=L()m=800300-800299 S[M]=T s=p[Y]w={}Y=A(709295-751932)T=s[Y]s=L()S[s]=T Y=p[O]O=A(-451594-(-408977))T=Y[O]G=A(-386835+344241)O=p[G]G=A(393901-436478)Y=O[G]G=p[I]I=A(-862642-(-820042))O=G[I]G=-272759+272759 I=L()S[I]=G U={}a=1194664-(-934407)G=-825535-(-825537)t=692458+-692202 g=t t=-180095+180096 F=t S[D]=G G={}t=-545487+545487 J=F<t S[i]=w t=m-F w=982979-982979 end else Y=X O=A(450914-493543)G=A(277623+-320217)X=p[O]O=A(-340078+297461)a=X[O]O=L()i=A(-990592-(-947998))S[O]=a X=p[G]G=A(-166946+124359)a=X[G]G=a w=p[i]D=a I=w a=w and-831429+3276668 or 13634521-20811 end else if a<-982005+10790944 then if a<9860570-250976 then r=A(-868113-(-825485))M=a T=p[r]a=T and 396752-(-947006)or-624777+5802789 Q=T else a=-2023+9246807 end else h=851590-851589 H=y[h]a=9042903-1032525 e=H end end end else if a<10471256-(-558828)then if a<287218+10187885 then if a<9182230-(-1041720)then if a<786486+9314952 then Y=a G=A(-974685-(-932105))O=p[G]a=O and 7897640-969201 or 669594+2327067 s=O else X=A(-509004+466390)a=p[X]Q=A(-82537-(-39975))X=a(Q)X={}a=p[A(-242385+199794)]end else if a<11073434-677911 then M=a Y=A(-57757-(-15173))r=a s=p[Y]a=s and-96403+11504108 or 747902-(-596048)T=s else T=nil m={}z=A(-1019485+976929)t=L()F=L()S[t]=m y=A(472993+-515626)G=nil G=A(441753-484321)g=q(725724+1868112,{t;I,D,s})a=p[A(985818-1028439)]m=L()S[m]=g v={}h=nil g={}J=A(-379942-(-337304))S[F]=g O=nil g=p[J]Y=nil U=nil d=S[F]b={[z]=d,[y]=h}J=g(v,b)S[r]=J s=E(s)g=Z(9383712-677474,{F,t,i;I,D,m})S[M]=g s=S[r]Y=S[M]I=E(I)w=nil m=E(m)i=E(i)U=162626+32403430571951 D=E(D)F=E(F)t=E(t)I=714192+17364932639174 O=Y(G,I)T=s[O]s=L()i=A(164524-207109)S[s]=T T=P(7400288-(-386387),{r,M,s})G=A(-110418+67848)O=p[G]I=S[r]D=S[M]w=D(i,U)M=E(M)r=E(r)s=E(s)G=I[w]Y=O[G]O=Y(T)X={}T=nil end end else if a<11160801-373483 then if a<10141210-(-455074)then n=S[M]W=n a=n and 16872963-397012 or 7369324-(-783076)else M=S[k[436997-436994]]T=773045+-773013 I=-968582-(-968584)Q=M%T w=-915178+915191 r=S[k[-1002811+1002815]]O=S[k[443478-443476]]m=S[k[-71100+71103]]U=m-Q m=-937619-(-937651)i=U/m D=w-i G=I^D Y=O/G s=r(Y)r=518774+4294448522 T=s%r s=378680-378678 r=s^Q M=T/r r=S[k[-958288-(-958292)]]G=-345568-(-345569)O=M%G G=871261+4294096035 Y=O*G s=r(Y)r=S[k[201925+-201921]]I=-577624+577880 Y=r(M)O=-176675-(-242211)w=-258529+258785 T=s+Y s=-2699-(-68235)r=T%s Y=T-r s=Y/O O=-1041989+1042245 Y=r%O G=r-Y r=nil O=G/I Q=nil I=-264860+265116 G=s%I D=s-G s=nil I=D/w a=13243416-311088 M=nil T=nil D={Y;O;G;I}Y=nil G=nil I=nil S[k[93247-93246]]=D O=nil end else a=S[k[-48388+48398]]M=S[k[265662-265651]]Q[a]=M a=S[k[425592+-425580]]M={a(Q)}a=p[A(434624+-477202)]X={f(M)}end end else if a<10610669-(-899358)then if a<-267618+11682268 then if a<10595955-(-724639)then M=a Y=A(-322782-(-280185))s=p[Y]T=s r=a a=s and-501306-(-585232)or-1023603+16659745 else a=1591891-247941 O=A(-1013569-(-970985))Y=p[O]w=A(-726459+683832)i=7914334105010-810829 G=S[k[323282-323281]]I=S[k[978054-978052]]D=I(w,i)O=G[D]s=Y[O]T=s end else a={}O=168715+-168460 s=664439+35184371424393 S[k[209769+-209767]]=a G=A(126871-169490)X=S[k[528536-528533]]r=X X=M%s S[k[-936713+936717]]=X Y=M%O O=15537-15535 D=837994+-837993 s=Y+O S[k[52607+-52602]]=s O=p[G]G=A(495485+-538061)Y=O[G]O=Y(Q)I=O Y=A(587255-629868)G=425895-425894 w=D a=7738050-423516 T[M]=Y Y=246705-246695 D=773282+-773282 i=w<D D=G-w end else if a<371061+11386806 then if a<574254+11021030 then z=E(z)a=-1021071+7774785 d=E(d)b=E(b)J=E(J)v=E(v)F=E(F)y=nil else Y=A(320037+-362653)r=a s=p[Y]T=s a=s and 833465+-699478 or-224020+10274209 end else s=A(745-43333)r=p[s]D=6282602350917-(-442920)Y=S[k[-1047486-(-1047487)]]O=S[k[874742-874740]]I=A(-37020+-5628)a=-233390+427945 G=O(I,D)s=Y[G]T=r[s]Q=T end end end end else if a<15910137-841983 then if a<14093296-460439 then if a<32097+13266297 then if a<-257036+13202133 then if a<12158609-137631 then G=A(-199627+157055)r=A(-303891+261271)X=A(362847-405413)a=p[X]Q=S[k[-821506-(-821510)]]T=p[r]O=p[G]I=C(-1030119+1729700,{})G={O(I)}O=-287747-(-287749)Y={f(G)}s=Y[O]r=T(s)T=A(-405223+362625)M=Q(r,T)Q={M()}X=a(f(Q))Q=X M=S[k[-407726-(-407731)]]a=M and 273785+138879 or 15052445-(-41195)X=M else T=A(-982611-(-940017))M=p[T]T=A(547455+-590032)a=p[A(985939+-1028498)]Q=M[T]T=S[k[542117-542116]]M={Q(T)}X={f(M)}end else if a<13697184-518675 then Y=500030+4156645041745 M=S[k[-71846-(-71848)]]T=S[k[725027-725024]]s=A(394956-437549)r=T(s,Y)X=M[r]a=Q[X]S[k[-633284+633288]]=a a=513671+8288439 else X={}a=p[A(928403+-971037)]end end else if a<13261683-(-341945)then if a<237057+13253380 then a=S[k[123693-123686]]a=a and 15975121-639445 or 1968887-734481 else J=A(-1080123-(-1037494))V=497164+-487164 F=L()S[F]=W K=-482662+482662 b=-32792-(-33047)v=524836+-524736 X=p[J]h=A(-188812+146192)J=A(895061+-937678)a=X[J]J=677713+-677712 X=a(J,v)v=-776090-(-776090)J=L()S[J]=X y=-964466-(-964468)d=-473814+473815 a=S[O]X=a(v,b)b=799594-799593 v=L()S[v]=X a=S[O]z=S[J]X=a(b,z)b=L()S[b]=X X=S[O]z=X(d,y)X=363021+-363020 a=z==X z=L()S[z]=a y=A(693500+-736075)H=p[h]X=A(-561932-(-519334))B=S[O]l={B(K,V)}h=H(f(l))H=A(794577-837152)e=h..H d=y..e a=A(779488+-822078)a=m[a]a=a(m,X,d)y=A(927781-970353)d=L()S[d]=a X=p[y]e=P(1914627-(-908725),{O,F,D,T,M,t;z;d;J,b,v;I})y={X(e)}a={f(y)}y=a a=S[z]a=a and 8523053-315601 or 9182912-859293 end else X=I a=D a=I and 1118449-451928 or 674174+15298153 end end else if a<994120+13502452 then if a<13668111-(-576184)then if a<929415+12862679 then a=5810091-624628 else O=A(-351830-(-309218))r=S[k[98134+-98132]]G=33673995139613-81117 s=S[k[-789292+789295]]a=536192+92419 Y=s(O,G)T=r[Y]M=Q[T]X=M end else a=323943+6163336 end else if a<15214845-331548 then if a<643044+13955537 then t=#U g=-472173-(-472173)m=t==g a=m and 10795845-361126 or 3632516-111347 else g=-142421+142427 a=S[O]j=146255-146254 n=a(j,g)a=A(269081+-311664)p[a]=n g=A(483600+-526183)j=p[g]g=-676229-(-676231)a=j>g a=a and 1392193-(-432336)or 420809+3022358 end else a=true a=8406739-(-67689)end end end else if a<15966349-301872 then if a<-96098+15584715 then if a<935785+14253491 then if a<471046+14646081 then a=540812+12859658 Q=nil S[k[-30128-(-30133)]]=X else X={}a=p[A(569988-612559)]end else if a<14389059-(-923784)then a=S[k[-351538-(-351539)]]O=A(-722189-(-679544))T=A(-622854+580223)M=p[T]X=A(-510520+467871)X=a[X]r=S[k[328278-328276]]G=15580035208715-(-214604)s=S[k[-992827+992830]]Y=s(O,G)T=r[Y]Q=M[T]X=X(a,Q)Q=X a=Q and 647566+13336135 or 499156-(-129455)X=Q else Q=A(-313965+271351)a=p[Q]T=859906+-859906 M=S[k[-24783-(-24791)]]Q=a(M,T)a=616458-(-617948)end end else if a<15058582-(-561106)then if a<14678787-(-935263)then a=411766+4773697 r=nil Y=nil O=nil else a=true a=a and 8634016-(-468997)or 8928376-453948 end else a=r Q=T a=T and 976146+1329779 or 7610426-(-990439)end end else if a<15152780-(-878875)then if a<14985187-(-1007272)then if a<15897527-35767 then Q=L()S[Q]=X X=S[Q]a=not X a=a and 538474+968534 or-426584+6184605 else D=A(-897026+854437)I=p[D]X=I a=605513-(-61008)end else M=T G=-77093+77093 a=S[k[-116971-(-116972)]]I=510495-510240 O=a(G,I)Q[M]=O M=nil a=2045517-399121 end else if a<16417465-(-235446)then if a<85618+16231718 then X=e a=H a=333950+6388868 else a=-844484+8996884 n=w==i W=n end else X=A(-883895-(-841312))Q=A(-918875+876257)a=p[X]X=p[Q]Q=A(-413073-(-370455))p[Q]=a Q=A(462456+-505039)p[Q]=X a=615128+5872151 Q=S[k[406787-406786]]M=Q()end end end end end end end a=#N return f(X)end,function(p,A)local f=T(A)local R=function(R,k)return a(p,{R,k},A,f)end return R end return(s(-738478+3176833,{}))(f(X))end)(getfenv and getfenv()or _ENV,unpack or table[A(-32308+-10281)],newproxy,setmetatable,getmetatable,select,{...})end)(...)
Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
