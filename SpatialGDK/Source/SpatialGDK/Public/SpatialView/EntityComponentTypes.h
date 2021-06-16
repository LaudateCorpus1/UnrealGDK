// Copyright (c) Improbable Worlds Ltd, All Rights Reserved

#pragma once

#include "SpatialView/ComponentData.h"
#include "SpatialView/ComponentUpdate.h"
#include "SpatialView/EntityComponentId.h"

namespace SpatialGDK
{
struct EntityComponentUpdate
{
	FSpatialEntityId EntityId;
	ComponentUpdate Update;

	EntityComponentId GetEntityComponentId() const { return { EntityId, Update.GetComponentId() }; }
};

struct EntityComponentData
{
	FSpatialEntityId EntityId;
	ComponentData Data;

	EntityComponentId GetEntityComponentId() const { return { EntityId, Data.GetComponentId() }; }
};

struct EntityComponentCompleteUpdate
{
	FSpatialEntityId EntityId;
	ComponentData CompleteUpdate;
	ComponentUpdate Events;

	EntityComponentId GetEntityComponentId() const { return { EntityId, CompleteUpdate.GetComponentId() }; }
};

struct EntityComponentIdEquality
{
	EntityComponentId Id;

	bool operator()(const EntityComponentUpdate& Element) const { return Element.GetEntityComponentId() == Id; }

	bool operator()(const EntityComponentData& Element) const { return Element.GetEntityComponentId() == Id; }

	bool operator()(const EntityComponentCompleteUpdate& Element) const { return Element.GetEntityComponentId() == Id; }
};

struct ComponentIdEquality
{
	Worker_ComponentId Id;

	bool operator()(const ComponentData& Element) const { return Element.GetComponentId() == Id; }

	bool operator()(const ComponentUpdate& Element) const { return Element.GetComponentId() == Id; }
};

} // namespace SpatialGDK
