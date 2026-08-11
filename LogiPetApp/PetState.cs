using System.Text.Json;
using System.IO;

namespace LogiPet;

public sealed class PetState
{
    public string PetName { get; set; } = "맥스";
    public double Hunger { get; set; } = 72;
    public double Mood { get; set; } = 78;
    public bool IsSleeping { get; set; }
    public double? WindowLeft { get; set; }
    public double? WindowTop { get; set; }
    public DateTime LastUpdatedUtc { get; set; } = DateTime.UtcNow;
    public string ActivityDate { get; set; } = DateTime.Today.ToString("yyyy-MM-dd");
    public long LeftClicksToday { get; set; }
    public long RightClicksToday { get; set; }
    public long MiddleClicksToday { get; set; }
    public long ActionRingActionsToday { get; set; }
    public long WheelDeltaToday { get; set; }
    public double ActiveSecondsToday { get; set; }
    public double LongestSessionSecondsToday { get; set; }
    public double PointerDistanceUnitsToday { get; set; }
    public int SprintMomentsToday { get; set; }
    public int CompanionMomentsToday { get; set; }
    public int LastCelebratedMilestoneMinutesToday { get; set; }

    private static string StatePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "LogiPet",
        "state.json");

    public static PetState Load()
    {
        try
        {
            if (!File.Exists(StatePath))
                return new PetState();

            var state = JsonSerializer.Deserialize<PetState>(File.ReadAllText(StatePath)) ?? new PetState();
            state.PetName = NormalizePetName(state.PetName);
            var elapsedHours = Math.Clamp((DateTime.UtcNow - state.LastUpdatedUtc).TotalHours, 0, 24);
            state.Hunger = Math.Clamp(state.Hunger - elapsedHours * 4, 0, 100);
            state.Mood = Math.Clamp(state.Mood - elapsedHours * 2, 0, 100);
            state.EnsureToday();
            return state;
        }
        catch
        {
            return new PetState();
        }
    }

    public static string NormalizePetName(string? name)
    {
        var value = (name ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(value))
            return "맥스";
        return value.Length > 8 ? value[..8] : value;
    }

    public void EnsureToday()
    {
        var today = DateTime.Today.ToString("yyyy-MM-dd");
        if (ActivityDate == today)
            return;

        ActivityDate = today;
        LeftClicksToday = 0;
        RightClicksToday = 0;
        MiddleClicksToday = 0;
        ActionRingActionsToday = 0;
        WheelDeltaToday = 0;
        ActiveSecondsToday = 0;
        LongestSessionSecondsToday = 0;
        PointerDistanceUnitsToday = 0;
        SprintMomentsToday = 0;
        CompanionMomentsToday = 0;
        LastCelebratedMilestoneMinutesToday = 0;
    }

    public void Save()
    {
        LastUpdatedUtc = DateTime.UtcNow;
        var directory = Path.GetDirectoryName(StatePath)!;
        Directory.CreateDirectory(directory);
        File.WriteAllText(StatePath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}
