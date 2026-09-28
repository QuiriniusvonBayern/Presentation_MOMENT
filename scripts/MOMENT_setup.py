import re
import subprocess
import sys
from pathlib import Path

BAR_WIDTH = 30

CAR_METAMODEL_JSON = """{
    "name": "ChassisModel",
    "enums": [],
    "classes": [
        {
            "name": "Chassis",
            "attributes": [
                {
                    "name": "Name",
                    "attribute_type": "STRING",
                    "multiplicity": "[1]"
                },
                {
                    "name": "Description",
                    "attribute_type": "STRING",
                    "multiplicity": "[1]"
                },
                {
                    "name": "Colour",
                    "attribute_type": "STRING",
                    "multiplicity": "[1]"
                }
            ],
            "associations": [
                {
                    "name": "wheels",
                    "target": "Wheel",
                    "association_type": "COMPOSITION",
                    "multiplicity": "[1..4]"
                }
            ]
        },
        {
            "name": "Wheel",
            "attributes": [
                {
                    "name": "Name",
                    "attribute_type": "STRING",
                    "multiplicity": "[1]"
                },
                {
                    "name": "Manufacturer",
                    "attribute_type": "STRING",
                    "multiplicity": "[1]"
                }
            ],
            "associations": []
        }
    ]
}
"""

CAR_MODEL_PY = """from ..API_output.class_code import Chassis, Wheel
from ..API_output.enum_code import *
from ..API_output.serializer import Serializer

model = Chassis(
    name="My_Car",
    description="My car description",
    colour="Red",
    wheels=[
        Wheel(name="Front_Left", manufacturer="Michelin"),
        Wheel(name="Front_Right", manufacturer="Michelin"),
        Wheel(name="Rear_Left", manufacturer="Michelin"),
        Wheel(name="Rear_Right", manufacturer="Michelin"),
    ],
)

serializer = Serializer(model)
serializer.serialize(
    fmt="json",
    output_path="workshop/serialized_model",
    file_name="car",
)
"""

INSTRUCTIONS_MD = """# Structure of a MOMENT Metamodel

A metamodel is a single JSON file (e.g. `metamodel.json`) that MOMENT
converts into Python classes. This guide describes the minimum structure
required for MOMENT to process the file correctly.

## Basic skeleton

```json
{
    "name": "ExampleModel",
    "enums": [],
    "classes": [
        {
            "name": "RootClass",
            "attributes": [
                {
                    "name": "Name",
                    "attribute_type": "STRING",
                    "multiplicity": "[1]",
                    "default_value": "example"
                }
            ],
            "associations": []
        }
    ]
}
```

## Top-level keys

| Key | Required | Description |
|---|---|---|
| `name`    | yes | Name of the metamodel. |
| `enums`   | no | List of enum definitions (see below). |
| `classes` | yes | List of class definitions. **The first class in this list is the root class.** |

### Root class and reachability

The first class in `classes` is treated as the root class. Every other
class must be reachable from it through at least one `COMPOSITION`
association (directly or via inheritance). If this is not the case, MOMENT
fails with an `UnreachableClassError`, unless `AllowUnreachableClasses` is
set to `"true"` in `src/api_config.json`.

## Classes (`classes[]`)

| Key | Required | Description |
|---|---|---|
| `name` | yes | Class name (must be unique across the model). |
| `attributes` | yes | List of attributes (can be empty: `[]`). |
| `associations` | yes | List of associations (can be empty: `[]`). |
| `inherits` | no | Name of a parent class (`"Base"`) or a list for multiple inheritance (`["A", "B"]`). |

## Attributes (`attributes[]`)

| Key | Required | Description |
|---|---|---|
| `name` | yes | Attribute name. |
| `attribute_type` | yes | `"STRING"`, `"INT"`, or `"BOOL"` (`"str"`, `"int"`, `"bool"` also work). |
| `multiplicity` | yes | See the "Multiplicity" section. |
| `default_value` | no | Default value. |

## Associations (`associations[]`)

| Key | Required | Description |
|---|---|---|
| `name` | yes | Name of the association. |
| `multiplicity` | yes | See the "Multiplicity" section. |
| `association_type` | yes | `"COMPOSITION"` (target class belongs to the model, counts for reachability) or `"REFERENCE"` (loose reference). |
| `target` | yes | Name of the target class or enum. |
| `import_link` | no | Path to another `.json` file (with `ImportMode: "merge"`) or a Python module name (with `ImportMode: "import"`), if the target is defined there. |
| `default_value` | no | Default value. |

## Enums (`enums[]`)

```json
{
    "name": "Status",
    "values": ["ACTIVE", "INACTIVE"]
}
```

Or with explicit values:

```json
{
    "name": "Color",
    "values": [
        { "name": "RED", "value": "red" },
        { "name": "BLUE", "value": "blue" }
    ]
}
```

## Multiplicity

Format: `"[lower]"`, `"[lower..upper]"`, or `"[lower..*]"`.

| Example | Meaning |
|---|---|
| `"[1]"` | exactly one (required field) |
| `"[0..1]"` | optional, at most one |
| `"[1..*]"` | one or more |
| `"[0..*]"` | any number, including none |

## Inheritance

```json
{
    "name": "ChildClass",
    "inherits": "BaseClass",
    "attributes": [],
    "associations": []
}
```

Multiple inheritance is possible with a list: `"inherits": ["BaseClass", "InterfaceClass"]`.

## Running

After running the setup script, the interactive shell it opens starts in the
repository root (the folder containing `MOMENT`, `scripts`, and `workshop`).
MOMENT's CLI itself must be run from the project directory (`MOMENT/MOMENT-main`),
since it looks up `src/api_config.json` relative to the current directory:

```
cd MOMENT/MOMENT-main
.venv/Scripts/python.exe -m src.main "../../workshop/create_your_metamodel/metamodel.json" -o "../../workshop/API_output"
cd -
```

(On macOS/Linux use `.venv/bin/python` instead of `.venv/Scripts/python.exe`.)

## Using your generated API

`workshop/create_your_model/your_car_model.py` shows how to use the generated API. It
uses relative imports (`from ..API_output import ...`), so it must be run as a module
from the repository root:

```
MOMENT/MOMENT-main/.venv/Scripts/python.exe -m workshop.create_your_model.your_car_model
```
"""


