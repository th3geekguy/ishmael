# ishamael
support dump analysis

## Call Me Ishmael
Ishmael, the main character of _Moby Dick_, is the codename for my personal project to create a better analysis tool for our company support dumps.

## Install
### Linux
I have the repository downloaded to ~/Projects/ishmael/ and created the following function in my ~/.bashrc:
```bash
ish()
{
  clear && ~/Projects/ishmael/ish.py | sed -f ~/Projects/ishmael/colors.sed
}
```
