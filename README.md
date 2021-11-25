# The SOFA ForceDimensions plugin

This plugin provides classes to use ForceDimensions haptic interfaces in SOFA.

## Installation

0. Download ForceDimensions SDK from http://forcedimension.com/software/sdk and uncompress it
1. When configuring SOFA with `cmake`, add the path to the plugin to the `SOFA_EXTERNAL_DIRECTORIES` variable and configure
2. Change the `FORCEDIMENSIONS_SDK_PATH` to point the downloaded SDK and re-configure, then generate
3. Build SOFA 

## Usage

You can use you ForceDimensions device in the simulation by creating an OmegaDriver device:

1. Add `ForceDimensions` plugin to the list of required plugins
2. Create an instance of the `OmegaDriver` object and set the properties

Please refer to the sample scene to learn more.

## OmegaDriver

Omega driver is the class inhereted from the SOFA Controller class and contains following properties:

`pose` : pose of the end-effector
`gripperState` : state of the gripper DOF
`baseFrame` : pose fo the base frame of the device
`forceFeedback` : rendered force
`scale` : scale of the device in the simulated space
`forceScale` : scale of force feedback
`maxForce` : maximal force allowed for rendering
`gammaOffset` : wrist gamma angle offset; this property can be used to define the initial position of the wrist when holding the device
`enableForceFeedback` : enable/disable force feedback; when disabled and `computeForceFeedback` is enabled, FF is calculated, but not rendered
`computeForceFeedback` : enable/disable force fedback computation
