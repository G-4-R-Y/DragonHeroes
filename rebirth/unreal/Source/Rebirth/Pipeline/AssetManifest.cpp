#include "Pipeline/AssetManifest.h"

#include "Dom/JsonObject.h"
#include "Engine/StaticMesh.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Rebirth.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "UObject/SoftObjectPath.h"

bool URebirthAssetManifest::Load()
{
	Entries.Reset();
	const FString Path = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Generated"), TEXT("manifest.json"));
	FString Text;
	if (!FFileHelper::LoadFileToString(Text, *Path)) return false;
	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Text);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid()) return false;
	const TSharedPtr<FJsonObject>* Creatures = nullptr;
	if (!Root->TryGetObjectField(TEXT("creatures"), Creatures) || !Creatures) return false;
	for (const auto& Pair : (*Creatures)->Values)
	{
		const TSharedPtr<FJsonObject>* Obj = nullptr;
		if (!Pair.Value->TryGetObject(Obj) || !Obj) continue;
		FGeneratedCreature C;
		(*Obj)->TryGetStringField(TEXT("file"), C.File);
		(*Obj)->TryGetStringField(TEXT("asset"), C.AssetPath);
		const TSharedPtr<FJsonObject>* Prov = nullptr;
		if ((*Obj)->TryGetObjectField(TEXT("provenance"), Prov) && Prov)
		{
			(*Prov)->TryGetStringField(TEXT("source"), C.Source);
			(*Prov)->TryGetStringField(TEXT("sha256"), C.Sha256);
		}
		Entries.Add(Pair.Key, C);
	}
	UE_LOG(LogRebirth, Log, TEXT("Asset manifest: %d generated creatures"), Entries.Num());
	return true;
}

UStaticMesh* URebirthAssetManifest::LoadCreatureMesh(const FString& Name) const
{
	const FGeneratedCreature* C = Entries.Find(Name);
	if (!C || C->AssetPath.IsEmpty()) return nullptr;
	UStaticMesh* Mesh = Cast<UStaticMesh>(FSoftObjectPath(C->AssetPath).TryLoad());
	if (!Mesh) UE_LOG(LogRebirth, Warning, TEXT("Asset manifest: %s not imported yet (%s) — placeholder stays"), *Name, *C->AssetPath);
	return Mesh;
}
