// The hunter: third-person locomotion, lock-on, dodge with i-frames + input
// buffering (the 2D game's feel rules), 3-hit combo + one skill. Hit tests are
// arc math against the dragon's hit capsule (Combat/RebirthCombat.h) — no
// overlap components, so dh-sim can take the rules over later unchanged.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "HunterCharacter.generated.h"

class USpringArmComponent;
class UCameraComponent;
class UPointLightComponent;
class UStaticMeshComponent;
class ADragonBoss;
class APetCompanion;
class AValleyGenerator;

UENUM(BlueprintType)
enum class EHunterState : uint8 { Idle, Dodge, Attack, Skill, Hitstun, Dead };

USTRUCT(BlueprintType)
struct FHunterStats
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly) int32 IframeAvoids = 0;
	UPROPERTY(BlueprintReadOnly) int32 MaxCombo = 0;
	UPROPERTY(BlueprintReadOnly) int32 Hits = 0;
	UPROPERTY(BlueprintReadOnly) int32 Dodges = 0;
	UPROPERTY(BlueprintReadOnly) int32 Skills = 0;
	UPROPERTY(BlueprintReadOnly) float DamageTaken = 0.f;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnHunterDied);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnHunterRematch);

UCLASS()
class REBIRTH_API AHunterCharacter : public ACharacter
{
	GENERATED_BODY()

public:
	AHunterCharacter();

	virtual void Tick(float DeltaSeconds) override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual float TakeDamage(float DamageAmount, const FDamageEvent& DamageEvent, AController* EventInstigator, AActor* DamageCauser) override;

	void Bind(ADragonBoss* InDragon, APetCompanion* InPet, AValleyGenerator* InValley);
	void ResetForRematch(const FVector& Location, const FRotator& Rotation);
	void Heal(float Amount);
	FVector Forward2D() const { return GetActorForwardVector().GetSafeNormal2D(); }
	bool IsLocked() const { return Lock.IsValid(); }

	UPROPERTY(BlueprintAssignable) FOnHunterDied OnDied;
	UPROPERTY(BlueprintAssignable) FOnHunterRematch OnRematchRequested;

	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") float Hp = 100.f;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") EHunterState State = EHunterState::Idle;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") int32 ComboStep = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") int32 ComboHits = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") int32 DodgeCharges = 3;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") float SkillCd = 0.f;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") FHunterStats Stats;

	UPROPERTY(VisibleAnywhere) TObjectPtr<USpringArmComponent> SpringArm;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UCameraComponent> Camera;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UPointLightComponent> Lantern;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Body;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Sword;

private:
	// input
	void MoveForward(float V) { MoveAxis.Y = V; }
	void MoveRight(float V) { MoveAxis.X = V; }
	void Turn(float V);
	void LookUp(float V);
	void OnDodgePressed() { BufDodge = 0.15f; }
	void OnAttackPressed() { BufAttack = 0.15f; }
	void OnSkillPressed() { BufSkill = 0.15f; }
	void OnPetSkillPressed();
	void OnLockOnPressed();
	void OnRematchPressed() { OnRematchRequested.Broadcast(); }

	// state machine
	void Enter(EHunterState S);
	bool TryActions(const FVector& Move);
	void TickIdle(const FVector& Move, float Dt);
	void TickDodge(float Dt);
	void TickAttack(float Dt);
	void TickSkill(float Dt);
	bool ArcHit(float ReachM, float ArcDeg, float Dmg);
	void FaceLock(float Dt);
	void UpdateLockCamera(float Dt);

	FVector2D MoveAxis = FVector2D::ZeroVector;
	float StateTime = 0.f, IFrames = 0.f, ComboLink = 0.f, DodgeRecharge = 0.f;
	float BufDodge = 0.f, BufAttack = 0.f, BufSkill = 0.f;
	FVector DodgeDir = FVector::ForwardVector;
	bool bHitDone = false;
	TWeakObjectPtr<ADragonBoss> Dragon;
	TWeakObjectPtr<ADragonBoss> Lock;
	TWeakObjectPtr<APetCompanion> Pet;
	TWeakObjectPtr<AValleyGenerator> Valley;
};
