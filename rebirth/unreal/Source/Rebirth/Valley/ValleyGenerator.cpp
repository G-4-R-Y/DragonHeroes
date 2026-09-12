#include "Valley/ValleyGenerator.h"

#include "Components/ExponentialHeightFogComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Engine/StaticMesh.h"
#include "ProceduralMeshComponent.h"
#include "Rebirth.h"
#include "UObject/ConstructorHelpers.h"

namespace
{
	constexpr float UU = 100.f;

	uint32 Hash2(int32 X, int32 Y, uint32 S)
	{
		uint32 H = static_cast<uint32>(X) * 374761393u + static_cast<uint32>(Y) * 668265263u + S * 2246822519u;
		H = (H ^ (H >> 13)) * 1274126177u;
		return H ^ (H >> 16);
	}

	float ValueNoise(float X, float Y, uint32 S)
	{
		const int32 Xi = FMath::FloorToInt(X), Yi = FMath::FloorToInt(Y);
		float Fx = X - Xi, Fy = Y - Yi;
		Fx = Fx * Fx * (3.f - 2.f * Fx);
		Fy = Fy * Fy * (3.f - 2.f * Fy);
		auto V = [&](int32 A, int32 B) { return (Hash2(A, B, S) & 0xFFFF) / 32767.5f - 1.f; };
		const float A = FMath::Lerp(V(Xi, Yi), V(Xi + 1, Yi), Fx);
		const float B = FMath::Lerp(V(Xi, Yi + 1), V(Xi + 1, Yi + 1), Fx);
		return FMath::Lerp(A, B, Fy);
	}
}

AValleyGenerator::AValleyGenerator()
{
	PrimaryActorTick.bCanEverTick = true;
	Terrain = CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("Terrain"));
	SetRootComponent(Terrain);
	Terrain->bUseAsyncCooking = true;
	Terrain->SetCollisionProfileName(TEXT("BlockAll"));
	Rocks = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("Rocks"));
	Rocks->SetupAttachment(Terrain);
	Rocks->SetCollisionProfileName(TEXT("NoCollision"));
	Rocks->SetMobility(EComponentMobility::Static);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
	if (Cube.Succeeded()) Rocks->SetStaticMesh(Cube.Object);
	Fog = CreateDefaultSubobject<UExponentialHeightFogComponent>(TEXT("Fog"));
	Fog->SetupAttachment(Terrain);
	Fog->SetFogDensity(0.012f);
	Fog->SetFogInscatteringColor(FLinearColor(0.05f, 0.07f, 0.14f));
	Fog->SetVolumetricFog(true);
	Fog->SetVolumetricFogScatteringDistribution(0.4f);
	Fog->SetVolumetricFogExtinctionScale(1.5f);
}

float AValleyGenerator::Noise(float X, float Y) const
{
	float Sum = 0.f, Amp = 1.f, Freq = 0.035f, Tot = 0.f;
	for (int32 O = 0; O < 4; ++O)
	{
		Sum += ValueNoise(X * Freq, Y * Freq, static_cast<uint32>(Seed) + O) * Amp;
		Tot += Amp;
		Amp *= 0.5f;
		Freq *= 2.f;
	}
	return Sum / Tot;
}

float AValleyGenerator::HeightAt(float X, float Y) const
{
	const float Xm = X / UU, Ym = Y / UU;
	const float R = FMath::Sqrt(Xm * Xm + Ym * Ym);
	const float Rim = FMath::SmoothStep(BowlRadiusM, BowlRadiusM + 28.f, R) * RimHeightM;
	const float Amp = FMath::Lerp(0.12f, 4.5f, FMath::SmoothStep(BowlRadiusM - 6.f, BowlRadiusM + 20.f, R));
	return (Rim + Noise(Xm, Ym) * Amp) * UU;
}

FVector AValleyGenerator::Ground(const FVector& L, float OffsetUU) const
{
	return FVector(L.X, L.Y, HeightAt(L.X, L.Y) + OffsetUU);
}

FLinearColor AValleyGenerator::ColorAt(float Xm, float Ym, float Hm) const
{
	const float R = FMath::Sqrt(Xm * Xm + Ym * Ym);
	const FLinearColor Earth(0.17f, 0.135f, 0.11f), Scorch(0.11f, 0.09f, 0.085f), Moss(0.10f, 0.16f, 0.09f), Rock(0.23f, 0.22f, 0.25f);
	FLinearColor C = FLinearColor::LerpUsingHSV(Earth, Scorch, FMath::Clamp(1.f - R / 12.f, 0.f, 1.f) * 0.7f);
	C = FMath::Lerp(C, Moss, FMath::SmoothStep(BowlRadiusM - 4.f, BowlRadiusM + 10.f, R));
	C = FMath::Lerp(C, Rock, FMath::SmoothStep(6.f, 16.f, Hm));
	const float V = ValueNoise(Xm * 0.11f + 100.f, Ym * 0.11f, 99u) * 0.06f;
	return C + FLinearColor(V, V, V, 0.f);
}

