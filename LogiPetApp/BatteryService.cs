using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;

namespace LogiPet;

public sealed record BatteryReading(int? Level, bool Connected, string Message);

public static class BatteryService
{
    public static async Task<BatteryReading> ReadMxMaster4Async()
    {
        BluetoothLEDevice? device = null;
        try
        {
            var selector = BluetoothLEDevice.GetDeviceSelectorFromPairingState(true);
            var devices = await DeviceInformation.FindAllAsync(selector);
            var info = devices.FirstOrDefault(d =>
                d.Name.Contains("MX Master 4", StringComparison.OrdinalIgnoreCase));

            if (info is null)
                return new BatteryReading(null, false, "MX Master 4를 찾지 못했어요");

            device = await BluetoothLEDevice.FromIdAsync(info.Id);
            if (device is null)
                return new BatteryReading(null, false, "마우스가 잠들어 있어요");

            var services = await device.GetGattServicesForUuidAsync(
                GattServiceUuids.Battery,
                BluetoothCacheMode.Uncached);

            if (services.Status != GattCommunicationStatus.Success || services.Services.Count == 0)
                return new BatteryReading(null, device.ConnectionStatus == BluetoothConnectionStatus.Connected, "배터리 정보를 기다리는 중이에요");

            using var service = services.Services[0];
            var characteristics = await service.GetCharacteristicsForUuidAsync(
                GattCharacteristicUuids.BatteryLevel,
                BluetoothCacheMode.Uncached);

            if (characteristics.Status != GattCommunicationStatus.Success || characteristics.Characteristics.Count == 0)
                return new BatteryReading(null, true, "배터리 센서를 읽지 못했어요");

            var read = await characteristics.Characteristics[0].ReadValueAsync(BluetoothCacheMode.Uncached);
            if (read.Status != GattCommunicationStatus.Success || read.Value.Length == 0)
                return new BatteryReading(null, true, "배터리 응답을 기다리는 중이에요");

            using var reader = DataReader.FromBuffer(read.Value);
            return new BatteryReading(reader.ReadByte(), true, "실제 MX Master 4 배터리");
        }
        catch (Exception ex)
        {
            return new BatteryReading(null, false, $"배터리 연결 오류: {ex.GetType().Name}");
        }
        finally
        {
            device?.Dispose();
        }
    }
}
