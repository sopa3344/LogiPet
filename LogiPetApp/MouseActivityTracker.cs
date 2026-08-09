using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Interop;

namespace LogiPet;

public readonly record struct MouseActivitySample(
    int DeltaX,
    int DeltaY,
    int LeftClicks,
    int RightClicks,
    int MiddleClicks,
    int WheelDelta);

public sealed class MouseActivityTracker : IDisposable
{
    private const int WmInput = 0x00FF;
    private const uint RidInput = 0x10000003;
    private const uint RidiDeviceName = 0x20000007;
    private const uint RidevInputSink = 0x00000100;
    private const ushort MouseLeftButtonDown = 0x0001;
    private const ushort MouseRightButtonDown = 0x0004;
    private const ushort MouseMiddleButtonDown = 0x0010;
    private const ushort MouseWheel = 0x0400;

    private readonly HwndSource _source;
    private readonly Action<MouseActivitySample> _onInput;
    private readonly Dictionary<IntPtr, bool> _logitechDevices = new();
    private bool _disposed;

    public bool HasSeenLogitechDevice { get; private set; }

    public MouseActivityTracker(Window window, Action<MouseActivitySample> onInput)
    {
        _onInput = onInput;
        var handle = new WindowInteropHelper(window).Handle;
        _source = HwndSource.FromHwnd(handle)
            ?? throw new InvalidOperationException("WPF window source is unavailable.");
        _source.AddHook(WindowProc);

        var devices = new[]
        {
            new RawInputDevice
            {
                UsagePage = 0x01,
                Usage = 0x02,
                Flags = RidevInputSink,
                Target = handle
            }
        };

        if (!RegisterRawInputDevices(devices, 1, (uint)Marshal.SizeOf<RawInputDevice>()))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }

    private IntPtr WindowProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg != WmInput || _disposed)
            return IntPtr.Zero;

        uint size = 0;
        var headerSize = (uint)Marshal.SizeOf<RawInputHeader>();
        _ = GetRawInputData(lParam, RidInput, IntPtr.Zero, ref size, headerSize);
        if (size == 0)
            return IntPtr.Zero;

        var buffer = Marshal.AllocHGlobal((int)size);
        try
        {
            if (GetRawInputData(lParam, RidInput, buffer, ref size, headerSize) != size)
                return IntPtr.Zero;

            var header = Marshal.PtrToStructure<RawInputHeader>(buffer);
            if (header.Type != 0 || !IsLogitechDevice(header.Device))
                return IntPtr.Zero;

            HasSeenLogitechDevice = true;
            var mousePointer = IntPtr.Add(buffer, Marshal.SizeOf<RawInputHeader>());
            var mouse = Marshal.PtrToStructure<RawMouse>(mousePointer);
            var wheel = (mouse.ButtonFlags & MouseWheel) != 0 ? (short)mouse.ButtonData : 0;
            var sample = new MouseActivitySample(
                mouse.LastX,
                mouse.LastY,
                (mouse.ButtonFlags & MouseLeftButtonDown) != 0 ? 1 : 0,
                (mouse.ButtonFlags & MouseRightButtonDown) != 0 ? 1 : 0,
                (mouse.ButtonFlags & MouseMiddleButtonDown) != 0 ? 1 : 0,
                wheel);

            if (sample.DeltaX != 0 || sample.DeltaY != 0 || sample.LeftClicks != 0 ||
                sample.RightClicks != 0 || sample.MiddleClicks != 0 || sample.WheelDelta != 0)
                _onInput(sample);
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }

        return IntPtr.Zero;
    }

    private bool IsLogitechDevice(IntPtr device)
    {
        if (device == IntPtr.Zero)
            return false;
        if (_logitechDevices.TryGetValue(device, out var cached))
            return cached;

        uint characterCount = 512;
        var name = new StringBuilder((int)characterCount);
        var result = GetRawInputDeviceInfo(device, RidiDeviceName, name, ref characterCount);
        var path = result == uint.MaxValue ? string.Empty : name.ToString();
        // USB/Bolt devices expose VID_046D, while Bluetooth LE HID paths use
        // the encoded form Dev_VID&02046d (for example MX Master 4 PID b042).
        var isLogitech = path.Contains("VID_046D", StringComparison.OrdinalIgnoreCase) ||
                         path.Contains("VID&02046D", StringComparison.OrdinalIgnoreCase) ||
                         path.Contains("LOGITECH", StringComparison.OrdinalIgnoreCase);
        _logitechDevices[device] = isLogitech;
        return isLogitech;
    }

    public void Dispose()
    {
        if (_disposed)
            return;
        _disposed = true;
        _source.RemoveHook(WindowProc);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RawInputDevice
    {
        public ushort UsagePage;
        public ushort Usage;
        public uint Flags;
        public IntPtr Target;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RawInputHeader
    {
        public uint Type;
        public uint Size;
        public IntPtr Device;
        public IntPtr WParam;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct RawMouse
    {
        [FieldOffset(0)] public ushort Flags;
        [FieldOffset(4)] public uint Buttons;
        [FieldOffset(4)] public ushort ButtonFlags;
        [FieldOffset(6)] public ushort ButtonData;
        [FieldOffset(8)] public uint RawButtons;
        [FieldOffset(12)] public int LastX;
        [FieldOffset(16)] public int LastY;
        [FieldOffset(20)] public uint ExtraInformation;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterRawInputDevices(
        [In] RawInputDevice[] devices, uint deviceCount, uint structureSize);

    [DllImport("user32.dll")]
    private static extern uint GetRawInputData(
        IntPtr rawInput, uint command, IntPtr data, ref uint size, uint headerSize);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern uint GetRawInputDeviceInfo(
        IntPtr device, uint command, StringBuilder data, ref uint size);
}
