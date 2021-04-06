#!/usr/bin/env python3

# Copyright (C) 2016-2018 Embecosm Limited
# Contributor Graham Markall <graham.markall@embecosm.com>
# Contributor Simon Cook <simon.cook@embecosm.com>

# This file is a script to run the GCC testsuite on RISC-V using the default
# simulator.

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.

from collections import namedtuple
from concurrent.futures import ThreadPoolExecutor, as_completed
from glob import glob
from shutil import rmtree
from threading import Lock
from subprocess import Popen

import os
import sys

# Set names and locations of various things we interact with
TOPDIR = os.path.abspath(os.path.join(os.path.dirname(__file__)))
TEST_SUITE = os.path.join(TOPDIR, 'gcc-for-llvm-testing', 'gcc', 'testsuite')
DG_EXTRACT_RESULTS = os.path.join(TOPDIR, 'gcc-for-llvm-testing', 'contrib', 'dg-extract-results.py')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'test-output')
TEST_TOOL = 'riscv32-unknown-elf-clang'
TEST_BOARD = 'riscv-sim/-march=rv32imc/-mabi=ilp32'
TEST_TARGET = 'riscv32-unknown-elf'
RUNTEST_FLAGS = []

TestSet = namedtuple('TestSet', ['tool', 'set_dir', 'sub_dir', 'expect_file'])

TORTURE_TESTS = [
#    TestSet('gcc', 'gcc.c-torture', 'compile', 'compile.exp'),
    TestSet('gcc', 'gcc.c-torture', 'execute', 'execute.exp'),
#    TestSet('gcc', 'gcc.c-torture', 'unsorted', 'unsorted.exp'),
]

# Tests from gcc.dg that we're not including:
#
# plugin:      GCC's plugin architecture
# tm:          Transactional memory
# tsan:        Thread Sanitizer
# cilk-plus:   Cilk Plus
# autopar:     Automatic parallelisation
# fixed-point: Fixed-point arithmetic
# vmx:         VMX instructions (for PowerPC)
# pch:         Precompiled headers
# dfp:         Decimal floating point
# gomp:        GNU OpenMP
# vxworks:     VxWorks targets
# graphite:    GRAPHITE polyhedral optimisation
# ipa:         Interprocedural analysis dumps
# goacc:       GNU OpenACC support
# goacc-gomp:  GNU OpenACC support
# cpp/trad:    Traditional preprocessor mode
# vect:        Vector instructions
# torture:     <<< Need to look at this again >>>
# charset:     IBM 1047 charset
# compat:      Test compatibility of code from two compilers linked together
# guality:     Test the quality of debug information
# special:     ???
# tree-ssa:    Test tree-ssa dumps
# debug:       debug info
# ubsan:       Undefined behaviour sanitizer
# tree-prof:   Profile-directed block ordering
# lto:         Link-time optimisation
# asan:        Address sanitizer
# wformat:     Warnings about format features
# atomic:      C11 atomics

DG_TESTS = [
    # Tests in root dir of dg suite
    TestSet('gcc', 'gcc.dg', '', 'dg.exp'),
    # C Preprocessor
    TestSet('gcc', 'gcc.dg', 'cpp', 'cpp.exp'),
    # Tests atomicity/for race conditions
    TestSet('gcc', 'gcc.dg', 'simulate-thread', 'simulate-thread.exp'),
    # Things that should not compile
    TestSet('gcc', 'gcc.dg', 'noncompile', 'noncompile.exp'),
    # Weak symbols
    TestSet('gcc', 'gcc.dg', 'weak', 'weak.exp'),
    # Thread-local storage
    TestSet('gcc', 'gcc.dg', 'tls', 'tls.exp'),
]

CXX_TESTS = [
    TestSet('g++', 'g++.dg', '', 'dg.exp')
]

# FIXME: The RISC-V baseboard does not work with clang++, don't run the g++
#        tests until this is investigated
#TEST_SETS = TORTURE_TESTS + DG_TESTS
TEST_SETS = TORTURE_TESTS

# The number of tests to pass to a single Dejagnu invocation at once
DG_INSTANCE_NTESTS = 20

# How many DejaGnu instances are run concurrently
WORKERS = os.cpu_count()


class TestManager(object):
    '''
    The TestManager maintains the list of the tests that need to be run for a
    particular test set.
    '''
    def __init__(self, test_set):
        self._tests_lock = Lock()
        self._tests = None
        self._current_run = 0
        self._test_set = test_set

    def find_tests(self):
        '''
        Find all .c files in the test set.
        '''
        root = os.path.join(TEST_SUITE, self._test_set.set_dir, self._test_set.sub_dir)
        found = []
        for path, _, files in os.walk(root):
            found += [ os.path.relpath(os.path.join(path, name), start=root)
                           for name in files if name[-2:] in ('.c', '.C') ]
        print("Discovered %s test files" % len(found))
        self._tests = found

    def pop_tests(self, ntests):
        '''
        Pop up to ntests tests from the list of tests. If there are less than
        ntests tests remaining, all the tests are popped.

        Returns i, t where i is a unique integer identifying the instance of
        dejagnu to be launched, and t is a list of test names.
        '''
        if self._tests is None:
            raise RuntimeError("Tests must be discovered first")
        self._tests_lock.acquire()

        t = []
        while self._tests and ntests:
            t.append(self._tests.pop())
            ntests -= 1

        i = self._current_run
        self._current_run += 1

        self._tests_lock.release()
        return i, t

    @property
    def test_set(self):
        return self._test_set


