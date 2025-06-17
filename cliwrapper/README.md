# cliwrapper

A simple demonstration of creating installable CLI scripts with persistent settings.

## Installation

```bash
cd cliwrapper
./cliwrapper.sh install
```

This will:
- Create a wrapper script in `~/.local/bin/cliwrapper`
- Create a configuration directory at `~/.cliwrapper/`
- Allow you to run `cliwrapper` from anywhere

## Usage

After installation, simply run:
```bash
cliwrapper
```

This will output "Hello, World" (or whatever is in `hello.txt`).

To change the output, edit `hello.txt` in the installation directory.

## Uninstall

```bash
cliwrapper uninstall
```

This will remove the wrapper script and configuration directory, but leave the installation directory intact.

## How It Works

The tool uses a wrapper pattern:
1. The main script (`cliwrapper.sh`) can be installed from anywhere
2. Installation creates a lightweight wrapper in your PATH
3. The wrapper knows where the original script lives via `~/.cliwrapper/config`
4. Settings and data files remain in the original installation directory

This allows the script to be run from anywhere while maintaining access to its data files.