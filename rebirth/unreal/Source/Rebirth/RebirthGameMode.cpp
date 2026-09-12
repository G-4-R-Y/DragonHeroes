#include "RebirthGameMode.h"

#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Creatures/DragonBoss.h"
#include "Creatures/PetCompanion.h"
#include "Engine/DirectionalLight.h"
#include "Engine/SkyLight.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "Hunter/HunterCharacter.h"
#include "Kismet/GameplayStatics.h"
#include "Pipeline/AssetManifest.h"
#include "Rebirth.h"
#include "RebirthHUD.h"
#include "Valley/ValleyGenerator.h"

const FVector ARebirthGameMode::HunterSpawn(1600.f, 0.f, 0.f);
const FVector ARebirthGameMode::DragonSpawn(-800.f, 0.f, 0.f);

namespace
{
	const TCHAR* kDrops[] = {TEXT("Cinderscale Fang"), TEXT("Ember-Heart Core"), TEXT("Wyrmking's Talon"), TEXT("Ashen Wing Membrane")};
}

ARebirthGameMode::ARebirthGameMode()
{
	PrimaryActorTick.bCanEverTick = true;
	DefaultPawnClass = AHunterCharacter::StaticClass();
	HUDClass = ARebirthHUD::StaticClass();
}

void ARebirthGameMode::BeginPlay()
{
	Super::BeginPlay();
	UWorld* W = GetWorld();
	for (TActorIterator<AValleyGenerator> It(W); It; ++It) { Valley = *It; break; }
	if (!Valley) Valley = W->SpawnActor<AValleyGenerator>(AValleyGenerator::StaticClass(), FTransform::Identity);
	SpawnWorldLights();

	Manifest = NewObject<URebirthAssetManifest>(this);
	Manifest->Load();

	FActorSpawnParameters P;
	P.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	Dragon = W->SpawnActorDeferred<ADragonBoss>(ADragonBoss::StaticClass(), FTransform(Valley->Ground(DragonSpawn, 300.f)));
	if (UStaticMesh* M = Manifest->LoadCreatureMesh(TEXT("dragon"))) Dragon->GeneratedBodyMesh = M;
	Dragon->FinishSpawning(FTransform(Valley->Ground(DragonSpawn, 300.f)));
	Pet = W->SpawnActor<APetCompanion>(APetCompanion::StaticClass(), FTransform(Valley->Ground(HunterSpawn + FVector(-160.f, -140.f, 0.f), 45.f)), P);
	if (UStaticMesh* M = Manifest->LoadCreatureMesh(TEXT("pet"))) Pet->GeneratedBodyMesh = M;

	bWorldBuilt = true;
	UE_LOG(LogRebirth, Log, TEXT("Rebirth world built: valley %s, dragon %s, pet %s"), *Valley->GetName(), *Dragon->GetName(), *Pet->GetName());
	if (APlayerController* PC = UGameplayStatics::GetPlayerController(W, 0)) TryBindHunter(PC->GetPawn());   // PIE: the player is already in
}

void ARebirthGameMode::PostLogin(APlayerController* NewPlayer)
{
	Super::PostLogin(NewPlayer);   // spawns the DefaultPawnClass hunter (at WorldSettings when the map has no PlayerStart)
	if (bWorldBuilt && NewPlayer) TryBindHunter(NewPlayer->GetPawn());   // standalone: BeginPlay already ran
}

void ARebirthGameMode::TryBindHunter(APawn* Pawn)
{
	AHunterCharacter* H = Cast<AHunterCharacter>(Pawn);
	if (!H || H == Hunter || !bWorldBuilt) return;
	Hunter = H;
	if (UStaticMesh* M = Manifest->LoadCreatureMesh(TEXT("hunter")))
	{
		Hunter->Body->SetStaticMesh(M);
		Hunter->Body->SetRelativeScale3D(FVector(1.f));
		Hunter->Body->SetRelativeLocation(FVector(0.f, 0.f, -90.f));
	}
	Dragon->Bind(Hunter, Valley);
	Pet->Bind(Hunter, Dragon, Valley);
	Hunter->Bind(Dragon, Pet, Valley);
	Dragon->OnSlain.AddUniqueDynamic(this, &ARebirthGameMode::HandleDragonSlain);
	Hunter->OnDied.AddUniqueDynamic(this, &ARebirthGameMode::HandleHunterDied);
	Hunter->OnRematchRequested.AddUniqueDynamic(this, &ARebirthGameMode::HandleRematchRequested);
	Kills = 0;
	Rematch();
	UE_LOG(LogRebirth, Log, TEXT("Rebirth slice ready: hunter %s bound"), *Hunter->GetName());
}

