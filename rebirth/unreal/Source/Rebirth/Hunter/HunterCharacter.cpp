#include "Hunter/HunterCharacter.h"

#include "Camera/CameraComponent.h"
#include "Combat/RebirthCombat.h"
#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Creatures/DragonBoss.h"
#include "Creatures/PetCompanion.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/SpringArmComponent.h"
#include "Rebirth.h"
#include "UObject/ConstructorHelpers.h"
#include "Valley/ValleyGenerator.h"

using namespace RebirthCombat;

AHunterCharacter::AHunterCharacter()
{
	PrimaryActorTick.bCanEverTick = true;
	GetCapsuleComponent()->InitCapsuleSize(35.f, 90.f);
	GetCharacterMovement()->MaxWalkSpeed = Hunter::Speed * UU;
	GetCharacterMovement()->bOrientRotationToMovement = true;
	GetCharacterMovement()->RotationRate = FRotator(0.f, 720.f, 0.f);
	GetCharacterMovement()->BrakingDecelerationWalking = 4000.f;
	bUseControllerRotationYaw = false;

	SpringArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("SpringArm"));
	SpringArm->SetupAttachment(RootComponent);
	SpringArm->TargetArmLength = 750.f;
	SpringArm->SocketOffset = FVector(0.f, 0.f, 160.f);
	SpringArm->bUsePawnControlRotation = true;
	SpringArm->bEnableCameraLag = true;
	SpringArm->CameraLagSpeed = 9.f;
	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(SpringArm);
	Camera->FieldOfView = 62.f;

	Lantern = CreateDefaultSubobject<UPointLightComponent>(TEXT("Lantern"));
	Lantern->SetupAttachment(RootComponent);
	Lantern->SetRelativeLocation(FVector(0.f, -50.f, 40.f));
	Lantern->SetLightColor(FLinearColor(1.f, 0.72f, 0.4f));
	Lantern->SetIntensity(1600.f);
	Lantern->SetAttenuationRadius(900.f);
	Lantern->SetCastShadows(false);

	// placeholders until /Game/Generated/hunter (gen_assets --stage unreal + import) exists
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Capsule(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(RootComponent);
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	if (Capsule.Succeeded()) Body->SetStaticMesh(Capsule.Object);
	Body->SetRelativeScale3D(FVector(0.64f, 0.64f, 1.7f));
	Sword = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Sword"));
	Sword->SetupAttachment(Body);
	Sword->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	if (Cube.Succeeded()) Sword->SetStaticMesh(Cube.Object);
	Sword->SetRelativeLocation(FVector(30.f, 45.f, 20.f));
	Sword->SetRelativeScale3D(FVector(0.07f, 0.03f, 0.68f));
}

void AHunterCharacter::Bind(ADragonBoss* InDragon, APetCompanion* InPet, AValleyGenerator* InValley)
{
	Dragon = InDragon;
	Pet = InPet;
	Valley = InValley;
	Lock = InDragon;
}

void AHunterCharacter::ResetForRematch(const FVector& Location, const FRotator& Rotation)
{
	Hp = Hunter::HpMax;
	Enter(EHunterState::Idle);
	ComboStep = ComboHits = 0;
	ComboLink = IFrames = SkillCd = DodgeRecharge = 0.f;
	DodgeCharges = Hunter::DodgeCharges;
	BufDodge = BufAttack = BufSkill = 0.f;
	SetActorLocationAndRotation(Location, Rotation, false, nullptr, ETeleportType::TeleportPhysics);
	GetCharacterMovement()->StopMovementImmediately();
	Lock = Dragon;
	SetActorHiddenInGame(false);
}

void AHunterCharacter::Heal(float Amount)
{
	if (State != EHunterState::Dead) Hp = FMath::Min(Hp + Amount, Hunter::HpMax);
}

void AHunterCharacter::SetupPlayerInputComponent(UInputComponent* PIC)
{
	Super::SetupPlayerInputComponent(PIC);
	PIC->BindAxis("MoveForward", this, &AHunterCharacter::MoveForward);
	PIC->BindAxis("MoveRight", this, &AHunterCharacter::MoveRight);
	PIC->BindAxis("Turn", this, &AHunterCharacter::Turn);
	PIC->BindAxis("LookUp", this, &AHunterCharacter::LookUp);
	PIC->BindAction("Dodge", IE_Pressed, this, &AHunterCharacter::OnDodgePressed);
	PIC->BindAction("Attack", IE_Pressed, this, &AHunterCharacter::OnAttackPressed);
	PIC->BindAction("Skill", IE_Pressed, this, &AHunterCharacter::OnSkillPressed);
	PIC->BindAction("PetSkill", IE_Pressed, this, &AHunterCharacter::OnPetSkillPressed);
	PIC->BindAction("LockOn", IE_Pressed, this, &AHunterCharacter::OnLockOnPressed);
	PIC->BindAction("Rematch", IE_Pressed, this, &AHunterCharacter::OnRematchPressed);
}

