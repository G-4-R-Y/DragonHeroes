// The companion beast (pet canon in miniature): heels the hunter, nips the
// dragon on a cooldown, and HOWLs on the hunter's E — staggers the dragon
// (punish window) and heals 10.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "PetCompanion.generated.h"

class UStaticMeshComponent;
class UPointLightComponent;
class AHunterCharacter;
class ADragonBoss;
class AValleyGenerator;

UCLASS()
class REBIRTH_API APetCompanion : public ACharacter
{
	GENERATED_BODY()

public:
	APetCompanion();
	virtual void Tick(float DeltaSeconds) override;
	void Bind(AHunterCharacter* InHunter, ADragonBoss* InDragon, AValleyGenerator* InValley);
	void ResetForRematch();
	bool TryHowl();

	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") float NipCd = 1.f;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") float HowlCd = 2.f;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") int32 Nips = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") int32 Howls = 0;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Art") TSoftObjectPtr<UStaticMesh> GeneratedBodyMesh;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Body;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UPointLightComponent> EyeGlow;

protected:
	virtual void BeginPlay() override;

private:
	TWeakObjectPtr<AHunterCharacter> Hunter;
	TWeakObjectPtr<ADragonBoss> Dragon;
	TWeakObjectPtr<AValleyGenerator> Valley;
};