void ARebirthGameMode::SpawnWorldLights()
{
	UWorld* W = GetWorld();
	bool bHasSun = false;
	for (TActorIterator<ADirectionalLight> It(W); It; ++It) { bHasSun = true; break; }
	if (!bHasSun)
	{
		ADirectionalLight* Moon = W->SpawnActor<ADirectionalLight>(ADirectionalLight::StaticClass(), FTransform(FRotator(-48.f, 35.f, 0.f)));
		if (Moon && Moon->GetLightComponent())
		{
			Moon->GetLightComponent()->SetIntensity(1.2f);           // lux-ish moon
			Moon->GetLightComponent()->SetLightColor(FLinearColor(0.55f, 0.62f, 0.88f));
			Moon->GetLightComponent()->SetCastShadows(true);
			Moon->SetMobility(EComponentMobility::Movable);
		}
	}
	bool bHasSky = false;
	for (TActorIterator<ASkyLight> It(W); It; ++It) { bHasSky = true; break; }
	if (!bHasSky)
	{
		ASkyLight* Sky = W->SpawnActor<ASkyLight>(ASkyLight::StaticClass(), FTransform::Identity);
		if (Sky && Sky->GetLightComponent())
		{
			Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
			Sky->GetLightComponent()->SetIntensity(0.35f);
			Sky->GetLightComponent()->SetLightColor(FLinearColor(0.28f, 0.32f, 0.50f));
			Sky->GetLightComponent()->bRealTimeCapture = true;
		}
	}
}

void ARebirthGameMode::Tick(float Dt)
{
	Super::Tick(Dt);
	LoopTime += Dt;
	ToastLeft = FMath::Max(ToastLeft - Dt, 0.f);
	if (ToastLeft <= 0.f) Toast.Empty();
	if (Loop == ESliceLoop::Drop && LoopTime > 2.5f) Prompt = TEXT("R — REMATCH");
}

void ARebirthGameMode::HandleDragonSlain()
{
	Loop = ESliceLoop::Drop;
	LoopTime = 0.f;
	++Kills;
	Toast = FString::Printf(TEXT("LEGENDARY DROP — %s"), kDrops[(Kills - 1) % 4]);
	ToastLeft = 4.f;
	Prompt.Empty();
	UE_LOG(LogRebirth, Log, TEXT("Dragon slain #%d: %s (hunter hp %.0f, i-frame avoids %d, max combo %d)"), Kills, *Toast, Hunter->Hp, Hunter->Stats.IframeAvoids, Hunter->Stats.MaxCombo);
}

void ARebirthGameMode::HandleHunterDied()
{
	Loop = ESliceLoop::Dead;
	LoopTime = 0.f;
	Toast = TEXT("SLAIN BY THE WYRM");
	ToastLeft = 3.f;
	Prompt = TEXT("R — TRY AGAIN");
}

void ARebirthGameMode::HandleRematchRequested()
{
	if (Loop != ESliceLoop::Fight && LoopTime > 1.f) Rematch();
}

void ARebirthGameMode::Rematch()
{
	if (!Valley || !Dragon || !Hunter || !Pet) return;
	Loop = ESliceLoop::Fight;
	LoopTime = 0.f;
	Prompt.Empty();
	Toast.Empty();
	Dragon->ResetForRematch(DragonSpawn);
	Hunter->ResetForRematch(Valley->Ground(HunterSpawn, 90.f), (DragonSpawn - HunterSpawn).GetSafeNormal2D().Rotation());
	Pet->ResetForRematch();
	UE_LOG(LogRebirth, Log, TEXT("Rematch (#%d kills so far)"), Kills);
}
