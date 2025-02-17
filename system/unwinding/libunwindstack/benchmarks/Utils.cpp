/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <err.h>
#include <stdint.h>

#include <benchmark/benchmark.h>
#include <malloc.h>

#include <string>
#include <vector>

#include <android-base/file.h>
#include <android-base/strings.h>
#include <benchmark/benchmark.h>

#include <unwindstack/Elf.h>
#include <unwindstack/Memory.h>

#include "utils/OfflineUnwindUtils.h"

#include "Utils.h"

std::string GetBenchmarkFilesDirectory() {
  std::string path = android::base::GetExecutableDirectory() + "/benchmarks/files/";
  unwindstack::DecompressFiles(path);
  return path;
}

std::string GetElfFile() {
  return GetBenchmarkFilesDirectory() + "libart_arm.so";
}

std::string GetSymbolSortedElfFile() {
  return GetBenchmarkFilesDirectory() + "boot_arm.oat";
}

std::string GetLargeCompressedFrameElfFile() {
  return GetBenchmarkFilesDirectory() + "libpac.so";
}

std::string GetLargeEhFrameElfFile() {
  return GetBenchmarkFilesDirectory() + "libLLVM_android.so";
}

#if defined(__BIONIC__)

#include <meminfo/procmeminfo.h>
#include <procinfo/process_map.h>

uint64_t GetRSSBytes() {
  uint64_t total_bytes = 0;
  android::meminfo::ProcMemInfo proc_mem(getpid());
  const std::vector<android::meminfo::Vma>& maps = proc_mem.MapsWithoutUsageStats();
  for (auto& vma : maps) {
    if (vma.name == "[anon:libc_malloc]" || android::base::StartsWith(vma.name, "[anon:scudo:") ||
        android::base::StartsWith(vma.name, "[anon:GWP-ASan")) {
      android::meminfo::Vma update_vma(vma);
      if (!proc_mem.FillInVmaStats(update_vma)) {
        err(1, "FillInVmaStats failed");
      }
      total_bytes += update_vma.usage.rss;
    }
  }
  return total_bytes;
}
#endif

void MemoryTracker::SetBenchmarkCounters(benchmark::State& state) {
  double total_iterations = static_cast<double>(state.iterations());
#if defined(__BIONIC__)
  state.counters["AVG_RSS_BYTES"] = total_rss_bytes_ / total_iterations;
  state.counters["MAX_RSS_BYTES"] = max_rss_bytes_;
  state.counters["MIN_RSS_BYTES"] = min_rss_bytes_;
#endif
  state.counters["AVG_ALLOCATED_BYTES"] = total_alloc_bytes_ / total_iterations;
  state.counters["MAX_ALLOCATED_BYTES"] = max_alloc_bytes_;
  state.counters["MIN_ALLOCATED_BYTES"] = min_alloc_bytes_;
}

void MemoryTracker::StartTrackingAllocations() {
#if defined(__BIONIC__)
  mallopt(M_PURGE_ALL, 0);
  rss_bytes_before_ = GetRSSBytes();
#endif
  alloc_bytes_before_ = mallinfo().uordblks;
}

void MemoryTracker::StopTrackingAllocations() {
#if defined(__BIONIC__)
  mallopt(M_PURGE_ALL, 0);
#endif
  uint64_t alloc_bytes = 0;
  uint64_t alloc_bytes_after = mallinfo().uordblks;
  if (alloc_bytes_after > alloc_bytes_before_) {
    alloc_bytes = alloc_bytes_after - alloc_bytes_before_;
  }
  total_alloc_bytes_ += alloc_bytes;
  if (alloc_bytes > max_alloc_bytes_) max_alloc_bytes_ = alloc_bytes;
  if (alloc_bytes < min_alloc_bytes_) min_alloc_bytes_ = alloc_bytes;
#if defined(__BIONIC__)
  uint64_t rss_bytes = 0;
  uint64_t rss_bytes_after = GetRSSBytes();
  if (rss_bytes_after > rss_bytes_before_) {
    rss_bytes = rss_bytes_after - rss_bytes_before_;
  }
  total_rss_bytes_ += rss_bytes;
  if (rss_bytes > max_rss_bytes_) max_rss_bytes_ = rss_bytes;
  if (rss_bytes < min_rss_bytes_) min_rss_bytes_ = rss_bytes;
#endif
}
