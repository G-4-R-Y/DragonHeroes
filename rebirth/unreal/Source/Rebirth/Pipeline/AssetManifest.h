// Reads Content/Generated/manifest.json — written by rebirth/assets/tools/gen_assets.py
// --stage unreal — so generated creature meshes (GenForge -> TripoSR/Pixal3D ->
// GLB -> Interchange import) replace the code-built placeholders with provenance.
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "AssetManifest.generated.h"

class UStaticMesh;

USTRUCT(BlueprintType)
struct FGeneratedCreature
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly) FString File;        // dragon.glb
	UPROPERTY(BlueprintReadOnly) FString AssetPath;   // /Game/Generated/dragon.dragon
	UPROPERTY(BlueprintReadOnly) FString Source;      // placeholder | genforge-mesh_gen
	UPROPERTY(BlueprintReadOnly) FString Sha256;
};

UCLASS()
class REBIRTH_API URebirthAssetManifest : public UObject
{
	GENERATED_BODY()

public:
	/** Loads <Project>/Content/Generated/manifest.json; returns false (and stays empty) if absent. */
	bool Load();
	/** The imported static mesh for a creature, or nullptr when not imported yet (callers keep their placeholder). */
	UStaticMesh* LoadCreatureMesh(const FString& Name) const;
	const TMap<FString, FGeneratedCreature>& Creatures() const { return Entries; }

private:
	TMap<FString, FGeneratedCreature> Entries;
};