void AHunterCharacter::Turn(float V) { if (!Lock.IsValid()) AddControllerYawInput(V); }
void AHunterCharacter::LookUp(float V) { if (!Lock.IsValid()) AddControllerPitchInput(V); }

void AHunterCharacter::OnPetSkillPressed()
{
	if (Pet.IsValid()) Pet->TryHowl();
}

void AHunterCharacter::OnLockOnPressed()
{
	if (Lock.IsValid()) Lock = nullptr;
	else if (Dragon.IsValid() && !Dragon->IsDead()) Lock = Dragon;
}

void AHunterCharacter::Enter(EHunterState S)
{
	State = S;
	StateTime = 0.f;
	bHitDone = false;
}

void AHunterCharacter::Tick(float Dt)
{
	Super::Tick(Dt);
	if (State == EHunterState::Dead) return;
	StateTime += Dt;
	IFrames = FMath::Max(IFrames - Dt, 0.f);
	SkillCd = FMath::Max(SkillCd - Dt, 0.f);
	ComboLink = FMath::Max(ComboLink - Dt, 0.f);
	if (ComboLink == 0.f && State != EHunterState::Attack) { ComboStep = 0; ComboHits = 0; }
	if (DodgeCharges < Hunter::DodgeCharges)
	{
		DodgeRecharge += Dt;
		if (DodgeRecharge >= Hunter::DodgeRecharge) { DodgeRecharge = 0.f; ++DodgeCharges; }
	}
	BufDodge = FMath::Max(BufDodge - Dt, 0.f);
	BufAttack = FMath::Max(BufAttack - Dt, 0.f);
	BufSkill = FMath::Max(BufSkill - Dt, 0.f);

	// camera-relative move vector
	const FRotator CamYaw(0.f, GetControlRotation().Yaw, 0.f);
	FVector Move = FRotationMatrix(CamYaw).GetUnitAxis(EAxis::X) * MoveAxis.Y + FRotationMatrix(CamYaw).GetUnitAxis(EAxis::Y) * MoveAxis.X;
	if (Move.SizeSquared() > 1.f) Move.Normalize();

	switch (State)
	{
	case EHunterState::Idle: TickIdle(Move, Dt); break;
	case EHunterState::Dodge: TickDodge(Dt); break;
	case EHunterState::Attack: TickAttack(Dt); break;
	case EHunterState::Skill: TickSkill(Dt); break;
	case EHunterState::Hitstun: if (StateTime >= Hunter::Hitstun) Enter(EHunterState::Idle); break;
	default: break;
	}
	if (Lock.IsValid() && Lock->IsDead()) Lock = nullptr;
	UpdateLockCamera(Dt);
	Lantern->SetIntensity(1600.f + FMath::Sin(GetWorld()->GetTimeSeconds() * 11.f) * 150.f);
}

bool AHunterCharacter::TryActions(const FVector& Move)
{
	if (BufDodge > 0.f && DodgeCharges > 0)
	{
		BufDodge = 0.f; --DodgeCharges; ++Stats.Dodges;
		if (Move.SizeSquared() > 0.01f) DodgeDir = Move.GetSafeNormal2D();
		else if (Lock.IsValid()) DodgeDir = (GetActorLocation() - Lock->GetActorLocation()).GetSafeNormal2D();
		else DodgeDir = Forward2D();
		IFrames = Hunter::DodgeIframes;
		Enter(EHunterState::Dodge);
		return true;
	}
	if (BufSkill > 0.f && SkillCd <= 0.f)
	{
		BufSkill = 0.f; SkillCd = Hunter::SkillCd; ++Stats.Skills;
		if (Lock.IsValid()) SetActorRotation((Lock->GetActorLocation() - GetActorLocation()).GetSafeNormal2D().Rotation());
		Enter(EHunterState::Skill);
		return true;
	}
	if (BufAttack > 0.f)
	{
		BufAttack = 0.f;
		if (ComboLink <= 0.f) { ComboStep = 0; ComboHits = 0; }
		if (Lock.IsValid()) SetActorRotation((Lock->GetActorLocation() - GetActorLocation()).GetSafeNormal2D().Rotation());
		Enter(EHunterState::Attack);
		return true;
	}
	return false;
}

void AHunterCharacter::TickIdle(const FVector& Move, float Dt)
{
	if (TryActions(Move)) return;
	if (Move.SizeSquared() > 0.0001f) AddMovementInput(Move, 1.f);
	GetCharacterMovement()->bOrientRotationToMovement = !Lock.IsValid();
	if (Lock.IsValid()) FaceLock(Dt);
}

void AHunterCharacter::FaceLock(float Dt)
{
	const FRotator Want = (Lock->GetActorLocation() - GetActorLocation()).GetSafeNormal2D().Rotation();
	SetActorRotation(FMath::RInterpTo(GetActorRotation(), FRotator(0.f, Want.Yaw, 0.f), Dt, 10.f));
}

