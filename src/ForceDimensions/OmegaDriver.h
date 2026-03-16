#pragma once

#include "initForceDimensions.h"

#include <sofa/component/controller/Controller.h>
#include <sofa/component/haptics/ForceFeedback.h>

#include <mutex>
#include <sofa/simulation/Simulation.h>


/**
 * Omega driver
 */
class SOFA_FORCEDIMENSIONS_API OmegaDriver : public sofa::component::controller::Controller
{
 public:
  SOFA_CLASS(OmegaDriver, Controller);
  OmegaDriver();
  virtual ~OmegaDriver();

  virtual void init() override;
  virtual void bwdInit() override;
  virtual void reinit() override;

  sofa::core::objectmodel::Data<sofa::defaulttype::RigidTypes::Coord> d_pose;
  sofa::core::objectmodel::Data<SReal> d_gripperState;
  sofa::core::objectmodel::Data<sofa::defaulttype::RigidTypes::Coord> d_baseFrame;
  sofa::core::objectmodel::Data<sofa::defaulttype::RigidTypes::Deriv> d_forceFeedback;
  sofa::core::objectmodel::Data<SReal> d_scale;
  sofa::core::objectmodel::Data<SReal> d_forceScale;
  sofa::core::objectmodel::Data<SReal> d_maxForce;
  sofa::core::objectmodel::Data<SReal> d_gammaOffset;
  sofa::core::objectmodel::Data<bool> d_enableForceFeedback;
  sofa::core::objectmodel::Data<bool> d_computeForceFeedback;

 private:
  void initDevice();
  void updateDevicePose();
  void updatePose();
  virtual void onBeginAnimationStep(const double) override;

  static void * updateForceFeedback(void *args);

  bool active;
  bool deviceInitialized;
  bool deviceRunning;
  int error;
  sofa::defaulttype::RigidTypes::Coord devicePose;
  std::mutex devicePoseMutex;

  sofa::component::haptics::ForceFeedback::SPtr forceFeedback;
};
