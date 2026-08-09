namespace Loupedeck.LogiPetPlugin
{
    using System;

    public abstract class PetCommand : PluginDynamicCommand
    {
        private readonly String _action;

        protected PetCommand(String displayName, String description, String action)
            : base(displayName, description, "LogiPet") => this._action = action;

        protected override void RunCommand(String actionParameter) => PetBridge.Send(this._action);
    }

    public sealed class FeedPetCommand : PetCommand
    {
        public FeedPetCommand() : base("Celebrate with Snack", "Celebrate today's activity with Mochi", "snack") { }
    }

    public sealed class PlayWithPetCommand : PetCommand
    {
        public PlayWithPetCommand() : base("High Five", "Celebrate the latest shared activity", "highfive") { }
    }

    public sealed class SleepPetCommand : PetCommand
    {
        public SleepPetCommand() : base("Stretch Together", "Take a short stretch with Mochi", "stretch") { }
    }

    public sealed class PetStatusCommand : PetCommand
    {
        public PetStatusCommand() : base("Quick Play", "Take a playful ten-second break", "play") { }
    }

    public sealed class RefreshBatteryCommand : PetCommand
    {
        public RefreshBatteryCommand() : base("Today's Activity", "Open today's mouse activity counters", "journal") { }
    }

    public sealed class GiveWaterCommand : PetCommand
    {
        public GiveWaterCommand() : base("Give Water", "Let Mochi drink some water", "water") { }
    }

    public sealed class ComeHereCommand : PetCommand
    {
        public ComeHereCommand() : base("Come Here", "Call Mochi over to you", "come") { }
    }

    public sealed class ZoomiesCommand : PetCommand
    {
        public ZoomiesCommand() : base("Zoomies", "Let Mochi run around excitedly", "zoomies") { }
    }

    public sealed class SpeakCommand : PetCommand
    {
        public SpeakCommand() : base("Speak", "Ask Mochi to bark", "speak") { }
    }

    public sealed class SitCommand : PetCommand
    {
        public SitCommand() : base("Sit", "Ask Mochi to sit and wait", "sit") { }
    }

    public sealed class LieDownCommand : PetCommand
    {
        public LieDownCommand() : base("Lie Down", "Ask Mochi to lie down", "lie") { }
    }

    public sealed class TakeNapCommand : PetCommand
    {
        public TakeNapCommand() : base("Take a Nap", "Let Mochi take a short nap", "nap") { }
    }

    public sealed class ScratchCommand : PetCommand
    {
        public ScratchCommand() : base("Scratch", "Play Mochi's scratching animation", "scratch") { }
    }
}
