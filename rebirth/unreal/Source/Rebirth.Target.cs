// UnrealBuildTool rules (C# is UBT's language — build rules, not game code;
// the "no C#" directive is about gameplay systems, canon CLAUDE.md #1).
using UnrealBuildTool;
using System.Collections.Generic;

public class RebirthTarget : TargetRules
{
	public RebirthTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_4;
		ExtraModuleNames.Add("Rebirth");
	}
}