void AValleyGenerator::PostInitializeComponents()
{
	Super::PostInitializeComponents();
	if (bBuilt) return;
	bBuilt = true;
	BuildTerrain();
	ScatterRocks();
	PlaceLights();
	UE_LOG(LogRebirth, Log, TEXT("Valley built: %d x %d grid, %d rocks, %d fire lights"), Grid, Grid, RockCount, FireLights.Num());
}

void AValleyGenerator::BuildTerrain()
{
	TArray<FVector> Verts;
	TArray<int32> Tris;
	TArray<FVector> Normals;
	TArray<FVector2D> UVs;
	TArray<FLinearColor> Colors;
	TArray<FProcMeshTangent> Tangents;
	const int32 N = Grid;
	const float Cell = SizeM * UU / N;
	Verts.Reserve((N + 1) * (N + 1));
	for (int32 I = 0; I <= N; ++I)
	{
		for (int32 J = 0; J <= N; ++J)
		{
			const float X = -SizeM * UU / 2 + I * Cell, Y = -SizeM * UU / 2 + J * Cell;
			const float H = HeightAt(X, Y);
			Verts.Add(FVector(X, Y, H));
			const float E = 50.f;
			const FVector Nrm = FVector(HeightAt(X - E, Y) - HeightAt(X + E, Y), HeightAt(X, Y - E) - HeightAt(X, Y + E), 2.f * E).GetSafeNormal();
			Normals.Add(Nrm);
			UVs.Add(FVector2D(I, J) / static_cast<float>(N));
			Colors.Add(ColorAt(X / UU, Y / UU, H / UU));
			Tangents.Add(FProcMeshTangent(1.f, 0.f, 0.f));
		}
	}
	const int32 W = N + 1;
	for (int32 I = 0; I < N; ++I)
	{
		for (int32 J = 0; J < N; ++J)
		{
			const int32 A = I * W + J, B = A + 1, C = A + W, D = C + 1;
			// UE is left-handed: wind so the normal faces +Z
			Tris.Append({A, C, B, B, C, D});
		}
	}
	Terrain->CreateMeshSection_LinearColor(0, Verts, Tris, Normals, UVs, Colors, Tangents, true);
}

void AValleyGenerator::ScatterRocks()
{
	if (!Rocks->GetStaticMesh()) return;
	FRandomStream Rng(Seed);
	for (int32 I = 0; I < RockCount; ++I)
	{
		const float Ang = Rng.FRand() * 2.f * PI;
		const float R = Rng.FRandRange(BowlRadiusM - 3.f, BowlRadiusM + 34.f);
		const float X = FMath::Cos(Ang) * R * UU, Y = FMath::Sin(Ang) * R * UU;
		const FVector S(Rng.FRandRange(1.f, 4.5f), Rng.FRandRange(1.f, 4.f), Rng.FRandRange(0.8f, 3.5f));   // metres; cube is 1 m
		const FRotator Rot(Rng.FRandRange(-12.f, 12.f), Rng.FRand() * 360.f, Rng.FRandRange(-10.f, 10.f));
		Rocks->AddInstance(FTransform(Rot, FVector(X, Y, HeightAt(X, Y) + S.Z * 25.f), S), true);
	}
}

void AValleyGenerator::PlaceLights()
{
	FRandomStream Rng(Seed + 3);
	for (int32 I = 0; I < 10; ++I)
	{
		const float Ang = (I / 10.f) * 2.f * PI + Rng.FRandRange(-0.3f, 0.3f);
		const float R = Rng.FRandRange(12.f, BowlRadiusM - 2.f);
		const FVector P(FMath::Cos(Ang) * R * UU, FMath::Sin(Ang) * R * UU, 0.f);
		UPointLightComponent* L = NewObject<UPointLightComponent>(this);
		L->SetupAttachment(Terrain);
		L->SetWorldLocation(Ground(P, 90.f));
		L->SetLightColor(FLinearColor(0.25f, 0.9f, 0.8f));
		L->SetIntensity(1300.f);
		L->SetAttenuationRadius(750.f);
		L->SetCastShadows(false);
		L->RegisterComponent();
	}
	for (int32 I = 0; I < 4; ++I)
	{
		const float Ang = (I / 4.f) * 2.f * PI + 0.6f;
		const FVector P(FMath::Cos(Ang) * 21.f * UU, FMath::Sin(Ang) * 21.f * UU, 0.f);
		UPointLightComponent* L = NewObject<UPointLightComponent>(this);
		L->SetupAttachment(Terrain);
		L->SetWorldLocation(Ground(P, 140.f));
		L->SetLightColor(FLinearColor(1.0f, 0.55f, 0.2f));
		L->SetIntensity(2600.f);
		L->SetAttenuationRadius(1300.f);
		L->SetCastShadows(true);
		L->RegisterComponent();
		FireLights.Add(L);
	}
}

void AValleyGenerator::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	Time += DeltaSeconds;
	for (int32 I = 0; I < FireLights.Num(); ++I)
	{
		if (!FireLights[I]) continue;
		const float Ph = I * 1.7f;
		FireLights[I]->SetIntensity(2600.f + FMath::Sin(Time * 9.f + Ph) * 350.f + FMath::Sin(Time * 23.f + Ph * 2.f) * 180.f);
	}
}
