// Copyright 2026 Shonn Li. MIT license.
// Native HarmonyOS surface decoder. USB data uses HDC rport, never ADB.
#include "wire.h"
#include <napi/native_api.h>
#include <native_window/external_window.h>
#include <multimedia/player_framework/native_avcodec_videodecoder.h>
#include <multimedia/player_framework/native_avcodec_base.h>
#include <multimedia/player_framework/native_avformat.h>
#include <multimedia/player_framework/native_avbuffer.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <cmath>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

namespace {
struct Slot { uint32_t index; OH_AVBuffer* buffer; };
class Receiver {
public:
    ~Receiver() { stop(); }
    bool start(uint64_t surface, uint16_t port) {
        stop();
        if (OH_NativeWindow_CreateNativeWindowFromSurfaceId(surface, &window_) != 0 || !window_) {
            setStatus("Cannot open display surface"); return false;
        }
        // Fit the complete desktop without distorting it when panel and stream ratios differ.
        OH_NativeWindow_NativeWindowSetScalingModeV2(window_, OH_SCALING_MODE_SCALE_FIT_V2);
        stopped_ = false; displayed_ = 0;
        worker_ = std::thread([this, port] { run(port); });
        return true;
    }
    void stop() {
        stopped_ = true;
        { std::lock_guard<std::mutex> lock(socketMutex_); if (fd_ >= 0) shutdown(fd_, SHUT_RDWR); }
        cv_.notify_all();
        if (worker_.joinable()) worker_.join();
        if (window_) { OH_NativeWindow_DestroyNativeWindow(window_); window_ = nullptr; }
        setStatus("Disconnected");
    }
    std::string status() { std::lock_guard<std::mutex> l(statusMutex_); return status_; }
    uint64_t frames() const { return displayed_; }
    bool running() const { return !stopped_; }
    int orientation() const { return orientation_; }
    void viewport(uint32_t w, uint32_t h, double dpiX, double dpiY) {
        if (w < 320 || h < 320 || w > 8192 || h > 8192 || uint64_t(w)*h > 32*1024*1024) return;
        auto dpi = [](double v) -> uint32_t { return std::isfinite(v) && v >= 50 && v <= 1000 ? uint32_t(std::round(v*10)) : 0; };
        uint32_t values[4] = {w,h,dpi(dpiX),dpi(dpiY)};
        std::lock_guard<std::mutex> l(socketMutex_);
        uint8_t packet[9] = {14};
        for (int i=0;i<4;++i) { packet[1+i*2] = 0x80 | (values[i] >> 7); packet[2+i*2] = 0x80 | (values[i] & 0x7f); }
        if (memcmp(viewport_,packet,9) == 0) return;
        memcpy(viewport_,packet,9);
        if (connected_) sendViewportLocked();
    }
    void touch(float x, float y, int32_t action) {
        if (stopped_ || x < 0 || x > 1 || y < 0 || y > 1 || action < 0 || action > 2) return;
        uint8_t packet[14] = {2,1}; // Wire touch payload is little endian on both supported hosts.
        memcpy(packet+2,&x,4); memcpy(packet+6,&y,4); memcpy(packet+10,&action,4);
        std::lock_guard<std::mutex> l(socketMutex_);
        if (fd_ >= 0) send(fd_,packet,sizeof(packet),MSG_NOSIGNAL);
    }
private:
    std::atomic<bool> stopped_{true};
    std::atomic<uint64_t> displayed_{0};
    std::atomic<int> decoderError_{0};
    std::thread worker_;
    std::mutex socketMutex_, statusMutex_, queueMutex_;
    std::condition_variable cv_;
    int fd_ = -1;
    bool connected_ = false; // guarded by socketMutex_
    uint8_t viewport_[9]{};
    std::atomic<int> orientation_{-1};
    void sendViewportLocked() {
        if (viewport_[0] != 14) return;
        size_t offset = 0;
        while (offset < sizeof(viewport_)) {
            auto n = send(fd_,viewport_+offset,sizeof(viewport_)-offset,MSG_NOSIGNAL);
            if (n <= 0) { shutdown(fd_,SHUT_RDWR); return; }
            offset += size_t(n);
        }
    }
    std::string status_ = "Ready";
    OHNativeWindow* window_ = nullptr;
    OH_AVCodec* decoder_ = nullptr;
    std::deque<Slot> slots_;
    uint32_t width_ = 0, height_ = 0;
    void setStatus(const std::string& value) { std::lock_guard<std::mutex> l(statusMutex_); status_ = value; }
    void read(void* dst, size_t size) {
        auto p = static_cast<uint8_t*>(dst);
        while (size && !stopped_) {
            auto n = recv(fd_,p,size,0);
            if (n <= 0) throw std::runtime_error("USB stream ended. Check Mac server and HDC connection.");
            p += n; size -= size_t(n);
        }
        if (size) throw std::runtime_error("Disconnected");
    }
    static void error(OH_AVCodec*, int32_t code, void* user) {
        auto self = static_cast<Receiver*>(user);
        self->decoderError_ = code; self->cv_.notify_all();
    }
    static void changed(OH_AVCodec*, OH_AVFormat*, void*) {}
    static void input(OH_AVCodec*, uint32_t index, OH_AVBuffer* b, void* user) {
        auto self = static_cast<Receiver*>(user);
        { std::lock_guard<std::mutex> l(self->queueMutex_); self->slots_.push_back({index,b}); }
        self->cv_.notify_one();
    }
    static void output(OH_AVCodec* c, uint32_t index, OH_AVBuffer*, void* user) {
        auto self = static_cast<Receiver*>(user);
        if (self->stopped_) { OH_VideoDecoder_FreeOutputBuffer(c,index); return; }
        if (OH_VideoDecoder_RenderOutputBuffer(c,index) == AV_ERR_OK) {
            ++self->displayed_;
            self->setStatus("Streaming over HDC USB");
        }
    }
    void releaseDecoder() {
        if (decoder_) { OH_VideoDecoder_Destroy(decoder_); decoder_ = nullptr; }
        // Destroy waits for callbacks; old slots must never reach the next decoder.
        std::lock_guard<std::mutex> l(queueMutex_); slots_.clear();
    }
    void configure(uint32_t w, uint32_t h) {
        if (decoder_ && w == width_ && h == height_) return;
        releaseDecoder(); width_ = w; height_ = h; decoderError_ = 0;
        decoder_ = OH_VideoDecoder_CreateByMime(OH_AVCODEC_MIMETYPE_VIDEO_HEVC);
        if (!decoder_) throw std::runtime_error("This device cannot create an HEVC decoder");
        OH_AVCodecCallback cb{error, changed, input, output};
        if (OH_VideoDecoder_RegisterCallback(decoder_,cb,this) != AV_ERR_OK)
            throw std::runtime_error("Decoder callback setup failed");
        OH_AVFormat* format = OH_AVFormat_Create();
        if (!format) throw std::runtime_error("Decoder format allocation failed");
        OH_AVFormat_SetIntValue(format,OH_MD_KEY_WIDTH,int32_t(w));
        OH_AVFormat_SetIntValue(format,OH_MD_KEY_HEIGHT,int32_t(h));
        OH_AVFormat_SetIntValue(format,OH_MD_KEY_VIDEO_ENABLE_LOW_LATENCY,1);
        auto configured = OH_VideoDecoder_Configure(decoder_,format);
        OH_AVFormat_Destroy(format);
        if (configured != AV_ERR_OK || OH_VideoDecoder_SetSurface(decoder_,window_) != AV_ERR_OK ||
            OH_VideoDecoder_Prepare(decoder_) != AV_ERR_OK || OH_VideoDecoder_Start(decoder_) != AV_ERR_OK)
            throw std::runtime_error("Decoder setup failed; try 1920 x 1200 at 30 FPS on the Mac");
        setStatus("Connected; waiting for first decoded frame");
    }
    void decode(const std::vector<uint8_t>& frame) {
        if (!decoder_) throw std::runtime_error("Video arrived before display configuration");
        std::unique_lock<std::mutex> l(queueMutex_);
        bool ready = cv_.wait_for(l,std::chrono::seconds(2),[this] { return stopped_ || decoderError_ || !slots_.empty(); });
        if (!ready || decoderError_) throw std::runtime_error("Video decoder stalled or rejected the stream");
        if (stopped_) throw std::runtime_error("Disconnected");
        Slot s = slots_.front(); slots_.pop_front(); l.unlock();
        auto capacity = OH_AVBuffer_GetCapacity(s.buffer);
        auto address = OH_AVBuffer_GetAddr(s.buffer);
        if (!address || capacity < 0 || frame.size() > size_t(capacity))
            throw std::runtime_error("Encoded frame exceeds decoder buffer capacity");
        memcpy(address,frame.data(),frame.size());
        OH_AVCodecBufferAttr attr{};
        attr.pts = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
        attr.size = int32_t(frame.size()); attr.offset = 0; attr.flags = AVCODEC_BUFFER_FLAGS_NONE;
        if (OH_AVBuffer_SetBufferAttr(s.buffer,&attr) != AV_ERR_OK || OH_VideoDecoder_PushInputBuffer(decoder_,s.index) != AV_ERR_OK)
            throw std::runtime_error("Decoder rejected a video frame");
    }
    void run(uint16_t port) {
        try {
            setStatus("Connecting to Mac through HDC…");
            { std::lock_guard<std::mutex> l(socketMutex_); fd_ = socket(AF_INET,SOCK_STREAM,0); }
            if (fd_ < 0) throw std::runtime_error("Could not create stream socket");
            timeval timeout{5,0};
            setsockopt(fd_,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
            setsockopt(fd_,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
            int one = 1; setsockopt(fd_,IPPROTO_TCP,TCP_NODELAY,&one,sizeof(one));
            sockaddr_in address{}; address.sin_family = AF_INET; address.sin_port = htons(port);
            address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
            if (connect(fd_,reinterpret_cast<sockaddr*>(&address),sizeof(address)) != 0)
                throw std::runtime_error("Mac unreachable. Start HarmonyScreen and verify its HDC tunnel is ready.");
            { std::lock_guard<std::mutex> l(socketMutex_); connected_ = true; sendViewportLocked(); }
            // Keep the first preview on the upstream legacy video framing (HEVC).
            while (!stopped_) {
                uint8_t type; read(&type,1);
                if (type == 1) {
                    uint8_t data[12]; read(data,sizeof(data));
                    auto w = harmony::be32(data), h = harmony::be32(data+4);
                    harmony::validateDisplay(w,h,harmony::be32(data+8)); configure(w,h);
                } else if (type == 0 || type == 6) {
                    uint8_t header[4]; read(header,4); auto size = harmony::frameLength(header);
                    if (type == 6) { uint8_t metadata[9]; read(metadata,9); }
                    std::vector<uint8_t> frame(size); read(frame.data(),frame.size()); decode(frame);
                } else if (type == 5 || type == 13) {
                    uint8_t data[8]; read(data,8);
                } else if (type == 15) {
                    uint8_t value; read(&value,1);
                    if (value > 2) throw std::runtime_error("Invalid phone orientation");
                    orientation_ = value;
                } else if (type == 10) {
                    uint8_t codec; read(&codec,1);
                    if (codec != 0) throw std::runtime_error("This preview requires HEVC");
                } else throw std::runtime_error("Unsupported stream protocol message");
            }
        } catch (const std::exception& e) { setStatus(e.what()); }
        stopped_ = true; cv_.notify_all(); releaseDecoder();
        { std::lock_guard<std::mutex> l(socketMutex_); if (fd_ >= 0) close(fd_); fd_ = -1; connected_ = false; }
    }
};
Receiver receiver;
napi_value Start(napi_env env,napi_callback_info info) {
    size_t count = 2; napi_value args[2]; napi_get_cb_info(env,info,&count,args,nullptr,nullptr);
    bool result = false;
    if (count == 2) {
        char id[32]{}; size_t length = 0; uint32_t port = 0;
        if (napi_get_value_string_utf8(env,args[0],id,sizeof(id),&length) == napi_ok &&
            napi_get_value_uint32(env,args[1],&port) == napi_ok && port >= 1024 && port <= 65535) {
            try { result = receiver.start(std::stoull(id),uint16_t(port)); } catch (...) { result = false; }
        }
    }
    napi_value value; napi_get_boolean(env,result,&value); return value;
}
napi_value Stop(napi_env env,napi_callback_info) { receiver.stop(); napi_value v; napi_get_undefined(env,&v); return v; }
napi_value Status(napi_env env,napi_callback_info) { napi_value v; auto s = receiver.status(); napi_create_string_utf8(env,s.c_str(),s.size(),&v); return v; }
napi_value Frames(napi_env env,napi_callback_info) { napi_value v; napi_create_double(env,double(receiver.frames()),&v); return v; }
napi_value Running(napi_env env,napi_callback_info) { napi_value v; napi_get_boolean(env,receiver.running(),&v); return v; }
napi_value Orientation(napi_env env,napi_callback_info) { napi_value v; napi_create_int32(env,receiver.orientation(),&v); return v; }
napi_value Viewport(napi_env env,napi_callback_info info) {
    size_t count=4; napi_value args[4]; napi_get_cb_info(env,info,&count,args,nullptr,nullptr);
    uint32_t w=0,h=0; double x=0,y=0;
    if (count==4 && napi_get_value_uint32(env,args[0],&w)==napi_ok && napi_get_value_uint32(env,args[1],&h)==napi_ok &&
        napi_get_value_double(env,args[2],&x)==napi_ok && napi_get_value_double(env,args[3],&y)==napi_ok) receiver.viewport(w,h,x,y);
    napi_value v; napi_get_undefined(env,&v); return v;
}
napi_value Touch(napi_env env,napi_callback_info info) {
    size_t count=3; napi_value args[3]; napi_get_cb_info(env,info,&count,args,nullptr,nullptr);
    double x=0,y=0; int32_t action=0;
    if (count==3 && napi_get_value_double(env,args[0],&x)==napi_ok && napi_get_value_double(env,args[1],&y)==napi_ok && napi_get_value_int32(env,args[2],&action)==napi_ok)
        receiver.touch(float(x),float(y),action);
    napi_value v; napi_get_undefined(env,&v); return v;
}
napi_value Init(napi_env env,napi_value exports) {
    napi_property_descriptor methods[] = {
        {"start",nullptr,Start,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"stop",nullptr,Stop,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"status",nullptr,Status,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"frames",nullptr,Frames,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"running",nullptr,Running,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"viewport",nullptr,Viewport,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"orientation",nullptr,Orientation,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"touch",nullptr,Touch,nullptr,nullptr,nullptr,napi_default,nullptr}};
    napi_define_properties(env,exports,8,methods); return exports;
}
napi_module module = {1,0,nullptr,Init,"harmonyscreen",nullptr,{0}};
}
extern "C" __attribute__((constructor)) void RegisterHarmonyScreen() { napi_module_register(&module); }
