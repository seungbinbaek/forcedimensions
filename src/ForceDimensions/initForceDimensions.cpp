#include "initForceDimensions.h"

extern "C" {
    SOFA_FORCEDIMENSIONS_API void initExternalModule()
    {
    }

    SOFA_FORCEDIMENSIONS_API const char* getModuleName()
    {
        return "ForceDimensions";
    }

    SOFA_FORCEDIMENSIONS_API const char* getModuleVersion()
    {
        return "0.1";
    }

    SOFA_FORCEDIMENSIONS_API const char* getModuleLicense()
    {
        return "LGPL";
    }

    SOFA_FORCEDIMENSIONS_API const char* getModuleDescription()
    {
        return "ForceDimensions haptic device drivers";
    }

    SOFA_FORCEDIMENSIONS_API const char* getModuleComponentList()
    {
        return "OmegaDriver";
    }
}