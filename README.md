# Ishmael
Ishmael, the main character of _Moby Dick_, is the codename for my personal project to create a better analysis tool for our company support dumps.

# Prequisites
Python3 installedcat
A modern terminal with support for UTF-8 and escape codes for coloring/icons: https://unix.stackexchange.com/questions/303712/how-can-i-enable-utf-8-support-in-the-linux-console

# Install
## Linux
I have the repository downloaded to ~/Projects/ishmael/ and created the following function in my ~/.bashrc:
```bash
ish()
{
  clear && ~/Projects/ishmael/ish.py | sed -f ~/Projects/ishmael/colors.sed
}
```

# Usage
## Basic SD Nodes
From the root of the extracted support dump, run `ish` and ouput of the nodes and states will be printed. For output that wraps and busies your terminal (i.e. output is too long to display on one line -- particularly errors for nodes), I use the following pipe:
```bash
ish | less -SR
```

## Common Patterns
Common node and cluster issues can be gathered from support dump by running the following from the root of extracted support dump directory: (you could also alias this)
```bash
bash ~/Projects/ishmael/sd_patterns.sh
```

Print out is sectioned by 1) search pattern (red), 2) number of occurrences (blue), and 3) last line in file (green for path to file).
TODO: would like to add links and advice for how to fix said error if possible
