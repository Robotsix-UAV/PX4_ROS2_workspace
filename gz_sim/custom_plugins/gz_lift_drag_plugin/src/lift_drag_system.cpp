// Copyright 2024 The Technology Innovation Institute (TII)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/**
 * @author Damien SIX (damien@robotsix.net)
 */

#include "lift_drag_system.hpp"

#include "gz/math/Vector3.hh"
#include "gz/sim/Link.hh"
#include "gz/sim/Model.hh"
#include "gz/sim/components/CanonicalLink.hh"

using namespace lift_drag_system;
using namespace gz::sim;

class lift_drag_system::LiftDragSystemPrivate {
public:
  Model model{kNullEntity};
  Link canonicalLink{kNullEntity};
  double liftCoefficient{0.0};
  double dragCoefficient{0.0};
  double groundVelocity{0.0};
  gz::math::v7::Vector3d worldVel{0, 0, 0};
};

LiftDragSystem::~LiftDragSystem() = default;

LiftDragSystem::LiftDragSystem()
    : dataPtr(std::make_unique<LiftDragSystemPrivate>()) {}

void LiftDragSystem::Configure(
    const gz::sim::Entity &_entity,
    const std::shared_ptr<const sdf::Element> &_sdf,
    gz::sim::EntityComponentManager &_ecm, gz::sim::EventManager &_eventMgr) {
  this->dataPtr->model = Model(_entity);

  if (!this->dataPtr->model.Valid(_ecm)) {
    gzerr << "LiftDragSystem plugin should be attached to a model entity. "
          << "Failed to initialize." << std::endl;
    return;
  }

  // Get the canonical link
  std::vector<Entity> links = _ecm.ChildrenByComponents(
      this->dataPtr->model.Entity(), components::CanonicalLink());
  if (!links.empty())
    this->dataPtr->canonicalLink = Link(links[0]);
  this->dataPtr->canonicalLink.EnableVelocityChecks(_ecm, true);

  // Get the lift coefficient
  if (_sdf->HasElement("liftCoefficient"))
    this->dataPtr->liftCoefficient = _sdf->Get<double>("liftCoefficient");
  else
    gzerr << "Lift coefficient not specified. Defaulting to 0.0" << std::endl;

  // Get the drag coefficient
  if (_sdf->HasElement("dragCoefficient"))
    this->dataPtr->dragCoefficient = _sdf->Get<double>("dragCoefficient");
  else
    gzerr << "Drag coefficient not specified. Defaulting to 0.0" << std::endl;
}

void LiftDragSystem::PreUpdate(const gz::sim::UpdateInfo &_info,
                                 gz::sim::EntityComponentManager &_ecm) {
  // Apply the drag force on the link based on the drag coefficient
  // Drag force is in the opposite direction of the velocity (assuming no world wind)
  auto dragForce =
      -dataPtr->worldVel * dataPtr->dragCoefficient * dataPtr->worldVel.Length();
  this->dataPtr->canonicalLink.AddWorldForce(_ecm, dragForce, {0, 0, 0});
  // Lift force is perpendicular to the velocity
  auto cross_vector = -dataPtr->worldVel.Normalized().Cross({0, 0, 1});
  auto liftForce = dataPtr->worldVel.Cross(cross_vector) *
                   dataPtr->liftCoefficient *
                   dataPtr->worldVel.Length();
  this->dataPtr->canonicalLink.AddWorldForce(_ecm, liftForce, {0, 0, 0});
}

void LiftDragSystem::PostUpdate(const gz::sim::UpdateInfo &_info,
                                  const gz::sim::EntityComponentManager &_ecm) {
  // Collect ground speed of the link
  std::optional<gz::math::v7::Vector3d> worldVel =
      this->dataPtr->canonicalLink.WorldLinearVelocity(_ecm);
  if (!worldVel.has_value()) {
    gzerr << "Failed to get velocity of the link." << std::endl;
    gzerr << "Link name: " << this->dataPtr->canonicalLink.Name(_ecm).value()
          << std::endl;
    return;
  }
  dataPtr->worldVel = worldVel.value();
  dataPtr->groundVelocity =
      std::pow(worldVel->X(), 2) + std::pow(worldVel->Y(), 2);
}

GZ_ADD_PLUGIN(lift_drag_system::LiftDragSystem, gz::sim::System,
              lift_drag_system::LiftDragSystem::ISystemConfigure,
              lift_drag_system::LiftDragSystem::ISystemPreUpdate,
              lift_drag_system::LiftDragSystem::ISystemPostUpdate)