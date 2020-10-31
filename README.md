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
| kcu     | To update all available contexts |
| cl      | Shows list of last 100 git tags  |

### JDK Switcher

| Command | Description                      |
| :-----  | :------------------------------- |
| jdk     | Lists all installed jdk versions |
| jdk 11  | Switches the jdk to version 11.x |
| jdk 1.8 | Switches the jdk to version 1.8  |

### Kafka Client CLI

Lots of `kafka-*` cli commands are available in your zsh-suite.
Those commands are targeting the kafka-broker, which is associated with the current connected kubernetes namespace (at the moment only dev and test).

Supported commands:
   `kafka-avro-console-consumer`,
   `kafka-avro-console-producer`,
   `kafka-broker-api-versions`,
   `kafka-configs`,
   `kafka-console-consumer`,
   `kafka-console-producer`,
   `kafka-consumer-groups`,
   `kafka-delete-records`,
   `kafka-consumer-perf-test`,
   `kafka-mirror-maker`,
   `kafka-topics`

## Links

How to make GUI work on Putty: [https://blog.mordsgau.de/oh-my-zsh-with-putty/](https://blog.mordsgau.de/oh-my-zsh-with-putty/)