namespace Loupedeck.LogiPetPlugin
{
    using System;
    using System.Diagnostics;
    using System.IO;
    using System.IO.Pipes;
    using System.Net.Sockets;
    using System.Runtime.InteropServices;
    using System.Text;

    internal static class PetBridge
    {
        private const String PipeName = "LogiPet.Actions";
        private const Int32 MacPort = 29473;

        public static void Send(String action)
        {
            if (TrySend(action))
                return;

            TryLaunchApp();
            System.Threading.Thread.Sleep(650);
            if (!TrySend(action))
                PluginLog.Warning("LogiPet app is not running. Start LogiPet.exe first.");
        }

        private static Boolean TrySend(String action)
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                return TrySendTcp(action);

            try
            {
                using var pipe = new NamedPipeClientStream(".", PipeName, PipeDirection.Out);
                pipe.Connect(350);
                using var writer = new StreamWriter(pipe) { AutoFlush = true };
                writer.WriteLine(action);
                return true;
            }
            catch (Exception ex)
            {
                PluginLog.Warning($"Could not send '{action}': {ex.Message}");
                return false;
            }
        }

        private static Boolean TrySendTcp(String action)
        {
            try
            {
                using var client = new TcpClient();
                client.ConnectAsync("127.0.0.1", MacPort).Wait(350);
                if (!client.Connected)
                    return false;
                var payload = Encoding.UTF8.GetBytes(action + "\n");
                client.GetStream().Write(payload, 0, payload.Length);
                return true;
            }
            catch (Exception ex)
            {
                PluginLog.Warning($"Could not send '{action}' to macOS app: {ex.Message}");
                return false;
            }
        }

        private static void TryLaunchApp()
        {
            try
            {
                if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                {
                    Process.Start(new ProcessStartInfo("open", "-a LogiPet") { UseShellExecute = false });
                    return;
                }

                var candidates = new[]
                {
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LogiPet", "LogiPet.exe"),
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "LogiPet", "LogiPet.exe")
                };

                foreach (var path in candidates)
                {
                    if (!File.Exists(path))
                        continue;
                    Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
                    return;
                }
            }
            catch (Exception ex)
            {
                PluginLog.Warning($"Could not launch LogiPet: {ex.Message}");
            }
        }
    }
}
