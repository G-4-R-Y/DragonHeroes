#include "Creatures/PetCompanion.h"

#include "Combat/RebirthCombat.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Creatures/DragonBoss.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Hunter/HunterCharacter.h"
#include "UObject/ConstructorHelpers.h"
#include "Valley/ValleyGenerator.h"

using namespace RebirthCombat;

APetCompanion::APetCompanion()
{
	PrimaryActorTick.bCanEverTick = true;
	GetCapsuleComponent()->InitCapsuleSize(30.f, 45.f);
	GetCharacterMovement()->MaxWalkSpeed = Pet::Speed * UU;
	GetCharacterMovement()->bOrientRotationToMovement = true;
	GetCharacterMovement()->RotationRate = FRotator(0.f, 900.f, 0.f);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(TEXT("/Engine/BasicShapes/Sphere.Sphere"));
	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(RootComponent);
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	if (Sphere.Succeeded()) Body->SetStaticMesh(Sphere.Object);
	Body->SetRelativeScale3D(FVector(1.2f, 0.6f, 0.6f));
	EyeGlow = CreateDefaultSubobject<UPointLightComponent>(TEXT("EyeGlow"));
	EyeGlow->SetupAttachment(RootComponent);
	EyeGlow->SetRelativeLocation(FVector(60.f, 0.f, 30.f));
	EyeGlow->SetLightColor(FLinearColor(0.4f, 1.f, 0.9f));
	EyeGlow->SetIntensity(300.f);
	EyeGlow->SetAttenuationRadius(250.f);
	EyeGlow->SetCastShadows(false);
}

void APetCompanion::BeginPlay()
{
	Super::BeginPlay();
	if (UStaticMesh* Gen = GeneratedBodyMesh.LoadSynchronous())
	{
		Body->SetStaticMesh(Gen);
		Body->SetRelativeScale3D(FVector(UU / 100.f));
		Body->SetRelativeLocation(FVector(0.f, 0.f, -45.f));
	}
}

void APetCompanion::Bind(AHunterCharacter* InHunter, ADragonBoss* InDragon, AValleyGenerator* InValley)
{
	Hunter = InHunter; Dragon = InDragon; Valley = InValley;
}

void APetCompanion::ResetForRematch()
{
	NipCd = 1.f; HowlCd = 2.f;
	if (Hunter.IsValid())
	{
		const FVector L = Hunter->GetActorLocation() - Hunter->Forward2D() * 160.f - Hunter->GetActorRightVector() * 140.f;
		SetActorLocation(Valley.IsValid() ? Valley->Ground(L, GetCapsuleComponent()->GetScaledCapsuleHalfHeight()) : L);
	}
}

bool APetCompanion::TryHowl()
{
	if (HowlCd > 0.f || !Hunter.IsValid()) return false;
	HowlCd = Pet::HowlCd; ++Howls;
	Hunter->Heal(Pet::HowlHeal);
	if (Dragon.IsValid() && FVector::Dist2D(GetActorLocation(), Dragon->GetActorLocation()) / UU <= Pet::HowlRange) Dragon->Stagger(1.1f);
	return true;
}

void APetCompanion::Tick(float Dt)
{
	Super::Tick(Dt);
	NipCd = FMath::Max(NipCd - Dt, 0.f);
	HowlCd = FMath::Max(HowlCd - Dt, 0.f);
	if (!Hunter.IsValid() || Hunter->State == EHunterState::Dead) return;
	const FVector Heel = Hunter->GetActorLocation() - Hunter->Forward2D() * 160.f - Hunter->GetActorRightVector() * 140.f;
	FVector Want = Heel;
	const bool bDragonAlive = Dragon.IsValid() && !Dragon->IsDead();
	float SurfD = 1e9f;
	if (bDragonAlive)
	{
		SurfD = SurfaceDistance(GetActorLocation(), Dragon->GetActorLocation(), RebirthCombat::Dragon::HitRadius);
		if (NipCd <= 0.f && SurfD < Pet::NipRange + 3.f)
			Want = Dragon->GetActorLocation() - (Dragon->GetActorLocation() - GetActorLocation()).GetSafeNormal2D() * (RebirthCombat::Dragon::HitRadius + 1.2f) * UU;
	}
	const FVector D = (Want - GetActorLocation()) * FVector(1, 1, 0);
	if (D.Size() > 30.f) AddMovementInput(D.GetSafeNormal(), FMath::Min(1.f, D.Size() / 200.f));
	if (bDragonAlive && NipCd <= 0.f && SurfD <= Pet::NipRange)
	{
		NipCd = Pet::NipCd; ++Nips;
		Dragon->TakeHit(Pet::NipDmg, GetActorLocation());
	}
}