def workshop_paths(repo_root):
    workshop_dir = repo_root / "workshop"
    return {
        "workshop_dir": workshop_dir,
        "metamodel_dir": workshop_dir / "create_your_metamodel",
        "model_dir": workshop_dir / "create_your_model",
        "output_dir": workshop_dir / "API_output",
    }


def scaffold(repo_root):
    paths = workshop_paths(repo_root)
    paths["metamodel_dir"].mkdir(parents=True, exist_ok=True)
    paths["model_dir"].mkdir(parents=True, exist_ok=True)

    workshop_init = paths["workshop_dir"] / "__init__.py"
    if not workshop_init.exists():
        workshop_init.write_text("", encoding="utf-8")

    model_init = paths["model_dir"] / "__init__.py"
    if not model_init.exists():
        model_init.write_text("", encoding="utf-8")

    metamodel_json = paths["metamodel_dir"] / "metamodel.json"
    if not metamodel_json.exists():
        metamodel_json.write_text(CAR_METAMODEL_JSON, encoding="utf-8")

    instructions_md = paths["metamodel_dir"] / "INSTRUCTIONS.md"
    if not instructions_md.exists():
        instructions_md.write_text(INSTRUCTIONS_MD, encoding="utf-8")

    your_car_model_py = paths["model_dir"] / "your_car_model.py"
    if not your_car_model_py.exists():
        your_car_model_py.write_text(CAR_MODEL_PY, encoding="utf-8")

    return 0


def render_bar(fraction, label):
    fraction = max(0.0, min(1.0, fraction))
    filled = int(BAR_WIDTH * fraction)
    bar = "#" * filled + "-" * (BAR_WIDTH - filled)
    percent = int(fraction * 100)
    sys.stdout.write(f"\r{label} [{bar}] {percent:3d}%")
    sys.stdout.flush()


def count_requirements(requirements_path):
    count = 0
    with requirements_path.open(encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                count += 1
    return max(count, 1)


def install_dependencies(project_dir):
    requirements_path = project_dir / "requirements.txt"
    total = count_requirements(requirements_path)
    done = 0

    render_bar(0.0, "Installing dependencies")
    process = subprocess.Popen(
        [sys.executable, "-m", "pip", "install", "-r", str(requirements_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    output_lines = []
    for line in process.stdout:
        output_lines.append(line)
        if line.startswith("Collecting ") or line.startswith(
            "Requirement already satisfied"
        ):
            done = min(done + 1, total)
            render_bar(done / total, "Installing dependencies")
    process.wait()
    render_bar(1.0, "Installing dependencies")
    print()

    if process.returncode != 0:
        print("Error: Dependency installation failed.\n")
        print("".join(output_lines))
    return process.returncode


def run_tests(project_dir):
    render_bar(0.0, "Running tests")
    process = subprocess.Popen(
        [sys.executable, "-m", "pytest"],
        cwd=str(project_dir),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    output_lines = []
    for line in process.stdout:
        output_lines.append(line)
        match = re.search(r"\[\s*(\d+)%\]", line)
        if match:
            render_bar(int(match.group(1)) / 100, "Running tests")
    process.wait()
    render_bar(1.0, "Running tests")
    print()

    if process.returncode == 0:
        print("All MOMENT tests passed.")
    else:
        print(f"MOMENT tests failed with exit code {process.returncode}.\n")
        for line in output_lines:
            if (
                "FAILED" in line
                or "ERROR" in line
                or "passed" in line
                or "failed" in line
            ):
                print(line, end="")
    return process.returncode


def run_setup(project_dir):
    install_code = install_dependencies(project_dir)
    if install_code != 0:
        return install_code

    print("Collecting tests...")
    test_code = run_tests(project_dir)

    return test_code


def clone_repository(repo_url, project_dir):
    project_dir.parent.mkdir(parents=True, exist_ok=True)
    label = "Downloading MOMENT"
    render_bar(0.0, label)

    process = subprocess.Popen(
        ["git", "clone", "--progress", "--depth", "1", repo_url, str(project_dir)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    output_lines = []
    for line in process.stdout:
        output_lines.append(line)
        # Weight the two slow, percent-reporting stages into a single 0-100% bar.
        match = re.search(r"Receiving objects:\s+(\d+)%", line)
        if match:
            render_bar(int(match.group(1)) / 100 * 0.8, label)
            continue
        match = re.search(r"Resolving deltas:\s+(\d+)%", line)
        if match:
            render_bar(0.8 + int(match.group(1)) / 100 * 0.2, label)
    process.wait()
    render_bar(1.0, label)
    print()

    if process.returncode != 0:
        print("Error: Could not clone the MOMENT repository.\n")
        print("".join(output_lines))
    return process.returncode


def main():
    command = sys.argv[1]
    if command == "run":
        return run_setup(Path(sys.argv[2]))
    if command == "scaffold":
        return scaffold(Path(sys.argv[2]))
    if command == "clone":
        return clone_repository(sys.argv[2], Path(sys.argv[3]))
    raise SystemExit(f"Error: Unknown command '{command}'.")


if __name__ == "__main__":
    sys.exit(main())
