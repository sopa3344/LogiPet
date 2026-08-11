using System.ComponentModel;
using System.Globalization;
using System.Windows;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace LogiPet;

public partial class MainWindow : Window
{
    private enum CompanionActivityState { Waiting, Walking, Running, Sitting, Resting, Sleeping }

    private readonly PetState _state = PetState.Load();
    private readonly PipeActionServer _pipeServer;
    private readonly DispatcherTimer _batteryTimer;
    private readonly DispatcherTimer _speechTimer;
    private readonly DispatcherTimer _balloonTimer;
    private readonly DispatcherTimer _motionResetTimer;
    private readonly DispatcherTimer _recoveryTimer;
    private readonly DispatcherTimer _spriteTimer;
    private readonly DispatcherTimer _activityTimer;
    private MouseActivityTracker? _mouseTracker;
    private int? _batteryLevel;
    private bool _isBatteryRefreshing;
    private bool _isRecovering;
    private string _petAnimation = string.Empty;
    private int _petFrame;
    private int _petFrameCount;
    private bool _petAnimationLoops;
    private bool _petAnimationLocked;
    private bool _activityStateDirty;
    private int _activitySaveTicks;
    private DateTime _lastMouseInputUtc = DateTime.MinValue;
    private DateTime _lastSprintUtc = DateTime.MinValue;
    private DateTime _lastAutomaticSpeechUtc = DateTime.MinValue;
    private int _lastHourlyGreetingKey;
    private int _talkIndex;
    private CompanionActivityState _activityState = CompanionActivityState.Waiting;
    private double _recentMotion;
    private int _recentClicks;
    private double _currentSessionSeconds;
    private bool _hasMouseInput;
    private int _petFacing = 1;
    private double _petFrameCenterX = 50;
    private readonly Dictionary<string, double> _frameCenterCache = new();
    private const double EstimatedWheelMetersPerNotch = 0.0025;

    public MainWindow()
    {
        InitializeComponent();
        _pipeServer = new PipeActionServer(action => Dispatcher.Invoke(() => HandleAction(action)));
        _batteryTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(45) };
        _batteryTimer.Tick += async (_, _) => await RefreshBatteryAsync();

