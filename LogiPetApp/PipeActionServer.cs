using System.IO.Pipes;
using System.IO;

namespace LogiPet;

public sealed class PipeActionServer : IDisposable
{
    public const string PipeName = "LogiPet.Actions";
    private readonly CancellationTokenSource _cancellation = new();
    private readonly Action<string> _onAction;

    public PipeActionServer(Action<string> onAction) => _onAction = onAction;

    public void Start() => _ = Task.Run(ListenLoopAsync);

    private async Task ListenLoopAsync()
    {
        while (!_cancellation.IsCancellationRequested)
        {
            try
            {
                await using var pipe = new NamedPipeServerStream(
                    PipeName,
                    PipeDirection.In,
                    1,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous);
                await pipe.WaitForConnectionAsync(_cancellation.Token);
                using var reader = new StreamReader(pipe);
                var action = await reader.ReadLineAsync(_cancellation.Token);
                if (!string.IsNullOrWhiteSpace(action))
                    _onAction(action.Trim().ToLowerInvariant());
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch
            {
                try { await Task.Delay(300, _cancellation.Token); } catch { break; }
            }
        }
    }

    public void Dispose()
    {
        _cancellation.Cancel();
        _cancellation.Dispose();
    }
}
