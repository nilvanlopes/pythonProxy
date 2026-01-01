Recently, I came across a tool called uv. As a long-time pyenv user, I don’t like the way pyenv-win handles virtual environments (yes, I’m a Windows user).

While testing uv, I kind of missed the ability to set a global system Python version, something I was used to as a pyenv user.

Because of that, I created this PowerShell script to work with uv, providing functionality similar to pyenv global <version> by acting as a Python command proxy.

# How to use

Install [uv](https://docs.astral.sh/uv/getting-started/installation/) and a python version with it.

Add this script to top of the user PATH

Open a new powershell, type 'python' if you already have a python installed and working on your system the behaviour is the same, if you don't the script will show a list of python versions installed by uv for you to choose a global version.

## Change the global version of python

use `python change version` and select a version of python installed by `uv`