void AHunterCharacter::UpdateLockCamera(float Dt)
{
	APlayerController* PC = Cast<APlayerController>(GetController());
	if (!PC || !Lock.IsValid()) return;
	const FVector To = (Lock->GetActorLocation() - GetActorLocation()).GetSafeNormal2D();
	const FRotator Want(-17.f, To.Rotation().Yaw, 0.f);
	PC->SetControlRotation(FMath::RInterpTo(PC->GetControlRotation(), Want, Dt, 4.f));
	SpringArm->TargetArmLength = 750.f + FMath::Clamp(FVector::Dist2D(GetActorLocation(), Lock->GetActorLocation()) * 0.12f, 0.f, 400.f);
}

void AHunterCharacter::TickDodge(float Dt)
{
	const float K = StateTime / Hunter::DodgeDur;
	const float Speed = (Hunter::DodgeDist / Hunter::DodgeDur) * (1.6f - 1.2f * K) * UU;
	AddActorWorldOffset(DodgeDir * Speed * Dt, true);
	if (Valley.IsValid()) SetActorLocation(Valley->Ground(GetActorLocation(), GetCapsuleComponent()->GetScaledCapsuleHalfHeight()));
	Body->SetRelativeRotation(FRotator(-FMath::Sin(K * PI) * 50.f, 0.f, 0.f));
	if (StateTime >= Hunter::DodgeDur) { Body->SetRelativeRotation(FRotator::ZeroRotator); Enter(EHunterState::Idle); }
}

void AHunterCharacter::TickAttack(float Dt)
{
	const Hunter::FStep& Step = Hunter::Combo(ComboStep);
	const float Total = Step.Startup + Step.Active + Step.Recover;
	const float K = FMath::Clamp(StateTime / (Step.Startup + Step.Active), 0.f, 1.f);
	Sword->SetRelativeRotation(FRotator(FMath::Lerp(100.f, -80.f, K) * (ComboStep == 1 ? -1.f : 1.f), 0.f, 0.f));
	if (StateTime >= Step.Startup && !bHitDone)
	{
		bHitDone = true;
		if (ArcHit(Step.Reach, Step.ArcDeg, Step.Dmg)) { ++ComboHits; Stats.MaxCombo = FMath::Max(Stats.MaxCombo, ComboHits); }
	}
	if (StateTime >= Step.Startup + Step.Active && BufDodge > 0.f && DodgeCharges > 0)
	{
		ComboLink = Hunter::ComboLink;
		TryActions(FVector::ZeroVector);
		return;
	}
	if (StateTime >= Total)
	{
		ComboStep = (ComboStep + 1) % 3;
		ComboLink = Hunter::ComboLink;
		Sword->SetRelativeRotation(FRotator::ZeroRotator);
		Enter(EHunterState::Idle);
		TryActions(FVector::ZeroVector);   // a buffered press chains immediately
	}
	(void)Dt;
}

void AHunterCharacter::TickSkill(float Dt)
{
	const Hunter::FStep& S = Hunter::Skill();
	const float Total = S.Startup + S.Active + S.Recover;
	if (StateTime < S.Startup + 0.06f) AddActorWorldOffset(Forward2D() * (Hunter::SkillLunge * UU / (S.Startup + 0.06f)) * Dt, true);
	if (StateTime >= S.Startup && !bHitDone)
	{
		bHitDone = true;
		if (Dragon.IsValid()) Dragon->SpawnFireField(GetActorLocation() + Forward2D() * 180.f, 1.4f, 2.5f);   // the hunter's flame trail lights the ground too
		ArcHit(S.Reach, S.ArcDeg, S.Dmg);
	}
	if (StateTime >= Total) Enter(EHunterState::Idle);
}

bool AHunterCharacter::ArcHit(float ReachM, float ArcDeg, float Dmg)
{
	if (!Dragon.IsValid() || Dragon->IsDead()) return false;
	if (!InArc(GetActorLocation(), Forward2D(), Dragon->GetActorLocation(), ReachM, ArcDeg, RebirthCombat::Dragon::HitRadius)) return false;
	Dragon->TakeHit(Dmg, GetActorLocation());
	++Stats.Hits;
	return true;
}

float AHunterCharacter::TakeDamage(float Amount, const FDamageEvent& Event, AController* Instigator, AActor* Causer)
{
	if (State == EHunterState::Dead) return 0.f;
	if (IFrames > 0.f)
	{
		++Stats.IframeAvoids;
		return 0.f;   // dodged: i-frames ate it (the feel bar)
	}
	const float Applied = Super::TakeDamage(Amount, Event, Instigator, Causer);
	Hp = FMath::Max(Hp - Amount, 0.f);
	Stats.DamageTaken += Amount;
	if (Causer)
	{
		const FVector Away = (GetActorLocation() - Causer->GetActorLocation()).GetSafeNormal2D();
		LaunchCharacter(Away * 600.f, true, false);
	}
	if (Hp <= 0.f)
	{
		State = EHunterState::Dead;
		OnDied.Broadcast();
		return Applied;
	}
	Enter(EHunterState::Hitstun);
	return Applied;
}
