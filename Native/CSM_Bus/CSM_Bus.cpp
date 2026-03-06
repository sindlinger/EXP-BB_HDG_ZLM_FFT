#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cwchar>

namespace {

constexpr uint32_t BUS_MAGIC = 0x42534D43; // "CSMB"
constexpr uint32_t BUS_VERSION = 1;

constexpr int BUS_KEY_CHARS = 96;
constexpr int BUS_MODULE_CHARS = 32;
constexpr int BUS_SYMBOL_CHARS = 16;
constexpr int BUS_STEP_CHARS = 48;
constexpr int BUS_DETAIL_CHARS = 160;

constexpr int BUS_MAX_ENTRIES = 4096;
constexpr int BUS_MAX_REPORTS = 512;

struct BusEntry {
    wchar_t key[BUS_KEY_CHARS];
    double curr;
    double prev;
    int32_t valid;
    wchar_t writer[BUS_MODULE_CHARS];
    int64_t tick_seq;
    uint64_t updated_msc;
};

struct BusReport {
    wchar_t module_id[BUS_MODULE_CHARS];
    wchar_t step_id[BUS_STEP_CHARS];
    int32_t code;
    wchar_t detail[BUS_DETAIL_CHARS];
    int64_t tick_seq;
    uint64_t ts_msc;
};

struct BusShared {
    uint32_t magic;
    uint32_t version;
    int32_t phase;
    int32_t _pad0;

    int64_t tick_seq;
    int64_t bar_time;
    int32_t timeframe;
    int32_t _pad1;
    wchar_t symbol[BUS_SYMBOL_CHARS];

    int32_t entry_count;
    int32_t _pad2;
    BusEntry entries[BUS_MAX_ENTRIES];

    int32_t report_head;
    int32_t report_count;
    BusReport reports[BUS_MAX_REPORTS];
};

HANDLE g_map = nullptr;
HANDLE g_mutex = nullptr;
BusShared* g_shared = nullptr;

wchar_t g_map_name[128] = {0};
wchar_t g_mtx_name[128] = {0};

void CopyWs(wchar_t* dst, const size_t cap, const wchar_t* src) {
    if (dst == nullptr || cap == 0) {
        return;
    }
    if (src == nullptr) {
        dst[0] = L'\0';
        return;
    }
    wcsncpy_s(dst, cap, src, _TRUNCATE);
}

void BuildIpcNames(const wchar_t* session) {
    wchar_t clean[64] = {0};
    const wchar_t* src = (session != nullptr && session[0] != L'\0') ? session : L"CSM_DEFAULT";
    int k = 0;
    for (int i = 0; src[i] != L'\0' && k < 63; ++i) {
        const wchar_t ch = src[i];
        const bool ok =
            (ch >= L'0' && ch <= L'9') ||
            (ch >= L'a' && ch <= L'z') ||
            (ch >= L'A' && ch <= L'Z') ||
            ch == L'_' || ch == L'-';
        clean[k++] = (ok ? ch : L'_');
    }
    clean[k] = L'\0';

    swprintf_s(g_map_name, L"Local\\CSM_BUS_%s", clean);
    swprintf_s(g_mtx_name, L"Local\\CSM_BUS_MTX_%s", clean);
}

bool LockBus() {
    if (g_mutex == nullptr) {
        return false;
    }
    const DWORD w = WaitForSingleObject(g_mutex, 2000);
    return (w == WAIT_OBJECT_0 || w == WAIT_ABANDONED);
}

void UnlockBus() {
    if (g_mutex != nullptr) {
        ReleaseMutex(g_mutex);
    }
}

bool EnsureAttached() {
    return (g_shared != nullptr && g_map != nullptr && g_mutex != nullptr);
}

int FindEntry(const wchar_t* key) {
    if (key == nullptr || key[0] == L'\0') {
        return -1;
    }
    for (int i = 0; i < g_shared->entry_count; ++i) {
        if (wcscmp(g_shared->entries[i].key, key) == 0) {
            return i;
        }
    }
    return -1;
}

} // namespace

extern "C" __declspec(dllexport) int __stdcall CsmBus_Init(const wchar_t* session) {
    if (EnsureAttached()) {
        return 0;
    }

    BuildIpcNames(session);
    g_map = CreateFileMappingW(INVALID_HANDLE_VALUE,
                               nullptr,
                               PAGE_READWRITE,
                               0,
                               static_cast<DWORD>(sizeof(BusShared)),
                               g_map_name);
    if (g_map == nullptr) {
        return -10;
    }

    const bool already_exists = (GetLastError() == ERROR_ALREADY_EXISTS);
    g_shared = reinterpret_cast<BusShared*>(MapViewOfFile(g_map, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(BusShared)));
    if (g_shared == nullptr) {
        CloseHandle(g_map);
        g_map = nullptr;
        return -11;
    }

    g_mutex = CreateMutexW(nullptr, FALSE, g_mtx_name);
    if (g_mutex == nullptr) {
        UnmapViewOfFile(g_shared);
        g_shared = nullptr;
        CloseHandle(g_map);
        g_map = nullptr;
        return -12;
    }

    if (!already_exists || g_shared->magic != BUS_MAGIC || g_shared->version != BUS_VERSION) {
        ZeroMemory(g_shared, sizeof(BusShared));
        g_shared->magic = BUS_MAGIC;
        g_shared->version = BUS_VERSION;
        g_shared->phase = 0;
        g_shared->entry_count = 0;
        g_shared->report_head = 0;
        g_shared->report_count = 0;
    }

    return 0;
}