        _speechTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3.2) };
        _speechTimer.Tick += (_, _) =>
        {
            _speechTimer.Stop();
            SpeechText.Text = GetBatteryPhrase();
        };

        _balloonTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(8) };
        _balloonTimer.Tick += (_, _) =>
        {
            _balloonTimer.Stop();
            SpeechBalloonPopup.IsOpen = false;
        };

        _motionResetTimer = new DispatcherTimer();
        _motionResetTimer.Tick += (_, _) =>
        {
            _motionResetTimer.Stop();
            ApplyBatteryMotion();
        };

        _recoveryTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(6) };
        _recoveryTimer.Tick += (_, _) =>
        {
            _recoveryTimer.Stop();
            _isRecovering = false;
            BoltEffect.Visibility = Visibility.Collapsed;
            UpdateStateUi();
        };

        _spriteTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(120) };
        _spriteTimer.Tick += (_, _) => AdvancePetFrame();

        _activityTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _activityTimer.Tick += (_, _) =>
        {
            UpdateClock();
            TickCompanionActivity();
            MaybeOfferHourlyGreeting();
            if (_activityStateDirty && ++_activitySaveTicks >= 15)
            {
                _state.Save();
                _activityStateDirty = false;
                _activitySaveTicks = 0;
            }
        };
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e)
    {
        RestoreWindowPosition();
        _state.PetName = PetState.NormalizePetName(_state.PetName);
        ApplyPetNameUi();
        _state.EnsureToday();
        _state.IsSleeping = false;
        try
        {
            _mouseTracker = new MouseActivityTracker(this, OnMouseActivity);
        }
        catch
        {
            ActivityScopeText.Text = "입력 추적 사용 불가";
        }
        _pipeServer.Start();
        _batteryTimer.Start();
        _activityTimer.Start();
        UpdateActivityUi();
        UpdateClock();
        _lastHourlyGreetingKey = GetHourKey(DateTime.Now);
        UpdateStateUi();
        await RefreshBatteryAsync();
        ShowSpeechBalloon(GetContextualPhrase());
    }

    private void RestoreWindowPosition()
    {
        var workArea = SystemParameters.WorkArea;
        if (_state.WindowLeft is double savedLeft && _state.WindowTop is double savedTop &&
            double.IsFinite(savedLeft) && double.IsFinite(savedTop))
        {
            Left = Math.Clamp(savedLeft, workArea.Left, Math.Max(workArea.Left, workArea.Right - Width));
            Top = Math.Clamp(savedTop, workArea.Top, Math.Max(workArea.Top, workArea.Bottom - Height));
            return;
        }

        Left = workArea.Right - Width - 14;
        Top = workArea.Bottom - Height - 12;
    }

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        _batteryTimer.Stop();
        _speechTimer.Stop();
        _balloonTimer.Stop();
        _motionResetTimer.Stop();
        _recoveryTimer.Stop();
        _spriteTimer.Stop();
        _activityTimer.Stop();
        _mouseTracker?.Dispose();
        _pipeServer.Dispose();
        _state.WindowLeft = Left;
        _state.WindowTop = Top;
        _state.Save();
    }

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left && !IsInsideButton(e.OriginalSource as DependencyObject))
            DragMove();
    }

    private void Window_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState != MouseButtonState.Pressed || IsInsideButton(e.OriginalSource as DependencyObject))
            return;

        var catPoint = e.GetPosition(CatHitArea);
        if (catPoint.X >= 0 && catPoint.X <= CatHitArea.ActualWidth &&
            catPoint.Y >= 0 && catPoint.Y <= CatHitArea.ActualHeight)
            return;

        DragMove();
    }

    private static bool IsInsideButton(DependencyObject? source)
    {
        while (source is not null)
        {
            if (source is ButtonBase)
                return true;
            source = VisualTreeHelper.GetParent(source);
        }
        return false;
    }

    private void Cat_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        PlayPetAnimation("bark", 3, 150, loop: false, locked: true, force: true);
        ActionMenuPopup.IsOpen = false;
        TalkToMochi();
        e.Handled = true;
    }

    private void Cat_MouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        PlayPetAnimation("itching", 2, 180, loop: false, locked: true, force: true);
        ActionMenuPopup.IsOpen = true;
        e.Handled = true;
    }

    private void HandleAction(string action)
    {
        if (action is "snack" or "water" or "highfive" or "stretch" or "play" or
            "come" or "zoomies" or "speak" or "sit" or "lie" or "nap" or "scratch" or
            "journal" or "feed" or "sleep" or "status")
        {
            _state.EnsureToday();
            _state.ActionRingActionsToday++;
            _activityStateDirty = true;
            UpdateActivityUi();
        }

        switch (action)
        {
            case "snack":
            case "feed": CelebrateWithSnack(); break;
            case "water": DrinkWater(); break;
            case "highfive": HighFive(); break;
            case "stretch":
            case "sleep": StretchTogether(); break;
            case "play": ShortPlay(); break;
            case "come": ComeHere(); break;
            case "zoomies": Zoomies(); break;
            case "speak": Speak(); break;
            case "sit": SitStill(); break;
            case "lie": LieDown(); break;
            case "nap": TakeNap(); break;
            case "scratch": Scratch(); break;
            case "journal":
            case "status": OpenFootprints(); break;
            case "battery": _ = RefreshBatteryAsync(); break;
        }
    }

    private void Feed_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        CelebrateWithSnack();
    }

    private void Talk_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        TalkToMochi();
    }

    private void TalkToMochi()
    {
        RecordCompanionMoment();
        Say(GetContextualPhrase());
        PlayPetAnimation("bark", 3, 150, loop: false, locked: true, force: true);
    }

    private void CloseSpeechBalloon_Click(object sender, RoutedEventArgs e)
    {
        _balloonTimer.Stop();
        SpeechBalloonPopup.IsOpen = false;
    }

    private void BalloonActivity_Click(object sender, RoutedEventArgs e)
    {
        SpeechBalloonPopup.IsOpen = false;
        OpenFootprints();
    }

    private void Play_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        HighFive();
    }

    private void Sleep_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        StretchTogether();
    }

    private void ShortPlay_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        ShortPlay();
    }

    private void Status_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        OpenFootprints();
    }

    private void Rename_Click(object sender, RoutedEventArgs e)
    {
        ActionMenuPopup.IsOpen = false;
        StatusPopup.IsOpen = false;
        PetNameInput.Text = _state.PetName;
        PetNameValidationText.Visibility = Visibility.Collapsed;
        NamePopup.IsOpen = true;
        Dispatcher.BeginInvoke(() =>
        {
            PetNameInput.Focus();
            PetNameInput.SelectAll();
        }, DispatcherPriority.Input);
    }

    private void SaveName_Click(object sender, RoutedEventArgs e)
    {
        var value = PetNameInput.Text.Trim();
        if (string.IsNullOrWhiteSpace(value))
        {
            PetNameValidationText.Visibility = Visibility.Visible;
            PetNameInput.Focus();
            return;
        }

        _state.PetName = PetState.NormalizePetName(value);
        _state.Save();
        ApplyPetNameUi();
        NamePopup.IsOpen = false;
        Say($"이제 내 이름은 {_state.PetName}야! 잘 부탁해.");
    }

    private void CancelName_Click(object sender, RoutedEventArgs e) => NamePopup.IsOpen = false;

    private void ApplyPetNameUi()
    {
        var name = _state.PetName;
        Title = $"LogiPet - {name}";
        AppTitleText.Text = Title;
        BalloonNameText.Text = name;
        TalkMenuText.Text = $"{name}에게 말 걸기";
        TalkContextMenuItem.Header = $"{name}에게 말 걸기";
        StatusTitleText.Text = $"{name} 상태";
        CurrentPetGroup.Header = $"지금 {name}";
    }

    private async void RefreshBattery_Click(object sender, RoutedEventArgs e) => await RefreshBatteryAsync();
    private void CloseStatus_Click(object sender, RoutedEventArgs e) => StatusPopup.IsOpen = false;
    private void Exit_Click(object sender, RoutedEventArgs e) => Close();

    private void CelebrateWithSnack()
    {
        RecordCompanionMoment();
        Say(_state.ActiveSecondsToday >= 1800
            ? "오늘도 같이 잘하고 있어! 냠냠!"
            : "좋아, 천천히 같이 시작해 보자!");
        PlayPetAnimation("licking1", 4, 140, loop: false, locked: true, force: true);
        AnimateSquish();
    }

    private void HighFive()
    {
        RecordCompanionMoment();
        var minutes = (int)(_state.ActiveSecondsToday / 60);
        Say(minutes >= 1
            ? $"하이파이브! 오늘 우리 {minutes}분 함께했어!"
            : "하이파이브! 오늘도 같이 가자!");
        PlayPetAnimation("bark", 3, 150, loop: false, locked: true, force: true);
        AnimateJump();
    }

    private void DrinkWater() => PerformAnimationMoment(
        "물 한 모금 마시고 다시 같이 가자!", "licking2", 4, 145);

    private void ComeHere() => PerformAnimationMoment(
        "불렀어? 바로 왔어!", "walk", 8, 120);

    private void Zoomies() => PerformAnimationMoment(
        "갑자기 신나졌어! 한 바퀴 달린다!", "run", 8, 82, jump: true);

    private void Speak() => PerformAnimationMoment(
        "멍! 오늘도 옆에 있을게", "bark", 3, 150, jump: true);

    private void SitStill() => PerformAnimationMoment(
        "얌전히 앉아서 기다릴게", "sitting", 1, 1400);

    private void LieDown() => PerformAnimationMoment(
        "여기서 편하게 쉬고 있을게", "lying-down", 7, 155);

    private void TakeNap() => PerformAnimationMoment(
        "잠깐 눈만 붙일게… zZ", "sleeping", 1, 2200);

    private void Scratch() => PerformAnimationMoment(
        "간질간질! 한 번 긁고 갈게", "itching", 2, 220);

    private void PerformAnimationMoment(string phrase, string animation, int frames, int intervalMs, bool jump = false)
    {
        RecordCompanionMoment();
        Say(phrase);
        PlayPetAnimation(animation, frames, intervalMs, loop: false, locked: true, force: true);
        if (jump)
            AnimateJump();
    }

    private void StretchTogether()
    {
        RecordCompanionMoment();
        Say(_currentSessionSeconds >= 1200
            ? "우리 오래 걸었어. 잠깐 같이 쭉 펴자!"
            : "좋아, 같이 한 번 쭉—!"
        );
        PlayPetAnimation("stretching", 10, 110, loop: false, locked: true, force: true);
    }

    private void ShortPlay()
    {
        RecordCompanionMoment();
        Say("신난다! 한 바퀴만 뛰고 다시 같이 가자!");
        PlayPetAnimation("run", 8, 85, loop: false, locked: true, force: true);
        AnimateJump();
    }

    private void OpenFootprints()
    {
        StatusPopup.IsOpen = true;
        StatusTabs.SelectedItem = ActivityTab;
        UpdateActivityUi();
        Say("오늘 우리 발자국을 모아 봤어");
    }

    private void RecordCompanionMoment()
    {
        _state.EnsureToday();
        _state.CompanionMomentsToday++;
        _activityStateDirty = true;
        UpdateActivityUi();
    }

    private async Task RefreshBatteryAsync()
    {
        if (_isBatteryRefreshing)
            return;

        _isBatteryRefreshing = true;
        BatteryDetail.Text = "배터리를 확인하는 중…";
        ConnectionDetail.Text = "연결 확인 중";
            ConnectionText.Text = "MX 확인 중";
        try
        {
            var previousLevel = _batteryLevel;
            var reading = await BatteryService.ReadMxMaster4Async();
            _batteryLevel = reading.Level;

            if (previousLevel.HasValue && reading.Level > previousLevel.Value)
                BeginRecoveryReaction();

            BatteryText.Text = reading.Level is int level ? $"{level}%" : "--%";
            BatteryDetail.Text = reading.Level is int value
                ? $"배터리 {value}% · {GetEnergyLabel(value)}"
                : reading.Message;
            ConnectionDetail.Text = reading.Connected ? "연결됨" : "연결 대기 중";
            ConnectionText.Text = reading.Connected ? "MX 연결됨" : "MX 연결 대기";
            ConnectionLed.Background = new SolidColorBrush(reading.Connected
                ? Color.FromRgb(45, 212, 143)
                : Color.FromRgb(242, 181, 65));

            UpdateBatteryVisual();
            UpdateStateUi();
            SpeechText.Text = GetBatteryPhrase();
        }
        finally
        {
            _isBatteryRefreshing = false;
        }
    }

    private void UpdateStateUi()
    {
        UpdateActivityUi();
        ApplyBatteryMotion();
    }

    private void OnMouseActivity(MouseActivitySample sample)
    {
        _state.EnsureToday();
        var now = DateTime.UtcNow;
        var wasAway = _hasMouseInput && (now - _lastMouseInputUtc).TotalMinutes >= 10;
        _hasMouseInput = true;
        _lastMouseInputUtc = now;

        _state.LeftClicksToday += sample.LeftClicks;
        _state.RightClicksToday += sample.RightClicks;
        _state.MiddleClicksToday += sample.MiddleClicks;
        _state.WheelDeltaToday += Math.Abs(sample.WheelDelta);
        var movement = Math.Sqrt(sample.DeltaX * (double)sample.DeltaX + sample.DeltaY * (double)sample.DeltaY);
        _state.PointerDistanceUnitsToday += movement;
        _recentMotion += movement;
        _recentClicks += sample.LeftClicks + sample.RightClicks + sample.MiddleClicks;
        _activityStateDirty = true;

        if (wasAway && CanSpeakAutomatically())
        {
            Say("다시 왔구나! 같이 걸어가자");
            PlayPetAnimation("stretching", 10, 105, loop: false, locked: true, force: true);
        }

        UpdateActivityUi();
        UpdateFacingFromCursor();

    }

    private void TickCompanionActivity()
    {
        _state.EnsureToday();
        var now = DateTime.UtcNow;
        var idleSeconds = _hasMouseInput ? (now - _lastMouseInputUtc).TotalSeconds : double.MaxValue;
        var isActive = idleSeconds < 5;

        if (isActive)
        {
            _state.ActiveSecondsToday += 1;
            _currentSessionSeconds += 1;
            _state.LongestSessionSecondsToday = Math.Max(_state.LongestSessionSecondsToday, _currentSessionSeconds);
            _activityStateDirty = true;
        }
        else if (idleSeconds >= 120)
        {
            _currentSessionSeconds = 0;
        }

        var intensity = _recentMotion + _recentClicks * 80;
        var nextState = idleSeconds switch
        {
            >= 600 => CompanionActivityState.Sleeping,
            >= 120 => CompanionActivityState.Resting,
            >= 12 => CompanionActivityState.Sitting,
            >= 3 => CompanionActivityState.Waiting,
            _ when intensity >= 320 => CompanionActivityState.Running,
            _ => CompanionActivityState.Walking
        };

        if (nextState != _activityState)
        {
            if (nextState == CompanionActivityState.Running &&
                (now - _lastSprintUtc).TotalSeconds >= 90)
            {
                _lastSprintUtc = now;
                _state.SprintMomentsToday++;
                _activityStateDirty = true;
            }
            _activityState = nextState;
            ApplyBatteryMotion();
        }

        _recentMotion *= 0.2;
        _recentClicks = 0;
        MaybeCelebrateMilestone();
        UpdateFacingFromCursor();
        UpdateActivityUi();
    }

    private void UpdateFacingFromCursor()
    {
        if (CatHitArea.ActualWidth <= 0)
            return;

        var cursor = Mouse.GetPosition(CatHitArea);
        var facing = cursor.X < CatHitArea.ActualWidth / 2 ? -1 : 1;
        if (facing == _petFacing)
            return;

        _petFacing = facing;
        UpdatePetFrameTransform();
    }

    private void UpdatePetFrameTransform()
    {
        PetFacing.ScaleX = _petFacing;
        var renderedScale = PetSprite.Width / 100d;
        PetFrameOffset.X = _petFacing * (50 - _petFrameCenterX) * renderedScale;
    }

    private void MaybeCelebrateMilestone()
    {
        var minutes = (int)(_state.ActiveSecondsToday / 60);
        var milestone = minutes switch
        {
            >= 120 => minutes / 60 * 60,
            >= 60 => 60,
            >= 30 => 30,
            _ => 0
        };
        if (milestone == 0 || milestone <= _state.LastCelebratedMilestoneMinutesToday || !CanSpeakAutomatically())
            return;

        _state.LastCelebratedMilestoneMinutesToday = milestone;
        _activityStateDirty = true;
        Say(milestone >= 60
            ? $"우리 오늘 {milestone / 60}시간이나 함께 걸었어!"
            : "우리 벌써 30분이나 함께 걸었어!");
        PlayPetAnimation("bark", 3, 150, loop: false, locked: true, force: true);
        AnimateJump();
    }

    private bool CanSpeakAutomatically()
    {
        var now = DateTime.UtcNow;
        if ((now - _lastAutomaticSpeechUtc).TotalMinutes < 5)
            return false;
        _lastAutomaticSpeechUtc = now;
        return true;
    }

    private void UpdateActivityUi()
    {
        var wheelTurns = _state.WheelDeltaToday / 120d;
        var wheelMeters = wheelTurns * EstimatedWheelMetersPerNotch;
        ActivityDateText.Text = DateTime.Today.ToString("M월 d일");
        ActivityScopeText.Text = _mouseTracker?.HasSeenLogitechDevice == true
            ? "Logitech 입력 · 로컬 저장"
            : "Logitech 입력 대기 · 로컬 저장";
        LeftClicksText.Text = $"{_state.LeftClicksToday:N0}번";
        RightClicksText.Text = $"{_state.RightClicksToday:N0}번";
        MiddleClicksText.Text = $"{_state.MiddleClicksToday:N0}번";
        ActionRingText.Text = $"{_state.ActionRingActionsToday:N0}번";
        WheelTurnsText.Text = $"{wheelTurns:N0}회";
        WheelDistanceText.Text = $"{wheelMeters:N2} m";

        var stateLabel = GetActivityLabel(_activityState);
        ActivityModeText.Text = stateLabel;
        CurrentActivityText.Text = stateLabel;
        CurrentSessionText.Text = FormatDuration(_currentSessionSeconds);
    }

    private static string FormatDuration(double totalSeconds)
    {
        var span = TimeSpan.FromSeconds(Math.Max(0, totalSeconds));
        return span.TotalHours >= 1 ? $"{(int)span.TotalHours}시간 {span.Minutes}분" : $"{Math.Max(0, (int)span.TotalMinutes)}분";
    }

    private static string GetActivityLabel(CompanionActivityState state) => state switch
    {
        CompanionActivityState.Walking => "함께 걷는 중",
        CompanionActivityState.Running => "신나게 달리는 중",
        CompanionActivityState.Sitting => "옆에서 기다리는 중",
        CompanionActivityState.Resting => "함께 쉬는 중",
        CompanionActivityState.Sleeping => "자리를 지키는 중",
        _ => "곁에 있는 중"
    };

    private void UpdateClock()
    {
        var now = DateTime.Now;
        var culture = CultureInfo.GetCultureInfo("ko-KR");
        ClockText.Text = now.ToString("tt h:mm", culture);
        ClockDateText.Text = now.ToString("yyyy년 M월 d일 dddd", culture);
    }

    private void MaybeOfferHourlyGreeting()
    {
        var now = DateTime.Now;
        var hourKey = GetHourKey(now);
        if (now.Minute != 0 || hourKey == _lastHourlyGreetingKey || !CanSpeakAutomatically())
            return;

        _lastHourlyGreetingKey = hourKey;
        Say($"{FormatTime(now)}야. {GetTimeOfDayMessage(now.Hour)}");
    }

    private static int GetHourKey(DateTime value) =>
        value.Year * 1_000_000 + value.Month * 10_000 + value.Day * 100 + value.Hour;

    private string GetContextualPhrase()
    {
        var now = DateTime.Now;
        var totalClicks = _state.LeftClicksToday + _state.RightClicksToday + _state.MiddleClicksToday;
        var wheelTurns = _state.WheelDeltaToday / 120d;
        var phrases = new List<string>
        {
            $"{FormatTime(now)}야. {GetTimeOfDayMessage(now.Hour)}",
            totalClicks > 0
                ? $"오늘 클릭을 {totalClicks:N0}번 했어. 나는 여기서 같이 걷고 있었어!"
                : "아직 오늘의 첫 클릭을 기다리는 중이야. 천천히 시작하자!",
            wheelTurns >= 1
                ? $"오늘 휠을 약 {wheelTurns:N0}바퀴 굴렸어. 꽤 멀리 함께 왔네!"
                : GetActivityCompanionPhrase()
        };

        if (_batteryLevel is < 15)
            phrases[2] = "배터리가 조금 졸려 보여. 여유 있을 때 충전해 주자!";

        var phrase = phrases[_talkIndex % phrases.Count];
        _talkIndex++;
        return phrase;
    }

    private string GetActivityCompanionPhrase() => _activityState switch
    {
        CompanionActivityState.Running => "방금 손이 아주 빨랐어! 나도 신나게 뛰는 중이야.",
        CompanionActivityState.Walking => "마우스를 움직일 때마다 나도 제자리에서 함께 걷고 있어.",
        CompanionActivityState.Sitting => "잠깐 조용해졌네. 나는 옆에서 기다리고 있을게.",
        CompanionActivityState.Resting => "잠깐 쉬는 것도 좋아. 다시 움직이면 나도 따라갈게.",
        CompanionActivityState.Sleeping => "조용해서 잠깐 눈을 붙였어. 그래도 자리는 지키고 있었어!",
        _ => "무슨 일을 시작하든 오늘도 옆에서 같이 갈게."
    };

    private static string GetTimeOfDayMessage(int hour) => hour switch
    {
        >= 5 and < 11 => "좋은 아침! 천천히 오늘을 시작하자.",
        >= 11 and < 14 => "점심때네. 손도 잠깐 쉬어 가자.",
        >= 14 and < 18 => "오후도 나란히 같이 가는 중이야.",
        >= 18 and < 22 => "오늘 하루도 거의 다 왔어. 조금만 더 같이 가자.",
        _ => "늦은 시간이야. 너무 무리하지는 말자."
    };

    private static string FormatTime(DateTime value) =>
        value.ToString("tt h:mm", CultureInfo.GetCultureInfo("ko-KR"));

    private void UpdateBatteryVisual()
    {
        var level = _batteryLevel ?? 0;
        BatteryBar.Value = level;
        BubbleBatteryBar.Value = level;
        var color = level switch
        {
            >= 60 => Color.FromRgb(45, 212, 143),
            >= 25 => Color.FromRgb(242, 181, 65),
            _ => Color.FromRgb(231, 72, 50)
        };
        var brush = new SolidColorBrush(color);
        BatteryBar.Foreground = brush;
        BubbleBatteryBar.Foreground = brush;
        BatteryText.Foreground = brush;

        var iconPath = _batteryLevel is < 15
            ? "Assets/Icons/warning.png"
            : "Assets/Icons/battery.png";
        BatteryStateIcon.Source = new BitmapImage(new Uri(iconPath, UriKind.Relative));
    }

    private void ApplyBatteryMotion()
    {
        PetMove.BeginAnimation(TranslateTransform.XProperty, null);
        PetMove.BeginAnimation(TranslateTransform.YProperty, null);

        if (_petAnimationLocked)
            return;

        if (_isRecovering)
        {
            PlayPetAnimation("stretching", 10, 95, loop: true);
            AnimateHappyHop();
            return;
        }

        switch (_activityState)
        {
            case CompanionActivityState.Running:
                PlayPetAnimation("run", 8, 88, loop: true);
                PetMove.BeginAnimation(TranslateTransform.YProperty, LoopAnimation(0, -3.2, 0.7));
                break;
            case CompanionActivityState.Walking:
                PlayPetAnimation("walk", 8, 120, loop: true);
                PetMove.BeginAnimation(TranslateTransform.YProperty, LoopAnimation(0, -1.2, 1.3));
                break;
            case CompanionActivityState.Sitting:
                PlayPetAnimation("sitting", 1, 500, loop: false);
                break;
            case CompanionActivityState.Resting:
                PlayPetAnimation("lying-down", 7, 155, loop: false);
                break;
            case CompanionActivityState.Sleeping:
                PlayPetAnimation("sleeping", 1, 500, loop: false);
                PetMove.BeginAnimation(TranslateTransform.YProperty, LoopAnimation(0, -0.5, 3.8));
                break;
            default:
                PlayPetAnimation("idle", 10, 145, loop: true);
                PetMove.BeginAnimation(TranslateTransform.YProperty, LoopAnimation(0, -1.0, 2.8));
                break;
        }
    }

    private void PlayPetAnimation(string animation, int frameCount, int intervalMs,
        bool loop, bool locked = false, bool force = false)
    {
        if (!force && _petAnimation == animation && _petAnimationLoops == loop && !_petAnimationLocked)
            return;

        _petAnimation = animation;
        _petFrame = 0;
        _petFrameCount = frameCount;
        _petAnimationLoops = loop;
        _petAnimationLocked = locked;
        _spriteTimer.Interval = TimeSpan.FromMilliseconds(intervalMs);
        ShowPetFrame();

        if (frameCount > 1 || locked)
            _spriteTimer.Start();
        else
            _spriteTimer.Stop();
    }

    private void AdvancePetFrame()
    {
        if (_petFrame + 1 < _petFrameCount)
        {
            _petFrame++;
            ShowPetFrame();
            return;
        }

        if (_petAnimationLoops)
        {
            _petFrame = 0;
            ShowPetFrame();
            return;
        }

        _spriteTimer.Stop();
        if (_petAnimationLocked)
        {
            _petAnimationLocked = false;
            ApplyBatteryMotion();
        }
    }

    private void ShowPetFrame()
    {
        var fileName = $"Golden-Retriever-{_petAnimation}.png";
        var uri = new Uri($"pack://application:,,,/Assets/Pets/GoldenRetriever/{fileName}", UriKind.Absolute);
        var sheet = new BitmapImage();
        sheet.BeginInit();
        sheet.CacheOption = BitmapCacheOption.OnLoad;
        sheet.UriSource = uri;
        sheet.EndInit();
        sheet.Freeze();

        var frame = new CroppedBitmap(sheet, new Int32Rect(_petFrame * 100, 0, 100, 100));
        frame.Freeze();
        PetSprite.Source = frame;
        var cacheKey = $"{_petAnimation}:{_petFrame}";
        if (!_frameCenterCache.TryGetValue(cacheKey, out _petFrameCenterX))
        {
            _petFrameCenterX = FindOpaqueCenterX(frame);
            _frameCenterCache[cacheKey] = _petFrameCenterX;
        }
        UpdatePetFrameTransform();
    }

    private static double FindOpaqueCenterX(BitmapSource source)
    {
        var converted = new FormatConvertedBitmap(source, PixelFormats.Bgra32, null, 0);
        var stride = converted.PixelWidth * 4;
        var pixels = new byte[stride * converted.PixelHeight];
        converted.CopyPixels(pixels, stride, 0);
        var minX = converted.PixelWidth;
        var maxX = -1;

        for (var y = 0; y < converted.PixelHeight; y++)
        {
            for (var x = 0; x < converted.PixelWidth; x++)
            {
                if (pixels[y * stride + x * 4 + 3] == 0)
                    continue;
                minX = Math.Min(minX, x);
                maxX = Math.Max(maxX, x);
            }
        }

        return maxX >= minX ? (minX + maxX) / 2d : 50;
    }

    private static DoubleAnimation LoopAnimation(double from, double to, double seconds) => new()
    {
        From = from,
        To = to,
        Duration = TimeSpan.FromSeconds(seconds),
        AutoReverse = true,
        RepeatBehavior = RepeatBehavior.Forever,
        EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
    };

    private void BeginRecoveryReaction()
    {
        _isRecovering = true;
        BoltEffect.Visibility = Visibility.Visible;
        BoltEffect.BeginAnimation(OpacityProperty, new DoubleAnimation
        {
            From = 0.2,
            To = 1,
            Duration = TimeSpan.FromMilliseconds(260),
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever
        });
        BoltMove.BeginAnimation(TranslateTransform.YProperty, LoopAnimation(2, -4, 0.55));
        _recoveryTimer.Stop();
        _recoveryTimer.Start();
        Say("충전 에너지 UP! ⚡");
    }

    private string GetBatteryPhrase()
    {
        if (_isRecovering)
            return "충전 에너지 UP! [⚡]";

        if (_batteryLevel is < 15)
            return "마우스 배터리가 낮아. 쉬면서 충전할까?";

        return _activityState switch
        {
            CompanionActivityState.Running => "방금 엄청 빨랐어! 같이 달리는 중",
            CompanionActivityState.Walking => "우리 나란히 걷는 중이야",
            CompanionActivityState.Sitting => "나는 여기서 기다리고 있을게",
            CompanionActivityState.Resting => "잠깐 쉬었다가 다시 같이 가자",
            CompanionActivityState.Sleeping => "zZ… 자리는 내가 지키고 있을게",
            _ => "천천히 시작해도 괜찮아"
        };
    }

    private static string GetEnergyLabel(int level) => level switch
    {
        >= 70 => "쌩쌩함",
        >= 30 => "평온함",
        >= 15 => "졸림",
        _ => "충전 필요"
    };

    private void Say(string text)
    {
        SpeechText.Text = text;
        ShowSpeechBalloon(text);
        BatteryBubble.BeginAnimation(OpacityProperty, new DoubleAnimation(0.45, 1, TimeSpan.FromMilliseconds(140)));
        _speechTimer.Stop();
        _speechTimer.Start();
    }

    private void ShowSpeechBalloon(string text)
    {
        BalloonText.Text = text;
        SpeechBalloonPopup.IsOpen = true;
        _balloonTimer.Stop();
        _balloonTimer.Start();
    }

    private void ScheduleMotionReset(int milliseconds)
    {
        _motionResetTimer.Stop();
        _motionResetTimer.Interval = TimeSpan.FromMilliseconds(milliseconds);
        _motionResetTimer.Start();
    }

    private void AnimateJump()
    {
        PetMove.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation
        {
            From = 0,
            To = -15,
            Duration = TimeSpan.FromMilliseconds(170),
            AutoReverse = true,
            EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
        });
        ScheduleMotionReset(430);
    }

    private void AnimateHappyHop()
    {
        PetMove.BeginAnimation(TranslateTransform.YProperty, LoopAnimation(0, -7, 0.42));
    }

    private void AnimateSquish()
    {
        PetScale.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation
        { From = 1, To = 0.86, Duration = TimeSpan.FromMilliseconds(110), AutoReverse = true });
        PetScale.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation
        { From = 1, To = 1.06, Duration = TimeSpan.FromMilliseconds(110), AutoReverse = true });
        ScheduleMotionReset(330);
    }

    private void AnimateTired()
    {
        PetMove.BeginAnimation(TranslateTransform.XProperty, new DoubleAnimation
        {
            From = -2,
            To = 2,
            Duration = TimeSpan.FromMilliseconds(90),
            AutoReverse = true,
            RepeatBehavior = new RepeatBehavior(3)
        });
        ScheduleMotionReset(650);
    }
}
