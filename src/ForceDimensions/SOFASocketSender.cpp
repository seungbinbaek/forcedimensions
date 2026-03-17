// SOFASocketSender.cpp

#include "SOFASocketSender.h"

#include <sofa/core/ObjectFactory.h>
#include <sofa/simulation/AnimateEndEvent.h>

#pragma comment(lib, "ws2_32.lib")

namespace sofa::component
{

// ── 등록 ─────────────────────────────────────────────────────
int SOFASocketSenderClass = sofa::core::RegisterObject(
    "TCP socket sender: liver mesh vertices → Unreal Engine 5")
    .add<SOFASocketSender>();

// ─────────────────────────────────────────────────────────────
// 패킷 타입
static constexpr uint8_t PKT_INIT   = 0x01;
static constexpr uint8_t PKT_UPDATE = 0x02;

// ─────────────────────────────────────────────────────────────

SOFASocketSender::SOFASocketSender()
    : d_host   (initData(&d_host,    std::string("127.0.0.1"), "host",    "UE5 호스트 주소"))
    , d_port   (initData(&d_port,    7777,                     "port",    "UE5 TCP 포트"))
    , d_enabled(initData(&d_enabled, true,                     "enabled", "송신 활성화"))
    , l_mstate (initLink("mstate",   "간 MechanicalObject 링크"))
    , l_topology(initLink("topology","간 Topology 링크"))
{
}

SOFASocketSender::~SOFASocketSender()
{
    disconnect();
    if (m_wsaOk) WSACleanup();
}

void SOFASocketSender::init()
{
    sofa::core::objectmodel::BaseObject::init();
    this->f_listening.setValue(true); // AnimateEndEvent 수신 활성화

    // Winsock 초기화
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) == 0)
        m_wsaOk = true;
    else
        msg_error() << "WSAStartup 실패";
}

void SOFASocketSender::cleanup()
{
    disconnect();
    sofa::core::objectmodel::BaseObject::cleanup();
}

// ── 이벤트 핸들러 ─────────────────────────────────────────────
void SOFASocketSender::handleEvent(core::objectmodel::Event* event)
{
    if (!dynamic_cast<sofa::simulation::AnimateEndEvent*>(event)) return;
    if (!d_enabled.getValue()) return;

    // 연결 시도
    if (m_socket == INVALID_SOCKET)
    {
        connectToUE();
        return; // 이번 프레임은 연결만
    }

    // 위상 전송 (최초 1회)
    if (!m_topologySent)
    {
        if (l_mstate && l_topology)
            sendTopologyPacket();
    }
    else
    {
        if (l_mstate)
            sendUpdatePacket();
    }
}

// ── TCP 연결 ──────────────────────────────────────────────────
bool SOFASocketSender::connectToUE()
{
    m_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (m_socket == INVALID_SOCKET) return false;

    sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons((u_short)d_port.getValue());
    inet_pton(AF_INET, d_host.getValue().c_str(), &addr.sin_addr);

    if (connect(m_socket, (sockaddr*)&addr, sizeof(addr)) != 0)
    {
        closesocket(m_socket);
        m_socket = INVALID_SOCKET;
        // 조용히 재시도 (매 프레임 로그 없음)
        return false;
    }

    msg_info() << "UE5 연결 성공 (" << d_host.getValue() << ":" << d_port.getValue() << ")";
    m_topologySent = false;
    m_frameId      = 0;
    return true;
}

void SOFASocketSender::disconnect()
{
    if (m_socket != INVALID_SOCKET)
    {
        closesocket(m_socket);
        m_socket = INVALID_SOCKET;
    }
    m_topologySent = false;
}

// ── 전송 유틸 ─────────────────────────────────────────────────
bool SOFASocketSender::sendAll(const char* data, int size)
{
    int sent = 0;
    while (sent < size)
    {
        int n = send(m_socket, data + sent, size - sent, 0);
        if (n == SOCKET_ERROR || n == 0)
        {
            disconnect();
            return false;
        }
        sent += n;
    }
    return true;
}

// ── INIT 패킷 전송 ────────────────────────────────────────────
//  [PKT_INIT:1][frameId:4][numVerts:4][numTris:4]
//  [float32*3*N: positions] [uint32*3*T: triangle indices]
void SOFASocketSender::sendTopologyPacket()
{
    const auto& pos   = l_mstate ->read(core::ConstVecCoordId::state<sofa::core::CoordState::POSITION>())->getValue();
    const auto& tris  = l_topology->getTriangles();

    uint32_t nv = (uint32_t)pos.size();
    uint32_t nt = (uint32_t)tris.size();

    if (nv == 0 || nt == 0)
    {
        msg_warning() << "위상 데이터 없음 (verts=" << nv << " tris=" << nt << ")";
        return;
    }

    // 버퍼 구성
    size_t totalSize = 1 + 4 + 4 + 4 + nv * 12 + nt * 12;
    std::vector<char> buf(totalSize);
    char* p = buf.data();

    uint8_t  type = PKT_INIT;
    uint32_t fid  = m_frameId++;

    memcpy(p, &type, 1); p += 1;
    memcpy(p, &fid,  4); p += 4;
    memcpy(p, &nv,   4); p += 4;
    memcpy(p, &nt,   4); p += 4;

    for (uint32_t i = 0; i < nv; ++i)
    {
        float x = (float)pos[i][0];
        float y = (float)pos[i][1];
        float z = (float)pos[i][2];
        memcpy(p, &x, 4); p += 4;
        memcpy(p, &y, 4); p += 4;
        memcpy(p, &z, 4); p += 4;
    }

    for (uint32_t i = 0; i < nt; ++i)
    {
        uint32_t i0 = tris[i][0];
        uint32_t i1 = tris[i][1];
        uint32_t i2 = tris[i][2];
        memcpy(p, &i0, 4); p += 4;
        memcpy(p, &i1, 4); p += 4;
        memcpy(p, &i2, 4); p += 4;
    }

    std::lock_guard<std::mutex> lock(m_sendMtx);
    if (sendAll(buf.data(), (int)totalSize))
    {
        m_topologySent = true;
        msg_info() << "INIT 전송 완료 (verts=" << nv << " tris=" << nt << ")";
    }
}

// ── UPDATE 패킷 전송 ──────────────────────────────────────────
//  [PKT_UPDATE:1][frameId:4][numVerts:4]
//  [float32*3*N: positions]
void SOFASocketSender::sendUpdatePacket()
{
    const auto& pos = l_mstate->read(core::ConstVecCoordId::state<sofa::core::CoordState::POSITION>())->getValue();
    uint32_t nv = (uint32_t)pos.size();

    size_t totalSize = 1 + 4 + 4 + nv * 12;
    std::vector<char> buf(totalSize);
    char* p = buf.data();

    uint8_t  type = PKT_UPDATE;
    uint32_t fid  = m_frameId++;

    memcpy(p, &type, 1); p += 1;
    memcpy(p, &fid,  4); p += 4;
    memcpy(p, &nv,   4); p += 4;

    for (uint32_t i = 0; i < nv; ++i)
    {
        float x = (float)pos[i][0];
        float y = (float)pos[i][1];
        float z = (float)pos[i][2];
        memcpy(p, &x, 4); p += 4;
        memcpy(p, &y, 4); p += 4;
        memcpy(p, &z, 4); p += 4;
    }

    std::lock_guard<std::mutex> lock(m_sendMtx);
    sendAll(buf.data(), (int)totalSize);
}

} // namespace sofa::component