def runtests_env():
    env = os.environ.copy()
    bindir = os.path.join(TOPDIR, 'install', 'bin')
    path = '%s:%s' % (bindir, env['PATH'])
    env['PATH'] = path
    env['DEJAGNU'] = os.path.join(TOPDIR, 'dejagnu', 'riscv-sim-site.exp')
    env['RISCV_SIM_COMMAND'] = 'riscv32-unknown-elf-run'
    env['RISCV_TRIPLE'] = 'riscv32-unknown-elf'
    return env

def runtests(i, test_set, tests):
    '''
    Launch instance i of DejaGnu, running the given list of tests in the
    test_set.
    '''
    set_dir = test_set.set_dir
    sub_dir = test_set.sub_dir

    # Prepare output directory
    unique_name = '%s_%s_%s' % (set_dir, sub_dir, i)
    dg_output_dir = os.path.join(OUTPUT_DIR, 'dgrun_%s' % unique_name)
    os.mkdir(dg_output_dir)

    test_list = " ".join([ os.path.join(test_set.sub_dir, test)
                           for test in tests ])
    args = [
        'runtest',
        '--tool=%s' % test_set.tool,
        '--tool_exec=%s' % TEST_TOOL,
        '--directory=%s' % os.path.join(TEST_SUITE, set_dir),
        '--srcdir=%s' % TEST_SUITE,
        '--target_board=%s' % TEST_BOARD,
        '--target=%s' % TEST_TARGET,
        '%s=%s' % (test_set.expect_file, test_list) ]
    args += RUNTEST_FLAGS

    proc = Popen(args, env=runtests_env(), cwd=dg_output_dir)
    return proc.wait()

def test_loop(*, tm=None):
    '''
    Repeatedly invoke DejaGnu with a list of tests obtained from the TestManager.

    Each worker thread runs this function until completion.
    '''
    if tm is None:
        raise ValueError("test_loop requires a TestManager")

    i, next_tests = tm.pop_tests(DG_INSTANCE_NTESTS)
    while next_tests:
        runtests(i, tm.test_set, next_tests)
        i, next_tests = tm.pop_tests(DG_INSTANCE_NTESTS)


def combine_results(dg_outfile, *, extra_args=None):
    '''
    Combine the outputs of all DejaGnu instances using the dg-extract-results.py
    script from GCC.
    '''
    output_files = glob(os.path.join(OUTPUT_DIR, 'dgrun*/%s' % dg_outfile))
    args = [ sys.executable, DG_EXTRACT_RESULTS ]
    if extra_args is not None:
        args += extra_args
    args += output_files

    with open(os.path.join(OUTPUT_DIR, dg_outfile), 'w') as f:
        result = Popen(args, cwd=os.path.dirname(__file__), stdout=f)
        if result.wait():
            print("Warning: error combining %s" % dg_outfile, file=sys.stderr)

def all_tools():
    tools = set()
    for ts in TEST_SETS:
        tools.add(ts.tool)
    return tools

def combine_sums():
    for tool in all_tools():
        combine_results('%s.sum' % tool)

def combine_logs():
    for tool in all_tools():
        combine_results('%s.log' % tool, extra_args=['-L'])

def print_summary():
    '''
    Search the combined summary output for the count of each result,
    and print them.
    '''
    interesting = [
        '# of expected passes',
        '# of unexpected failures',
        '# of unexpected successes',
        '# of expected failures',
        '# of unknown successes',
        '# of known failures',
        '# of untested testcases',
        '# of unresolved testcases',
        '# of unsupported tests' ]

    for tool in all_tools():
        with open(os.path.join(OUTPUT_DIR, '%s.sum' % tool)) as f:
            summary = [
                line for line in f
                for phrase in interesting
                if phrase in line ]

        print("\n%s summary:\n" % tool)
        print("".join(summary))


def main(args):
    # Prepare output directory
    if os.path.exists(OUTPUT_DIR):
        rmtree(OUTPUT_DIR)
    os.mkdir(OUTPUT_DIR)

    for test_set in TEST_SETS:
        # Set up the test manager
        tm = TestManager(test_set)
        tm.find_tests()

        # Use a set of workers to execute tests in parallel
        executor = ThreadPoolExecutor(max_workers=WORKERS)
        test_loop_args = { 'tm': tm }
        jobs = { executor.submit(test_loop, **test_loop_args): i
                 for i in range(WORKERS) }

        # Wait on workers - halt if any errors from any of them
        halt = False
        for worker in as_completed(jobs):
            try:
                worker.result()
            except Exception as exc:
                import traceback
                print("Job %s generated an exception: %s" % (worker, exc))
                traceback.print_exc()
                halt = True

        if halt:
            break

    # Combine the output from all instances
    combine_sums()
    combine_logs()

    print_summary()


if __name__ == '__main__':
    sys.exit(main(sys.argv))
