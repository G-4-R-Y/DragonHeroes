#include "RebirthHUD.h"

#include "Combat/RebirthCombat.h"
#include "Creatures/DragonBoss.h"
#include "Creatures/PetCompanion.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"
#include "Hunter/HunterCharacter.h"
#include "Misc/App.h"
#include "RebirthGameMode.h"

void ARebirthHUD::Bar(float X, float Y, float W, float H, float Frac, const FLinearColor& Fill, const FString& Label)
{
	DrawRect(FLinearColor(0.05f, 0.05f, 0.07f, 0.85f), X, Y, W, H);
	DrawRect(Fill, X + 2.f, Y + 2.f, (W - 4.f) * FMath::Clamp(Frac, 0.f, 1.f), H - 4.f);
	DrawText(Label, FLinearColor(0.95f, 0.92f, 0.85f), X + 6.f, Y - 20.f, GEngine->GetMediumFont());
}

void ARebirthHUD::DrawHUD()
{
	Super::DrawHUD();
	if (!Canvas) return;
	const ARebirthGameMode* GM = GetWorld()->GetAuthGameMode<ARebirthGameMode>();
	if (!GM || !GM->Hunter) return;
	const AHunterCharacter* H = GM->Hunter;
	const ADragonBoss* D = GM->Dragon;
	const APetCompanion* P = GM->Pet;
	const float SX = Canvas->SizeX, SY = Canvas->SizeY;
	UFont* Font = GEngine->GetMediumFont();

	Bar(28.f, 40.f, 300.f, 18.f, H->Hp / RebirthCombat::Hunter::HpMax, FLinearColor(0.75f, 0.15f, 0.1f), FString::Printf(TEXT("HUNTER  %d / %d"), FMath::RoundToInt(H->Hp), 100));
	for (int32 I = 0; I < RebirthCombat::Hunter::DodgeCharges; ++I)
		DrawRect(I < H->DodgeCharges ? FLinearColor(0.45f, 0.8f, 1.f) : FLinearColor(0.2f, 0.25f, 0.3f), 28.f + I * 22.f, 64.f, 18.f, 8.f);
	DrawText(H->SkillCd <= 0.f ? TEXT("SKILL READY (K)") : *FString::Printf(TEXT("skill %.1fs"), H->SkillCd), H->SkillCd <= 0.f ? FLinearColor(1.f, 0.7f, 0.35f) : FLinearColor(0.6f, 0.6f, 0.6f), 28.f, 80.f, Font);
	if (P) DrawText(P->HowlCd <= 0.f ? TEXT("HOWL READY (E)") : *FString::Printf(TEXT("howl %.1fs"), P->HowlCd), P->HowlCd <= 0.f ? FLinearColor(0.4f, 1.f, 0.9f) : FLinearColor(0.6f, 0.6f, 0.6f), 28.f, 98.f, Font);
	if (H->ComboHits > 0) DrawText(FString::Printf(TEXT("COMBO x%d"), H->ComboHits), FLinearColor(1.f, 0.9f, 0.5f), 28.f, 122.f, Font);

	if (D)
	{
		const FString Name = FString(TEXT("CINDER WYRM, THE VALLEY'S END")) + (D->bEnraged ? TEXT("  — ENRAGED") : TEXT(""));
		Bar(SX * 0.5f - 260.f, 40.f, 520.f, 16.f, D->Hp / RebirthCombat::Dragon::HpMax, D->bEnraged ? FLinearColor(0.85f, 0.35f, 0.1f) : FLinearColor(0.7f, 0.55f, 0.15f), Name);
		if (D->State == EDragonState::Tele) DrawText(FString::Printf(TEXT("!! %s !!"), RebirthCombat::SkillName(D->CurrentSkill())).ToUpper(), FLinearColor(1.f, 0.5f, 0.2f), SX * 0.5f - 60.f, 66.f, Font);
		else if (D->IsPunishable()) DrawText(TEXT("PUNISH"), FLinearColor(0.5f, 1.f, 0.6f), SX * 0.5f - 40.f, 66.f, Font);
	}

	const float Ms = FApp::GetDeltaTime() * 1000.f;
	DrawText(FString::Printf(TEXT("%.1f ms  (%d fps)"), Ms, FMath::RoundToInt(1.f / FMath::Max(FApp::GetDeltaTime(), 0.0001f))), Ms < 16.7f ? FLinearColor(0.6f, 1.f, 0.6f) : FLinearColor(1.f, 0.5f, 0.4f), SX - 220.f, 28.f, Font);

	if (!GM->Toast.IsEmpty())
	{
		const float A = FMath::Clamp(GM->ToastLeft / 0.6f, 0.f, 1.f);
		DrawRect(FLinearColor(0.05f, 0.03f, 0.02f, 0.8f * A), SX * 0.5f - 300.f, SY * 0.5f - 60.f, 600.f, 64.f);
		DrawText(GM->Toast, FLinearColor(1.f, 0.85f, 0.4f, A), SX * 0.5f - 280.f, SY * 0.5f - 40.f, GEngine->GetLargeFont());
	}
	if (!GM->Prompt.IsEmpty()) DrawText(GM->Prompt, FLinearColor(0.95f, 0.92f, 0.85f), SX * 0.5f - 80.f, SY - 60.f, Font);
	DrawText(TEXT("WASD move · Space dodge · J attack · K skill · E howl · Tab lock-on · mouse orbit · R rematch"), FLinearColor(0.6f, 0.6f, 0.65f), 28.f, SY - 30.f, GEngine->GetSmallFont());
}
