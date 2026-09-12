using UnrealBuildTool;

public class Rebirth : ModuleRules
{
	public Rebirth(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		CppStandard = CppStandardVersion.Cpp20;

		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput",
			"Niagara", "ProceduralMeshComponent", "AIModule", "Json", "JsonUtilities"
		});
		PrivateDependencyModuleNames.AddRange(new string[] { "RenderCore", "RHI" });

		// The slice's combat rules are plain C++ (Combat/RebirthCombat.h) so they
		// can be replaced by the parent repo's dh-sim (engine-agnostic, canon §10)
		// without touching the Actors. Set REBIRTH_WITH_DHSIM=1 and add the
		// include path once dh-sim grows a 3D arena.
		PublicDefinitions.Add("REBIRTH_WITH_DHSIM=0");
	}
}
