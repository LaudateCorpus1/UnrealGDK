// Copyright (c) Improbable Worlds Ltd, All Rights Reserved

#pragma once

#include "CoreMinimal.h"
#include "SpatialFunctionalTest.h"
#include "DormancyTest.generated.h"

UCLASS()
class SPATIALGDKFUNCTIONALTESTS_API ADormancyTest : public ASpatialFunctionalTest
{
	GENERATED_BODY()

protected:
	void RequireDormancyTestState(const TEnumAsByte<enum ENetDormancy> ExpectedNetDormancy, const int ExpectedTestIntProp,
								  const int ExpectedCount);
	void DestroyDormancyTestActors();
};