extern "C" __declspec(dllexport) int __stdcall CsmBus_Shutdown() {
    if (g_shared != nullptr) {
        UnmapViewOfFile(g_shared);
        g_shared = nullptr;
    }
    if (g_map != nullptr) {
        CloseHandle(g_map);
        g_map = nullptr;
    }
    if (g_mutex != nullptr) {
        CloseHandle(g_mutex);
        g_mutex = nullptr;
    }
    return 0;
}

extern "C" __declspec(dllexport) int __stdcall CsmBus_BeginTick(const int64_t tickSeq,
                                                                  const int64_t barTime,
                                                                  const wchar_t* symbol,
                                                                  const int32_t timeframe) {
    if (!EnsureAttached()) {
        return -100;
    }
    if (!LockBus()) {
        return -101;
    }

    g_shared->phase = 1;
    g_shared->tick_seq = tickSeq;
    g_shared->bar_time = barTime;
    g_shared->timeframe = timeframe;
    CopyWs(g_shared->symbol, BUS_SYMBOL_CHARS, symbol);

    g_shared->entry_count = 0;
    g_shared->report_head = 0;
    g_shared->report_count = 0;

    UnlockBus();
    return 0;
}

extern "C" __declspec(dllexport) int __stdcall CsmBus_EndTick(const int64_t tickSeq) {
    if (!EnsureAttached()) {
        return -100;
    }
    if (!LockBus()) {
        return -101;
    }

    if (g_shared->tick_seq == tickSeq) {
        g_shared->phase = 2;
    }

    UnlockBus();
    return 0;
}

extern "C" __declspec(dllexport) int __stdcall CsmBus_Publish(const wchar_t* moduleId,
                                                               const wchar_t* key,
                                                               const double curr,
                                                               const double prev,
                                                               const int32_t valid) {
    if (!EnsureAttached()) {
        return -100;
    }
    if (key == nullptr || key[0] == L'\0') {
        return -200;
    }
    if (!LockBus()) {
        return -101;
    }

    int idx = FindEntry(key);
    if (idx < 0) {
        if (g_shared->entry_count >= BUS_MAX_ENTRIES) {
            UnlockBus();
            return -201;
        }
        idx = g_shared->entry_count++;
        ZeroMemory(&g_shared->entries[idx], sizeof(BusEntry));
        CopyWs(g_shared->entries[idx].key, BUS_KEY_CHARS, key);
    }

    BusEntry& e = g_shared->entries[idx];
    e.curr = curr;
    e.prev = prev;
    e.valid = (valid != 0 ? 1 : 0);
    CopyWs(e.writer, BUS_MODULE_CHARS, moduleId);
    e.tick_seq = g_shared->tick_seq;
    e.updated_msc = static_cast<uint64_t>(GetTickCount());

    UnlockBus();
    return 0;
}

extern "C" __declspec(dllexport) int __stdcall CsmBus_Read(const wchar_t* key,
                                                            double* curr,
                                                            double* prev,
                                                            int32_t* valid,
                                                            int64_t* tickSeq) {
    if (!EnsureAttached()) {
        return -100;
    }
    if (key == nullptr || key[0] == L'\0') {
        return -200;
    }
    if (!LockBus()) {
        return -101;
    }

    const int idx = FindEntry(key);
    if (idx < 0) {
        UnlockBus();
        return -404;
    }

    const BusEntry& e = g_shared->entries[idx];
    if (curr != nullptr) {
        *curr = e.curr;
    }
    if (prev != nullptr) {
        *prev = e.prev;
    }
    if (valid != nullptr) {
        *valid = e.valid;
    }
    if (tickSeq != nullptr) {
        *tickSeq = e.tick_seq;
    }

    UnlockBus();
    return 0;
}

extern "C" __declspec(dllexport) int __stdcall CsmBus_Report(const wchar_t* moduleId,
                                                              const wchar_t* stepId,
                                                              const int32_t code,
                                                              const wchar_t* detail) {
    if (!EnsureAttached()) {
        return -100;
    }
    if (!LockBus()) {
        return -101;
    }

    const int idx = g_shared->report_head;
    g_shared->report_head = (g_shared->report_head + 1) % BUS_MAX_REPORTS;
    if (g_shared->report_count < BUS_MAX_REPORTS) {
        g_shared->report_count++;
    }

    BusReport& r = g_shared->reports[idx];
    ZeroMemory(&r, sizeof(BusReport));
    CopyWs(r.module_id, BUS_MODULE_CHARS, moduleId);
    CopyWs(r.step_id, BUS_STEP_CHARS, stepId);
    CopyWs(r.detail, BUS_DETAIL_CHARS, detail);
    r.code = code;
    r.tick_seq = g_shared->tick_seq;
    r.ts_msc = static_cast<uint64_t>(GetTickCount());

    UnlockBus();
    return 0;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    (void)hModule;
    (void)lpReserved;
    if (ul_reason_for_call == DLL_PROCESS_DETACH) {
        CsmBus_Shutdown();
    }
    return TRUE;
}
