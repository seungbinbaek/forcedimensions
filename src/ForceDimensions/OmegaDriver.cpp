#include "OmegaDriver.h"
#include <drdc.h>
#include <sofa/simulation/AnimateBeginEvent.h>
#include <sofa/simulation/events/SimulationStartEvent.h>
#include <sofa/core/ObjectFactory.h>
#include <sofa/simulation/Node.h>

using sofa::simulation::Node;
using sofa::simulation::AnimateBeginEvent;
using sofa::simulation::SimulationStartEvent;

using sofa::core::objectmodel::BaseContext;
using sofa::core::objectmodel::Event;

using sofa::type::Vec3;
using Quat = sofa::type::Quat<SReal>;
typedef sofa::defaulttype::RigidTypes::Coord Coord;
typedef sofa::defaulttype::RigidTypes::Deriv Deriv;

using sofa::component::haptics::ForceFeedback;

void * OmegaDriver::updateForceFeedback(void *args) {
    OmegaDriver *driver = reinterpret_cast<OmegaDriver*>(args);

    for (;;) {
        if (!driver->active)
            continue;

        driver->updateDevicePose();

        Vec3 fdev(0, 0, 0);

        if (driver->d_computeForceFeedback.getValue() && driver->forceFeedback) {
            double fx, fy, fz;
            auto pos = driver->devicePose.getCenter();

            // maybe compute wrench instead?
            driver->forceFeedback->computeForce(pos[0], pos[1], pos[2],
                                                0, 0, 0, 0,
                                                fx, fy, fz);

            fdev = driver->d_baseFrame.getValue().unprojectVector(Vec3(fx, fy, fz));

            // Apply forceScale
            SReal forceScale = driver->d_forceScale.getValue();
            if (forceScale > 0)
                fdev *= forceScale;

            driver->d_forceFeedback.setValue(Deriv(fdev, Vec3()));
        }

        // Always send force when enabled:
        // - In free space: sends (0,0,0) so SDK gravity compensation runs cleanly
        // - In contact: sends computed contact force
        if (driver->d_enableForceFeedback.getValue()) {
            dhdSetForce(fdev[2], fdev[0], fdev[1]);
        }
    }

    return nullptr;
}

OmegaDriver::OmegaDriver() :
  d_pose(initData(&d_pose, "pose", "Pose of the end-effector")),
  d_gripperState(initData(&d_gripperState, "gripperState", "State of the gripper")),
  d_baseFrame(initData(&d_baseFrame, "baseFrame", "Pose of the base frame of the device")),
  d_forceFeedback(initData(&d_forceFeedback, "forceFeedback", "Rendered force")),
  d_scale(initData(&d_scale, "scale", "Scale of the device in the simulation world")),
  d_forceScale(initData(&d_forceScale, "forceScale", "Force feedback scale")),
  d_maxForce(initData(&d_maxForce, "maxForce", "Maximum rendered force")),
  d_gammaOffset(initData(&d_gammaOffset, "gammaOffset", "Wrist gamma angle offset")),
  d_enableForceFeedback(initData(&d_enableForceFeedback, "enableForceFeedback", "Enable force feedback")),
  d_computeForceFeedback(initData(&d_computeForceFeedback, "computeForceFeedback", "Enable force feedback computation")),
  d_autoInit(initData(&d_autoInit, false, "autoInit", "Use DRD auto-initialization for smooth free movement")),
  active(false),
  deviceInitialized(false),
  deviceRunning(false),
  error(0),
  forceFeedback(nullptr)
{
  f_listening.setValue(true);
  d_gammaOffset.setValue(1.15);
  d_forceScale.setValue(1.0);
  d_computeForceFeedback.setValue(true);
  d_enableForceFeedback.setValue(true);
}

OmegaDriver::~OmegaDriver()
{
    drdClose();
}

void OmegaDriver::init()
{

}

