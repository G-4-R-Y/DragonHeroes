// The slice's combat table — plain C++, no UObjects, so it is the piece the
// parent repo's dh-sim replaces (canon §10: the sim is engine-agnostic).
// SAME numbers as rebirth/godot3d and rebirth/native (docs/02-status.md
// "shared combat table"). Units here are METRES; callers convert to UU (x100).
#pragma once

#include "CoreMinimal.h"

namespace RebirthCombat
{
	constexpr float UU = 100.f;   // 1 m = 100 Unreal units

	enum class ESkill : uint8 { Nil, Breath, Meteors, Tail, Gust, Pounce, Count };

	struct FSkillDef { float Tele, Act, Recover, MinD, MaxD, Dmg, Cd; };

	// tele, act, recover, min_d, max_d, dmg, cd  (seconds / metres / hp)
	inline const FSkillDef& SkillDef(ESkill S)
	{
		static const FSkillDef Table[] = {
			{0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f},          // Nil
			{1.10f, 1.20f, 1.60f, 3.0f, 15.0f, 30.f, 5.f}, // Breath
			{1.40f, 0.50f, 1.00f, 9.0f, 60.0f, 24.f, 9.f}, // Meteors
			{0.80f, 0.30f, 1.20f, 0.0f, 7.0f, 22.f, 4.f},  // Tail
			{0.90f, 0.30f, 1.90f, 0.0f, 7.5f, 12.f, 6.f},  // Gust
			{1.00f, 0.55f, 1.30f, 3.0f, 30.0f, 34.f, 8.f}, // Pounce
		};
		return Table[static_cast<int32>(S)];
	}

	inline const TCHAR* SkillName(ESkill S)
	{
		switch (S)
		{
		case ESkill::Breath: return TEXT("breath");
		case ESkill::Meteors: return TEXT("meteors");
		case ESkill::Tail: return TEXT("tail");
		case ESkill::Gust: return TEXT("gust");
		case ESkill::Pounce: return TEXT("pounce");
		default: return TEXT("none");
		}
	}

	namespace Hunter
	{
		constexpr float HpMax = 100.f, Speed = 6.2f, DodgeDur = 0.42f, DodgeDist = 6.f, DodgeIframes = 0.28f,
			DodgeRecharge = 1.8f, InputBuffer = 0.15f, ComboLink = 0.45f, Hitstun = 0.30f, SkillCd = 6.f, SkillLunge = 4.f;
		constexpr int32 DodgeCharges = 3;
		struct FStep { float Startup, Active, Recover, Dmg, Reach, ArcDeg; };
		inline const FStep& Combo(int32 Step)
		{
			static const FStep Table[3] = {
				{0.12f, 0.10f, 0.22f, 10.f, 2.6f, 70.f},
				{0.10f, 0.10f, 0.22f, 10.f, 2.6f, 70.f},
				{0.16f, 0.12f, 0.34f, 18.f, 2.9f, 90.f},
			};
			return Table[FMath::Clamp(Step, 0, 2)];
		}
		inline const FStep& Skill() { static const FStep S{0.18f, 0.16f, 0.36f, 45.f, 3.4f, 100.f}; return S; }
	}

	namespace Dragon
	{
		constexpr float HpMax = 600.f, HitRadius = 2.4f, Speed = 4.2f, Turn = 2.0f, TeleTurn = 1.2f, EnrageAt = 0.40f,
			Commit = 0.35f, BreathRange = 14.f, BreathHalfDeg = 35.f, MeteorR = 3.2f, TailReach = 7.f, GustR = 7.5f,
			PounceR = 3.6f, RetreatS = 0.6f, RetreatM = 14.f, RetreatEvery = 18.f;
	}

	namespace Pet
	{
		constexpr float Speed = 8.f, NipCd = 4.f, NipDmg = 6.f, NipRange = 4.5f, HowlCd = 12.f, HowlRange = 14.f, HowlHeal = 10.f;
	}

	/** Horizontal distance (m) from A to B's surface (B has HitRadius). */
	inline float SurfaceDistance(const FVector& A, const FVector& B, float HitRadiusM)
	{
		return FMath::Max(FVector::Dist2D(A, B) / UU - HitRadiusM, 0.f);
	}

	/** Is P inside the forward arc of Origin facing Forward (unit, XY) within ReachM past HitRadiusM? */
	inline bool InArc(const FVector& Origin, const FVector& Forward, const FVector& P, float ReachM, float ArcDeg, float HitRadiusM)
	{
		const FVector To = (P - Origin) * FVector(1, 1, 0);
		const float Dist = To.Size() / UU;
		if (Dist - HitRadiusM > ReachM) return false;
		if (Dist <= HitRadiusM) return true;
		const float Cos = FVector::DotProduct(Forward.GetSafeNormal2D(), To.GetSafeNormal());
		return FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(Cos, -1.f, 1.f))) <= ArcDeg * 0.5f;
	}

	/** Unsigned angle (deg) between Forward and the direction to P. > ~100 means P is behind. */
	inline float RelAngleDeg(const FVector& Origin, const FVector& Forward, const FVector& P)
	{
		const float Cos = FVector::DotProduct(Forward.GetSafeNormal2D(), ((P - Origin) * FVector(1, 1, 0)).GetSafeNormal());
		return FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(Cos, -1.f, 1.f)));
	}
}
