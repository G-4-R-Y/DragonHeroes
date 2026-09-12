// The slice loop: build the valley, spawn dragon + pet, bind the player's
// hunter, kill -> legendary drop toast -> rematch (R). No economy, no MP.
//
// Binding order differs between PIE (players log in BEFORE BeginPlay) and a
// standalone launch (BeginPlay runs first, then the local player logs in), so
// the hunter is bound from whichever of BeginPlay / PostLogin comes second.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "RebirthGameMode.generated.h"

class AValleyGenerator;
class ADragonBoss;
class APetCompanion;
class AHunterCharacter;
class URebirthAssetManifest;

UENUM(BlueprintType)
enum class ESliceLoop : uint8 { Fight, Drop, Dead };

UCLASS()
class REBIRTH_API ARebirthGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ARebirthGameMode();
	virtual void BeginPlay() override;
	virtual void PostLogin(APlayerController* NewPlayer) override;
	virtual void Tick(float DeltaSeconds) override;

	UFUNCTION(BlueprintCallable, Category = "Rebirth") void Rematch();

	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") ESliceLoop Loop = ESliceLoop::Fight;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") int32 Kills = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") FString Toast;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") float ToastLeft = 0.f;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") FString Prompt;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") TObjectPtr<AValleyGenerator> Valley;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") TObjectPtr<ADragonBoss> Dragon;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") TObjectPtr<APetCompanion> Pet;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") TObjectPtr<AHunterCharacter> Hunter;

	static const FVector HunterSpawn;   // UU; +X looks toward the dragon
	static const FVector DragonSpawn;

private:
	UFUNCTION() void HandleDragonSlain();
	UFUNCTION() void HandleHunterDied();
	UFUNCTION() void HandleRematchRequested();
	void SpawnWorldLights();
	void TryBindHunter(APawn* Pawn);
	float LoopTime = 0.f;
	bool bWorldBuilt = false;
	UPROPERTY() TObjectPtr<URebirthAssetManifest> Manifest;
};
