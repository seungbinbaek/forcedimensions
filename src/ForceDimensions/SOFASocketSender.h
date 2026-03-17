// SOFASocketSender.h
// SOFA AnimateEndEvent마다 간 메쉬 vertex 데이터를 TCP로 UE5에 전송

#pragma once

#include <sofa/core/objectmodel/BaseObject.h>
#include <sofa/core/objectmodel/Data.h>
#include <sofa/core/objectmodel/Link.h>
#include <sofa/core/behavior/MechanicalState.h>
#include <sofa/defaulttype/VecTypes.h>
#include <sofa/core/topology/BaseMeshTopology.h>

#include <atomic>
#include <mutex>
#include <vector>

// Windows 소켓
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>

namespace sofa::component
{

class SOFASocketSender : public core::objectmodel::BaseObject
{
public:
    SOFA_CLASS(SOFASocketSender, core::objectmodel::BaseObject);

    using MState   = core::behavior::MechanicalState<defaulttype::Vec3Types>;
    using BaseTopo = core::topology::BaseMeshTopology;

    // ── 파라미터 ─────────────────────────────────────
    Data<std::string> d_host;   ///< UE5 호스트 (기본 "127.0.0.1")
    Data<int>         d_port;   ///< UE5 포트 (기본 7777)
    Data<bool>        d_enabled;

    // ── 링크 ─────────────────────────────────────────
    SingleLink<SOFASocketSender, MState,
        BaseLink::FLAG_STOREPATH | BaseLink::FLAG_STRONGLINK> l_mstate;

    SingleLink<SOFASocketSender, BaseTopo,
        BaseLink::FLAG_STOREPATH | BaseLink::FLAG_STRONGLINK> l_topology;

    SOFASocketSender();
    ~SOFASocketSender() override;

    void init()    override;
    void cleanup() override;
    void handleEvent(core::objectmodel::Event* event) override;

private:
    bool connectToUE();
    void disconnect();
    bool sendAll(const char* data, int size);

    void sendTopologyPacket();
    void sendUpdatePacket();

    SOCKET   m_socket        = INVALID_SOCKET;
    bool     m_wsaOk         = false;
    bool     m_topologySent  = false;
    uint32_t m_frameId       = 0;

    std::mutex m_sendMtx;
};

} // namespace sofa::component
