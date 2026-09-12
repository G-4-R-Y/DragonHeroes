// Asset-free HUD (Canvas): hunter/dragon bars, dodge charges, cooldowns, combo,
// telegraph/punish cue, toast, prompt, frame-time readout (60 FPS directive).
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "RebirthHUD.generated.h"

UCLASS()
class REBIRTH_API ARebirthHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void DrawHUD() override;

private:
	void Bar(float X, float Y, float W, float H, float Frac, const FLinearColor& Fill, const FString& Label);
};
