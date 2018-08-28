#!/bin/bash

main() {
    config=Release
    test=
    test_regex=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config=*)
                config=${1##--config=}
                shift
                ;;
            -C)
                [[ -z "$2" ]] && error_exit "Config not specified after \"-C\""
                config=$2
                shift 2
                ;;
            --test=*)
                test=1
                test_regex=${1##--test=}
                shift
                ;;
            --test)
                test=1
                shift
                ;;
            -T)
                test=1
                shift
                if [[ -n "$1" ]]; then
                    test_regex=$1
                    shift
                fi
                ;;
            *)
                error_exit "Unrecognized argument. Usage: build.sh [ -C <config> | --config=<config> ] [ -T [ <test regex> ] | --test [ =<test regex> ] ]"
                ;;
        esac
    done

    mkdir -p ./build/install || {
        error_exit "Failed to create build/install directory."
    }

    cd ./build || {
        error_exit "Failed to cd to build directory."
    }

    if [[ -n "$test" ]]; then
        if [[ ! -d ".venv" ]]; then
            echo "Creating python virtual environment..."
            virtualenv -p python2 .venv || {
                error_exit "Failed to create python virtual environment"
            }
            echo

            echo "Initializing git repository in python virtual environment directory..."
            echo "*" > .venv/.gitignore || {
                error_exit "Failed to write virtual environment .gitignore file"
            }
            git init .venv || {
                error_exit "Failed to initialize virtual environment git repository"
            }
            echo
        fi

        echo "Activating python virtual environment..."
        source .venv/Scripts/activate || {
            error_exit "Failed to activate python virtual environment"
        }
        echo
    fi

    cmake -G"Visual Studio 15 2017 Win64" \
          -DCMAKE_INSTALL_PREFIX=install \
          -Dgtest_build_tests=ON \
          -Dgmock_build_tests=ON \
          ../repo || {
        error_exit "cmake generation failed."
    }

    cmake --build . --config $config || {
        error_exit "cmake build failed."
    }

    cmake --build . --config $config --target install || {
        error_exit "Failed to install."
    }

    if [[ -n "$test" ]]; then
        [[ -n "$test_regex" ]] && test_regex="--tests-regex $test_regex"
        ctest --output-on-failure --build-config $config $test_regex || {
            error_exit "Tests failed."
        }
    fi
}

build_args=$@
error_exit() {
    echo
    echo "$1" >&2
    echo
    echo "Build error: $(basename -- "$0") $build_args"
    echo "----------------------------------------------------------------------"
    echo
    exit 1
}

scriptdir=$(dirname "$(readlink -f "$0")")
cd "$scriptdir" || {
    error_exit "Failed to cd to scripts directory."
}

echo "----------------------------------------------------------------------"
echo "Build started: $(basename -- "$0") $@"
echo
time main "$@"
echo
echo "Build finished: $(basename -- "$0") $@"
echo "----------------------------------------------------------------------"
echo

exit 0