void OmegaDriver::bwdInit()
{
    Node *context = dynamic_cast<Node *>(this->getContext()); // access to current node
    forceFeedback = context->get<ForceFeedback>(this->getTags(), BaseContext::SearchRoot);
    // Device initialization is deferred to the first animation step (Play button click)
}

void OmegaDriver::reinit()
{
    active = false;
    // Note: deviceInitialized is intentionally NOT reset here because reinit()
    // is called from within initDevice() after a successful init.
    // deviceInitialized is only reset externally (e.g. simulation restart) via resetDevice().
}

void OmegaDriver::initDevice()
{
    bool opened = false;

    auto handleError = [&]() {
        if (opened)
            drdClose();   // ensure device is released so next attempt can open it
        error = dhdErrorGetLast();
        throw std::runtime_error(dhdErrorGetLastStr());
    };

    // get device count
    if (dhdGetDeviceCount() <= 0)
        handleError();

    // open the first available device (via DRD — DHD functions remain available)
    if (drdOpen() < 0)
        handleError();
    opened = true;

    // Optionally run DRD auto-initialization for smooth free movement
    if (d_autoInit.getValue()) {
        if (!drdIsSupported()) {
            msg_warning() << "Device does not support DRD auto-initialization";
        } else {
            if (drdAutoInit() < 0)
                handleError();
            // drdCheckInit validates calibration quality; treat failure as warning
            // so a slightly imperfect autoInit does not abort initialization
            if (drdCheckInit() < 0)
                msg_warning() << "DRD calibration check failed — proceeding anyway: "
                              << dhdErrorGetLastStr();
            // Stop regulation thread but keep forces enabled → smooth free movement
            if (drdStop(true) < 0)
                handleError();
        }
    }

    if (dhdSetGravityCompensation(DHD_ON) < 0)
        handleError();

    if (dhdEnableForce(DHD_ON) < 0)
        handleError();

    // Explicitly release electromagnetic brakes to allow smooth free movement
    if (dhdSetBrakes(DHD_OFF) < 0)
        handleError();

    // Set SDK-level max force limit if configured (hardware-level clamping)
    SReal maxF = d_maxForce.getValue();
    if (maxF > 0)
        dhdSetMaxForce(static_cast<double>(maxF));

    reinit();

    dhdSetForceAndTorqueAndGripperForce(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    dhdStartThread(updateForceFeedback, this, DHD_THREAD_PRIORITY_HIGH);

    deviceRunning = true;
    updatePose();
}

void OmegaDriver::updateDevicePose()
{
    // retrive the pose from the device
    double x, y, z;
    double oa, ob, og;

    dhdGetPositionAndOrientationRad(&x, &y, &z, &oa, &ob, &og);

    og -= d_gammaOffset.getValue();

    x *= d_scale.getValue();
    y *= d_scale.getValue();
    z *= d_scale.getValue();

    // update the pose data
    devicePoseMutex.lock();
    devicePose.getCenter() = Vec3(y, z, x);
    devicePose.getOrientation() = Quat::fromEuler(ob, og, oa, Quat::EulerOrder::XZY);
    devicePose = d_baseFrame.getValue().mult(devicePose);
    devicePoseMutex.unlock();
}

void OmegaDriver::updatePose()
{
    // update the pose data
    auto pose = d_pose.beginEdit();
    devicePoseMutex.lock();
    *pose = devicePose;
    devicePoseMutex.unlock();
    d_pose.endEdit();
}

void OmegaDriver::onBeginAnimationStep(const double)
{
    if (!deviceInitialized) {
        deviceInitialized = true;
        try {
            initDevice();
        } catch (std::runtime_error &e) {
            msg_warning() << "Failed to initialize the device: " << e.what();
        }
    }

    if (deviceRunning)
        updatePose();
}

int OmegaDriverClass = sofa::core::RegisterObject("ForceDimensions Omega haptic interface driver.")
.add< OmegaDriver >()
.addAlias("HapticDevice")
;
