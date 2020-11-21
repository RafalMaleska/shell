# ZSH - Suite

Cool suite to pimp up Your Shell


## How to install:

 1. clone the project
 2. run: `./install.zsh`
 3. run: `/bin/zsh` to check if working
 4. go to your home directory: `cd ~`
 5. edit bashrc `vi .bashrc`
 6. add `/bin/zsh` in the first line to save zsh permanently


## Putty Install:
Putty Users should install an special font on their Host machines and add it to Putty.


1. Install font from here [Font](/putty/Meslo%20LG%20L%20DZ%20Regular%20for%20Powerline.ttf)
2. Configure Putty as can be seen on screenshot:

![alt text](/putty/putty_change_font-1024x601.jpeg)

## Mac Install

You need to replace the tools with the GNU ones to make the script running:

```sh
# install
brew install coreutils
brew install binutils
brew install gnu-sed
brew install gnu-getopt

# add to path
PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
PATH="/usr/local/opt/gnu-getopt/bin:$PATH"

# verify
$ sed --help
Usage: sed [OPTION]... {script-only-if-no-other-script} [input-file]...
...
GNU sed home page: <https://www.gnu.org/software/sed/>.
General help using GNU software: <https://www.gnu.org/gethelp/>.
E-mail bug reports to: <bug-sed@gnu.org>.
$ getopt 
getopt: missing optstring argument
Try 'getopt --help' for more information
```

## Font fixes for VS CODE integrated terminal:
Change it a `settings -> Terminal -> Integrated Font Family`
- Ubuntu Linux: `'Ubuntu Mono', 'PowerlineSymbols'` (with quotes)
![Ubuntu font](/vscode/ubuntu.png)
- Mac: `Meslo LG S for Powerline` (without quotes)
![Mac font](/vscode/mac.png)

## Useful commands:

### Kubernetes

| Command | Description                      |
| :-----  | :------------------------------- |
| kc      | To switch between contexts       |
| cl      | Shows list of last 100 git tags  |


## Links

How to make GUI work on Putty: [https://blog.mordsgau.de/oh-my-zsh-with-putty/](https://blog.mordsgau.de/oh-my-zsh-with-putty/)