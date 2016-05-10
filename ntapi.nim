#   ---   from ntdll.dll  --- #


import windows

type
  PROCESSINFOCLASS {. pure .} = enum
    ProcessBasicInformation = 0,
    ProcessQuotaLimits,
    ProcessIoCounters,
    ProcessVmCounters,
    ProcessTimes,
    ProcessBasePriority,
    ProcessRaisePriority,
    ProcessDebugPort,
    ProcessExceptionPort,
    ProcessAccessToken,
    ProcessLdtInformation,
    ProcessLdtSize,
    ProcessDefaultHardErrorMode,
    ProcessIoPortHandlers,
    ProcessPooledUsageAndLimits,
    ProcessWorkingSetWatch,
    ProcessUserModeIOPL,
    ProcessEnableAlignmentFaultFixup,
    ProcessPriorityClass,
    ProcessWx86Information,
    ProcessHandleCount,
    ProcessAffinityMask,
    ProcessPriorityBoost,
    ProcessDeviceMap,
    ProcessSessionInformation,
    ProcessForegroundInformation,
    ProcessWow64Information,
    ProcessImageFileName,
    ProcessLUIDDeviceMapsEnabled,
    ProcessBreakOnTermination,
    ProcessDebugObjectHandle,
    ProcessDebugFlags,
    ProcessHandleTracing,
    MaxProcessInfoClass

  NTSTATUS = LONG
  PEB {.final, pure.} = object
  PPEB = ptr PEB
  KPRIORITY = LONG

  PROCESS_BASIC_INFORMATION = object
    ExitStatus: NTSTATUS
    PebBaseAddress: PPEB
    AffinityMask: KAFFINITY
    BasePriority: KPRIORITY
    UniqueProcessId: ULONG
    InheritedFromUniqueProcessId: ULONG

proc ZwQueryInformationProcess(
  ProcessHandle: HANDLE,
  ProcessInformationClass: PROCESSINFOCLASS,
  ProcessInformation: ptr,
  ProcessInformationLength: ULONG,
  ReturnLength: PULONG):
  NTSTATUS
  {.stdcall, dynlib: "ntdll", importc: "ZwQueryInformationProcess".}



#   ---   additional procs  ---   #


proc GetParentProcessID*(dwPID: DWORD): DWORD =
  const FALSE = 0
  var
    ntStatus: NTSTATUS
    dwParentPID: DWORD = DWORD(0xffffffff'i32)
    hProcess: HANDLE
    pbi: PROCESS_BASIC_INFORMATION
    ulRetLen: ULONG
  hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, dwPID)
  if hProcess == 0:
    return DWORD(0xffffffff'i32)
  ntStatus = ZwQueryInformationProcess(
              hProcess,
              PROCESSINFOCLASS.ProcessBasicInformation,
              addr(pbi),
              sizeof(PROCESS_BASIC_INFORMATION),
              addr(ulRetLEn))
  if ntStatus == 0:
    dwParentPID = DWORD(pbi.InheritedFromUniqueProcessId)
  discard CloseHandle(hProcess)
  return dwParentPID
