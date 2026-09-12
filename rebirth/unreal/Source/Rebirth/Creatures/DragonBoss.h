// The legendary dragon: FIVE signature skills composing one learnable strategy
// (canon §4) — BREATH cone (leaves a burning field), METEOR volley, TAIL sweep
// (punishes standing behind), WING GUST (punishes hugging the front; long
// recovery = the punish window), POUNCE; ENRAGE at 40% (faster, shorter
// telegraphs, 5 meteors, the RETREAT LEAP -> meteors -> pounce pattern).
// Telegraph -> commit (aim locks 0.35 s before the strike: the dodge window)
// -> act -> recover. Telegraphs are pooled ground meshes (danger rings/cones);
// swap for Niagara danger volumes once the systems exist (soft refs below).
#pragma once

#include "CoreMinimal.h"
#include "Combat/RebirthCombat.h"
#include "GameFramework/Actor.h"
#include "DragonBoss.generated.h"

class UCapsuleComponent;
class UStaticMeshComponent;
class UPointLightComponent;
class UMaterialInstanceDynamic;
class UNiagaraSystem;
class UNiagaraComponent;
class AHunterCharacter;
class AValleyGenerator;

UENUM(BlueprintType)
enum class EDragonState : uint8 { Idle, Approach, Tele, Act, Recover, Stagger, Retreat, Dead };

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnDragonSlain);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnDragonEnraged);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnDragonSkill, FName, SkillId);

UCLASS()
class REBIRTH_API ADragonBoss : public AActor
{
	GENERATED_BODY()

public:
	ADragonBoss();
	virtual void Tick(float DeltaSeconds) override;

	void Bind(AHunterCharacter* InHunter, AValleyGenerator* InValley);
	void ResetForRematch(const FVector& Location);
	void TakeHit(float Dmg, const FVector& From);
	void Stagger(float Seconds);
	void SpawnFireField(const FVector& Location, float RadiusM, float Seconds);
	bool IsDead() const { return State == EDragonState::Dead; }
	bool IsPunishable() const { return bPunishable; }
	float TelegraphLeft() const { return TelegraphLeftS; }
	RebirthCombat::ESkill CurrentSkill() const { return Skill; }

	UPROPERTY(BlueprintAssignable) FOnDragonSlain OnSlain;
	UPROPERTY(BlueprintAssignable) FOnDragonEnraged OnEnraged;
	UPROPERTY(BlueprintAssignable) FOnDragonSkill OnSkillUsed;

	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") float Hp = 600.f;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") EDragonState State = EDragonState::Idle;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") bool bEnraged = false;
	UPROPERTY(BlueprintReadOnly, Category = "Rebirth") TMap<FName, int32> SkillsUsed;

	/** Set by the GameMode from Content/Generated/manifest.json (gen_assets --stage unreal + Interchange import). */
	UPROPERTY(EditAnywhere, Category = "Rebirth|Art") TSoftObjectPtr<UStaticMesh> GeneratedBodyMesh;
	/** Optional Niagara systems; null = pooled mesh telegraphs / point-light fire. */
	UPROPERTY(EditAnywhere, Category = "Rebirth|Art") TSoftObjectPtr<UNiagaraSystem> BreathSystem;
	UPROPERTY(EditAnywhere, Category = "Rebirth|Art") TSoftObjectPtr<UNiagaraSystem> FireFieldSystem;

	UPROPERTY(VisibleAnywhere) TObjectPtr<UCapsuleComponent> Capsule;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UStaticMeshComponent> Body;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UPointLightComponent> MawLight;
	UPROPERTY(VisibleAnywhere) TObjectPtr<UPointLightComponent> AuraLight;

protected:
	virtual void BeginPlay() override;

private:
	using ESkill = RebirthCombat::ESkill;
	struct FMeteor { FVector Target; float LandIn; bool bApplied; int32 Ring; };
	struct FField { UStaticMeshComponent* Disc; UPointLightComponent* Light; UNiagaraComponent* Fx; float Left; float Dur; float RadiusM; };
	struct FMeteorFx { UStaticMeshComponent* Ball; UPointLightComponent* Light; FVector From, To; float T, Dur; bool bActive; };
	struct FTelegraph { UStaticMeshComponent* Mesh; UMaterialInstanceDynamic* Mid; float Left; bool bActive; bool bCone; };

	void Enter(EDragonState S);
	void FaceHunter(float Dt, float RateRadS);
	float SurfaceDist() const;
	float RelAngleDeg() const;
	float TeleTime(ESkill S) const;
	bool Legal(ESkill S) const;
	void Decide();
	void StartSkill(ESkill S);
	void ShowTelegraph();
	void RefreshAimedTelegraph();
	void EndTelegraphs();
	void BeginAct();
	void TickAct(float Dt);
	void TickMeteors(float Dt);
	void TickFields(float Dt);
	void TickTelegraphs(float Dt);
	void Deal(float Dmg);
	void Enrage();
	FVector Ground(const FVector& L, float Offset = 0.f) const;
	FVector ToHunter() const;

	int32 Ring(const FVector& Center, float RadiusM, const FLinearColor& Color, float Seconds);
	int32 Cone(const FVector& Apex, float YawDeg, float RangeM, const FLinearColor& Color, float Seconds);
	void EndTelegraph(int32 Handle);

	TWeakObjectPtr<AHunterCharacter> Hunter;
	TWeakObjectPtr<AValleyGenerator> Valley;
	ESkill Skill = ESkill::Nil;
	float StateTime = 0.f, Think = 0.6f, TelegraphLeftS = 0.f, FieldTick = 0.f, RetreatTimer = 0.f, BodyLift = 0.f;
	bool bPunishable = false, bActDone = false, bAimLocked = false, bRetreatPending = false, bFieldSpawned = false;
	float Cds[static_cast<int32>(ESkill::Count)] = {};
	TArray<FMeteor> Meteors;
	TArray<int32> TeleHandles;
	FVector PounceFrom, PounceTo, SpawnLocation;
	FRandomStream Rng;
	TArray<FTelegraph> Telegraphs;   // pooled: 16 rings + 4 cones
	TArray<FField> Fields;           // pooled: 6
	TArray<FMeteorFx> MeteorFx;      // pooled: 8
	UPROPERTY() TObjectPtr<UMaterialInstanceDynamic> BodyMid;
	UPROPERTY() TObjectPtr<UStaticMesh> CylinderMesh;
	UPROPERTY() TObjectPtr<UStaticMesh> ConeMesh;
	UPROPERTY() TObjectPtr<UStaticMesh> SphereMesh;
	UPROPERTY() TObjectPtr<UMaterialInterface> ShapeMaterial;
};
