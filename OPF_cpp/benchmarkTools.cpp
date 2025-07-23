#include"benchmarkTools.h"
#include "solve_opf.h"

#include <iostream>
#include <iomanip>
#include <fstream>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <thread>
#include <vector>
#include <string>
#include<sstream>

//Fix for std::max conflict on Windows
#ifdef _WIN32
#define NOMINMAX  // Prevent Windows macros from redefining min/max
#include <windows.h>
#include <psapi.h>
#else
#include <unistd.h>
#include <fstream>
#endif

double get_peak_memory_mb() {
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS pmc;
    GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc));
    return pmc.PeakWorkingSetSize / (1024.0 * 1024.0);
#else
    std::ifstream status("/proc/self/status");
    std::string line;
    double rss_kb = 0.0;
    while (getline(status, line)) {
        if (line.find("VmRSS:") != std::string::npos) {
            std::istringstream iss(line);
            std::string label;
            iss >> label >> rss_kb;
            break;
        }
    }
    return rss_kb / 1024.0;
#endif
}

static double median(std::vector<double> v) {
    std::sort(v.begin(), v.end());
    size_t n = v.size();
    return n % 2 == 0 ? (v[n / 2 - 1] + v[n / 2]) / 2.0 : v[n / 2];
}

void run_benchmark(const std::vector<std::string>& test_cases, const std::string& dc_case, std::vector<BenchmarkResult>& results) {
    std::cout << "\n====== AC/DC OPF C++ Benchmark ======\n\n";
    std::cout << "Configuration:\n  DC Case: " << dc_case << "\n  Samples: 5\n\n";

    std::cout << "Performing warm-up runs...\n";
    for (int i = 0; i < 3; ++i) {
        solve_opf(dc_case, test_cases[0],
            /*vscControl*/ true,
            /*writeTxt  */ false,
            /*plotResult*/ false);  // Warm-up using first test case
    }

    for (const auto& ac_case : test_cases) {
        std::cout << "\nBenchmarking case: " << ac_case << "\n";
        std::vector<double> run_times, memory_usages;

        for (int i = 0; i < 5; ++i) {
            double mem_before = get_peak_memory_mb();
            auto start = std::chrono::high_resolution_clock::now();

            try {
                // Fix: Check for a file based only on the dc_case, not including the ac_case
                std::string expected_file = dc_case + "_baseMW_dc.csv";
                std::ifstream check(expected_file);
                if (!check.good()) {
                    std::cerr << "Skipping run: Missing required file: " << expected_file << "\n";
                    run_times.push_back(0.0);
                    memory_usages.push_back(0.0);
                    continue;
                }

                solve_opf(dc_case, test_cases[0],
                    /*vscControl*/ true,
                    /*writeTxt  */ false,
                    /*plotResult*/ false);  
            }
            catch (...) {
                std::cerr << "Exception during optimization\n";
            }

            auto end = std::chrono::high_resolution_clock::now();
            double elapsed = std::chrono::duration<double>(end - start).count();
            double mem_after = get_peak_memory_mb();
            double mem_used = std::max(0.0, static_cast<double>(mem_after - mem_before));

            run_times.push_back(elapsed);
            memory_usages.push_back(mem_used);

            std::cout << "  Run " << (i + 1) << ": " << std::fixed << std::setprecision(3)
                << elapsed << " s, " << std::setprecision(1) << mem_used << " MB\n";
        }

        std::sort(run_times.begin(), run_times.end());
        std::sort(memory_usages.begin(), memory_usages.end());

        double median_time = median(run_times);
        double min_time = *std::min_element(run_times.begin(), run_times.end());
        double max_time = *std::max_element(run_times.begin(), run_times.end());
        double peak_memory = *std::max_element(memory_usages.begin(), memory_usages.end());

        double relative_memory = (!results.empty() && results[0].peak_memory > 0.0)
            ? peak_memory / results[0].peak_memory
            : (results.empty() ? 1.0 : NAN);

        results.push_back({ ac_case, median_time, min_time, max_time, peak_memory, relative_memory });
    }
}


void print_summary(const std::vector<BenchmarkResult>& results) {
    std::cout << "\n====== Benchmark Results Summary ======\n";
    std::cout << "| Case       | Time (s)         | Memory Usage       |\n";
    std::cout << "|------------|------------------|--------------------|\n";
    std::cout << "|            | Median | Range   | Absolute | Relative |\n";
    std::cout << "|------------|--------|---------|----------|----------|\n";

    for (const auto& res : results) {
        std::cout << "| " << std::setw(10) << res.case_name << " | "
            << std::setw(6) << std::fixed << std::setprecision(3) << res.median_time << " | "
            << std::setw(5) << res.min_time << "-"
            << std::setw(3) << res.max_time << " | "
            << std::setw(8) << std::setprecision(1) << res.peak_memory << " | "
            << std::setw(8)
            << (std::isnan(res.relative_memory)
                ? std::string("N/A")
                : std::to_string(std::round(res.relative_memory * 100) / 100.0))
            << "x |\n";
    }
}

void save_results_csv(const std::vector<BenchmarkResult>& results, const std::string& filename) {
    std::ofstream out(filename);
    out << "case_name,median_time,min_time,max_time,peak_memory,relative_memory\n";
    for (const auto& res : results) {
        out << res.case_name << "," << res.median_time << "," << res.min_time << ","
            << res.max_time << "," << res.peak_memory << "," << res.relative_memory << "\n";
    }
    out.close();
    std::cout << "\nResults saved to " << filename << "\n";
}