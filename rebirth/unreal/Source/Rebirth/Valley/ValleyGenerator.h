// The night valley, built procedurally at BeginPlay: a UProceduralMeshComponent
// heightfield (flat bowl + rising rim, same formula as godot3d/native), rocks as
// one instanced mesh, glowshroom and fire-pit point lights, exponential height
// fog + volumetric fog. Lumen lights the bowl from the fires (plan §4.1).
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ValleyGenerator.generated.h"

class UProceduralMeshComponent;
class UInstancedStaticMeshComponent;
class UPointLightComponent;
class UExponentialHeightFogComponent;
class UStaticMesh;

UCLASS()
class REBIRTH_API AValleyGenerator : public AActor
{
	GENERATED_BODY()

public:
	AValleyGenerator();

	/** Terrain height (UU) at world XY (UU). */
	UFUNCTION(BlueprintCallable, Category = "Rebirth|Valley")
	float HeightAt(float X, float Y) const;

	/** Snap a location to the terrain plus an offset (UU). */
	UFUNCTION(BlueprintCallable, Category = "Rebirth|Valley")
	FVector Ground(const FVector& Location, float OffsetUU = 0.f) const;

	UPROPERTY(EditAnywhere, Category = "Rebirth|Valley") float SizeM = 180.f;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Valley") int32 Grid = 84;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Valley") float BowlRadiusM = 30.f;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Valley") float RimHeightM = 22.f;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Valley") int32 RockCount = 160;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Valley") int32 Seed = 7;

	UPROPERTY(VisibleAnywhere, Category = "Rebirth|Valley") TObjectPtr<UProceduralMeshComponent> Terrain;
	UPROPERTY(VisibleAnywhere, Category = "Rebirth|Valley") TObjectPtr<UInstancedStaticMeshComponent> Rocks;
	UPROPERTY(VisibleAnywhere, Category = "Rebirth|Valley") TObjectPtr<UExponentialHeightFogComponent> Fog;
	UPROPERTY(VisibleAnywhere, Category = "Rebirth|Valley") TArray<TObjectPtr<UPointLightComponent>> FireLights;

protected:
	virtual void PostInitializeComponents() override;
	virtual void Tick(float DeltaSeconds) override;

private:
	float Noise(float X, float Y) const;   // fbm value noise in [-1,1], metres in
	FLinearColor ColorAt(float XM, float YM, float HM) const;
	void BuildTerrain();
	void ScatterRocks();
	void PlaceLights();
	float Time = 0.f;
	bool bBuilt = false;
};
