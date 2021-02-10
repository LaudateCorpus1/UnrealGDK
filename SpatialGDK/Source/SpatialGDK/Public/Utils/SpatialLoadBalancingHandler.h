// Copyright (c) Improbable Worlds Ltd, All Rights Reserved

#pragma once

#include "EngineClasses/SpatialPackageMapClient.h"
#include "Schema/AuthorityIntent.h"

DECLARE_LOG_CATEGORY_EXTERN(LogSpatialLoadBalancingHandler, Log, All);

class USpatialNetDriver;

namespace SpatialGDK
{
class SpatialEventTracer;
class FSubView;

enum class EActorMigrationResult : uint8
{
	Success,
	NotAuthoritative,
	NotReady,
	PendingKill,
	NotInitialized,
	Streaming,
	NetDormant,
	NoSpatialClassFlags,
	DormantOnConnection
};

class FSpatialLoadBalancingHandler
{
public:
	FSpatialLoadBalancingHandler(USpatialNetDriver* InNetDriver, const FSubView& InSubView, SpatialEventTracer* InEventTracer);
	void AdvanceView();

	// Iterates over the list of actors to replicate, to check if they should migrate to another worker
	// and collects additional actors to replicate if needed.
	template <typename ReplicationContext>
	void EvaluateActorsToMigrate(ReplicationContext& iCtx)
	{
		for (AActor* Actor : iCtx.GetActorsBeingReplicated())
		{
			AActor* NetOwner;
			VirtualWorkerId NewAuthWorkerId;
			const EvaluateActorResult Result = EvaluateSingleActor(Actor, NetOwner, NewAuthWorkerId);
			switch (Result)
			{
			case EvaluateActorResult::Migrate:
				if (CollectActorsToMigrate(iCtx, NetOwner, NetOwner->HasAuthority()))
				{
					for (AActor* ActorToMigrate : TempActorsToMigrate)
					{
						if (ActorToMigrate != Actor)
						{
							iCtx.AddActorToReplicate(ActorToMigrate);
						}
						ActorsToMigrate.Add(ActorToMigrate, NewAuthWorkerId);
					}
				}
				TempActorsToMigrate.Empty();
				break;
			case EvaluateActorResult::RemoveAdditional:
				iCtx.RemoveAdditionalActor(Actor);
				break;
			default:
				break;
			}
		}
	}

	const TMap<AActor*, VirtualWorkerId>& GetActorsToMigrate() const { return ActorsToMigrate; }

	// Sends the migration instructions and update actor authority.
	void ProcessMigrations();
	void SendAuthorityIntentUpdate(const AActor& Actor, VirtualWorkerId NewAuthoritativeVirtualWorkerId);

	enum class EvaluateActorResult
	{
		None,			 // Actor not concerned by load balancing
		Migrate,		 // Actor should migrate
		RemoveAdditional // Actor is already marked as migrating.
	};

	EvaluateActorResult EvaluateSingleActor(AActor* Actor, AActor*& OutNetOwner, VirtualWorkerId& OutWorkerId);

protected:
	void UpdateSpatialDebugInfo(AActor* Actor, Worker_EntityId EntityId) const;

	uint64 GetLatestAuthorityChangeFromHierarchy(const AActor* HierarchyActor) const;

	template <typename ReplicationContext>
	bool CollectActorsToMigrate(ReplicationContext& iCtx, AActor* Actor, bool bNetOwnerHasAuth)
	{
		if (Actor->GetIsReplicated())
		{
			EActorMigrationResult ActorMigration = iCtx.IsActorReadyForMigration(Actor);
			if (ActorMigration != EActorMigrationResult::Success)
			{
				// Prevents an Actor hierarchy from migrating if one of its actor is not ready.
				// Child Actors are always allowed to join the owner.
				// This is a band aid to prevent Actors from being left behind,
				// although it has the risk of creating an infinite lock if the child is unable to become ready.
				if (bNetOwnerHasAuth)
				{
					LogMigrationFailure(ActorMigration, Actor);
					return false;
				}
			}
			else
			{
				TempActorsToMigrate.Add(Actor);
			}
		}

		for (AActor* Child : iCtx.GetDependentActors(Actor))
		{
			if (!CollectActorsToMigrate(iCtx, Child, bNetOwnerHasAuth))
			{
				return false;
			}
		}

		return true;
	}

	void LogMigrationFailure(EActorMigrationResult ActorMigrationResult, AActor* Actor);

	bool EvaluateRemoteMigrationComponent(const AActor* NetOwner, const AActor* Target, VirtualWorkerId& OutWorkerId);

	VirtualWorkerId GetWorkerId(const AActor* NetOwner);

	USpatialNetDriver* NetDriver;
	const FSubView* SubView;
	SpatialEventTracer* EventTracer;

	TMap<AActor*, VirtualWorkerId> ActorsToMigrate;
	TSet<AActor*> TempActorsToMigrate;

	TMap<Worker_EntityId_Key, AuthorityIntent> AuthIntentStore;
};
} // namespace SpatialGDK
