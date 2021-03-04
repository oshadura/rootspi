#---Common Settings-------------------------------------------------------
include(${CTEST_SCRIPT_DIRECTORY}/rootCommon.cmake)
unset(CTEST_CHECKOUT_COMMAND)  # We do not need to checkout

if(WIN32 AND ${CMAKE_VERSION} VERSION_GREATER_EQUAL 3.17)
  set(CTEST_EXTRA_ARGS REPEAT UNTIL_PASS:3)
endif()

#---Read custom files and generate a note with ignored tests----------------
ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
WRITE_INGNORED_TESTS(ignoredtests.txt)
set(CTEST_NOTES_FILES  ignoredtests.txt)
#--------------------------------------------------------------------------

#----Continuous-----------------------------------------------------------
if(CTEST_MODE STREQUAL continuous)
  ctest_start (Continuous TRACK Incremental APPEND)
  ctest_test(PARALLEL_LEVEL ${ncpu} EXCLUDE "^tutorial-" EXCLUDE_LABEL "benchmark"
  ${CTEST_EXTRA_ARGS})

#----Install mode---------------------------------------------------------
elseif(CTEST_MODE STREQUAL install)
  get_filename_component(CTEST_BINARY_DIRECTORY runtests ABSOLUTE)
  ctest_start(${CTEST_MODE} TRACK Install)
  #---Set the environment---------------------------------------------------
  set(ENV{PATH} ${CTEST_INSTALL_DIRECTORY}/bin:$ENV{PATH})
  if(APPLE)
    set(ENV{DYLD_LIBRARY_PATH} ${CTEST_INSTALL_DIRECTORY}/lib/root:$ENV{DYLD_LIBRARY_PATH})
  elseif(UNIX)
    set(ENV{LD_LIBRARY_PATH} ${CTEST_INSTALL_DIRECTORY}/lib/root:$ENV{LD_LIBRARY_PATH})
  endif()
  set(ENV{PYTHONPATH} ${CTEST_INSTALL_DIRECTORY}/lib/root:$ENV{PAYTHONPATH})

  #---Configure and run the tests--------------------------------------------
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}/tutorials
                  SOURCE  ${CTEST_INSTALL_DIRECTORY}/share/doc/root/tutorials)
  ctest_test(BUILD ${CTEST_RUNTESTS_DIRECTORY}/tutorials PARALLEL_LEVEL ${ncpu}
             EXCLUDE_LABEL "benchmark" ${CTEST_EXTRA_ARGS})

#----Package mode---------------------------------------------------------
elseif(CTEST_MODE STREQUAL package)
  ctest_start(${CTEST_MODE} TRACK Package APPEND)
  #--Untar the installation kit----------------------------------------------
  file(GLOB tarfile ${CTEST_BINARY_DIRECTORY}/root_*.tar.gz)
  execute_process(COMMAND cmake -E tar xfz ${tarfile} WORKING_DIRECTORY ${CTEST_BINARY_DIRECTORY})
  set(installdir ${CTEST_BINARY_DIRECTORY}/root)
  #---Set the environment---------------------------------------------------
  set(ENV{ROOTSYS} ${installdir})
  set(ENV{PATH} ${installdir}/bin:$ENV{PATH})
  if(APPLE)
    set(ENV{DYLD_LIBRARY_PATH} ${installdir}/lib:$ENV{DYLD_LIBRARY_PATH})
  elseif(UNIX)
    set(ENV{LD_LIBRARY_PATH} ${installdir}/lib:$ENV{LD_LIBRARY_PATH})
  endif()
  set(ENV{PYTHONPATH} ${installdir}/lib:$ENV{PAYTHONPATH})
  #---Configure and run the tests--------------------------------------------
  file(MAKE_DIRECTORY ${CTEST_BINARY_DIRECTORY}/runtests)
  ctest_configure(BUILD   ${CTEST_BINARY_DIRECTORY}/runtests
                  SOURCE  ${CTEST_SOURCE_DIRECTORY}/tutorials)
  ctest_test(BUILD ${CTEST_BINARY_DIRECTORY}/runtests
             PARALLEL_LEVEL ${ncpu} EXCLUDE_LABEL "benchmark"
             ${CTEST_EXTRA_ARGS})

#---Pullrequest mode--------------------------------------------------------
elseif(CTEST_MODE STREQUAL pullrequests)
  ctest_start(Pullrequests TRACK Pullrequests APPEND)
  string(TOLOWER "$ENV{ExtraCMakeOptions}" EXTRA_CMAKE_OPTS_LOWER)
  if(${EXTRA_CMAKE_OPTS_LOWER} MATCHES "dctest_test_exclude_none=on"
     OR "$ENV{LABEL}" MATCHES "ROOT-performance-centos8-multicore")
    message("Enabling all tests.")
    ctest_test(PARALLEL_LEVEL ${ncpu} ${CTEST_EXTRA_ARGS})
  else()
    message("***WARNING: DISABLING TUTORIALS / SLOW TESTS.***")
    ctest_test(PARALLEL_LEVEL ${ncpu} EXCLUDE "^tutorial-" EXCLUDE_LABEL "longtest"
               ${CTEST_EXTRA_ARGS})
  endif()

  if(${EXTRA_CMAKE_OPTS_LOWER} MATCHES "dkeep_pr_builds_for_a_day=on")
     # Copy the PR environment.
     # cp /build/workspace/root-pullrequests-build to
     # /build/workspace/root-pullrequests-build-keep-for-vgvassilev
     execute_process_and_log(COMMAND ${CMAKE_COMMAND} -E
       copy_directory "$ENV{WORKSPACE}/" "$ENV{WORKSPACE}-keep-for-$ENV{ghprbPullAuthorLogin}"
       HINT "Copying $ENV{WORKSPACE}/ into $ENV{WORKSPACE}-keep-for-$ENV{ghprbPullAuthorLogin} due to -DKEEP_PR_BUILDS_FOR_A_DAY=On"
       )
  endif()

  # We are done, switch to master to clean up the created branch.
  set(LOCAL_BRANCH_NAME "$ENV{ghprbPullAuthorLogin}-$ENV{ghprbSourceBranch}")
  cleanup_pr_area($ENV{ghprbTargetBranch} ${LOCAL_BRANCH_NAME} ${REBASE_WORKING_DIR})

#---Experimental/Nightly----------------------------------------------------
else()
  ctest_start(${CTEST_MODE} APPEND)
  ctest_test(PARALLEL_LEVEL ${ncpu} EXCLUDE_LABEL "benchmark" ${CTEST_EXTRA_ARGS})
endif()

# TODO: uncomment next line if CDASH will be back
#ctest_submit(PARTS Test Notes)
