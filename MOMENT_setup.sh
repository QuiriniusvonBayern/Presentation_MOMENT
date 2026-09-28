#!/usr/bin/env bash
set -Eeuo pipefail

main() {
    local script_dir destination_dir python_script_path python_version candidate
    local python_script_argument project_dir requirements_path
    local venv_path venv_argument venv_python usage_python run_status setup_script_argument
    local project_dir_argument scaffold_argument
    local version_check='import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}" if sys.version_info >= (3, 10) else "")'
    local repository_url='https://github.com/MOMENT-in-MOTION/MOMENT.git'
    local -a python_runner=()
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    destination_dir="$script_dir/MOMENT"
    python_script_path="$script_dir/scripts/MOMENT_setup.py"

    if command -v py.exe >/dev/null 2>&1; then
        python_version="$(py.exe -3 -c "$version_check" 2>/dev/null || true)"
        if [[ -n "$python_version" ]]; then
            python_runner=(py.exe "-$python_version")
        fi
    else
        for candidate in python.exe python; do
            if command -v "$candidate" >/dev/null 2>&1; then
                python_version="$("$candidate" -c "$version_check" 2>/dev/null || true)"
                if [[ -n "$python_version" ]]; then
                    python_runner=("$candidate")
                    break
                fi
            fi
        done
    fi

    if [[ ${#python_runner[@]} -eq 0 ]]; then
        printf 'Error: Python 3.10 or newer is required. Install it and make sure py.exe, python.exe, or python is available on PATH.\n' >&2
        return 1
    fi

    if [[ ! -f "$python_script_path" ]]; then
        printf 'Error: Python script not found: %s\n' "$python_script_path" >&2
        return 1
    fi

    python_script_argument="$python_script_path"
    scaffold_argument="$script_dir"
    if [[ "${python_runner[0]}" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
        python_script_argument="$(wslpath -w "$python_script_path")"
        scaffold_argument="$(wslpath -w "$script_dir")"
    fi

    if ! "${python_runner[@]}" "$python_script_argument" scaffold "$scaffold_argument"; then
        run_status=$?
        printf 'Error: Could not create the workshop folder structure (exit code %s).\n' "$run_status" >&2
        return "$run_status"
    fi

    project_dir="$destination_dir/MOMENT-main"
    if [[ ! -d "$project_dir/.git" ]]; then
        if [[ -e "$project_dir" ]]; then
            printf 'Error: %s exists but is not a Git checkout. Move it aside and run setup again.\n' "$project_dir" >&2
            return 1
        fi
        if ! command -v git >/dev/null 2>&1; then
            printf 'Error: Git is required to download MOMENT. Install Git and make sure it is available on PATH.\n' >&2
            return 1
        fi
        clone_project_dir_argument="$project_dir"
        if [[ "${python_runner[0]}" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
            clone_project_dir_argument="$(wslpath -w "$project_dir")"
        fi
        if ! "${python_runner[@]}" "$python_script_argument" clone "$repository_url" "$clone_project_dir_argument"; then
            run_status=$?
            printf 'Error: Could not clone the MOMENT repository (exit code %s).\n' "$run_status" >&2
            return "$run_status"
        fi
    fi

    requirements_path="$project_dir/requirements.txt"
    if [[ ! -f "$requirements_path" || ! -d "$project_dir/tests" || ! -f "$project_dir/src/main.py" ]]; then
        printf 'Error: MOMENT project files were not found in %s\n' "$project_dir" >&2
        return 1
    fi

    printf 'Setting up the Python virtual environment...\n'
    venv_path="$project_dir/.venv"
    if [[ "${python_runner[0]}" == *.exe ]]; then
        usage_python='.venv/Scripts/python.exe'
        if command -v wslpath >/dev/null 2>&1; then
            venv_argument="$(wslpath -w "$venv_path")"
            venv_python="$(wslpath -u "$venv_argument/Scripts/python.exe")"
        else
            venv_argument="$venv_path"
            venv_python="$venv_path/Scripts/python.exe"
        fi
    else
        usage_python='.venv/bin/python'
        venv_argument="$venv_path"
        venv_python="$venv_path/bin/python"
    fi

    if [[ ! -x "$venv_python" ]]; then
        if ! "${python_runner[@]}" -m venv "$venv_argument"; then
            printf 'Error: Could not create the MOMENT virtual environment.\n' >&2
            return 1
        fi
    fi

    setup_script_argument="$python_script_argument"
    project_dir_argument="$project_dir"
    if [[ "${python_runner[0]}" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
        project_dir_argument="$(wslpath -w "$project_dir")"
    fi

    run_status=0
    if ! "$venv_python" "$setup_script_argument" run "$project_dir_argument"; then
        run_status=$?
    fi

    cd -- "$script_dir"

    # Paths below are relative to the repository root ("$script_dir"), where this shell ends up.
    project_relative="MOMENT/MOMENT-main"
    metamodel_relative="workshop/create_your_metamodel/metamodel.json"
    output_relative="workshop/API_output"
    model_script_relative="workshop/create_your_model/your_car_model.py"
    venv_python_from_root="$project_relative/${usage_python}"
    generate_api_command="(cd $project_relative && $usage_python -m src.main \"../../$metamodel_relative\" -o \"../../$output_relative\")"

    printf '\nWorkshop steps (run all commands from this window/directory):\n'
    printf '\n1. Open your metamodel: %s\n' "$metamodel_relative"
    printf '   It is the unfinished car metamodel from the presentation.\n'
    printf '\n2. Complete the metamodel as described in the presentation instructions.\n'
    printf '\n3. Generate the API from your metamodel:\n'
    printf '     %s\n' "$generate_api_command"
    printf '\n4. Open your model script: %s\n' "$model_script_relative"
    printf '   Build a model of a vehicle of your choice using the generated API.\n'
    printf '\n5. Run the script to serialize your model:\n'
    printf '     %s -m workshop.create_your_model.your_car_model\n' "$venv_python_from_root"
    printf '\nFor CLI help and available options:\n'
    printf '  (cd %s && %s -m src.main --help)\n' "$project_relative" "$usage_python"

    if [[ "${python_runner[0]}" == *.exe ]]; then
        export VIRTUAL_ENV="$venv_path"
        export MOMENT_VENV_PYTHON="$venv_python"
        python() {
            "$MOMENT_VENV_PYTHON" "$@"
        }
        export -f python
    else
        source "$venv_path/bin/activate"
    fi

    exec bash -i
}

main "$@"