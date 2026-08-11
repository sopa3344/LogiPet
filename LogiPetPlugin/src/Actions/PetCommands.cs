namespace Loupedeck.LogiPetPlugin
{
    using System;

    public abstract class PetCommand : PluginDynamicCommand
    {
        private readonly String _action;
        private readonly String _iconName;
        private BitmapImage _icon;

        protected PetCommand(String displayName, String description, String action, String iconName)
            : base(displayName, description, "LogiPet")
        {
            this._action = action;
            this._iconName = iconName;
        }

        protected override void RunCommand(String actionParameter) => PetBridge.Send(this._action);

        protected override BitmapImage GetCommandImage(String actionParameter, PluginImageSize imageSize)
            => this._icon ??= PluginResources.ReadImage($"{this._iconName}.png");
    }

    public sealed class FeedPetCommand : PetCommand
    {
        public FeedPetCommand() : base("Celebrate with Snack", "Celebrate today's activity with Max", "snack", "snack") { }
    }

    public sealed class PlayWithPetCommand : PetCommand
    {
        public PlayWithPetCommand() : base("High Five", "Celebrate the latest shared activity", "highfive", "highfive") { }
    }

    public sealed class SleepPetCommand : PetCommand
    {
        public SleepPetCommand() : base("Stretch Together", "Take a short stretch with Max", "stretch", "stretch") { }
    }

    public sealed class PetStatusCommand : PetCommand
    {
        public PetStatusCommand() : base("Quick Play", "Take a playful ten-second break", "play", "play") { }
    }

    public sealed class RefreshBatteryCommand : PetCommand
    {
        public RefreshBatteryCommand() : base("Today's Activity", "Open today's mouse activity counters", "journal", "journal") { }
    }

    public sealed class GiveWaterCommand : PetCommand
    {
        public GiveWaterCommand() : base("Give Water", "Let Max drink some water", "water", "water") { }
    }

    public sealed class ComeHereCommand : PetCommand
    {
        public ComeHereCommand() : base("Come Here", "Call Max over to you", "come", "come") { }
    }

    public sealed class ZoomiesCommand : PetCommand
    {
        public ZoomiesCommand() : base("Zoomies", "Let Max run around excitedly", "zoomies", "zoomies") { }
    }

    public sealed class SpeakCommand : PetCommand
    {
        public SpeakCommand() : base("Speak", "Ask Max to bark", "speak", "speak") { }
    }

    public sealed class SitCommand : PetCommand
    {
        public SitCommand() : base("Sit", "Ask Max to sit and wait", "sit", "sit") { }
    }

    public sealed class LieDownCommand : PetCommand
    {
        public LieDownCommand() : base("Lie Down", "Ask Max to lie down", "lie", "lie") { }
    }

    public sealed class TakeNapCommand : PetCommand
    {
        public TakeNapCommand() : base("Take a Nap", "Let Max take a short nap", "nap", "nap") { }
    }

    public sealed class ScratchCommand : PetCommand
    {
        public ScratchCommand() : base("Scratch", "Play Max's scratching animation", "scratch", "scratch") { }
    }
}
