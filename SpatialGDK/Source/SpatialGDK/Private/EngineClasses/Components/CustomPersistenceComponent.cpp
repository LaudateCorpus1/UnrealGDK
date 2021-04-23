// Copyright (c) Improbable Worlds Ltd, All Rights Reserved

#include "EngineClasses/Components/CustomPersistenceComponent.h"

#include "EngineClasses/SpatialGameInstance.h"
#include "Interop/Connection/SpatialWorkerConnection.h"
#include "Utils/SpatialStatics.h"

// Sets default values for this component's properties
UCustomPersistenceComponent::UCustomPersistenceComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
	PrimaryComponentTick.bStartWithTickEnabled = false;

	bWantsInitializeComponent = true;

	bHasProvidedPersistenceData = false;

	// Needed for now, both to replicate the bHasProvidedPersistenceData bool, and to get PreReplication callbacks, during which we pull in
	// the data from the actor. The latter is not a hard requirement (the actor could also be required to push its data to us)
	SetIsReplicatedByDefault(true);
}

// Once we gain authority, we know we have all the data for an entity, and authority to modify it.
// If we can find data for the actor's persistence spatial component, pass it to the user implementation via OnPersistenceDataAvailable
// If we don't have any data for the component, add it to the entity. This usually happens when the actor is loaded for the first time in a
// fresh deployment, or spawned dynamically.
void UCustomPersistenceComponent::OnAuthorityGained()
{
	UE_LOG(LogTemp, Log, TEXT("UCustomPersistenceComponent, %s, OnAuthorityGained, bHasProvidedPersistenceData %d"), *GetName(),
		   bHasProvidedPersistenceData);

	// This doesn't work upon snapshot reload until this flag gets scrubbed from the snapshot
	// Commenting it out means that we'll re-apply persistence data on every server migration, but for testing purposes that should be okay.
	// if (bHasProvidedPersistenceData)
	// {
	// 	UE_LOG(LogTemp, Log, TEXT("UCustomPersistenceComponent, OnAuthorityGained, but already provided persistence data previously"));
	// 	return;
	// }

	bHasProvidedPersistenceData = true;
	UE_LOG(LogTemp, Log, TEXT("UCustomPersistenceComponent, OnAuthorityGained, Setting bHasProvidedPersistenceData to true"));

	AActor* Owner = GetOwner();
	if (Owner == nullptr)
	{
		UE_LOG(LogTemp, Error, TEXT("UCustomPersistenceComponent, didn't have an owner actor during InternalOnPersistenceDataAvailable"));
		return;
	}

	// TODO this shouldn't be needed, keeping it for now to avoid any surprises
	if (!Owner->HasAuthority())
	{
		UE_LOG(LogTemp, Log, TEXT("UCustomPersistenceComponent, owner doesn't have authority"));
		return;
	}

	const uint64 EntityID = USpatialStatics::GetActorEntityId(Owner);
	if (EntityID == 0)
	{
		UE_LOG(LogTemp, Warning, TEXT("UCustomPersistenceComponent, Don't have an entity ID in persistence callback."));
		return;
	}

	const USpatialNetDriver* NetDriver = Cast<USpatialNetDriver>(GetWorld()->GetNetDriver());
	if (NetDriver == nullptr)
	{
		UE_LOG(LogTemp, Error, TEXT("UCustomPersistenceComponent, Got persistence data callback but can't find a spatial net driver."));
		return;
	}

	SpatialGDK::ViewCoordinator& Coordinator = NetDriver->Connection->GetCoordinator();

	if (!Coordinator.HasEntity(EntityID))
	{
		UE_LOG(LogTemp, Warning,
			   TEXT("UCustomPersistenceComponent, View coordinator doesn't have entity %llu during persistence callback."), EntityID);
		return;
	}

	const SpatialGDK::EntityView& View = Coordinator.GetView();
	const SpatialGDK::EntityViewElement* ViewData = View.Find(EntityID);
	if (ViewData == nullptr)
	{
		UE_LOG(LogTemp, Error, TEXT("UCustomPersistenceComponent, Found no persistence data for entity %llu"), EntityID);
		return;
	}

	bool bFoundComponent = false;
	for (const auto& ComponentData : ViewData->Components)
	{
		if (ComponentData.GetComponentId() == GetComponentId())
		{
			OnPersistenceDataAvailable(ComponentData);
			bFoundComponent = true;
			break;
		}
	}

	if (!bFoundComponent)
	{
		SpatialGDK::ComponentData Data(GetComponentId());
		GetAddComponentData(Data);
		Coordinator.SendAddComponent(EntityID, MoveTemp(Data), {});
		UE_LOG(LogTemp, Log, TEXT("UCustomPersistenceComponent, added component %u to entity %llu"), GetComponentId(), EntityID);
	}
}

void UCustomPersistenceComponent::PostReplication()
{
	// Work with spatial turned off
	if (!USpatialStatics::IsSpatialNetworkingEnabled())
	{
		UE_LOG(LogTemp, Log, TEXT("UCustomPersistenceComponent, not using spatial networking"));
		return;
	}

	AActor* Owner = GetOwner();
	if (Owner == nullptr)
	{
		UE_LOG(LogTemp, Error, TEXT("UCustomPersistenceComponent, didn't have an owner actor during PreReplication"));
		return;
	}

	if (!IsValid(Owner))
	{
		UE_LOG(LogTemp, Error, TEXT("UCustomPersistenceComponent, Owner is not yet valid, data loading may fail"));
		return;
	}

	const uint64 EntityID = USpatialStatics::GetActorEntityId(Owner);
	if (EntityID == 0)
	{
		UE_LOG(LogTemp, Warning, TEXT("UCustomPersistenceComponent, didn't have an entity ID in PreReplication."));
		return;
	}

	const USpatialNetDriver* NetDriver = Cast<USpatialNetDriver>(GetWorld()->GetNetDriver());
	if (NetDriver == nullptr)
	{
		UE_LOG(LogTemp, Error, TEXT("UCustomPersistenceComponent, running with spatial but can't find a spatial net driver."));
		return;
	}

	if (!NetDriver->Connection->GetCoordinator().HasEntity(EntityID))
	{
		UE_LOG(LogTemp, Warning, TEXT("UCustomPersistenceComponent, View coordinator doesn't have entity %llu yet."), EntityID);
		return;
	}

	// Will have to see if the ComponentUpdate type makes sense to be user-facing.
	SpatialGDK::ComponentUpdate Update(GetComponentId());
	GetComponentUpdate(Update);
	NetDriver->Connection->GetCoordinator().SendComponentUpdate(EntityID, MoveTemp(Update), {});
}

void UCustomPersistenceComponent::GetAddComponentData(SpatialGDK::ComponentData& Data) {}

void UCustomPersistenceComponent::GetComponentUpdate(SpatialGDK::ComponentUpdate& Update) {}

void UCustomPersistenceComponent::OnPersistenceDataAvailable(const SpatialGDK::ComponentData& Data) {}