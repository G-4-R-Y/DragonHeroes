#include "Creatures/DragonBoss.h"

#include "Components/CapsuleComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/DamageType.h"
#include "Hunter/HunterCharacter.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "NiagaraComponent.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraSystem.h"
#include "Rebirth.h"
#include "UObject/ConstructorHelpers.h"
#include "Valley/ValleyGenerator.h"

using namespace RebirthCombat;

namespace
{
	constexpr int32 kRings = 16, kCones = 4, kFields = 6, kMeteors = 8;
	int32 Idx(ESkill S) { return static_cast<int32>(S); }
	FName SkillFName(ESkill S) { return FName(SkillName(S)); }
}

ADragonBoss::ADragonBoss()
{
	PrimaryActorTick.bCanEverTick = true;
	Capsule = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Capsule"));
	Capsule->InitCapsuleSize(Dragon::HitRadius * UU, 300.f);
	Capsule->SetCollisionProfileName(TEXT("Pawn"));
	SetRootComponent(Capsule);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(TEXT("/Engine/BasicShapes/Sphere.Sphere"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> ConeShape(TEXT("/Engine/BasicShapes/Cone.Cone"));
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> ShapeMat(TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"));
	if (Sphere.Succeeded()) SphereMesh = Sphere.Object;
	if (Cylinder.Succeeded()) CylinderMesh = Cylinder.Object;
	if (ConeShape.Succeeded()) ConeMesh = ConeShape.Object;
	if (ShapeMat.Succeeded()) ShapeMaterial = ShapeMat.Object;

	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(Capsule);
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	if (SphereMesh) Body->SetStaticMesh(SphereMesh);
	Body->SetRelativeScale3D(FVector(6.2f, 2.7f, 2.4f));   // placeholder wyrm body until the GLB import lands
	Body->SetRelativeLocation(FVector(0.f, 0.f, -100.f));

	MawLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("MawLight"));
	MawLight->SetupAttachment(Capsule);
	MawLight->SetRelativeLocation(FVector(560.f, 0.f, 120.f));
	MawLight->SetLightColor(FLinearColor(1.f, 0.5f, 0.15f));
	MawLight->SetIntensity(1400.f);
	MawLight->SetAttenuationRadius(700.f);
	MawLight->SetCastShadows(false);

	AuraLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("AuraLight"));
	AuraLight->SetupAttachment(Capsule);
	AuraLight->SetRelativeLocation(FVector(0.f, 0.f, -50.f));
	AuraLight->SetLightColor(FLinearColor(1.f, 0.15f, 0.05f));
	AuraLight->SetIntensity(2400.f);
	AuraLight->SetAttenuationRadius(1100.f);
	AuraLight->SetCastShadows(false);
	AuraLight->SetVisibility(false);
}

void ADragonBoss::BeginPlay()
{
	Super::BeginPlay();
	if (UStaticMesh* Gen = GeneratedBodyMesh.LoadSynchronous())
	{
		Body->SetStaticMesh(Gen);
		Body->SetRelativeScale3D(FVector(UU / 100.f));   // GLB in metres -> UU (Interchange imports metres as cm; adjust if the import scale differs)
		Body->SetRelativeLocation(FVector(0.f, 0.f, -300.f));
		UE_LOG(LogRebirth, Log, TEXT("Dragon: generated body mesh %s"), *Gen->GetName());
	}
	if (ShapeMaterial)
	{
		BodyMid = UMaterialInstanceDynamic::Create(ShapeMaterial, this);
		BodyMid->SetVectorParameterValue(TEXT("Color"), FLinearColor(0.22f, 0.09f, 0.08f));
		Body->SetMaterial(0, BodyMid);
	}
	// pools — allocated once, never per hit (canon §12.19)
	auto MakeShape = [&](UStaticMesh* Mesh, const TCHAR* Name, int32 I) -> UStaticMeshComponent* {
		UStaticMeshComponent* C = NewObject<UStaticMeshComponent>(this, FName(FString::Printf(TEXT("%s_%d"), Name, I)));
		C->SetupAttachment(Capsule);
		C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		C->SetStaticMesh(Mesh);
		C->SetVisibility(false);
		C->SetCastShadow(false);
		C->SetAbsolute(true, true, true);
		C->RegisterComponent();
		return C;
	};
	for (int32 I = 0; I < kRings + kCones; ++I)
	{
		const bool bCone = I >= kRings;
		FTelegraph T{};
		T.Mesh = MakeShape(bCone ? ConeMesh.Get() : CylinderMesh.Get(), bCone ? TEXT("TeleCone") : TEXT("TeleRing"), I);
		T.Mid = ShapeMaterial ? UMaterialInstanceDynamic::Create(ShapeMaterial, this) : nullptr;
		if (T.Mid) T.Mesh->SetMaterial(0, T.Mid);
		T.bCone = bCone;
		Telegraphs.Add(T);
	}
	for (int32 I = 0; I < kFields; ++I)
	{
		FField F{};
		F.Disc = MakeShape(CylinderMesh.Get(), TEXT("Field"), I);
		if (ShapeMaterial) { UMaterialInstanceDynamic* M = UMaterialInstanceDynamic::Create(ShapeMaterial, this); M->SetVectorParameterValue(TEXT("Color"), FLinearColor(1.f, 0.4f, 0.08f)); F.Disc->SetMaterial(0, M); }
		F.Light = NewObject<UPointLightComponent>(this, FName(FString::Printf(TEXT("FieldLight_%d"), I)));
		F.Light->SetupAttachment(Capsule);
		F.Light->SetAbsolute(true, true, true);
		F.Light->SetLightColor(FLinearColor(1.f, 0.5f, 0.15f));
		F.Light->SetAttenuationRadius(1000.f);
		F.Light->SetCastShadows(false);
		F.Light->SetVisibility(false);
		F.Light->RegisterComponent();
		F.Fx = nullptr;
		if (UNiagaraSystem* Sys = FireFieldSystem.LoadSynchronous())
		{
			F.Fx = UNiagaraFunctionLibrary::SpawnSystemAttached(Sys, Capsule, NAME_None, FVector::ZeroVector, FRotator::ZeroRotator, EAttachLocation::KeepWorldPosition, false, false);
		}
		Fields.Add(F);
	}
	for (int32 I = 0; I < kMeteors; ++I)
	{
		FMeteorFx M{};
		M.Ball = MakeShape(SphereMesh.Get(), TEXT("Meteor"), I);
		M.Ball->SetWorldScale3D(FVector(1.4f));
		if (ShapeMaterial) { UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(ShapeMaterial, this); Mid->SetVectorParameterValue(TEXT("Color"), FLinearColor(1.f, 0.45f, 0.1f)); M.Ball->SetMaterial(0, Mid); }
		M.Light = NewObject<UPointLightComponent>(this, FName(FString::Printf(TEXT("MeteorLight_%d"), I)));
		M.Light->SetupAttachment(Capsule);
		M.Light->SetAbsolute(true, true, true);
		M.Light->SetLightColor(FLinearColor(1.f, 0.5f, 0.2f));
		M.Light->SetIntensity(2500.f);
		M.Light->SetAttenuationRadius(1200.f);
		M.Light->SetCastShadows(false);
		M.Light->SetVisibility(false);
		M.Light->RegisterComponent();
		MeteorFx.Add(M);
	}
	SpawnLocation = GetActorLocation();
	ResetForRematch(SpawnLocation);
}

void ADragonBoss::Bind(AHunterCharacter* InHunter, AValleyGenerator* InValley)
{
	Hunter = InHunter;
	Valley = InValley;
}

FVector ADragonBoss::Ground(const FVector& L, float Offset) const
{
	return Valley.IsValid() ? Valley->Ground(L, Offset) : FVector(L.X, L.Y, Offset);
}

void ADragonBoss::ResetForRematch(const FVector& Location)
{
	Hp = Dragon::HpMax;
	bEnraged = false;
	bPunishable = bRetreatPending = false;
	RetreatTimer = 0.f;
	Think = 0.6f;
	for (float& C : Cds) C = 0.f;
	Cds[Idx(ESkill::Meteors)] = 4.f;
	Cds[Idx(ESkill::Pounce)] = 3.f;
	Rng.Initialize(11);
	Meteors.Reset();
	EndTelegraphs();
	for (FField& F : Fields) { F.Left = 0.f; F.Disc->SetVisibility(false); F.Light->SetVisibility(false); if (F.Fx) F.Fx->Deactivate(); }
	for (FMeteorFx& M : MeteorFx) { M.bActive = false; M.Ball->SetVisibility(false); M.Light->SetVisibility(false); }
	SpawnLocation = Location;
	SetActorLocation(Ground(Location, Capsule->GetScaledCapsuleHalfHeight()));
	if (Hunter.IsValid()) SetActorRotation((Hunter->GetActorLocation() - GetActorLocation()).GetSafeNormal2D().Rotation());
	AuraLight->SetVisibility(false);
	if (BodyMid) BodyMid->SetVectorParameterValue(TEXT("Color"), FLinearColor(0.22f, 0.09f, 0.08f));
	SetActorScale3D(FVector::OneVector);
	Enter(EDragonState::Idle);
}

void ADragonBoss::Enter(EDragonState S)
{
	State = S;
	StateTime = 0.f;
	bActDone = bAimLocked = bFieldSpawned = false;
}

FVector ADragonBoss::ToHunter() const
{
	return Hunter.IsValid() ? (Hunter->GetActorLocation() - GetActorLocation()) * FVector(1, 1, 0) : FVector::ZeroVector;
}

float ADragonBoss::SurfaceDist() const
{
	return Hunter.IsValid() ? SurfaceDistance(Hunter->GetActorLocation(), GetActorLocation(), Dragon::HitRadius) : 1e9f;
}

float ADragonBoss::RelAngleDeg() const
{
	return Hunter.IsValid() ? RebirthCombat::RelAngleDeg(GetActorLocation(), GetActorForwardVector(), Hunter->GetActorLocation()) : 180.f;
}

float ADragonBoss::TeleTime(ESkill S) const { return SkillDef(S).Tele * (bEnraged ? 0.8f : 1.f); }

void ADragonBoss::FaceHunter(float Dt, float RateRadS)
{
	const FVector To = ToHunter();
	if (To.SizeSquared() < 1.f) return;
	const float Want = To.Rotation().Yaw;
	const float Diff = FMath::FindDeltaAngleDegrees(GetActorRotation().Yaw, Want);
	const float Max = FMath::RadiansToDegrees(RateRadS) * Dt;
	SetActorRotation(FRotator(0.f, GetActorRotation().Yaw + FMath::Clamp(Diff, -Max, Max), 0.f));
}

bool ADragonBoss::Legal(ESkill S) const
{
	if (Cds[Idx(S)] > 0.f) return false;
	const float D = SurfaceDist();
	const FSkillDef& Def = SkillDef(S);
	if (D < Def.MinD || D > Def.MaxD) return false;
	const float Rel = RelAngleDeg();
	switch (S)
	{
	case ESkill::Breath: case ESkill::Gust: return Rel < 70.f;
	case ESkill::Tail: return Rel > 95.f || (bEnraged && D < 3.f);
	case ESkill::Pounce: return bEnraged || D > 14.f;
	default: return true;
	}
}

void ADragonBoss::Decide()
{
	const float D = SurfaceDist();
	const float Rel = RelAngleDeg();
	ESkill Pick = ESkill::Nil;
	if (Legal(ESkill::Tail)) Pick = ESkill::Tail;
	else if (D > 9.f && Legal(ESkill::Meteors)) Pick = ESkill::Meteors;
	else if (D > 3.f && Legal(ESkill::Pounce)) Pick = ESkill::Pounce;
	else if (Legal(ESkill::Gust) && D < 4.f && (bEnraged || Rng.FRand() < 0.35f)) Pick = ESkill::Gust;
	else if (Legal(ESkill::Breath) && D >= 3.f) Pick = ESkill::Breath;
	else if (Legal(ESkill::Gust)) Pick = ESkill::Gust;
	if (Pick == ESkill::Nil)
	{
		Enter((Rel > 70.f || D > 3.6f) ? EDragonState::Approach : EDragonState::Idle);
		return;
	}
	StartSkill(Pick);
}

void ADragonBoss::StartSkill(ESkill S)
{
	Skill = S;
	Cds[Idx(S)] = SkillDef(S).Cd;
	SkillsUsed.FindOrAdd(SkillFName(S))++;
	Enter(EDragonState::Tele);
	TelegraphLeftS = TeleTime(S);
	ShowTelegraph();
	OnSkillUsed.Broadcast(SkillFName(S));
}

int32 ADragonBoss::Ring(const FVector& Center, float RadiusM, const FLinearColor& Color, float Seconds)
{
	for (int32 I = 0; I < kRings; ++I)
	{
		FTelegraph& T = Telegraphs[I];
		if (T.bActive) continue;
		T.bActive = true; T.Left = Seconds;
		T.Mesh->SetWorldLocation(Ground(Center, 12.f));
		T.Mesh->SetWorldRotation(FRotator::ZeroRotator);
		T.Mesh->SetWorldScale3D(FVector(RadiusM * UU / 50.f, RadiusM * UU / 50.f, 0.02f));
		if (T.Mid) T.Mid->SetVectorParameterValue(TEXT("Color"), Color);
		T.Mesh->SetVisibility(true);
		return I;
	}
	return -1;
}

int32 ADragonBoss::Cone(const FVector& Apex, float YawDeg, float RangeM, const FLinearColor& Color, float Seconds)
{
	for (int32 I = kRings; I < Telegraphs.Num(); ++I)
	{
		FTelegraph& T = Telegraphs[I];
		if (T.bActive) continue;
		T.bActive = true; T.Left = Seconds;
		const FVector Fwd = FRotator(0.f, YawDeg, 0.f).Vector();
		// engine Cone: 100 UU, centred, apex at local +Z. Pitch +90 maps local +Z to world -X (yaw frame),
		// so with the centre half a range ahead the apex sits at the dragon and the base at range.
		// After the rotation local X is world-up (kept paper-thin) and local Y is the sideways width.
		T.Mesh->SetWorldLocation(Ground(Apex + Fwd * (RangeM * UU * 0.5f), 14.f));
		T.Mesh->SetWorldRotation(FRotator(90.f, YawDeg, 0.f));
		const float Width = 2.f * RangeM * FMath::Tan(FMath::DegreesToRadians(Dragon::BreathHalfDeg));
		T.Mesh->SetWorldScale3D(FVector(0.02f, Width * UU / 100.f, RangeM * UU / 100.f));
		if (T.Mid) T.Mid->SetVectorParameterValue(TEXT("Color"), Color);
		T.Mesh->SetVisibility(true);
		return I;
	}
	return -1;
}

void ADragonBoss::EndTelegraph(int32 Handle)
{
	if (Handle < 0 || Handle >= Telegraphs.Num()) return;
	Telegraphs[Handle].bActive = false;
	Telegraphs[Handle].Mesh->SetVisibility(false);
}

void ADragonBoss::EndTelegraphs()
{
	for (int32 H : TeleHandles) EndTelegraph(H);
	TeleHandles.Reset();
}

void ADragonBoss::ShowTelegraph()
{
	TeleHandles.Reset();
	const float Dur = TeleTime(Skill) + SkillDef(Skill).Act;
	const FVector Loc = GetActorLocation();
	const float Yaw = GetActorRotation().Yaw;
	switch (Skill)
	{
	case ESkill::Breath:
		TeleHandles.Add(Cone(Loc, Yaw, Dragon::BreathRange, FLinearColor(1.f, 0.35f, 0.1f), Dur));
		break;
	case ESkill::Meteors:
	{
		const int32 N = bEnraged ? 5 : 3;
		Meteors.Reset();
		for (int32 I = 0; I < N; ++I)
		{
			FVector Off = FVector::ZeroVector;
			if (I > 0) { const float A = (I / static_cast<float>(N)) * 2.f * PI; Off = FVector(FMath::Cos(A), FMath::Sin(A), 0.f) * (3.2f + I * 0.6f) * UU; }
			const FVector P = Ground(Hunter->GetActorLocation() + Off);
			Meteors.Add({P, -1.f, false, Ring(P, Dragon::MeteorR, FLinearColor(1.f, 0.4f, 0.1f), Dur + 1.f)});
		}
		break;
	}
	case ESkill::Tail:
		for (float Off : {0.f, 60.f, -60.f}) TeleHandles.Add(Cone(Loc, Yaw + 180.f + Off, Dragon::TailReach + Dragon::HitRadius, FLinearColor(1.f, 0.5f, 0.15f), Dur));
		break;
	case ESkill::Gust:
		TeleHandles.Add(Ring(Loc, Dragon::GustR + Dragon::HitRadius, FLinearColor(0.6f, 0.75f, 1.f), Dur));
		break;
	case ESkill::Pounce:
		PounceTo = Hunter->GetActorLocation();
		TeleHandles.Add(Ring(PounceTo, Dragon::PounceR, FLinearColor(1.f, 0.25f, 0.1f), Dur));
		break;
	default: break;
	}
}

void ADragonBoss::RefreshAimedTelegraph()
{
	const float Dur = TelegraphLeftS + SkillDef(Skill).Act;
	if (Skill == ESkill::Breath)
	{
		EndTelegraphs();
		TeleHandles.Add(Cone(GetActorLocation(), GetActorRotation().Yaw, Dragon::BreathRange, FLinearColor(1.f, 0.35f, 0.1f), Dur));
	}
	else if (Skill == ESkill::Pounce)
	{
		PounceTo = Hunter->GetActorLocation();
		EndTelegraphs();
		TeleHandles.Add(Ring(PounceTo, Dragon::PounceR, FLinearColor(1.f, 0.25f, 0.1f), Dur));
	}
}

void ADragonBoss::BeginAct()
{
	Enter(EDragonState::Act);
	if (Skill == ESkill::Meteors)
	{
		for (FMeteor& M : Meteors)
		{
			M.LandIn = 0.9f;
			for (FMeteorFx& F : MeteorFx)
			{
				if (F.bActive) continue;
				F.bActive = true; F.T = 0.f; F.Dur = 0.9f; F.To = M.Target; F.From = M.Target + FVector(-600.f, 400.f, 3400.f);
				F.Ball->SetVisibility(true); F.Light->SetVisibility(true);
				break;
			}
		}
	}
	else if (Skill == ESkill::Pounce)
	{
		PounceFrom = GetActorLocation();
		const FVector To = (PounceTo - GetActorLocation()) * FVector(1, 1, 0);
		if (To.SizeSquared() > 1.f) SetActorRotation(FRotator(0.f, To.Rotation().Yaw, 0.f));
	}
}

void ADragonBoss::Deal(float Dmg)
{
	if (Hunter.IsValid()) UGameplayStatics::ApplyDamage(Hunter.Get(), Dmg, nullptr, this, UDamageType::StaticClass());
}

void ADragonBoss::SpawnFireField(const FVector& Location, float RadiusM, float Seconds)
{
	for (FField& F : Fields)
	{
		if (F.Left > 0.f) continue;
		F.Left = Seconds; F.Dur = Seconds; F.RadiusM = RadiusM;
		const FVector G = Ground(Location);
		F.Disc->SetWorldLocation(G + FVector(0.f, 0.f, 5.f));
		F.Disc->SetWorldScale3D(FVector(RadiusM * UU / 50.f, RadiusM * UU / 50.f, 0.03f));
		F.Disc->SetVisibility(true);
		F.Light->SetWorldLocation(G + FVector(0.f, 0.f, 120.f));
		F.Light->SetAttenuationRadius((RadiusM * 3.5f + 3.f) * UU);
		F.Light->SetVisibility(true);
		if (F.Fx) { F.Fx->SetWorldLocation(G); F.Fx->Activate(true); }
		return;
	}
}

void ADragonBoss::TickAct(float Dt)
{
	const FSkillDef& Def = SkillDef(Skill);
	const FVector Loc = GetActorLocation();
	switch (Skill)
	{
	case ESkill::Breath:
		if (!bActDone && Hunter.IsValid() && InArc(Loc, GetActorForwardVector(), Hunter->GetActorLocation(), Dragon::BreathRange, Dragon::BreathHalfDeg * 2.f, Dragon::HitRadius)) { bActDone = true; Deal(Def.Dmg); }
		if (StateTime >= Def.Act - 0.02f && !bFieldSpawned)
		{
			bFieldSpawned = true;
			EndTelegraphs();
			SpawnFireField(Loc + GetActorForwardVector().GetSafeNormal2D() * (Dragon::HitRadius + 4.5f) * UU, bEnraged ? 3.2f : 2.6f, 7.f);
		}
		break;
	case ESkill::Tail:
		if (!bActDone && StateTime >= 0.05f)
		{
			bActDone = true;
			if (RelAngleDeg() > 80.f && SurfaceDist() <= Dragon::TailReach) Deal(Def.Dmg);
			EndTelegraphs();
		}
		break;
	case ESkill::Gust:
		if (!bActDone && StateTime >= 0.05f)
		{
			bActDone = true;
			if (RelAngleDeg() < 100.f && SurfaceDist() <= Dragon::GustR) Deal(Def.Dmg);
			Ring(Loc, Dragon::GustR + Dragon::HitRadius, FLinearColor(0.7f, 0.85f, 1.f), 0.35f);
			EndTelegraphs();
		}
		break;
	case ESkill::Pounce:
	{
		const float K = FMath::Clamp(StateTime / Def.Act, 0.f, 1.f);
		const FVector P = FMath::Lerp(PounceFrom, PounceTo, K);
		BodyLift = FMath::Sin(K * PI) * 500.f;
		SetActorLocation(Ground(P, Capsule->GetScaledCapsuleHalfHeight()) + FVector(0.f, 0.f, BodyLift));
		if (K >= 1.f && !bActDone)
		{
			bActDone = true; BodyLift = 0.f;
			if (Hunter.IsValid() && (SurfaceDist() <= Dragon::PounceR + 0.5f || FVector::Dist2D(Hunter->GetActorLocation(), PounceTo) / UU <= Dragon::PounceR)) Deal(Def.Dmg);
			Ring(GetActorLocation(), Dragon::PounceR + Dragon::HitRadius, FLinearColor(1.f, 0.4f, 0.1f), 0.3f);
			EndTelegraphs();
		}
		break;
	}
	default: break;
	}
	(void)Dt;
	if (StateTime >= Def.Act) { Enter(EDragonState::Recover); bPunishable = true; }
}

void ADragonBoss::TickMeteors(float Dt)
{
	for (FMeteor& M : Meteors)
	{
		if (M.LandIn < 0.f || M.bApplied) continue;
		M.LandIn -= Dt;
		if (M.LandIn <= 0.f)
		{
			M.bApplied = true;
			EndTelegraph(M.Ring);
			SpawnFireField(M.Target, 2.2f, 3.5f);
			if (Hunter.IsValid() && FVector::Dist2D(Hunter->GetActorLocation(), M.Target) / UU <= Dragon::MeteorR) Deal(SkillDef(ESkill::Meteors).Dmg);
		}
	}
	for (FMeteorFx& F : MeteorFx)
	{
		if (!F.bActive) continue;
		F.T += Dt;
		const float K = FMath::Clamp(F.T / F.Dur, 0.f, 1.f);
		const FVector P = FMath::Lerp(F.From, F.To, K * K);
		F.Ball->SetWorldLocation(P);
		F.Light->SetWorldLocation(P);
		if (F.T >= F.Dur + 0.05f) { F.bActive = false; F.Ball->SetVisibility(false); F.Light->SetVisibility(false); }
	}
}

void ADragonBoss::TickFields(float Dt)
{
	for (FField& F : Fields)
	{
		if (F.Left <= 0.f) continue;
		F.Left -= Dt;
		const float Life = FMath::Clamp(F.Left / F.Dur, 0.f, 1.f);
		F.Light->SetIntensity((2200.f + 1200.f * Life) + FMath::Sin(GetWorld()->GetTimeSeconds() * 17.f) * 400.f);
		if (F.Left <= 0.f) { F.Disc->SetVisibility(false); F.Light->SetVisibility(false); if (F.Fx) F.Fx->Deactivate(); }
	}
	FieldTick -= Dt;
	if (FieldTick <= 0.f)
	{
		FieldTick = 0.5f;
		if (Hunter.IsValid() && Hunter->State != EHunterState::Dead)
		{
			for (const FField& F : Fields)
			{
				if (F.Left > 0.f && FVector::Dist2D(Hunter->GetActorLocation(), F.Disc->GetComponentLocation()) / UU <= F.RadiusM) { Deal(4.f); break; }
			}
		}
	}
}

void ADragonBoss::TickTelegraphs(float Dt)
{
	for (FTelegraph& T : Telegraphs)
	{
		if (!T.bActive) continue;
		T.Left -= Dt;
		if (T.Left <= 0.f) { T.bActive = false; T.Mesh->SetVisibility(false); }
	}
}

void ADragonBoss::Enrage()
{
	bEnraged = true;
	AuraLight->SetVisibility(true);
	if (BodyMid) BodyMid->SetVectorParameterValue(TEXT("Color"), FLinearColor(0.6f, 0.08f, 0.04f));
	Ring(GetActorLocation(), Dragon::HitRadius + 6.f, FLinearColor(1.f, 0.1f, 0.05f), 0.8f);
	Cds[Idx(ESkill::Pounce)] = 0.f;
	bRetreatPending = true;
	OnEnraged.Broadcast();
}

void ADragonBoss::Stagger(float Seconds)
{
	if (IsDead()) return;
	EndTelegraphs();
	for (FMeteor& M : Meteors) if (M.LandIn < 0.f) EndTelegraph(M.Ring);
	Meteors.RemoveAll([](const FMeteor& M) { return M.LandIn < 0.f; });
	Enter(EDragonState::Stagger);
	StateTime = 1.1f - Seconds;
	bPunishable = true;
}

void ADragonBoss::TakeHit(float Dmg, const FVector& From)
{
	if (IsDead()) return;
	Hp = FMath::Max(Hp - Dmg, 0.f);
	(void)From;
	if (Hp <= 0.f)
	{
		State = EDragonState::Dead;
		bPunishable = false;
		EndTelegraphs();
		for (FMeteor& M : Meteors) EndTelegraph(M.Ring);
		Meteors.Reset();
		AuraLight->SetVisibility(false);
		OnSlain.Broadcast();
	}
}

void ADragonBoss::Tick(float Dt)
{
	Super::Tick(Dt);
	TickTelegraphs(Dt);
	TickMeteors(Dt);
	TickFields(Dt);
	if (IsDead())
	{
		SetActorScale3D(FMath::VInterpTo(GetActorScale3D(), FVector(1.f, 1.f, 0.25f), Dt, 3.f));
		return;
	}
	if (!Hunter.IsValid()) return;
	StateTime += Dt;
	for (float& C : Cds) C = FMath::Max(C - Dt, 0.f);
	if (!bEnraged && Hp <= Dragon::HpMax * Dragon::EnrageAt) Enrage();
	if (bEnraged && (State == EDragonState::Idle || State == EDragonState::Approach || State == EDragonState::Recover) && SurfaceDist() < 6.f)
	{
		RetreatTimer += Dt;
		if (RetreatTimer >= Dragon::RetreatEvery) { RetreatTimer = 0.f; bRetreatPending = true; }
	}
	const bool bHunterAlive = Hunter->State != EHunterState::Dead;
	const float Speed = Dragon::Speed * (bEnraged ? 1.3f : 1.f) * UU;
	switch (State)
	{
	case EDragonState::Idle:
		bPunishable = false;
		if (bHunterAlive)
		{
			Think -= Dt;
			if (Think <= 0.f)
			{
				Think = 0.35f;
				if (bRetreatPending) { bRetreatPending = false; RetreatTimer = 0.f; Enter(EDragonState::Retreat); }
				else Decide();
			}
		}
		break;
	case EDragonState::Approach:
		FaceHunter(Dt, Dragon::Turn * (bEnraged ? 1.3f : 1.f));
		if (SurfaceDist() > 3.6f) SetActorLocation(Ground(GetActorLocation() + GetActorForwardVector().GetSafeNormal2D() * Speed * Dt, Capsule->GetScaledCapsuleHalfHeight()));
		Think -= Dt;
		if (Think <= 0.f) { Think = 0.35f; Decide(); }
		break;
	case EDragonState::Tele:
		TelegraphLeftS = FMath::Max(TeleTime(Skill) - StateTime, 0.f);
		if (TelegraphLeftS > Dragon::Commit && (Skill == ESkill::Breath || Skill == ESkill::Gust || Skill == ESkill::Pounce))
		{
			FaceHunter(Dt, Dragon::TeleTurn);
			RefreshAimedTelegraph();
		}
		else bAimLocked = true;   // COMMIT: the dodge window
		if (TelegraphLeftS <= 0.f) BeginAct();
		break;
	case EDragonState::Act: TickAct(Dt); break;
	case EDragonState::Recover:
		bPunishable = true;
		if (StateTime >= SkillDef(Skill).Recover) { bPunishable = false; Enter(EDragonState::Idle); }
		break;
	case EDragonState::Stagger:
		bPunishable = true;
		if (StateTime >= 1.1f) { bPunishable = false; Enter(EDragonState::Idle); }
		break;
	case EDragonState::Retreat:
	{
		const float K = FMath::Clamp(StateTime / Dragon::RetreatS, 0.f, 1.f);
		FVector P = GetActorLocation() - GetActorForwardVector().GetSafeNormal2D() * (Dragon::RetreatM / Dragon::RetreatS) * UU * Dt;
		const float MaxR = (Valley.IsValid() ? Valley->BowlRadiusM - 2.f : 28.f) * UU;
		if (FVector(P.X, P.Y, 0.f).Size() > MaxR) { const FVector N = FVector(P.X, P.Y, 0.f).GetSafeNormal() * MaxR; P.X = N.X; P.Y = N.Y; }
		BodyLift = FMath::Sin(K * PI) * 300.f;
		SetActorLocation(Ground(P, Capsule->GetScaledCapsuleHalfHeight()) + FVector(0.f, 0.f, BodyLift));
		if (StateTime >= Dragon::RetreatS)
		{
			BodyLift = 0.f;
			Cds[Idx(ESkill::Meteors)] = 0.f;
			Cds[Idx(ESkill::Pounce)] = FMath::Min(Cds[Idx(ESkill::Pounce)], 2.5f);
			Think = 0.05f;
			Enter(EDragonState::Idle);
		}
		break;
	}
	default: break;
	}
	if (State != EDragonState::Retreat && !(State == EDragonState::Act && Skill == ESkill::Pounce))
		SetActorLocation(Ground(GetActorLocation(), Capsule->GetScaledCapsuleHalfHeight()));
	if (AuraLight->IsVisible()) AuraLight->SetIntensity(2400.f + FMath::Sin(GetWorld()->GetTimeSeconds() * 11.f) * 500.f);
}
