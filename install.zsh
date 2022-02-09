#!/bin/zsh

# source repos

if [[ -z "$REPO_OH_MY_ZSH" ]]; then
    REPO_OH_MY_ZSH="https://github.com/robbyrussell/oh-my-zsh.git"
fi

if [[ -z "$REPO_POWERLINE_FONTS" ]]; then
    REPO_POWERLINE_FONTS="https://github.com/powerline/fonts.git"
fi

if [[ -z "$REPO_KUBE_PS1" ]]; then
    REPO_KUBE_PS1="https://github.com/jonmosco/kube-ps1.git"
fi

if [[ -z "$REPO_ZSH_SUITE" ]]; then
    REPO_ZSH_SUITE="https://github.com/RafalMaleska/shell.git"
fi

if [[ -z "$REPO_KUBECTX" ]]; then
    REPO_KUBECTX="https://github.com/ahmetb/kubectx.git"
fi

if [[ -z "$REPO_ZSH_OUTPUT_HIGHLIGHTING" ]]; then
    REPO_ZSH_OUTPUT_HIGHLIGHTING="https://github.com/l4u/zsh-output-highlighting.git"
fi

if [[ -z "$REPO_ZSH_AUTOSUGGESTIONS" ]]; then
  REPO_ZSH_AUTOSUGGESTIONS="https://github.com/zsh-users/zsh-autosuggestions.git"
fi

if [[ -z "$REPO_FZF" ]]; then
    REPO_FZF="https://github.com/junegunn/fzf.git"
fi

# installation configuration

if [[ -z "$ZSH_SUITE_INSTALL_DIR" ]]; then
    ZSH_SUITE_INSTALL_DIR="$HOME/.zsh-suite"
fi

if [[ -z "$ZSH_SUITE_CUSTOM_DIR" ]]; then
    ZSH_SUITE_CUSTOM_DIR="$ZSH_SUITE_INSTALL_DIR/custom"
fi

if [[ -z "$ZSH_SUITE_CACHE_DIR" ]]; then
    ZSH_SUITE_CACHE_DIR="$ZSH_SUITE_INSTALL_DIR/cache"
fi

if [[ -z "$ZSH_RC_BACKUP_FILE" ]]; then
    ZSH_RC_BACKUP_FILE="~/.zshrc_before_zsh_suite"
fi

function welcome_message () {
    echo "$(date)|starting to install zsh-suite"
}

function end_or_continue() {
    local return_code=$1
    local return_value=$2

    if [[ $1 -eq 0 ]]; then
        echo "ok"
    else
        echo "nok, $return_value"
        exit 1
    fi
}

function precondition_check() {
    local -a needed_tools missing_tools
    local return_code return_value
    needed_tools=( curl git zsh tmux jq )

    echo -n "$(date)|precondition check|"
    for tool in $needed_tools[@]; do
        which $tool &> /dev/null
        return_code=$?
        return_code_all=$(( $return_code_all+$return_code ))
        if [[ $return_code -ne 0 ]]; then
            missing_tools+=( $tool )
        fi
    done
    end_or_continue $return_code_all "missing tools: $(IFS=',';echo "$missing_tools" )"
}

function get_from_git () {
    local app_name=$1 repo=$2 target_dir=$3 return_value
    echo -n "$(date)|starting to git clone $app_name to $target_dir|"
    if [[ ! -d $target_dir ]]; then
        mkdir -p $( dirname $target_dir ) &> /dev/null
        return_value=$(git clone $repo $target_dir 2>&1)
    else
        return_value=$(cd $target_dir; git reset --hard; git pull -r 2>&1)
    fi
    end_or_continue $? "$return_value"
}

function install_zsh_output_highlighting() {
    local return_value

    echo "$(date)|starting to install zsh-output-highlighting"


    target_dir="$ZSH_SUITE_INSTALL_DIR/custom/plugins/zsh-output-highlighting"
    get_from_git "zsh-output-highlighting" "$REPO_ZSH_OUTPUT_HIGHLIGHTING" "$target_dir"
}


function install_kube_ps1 () {
    local return_value target_dir plugin_file_new plugin_file_org stage_sensitiv_code

    echo "$(date)|starting to install kube-ps1"

    target_dir="$ZSH_SUITE_INSTALL_DIR/custom/plugins/kube-ps1"

    plugin_file_org="$ZSH_SUITE_INSTALL_DIR/custom/plugins/kube-ps1/kube-ps1.sh"
    plugin_file_new="$ZSH_SUITE_INSTALL_DIR/custom/plugins/kube-ps1/kube-ps1.plugin.zsh"

    get_from_git "kube-ps1" "$REPO_KUBE_PS1" "$target_dir"

    # insert stage sensitiv context colouring into kube-ps1
    echo -n "$(date)|insert stage sensitiv context colouring into $(basename $plugin_file_new)|"
    stage_sensitiv_code=$(cat <<"EOM"
  # Context

  # if stage awareness is given as json file
  if [[ -n "$KUBE_PS1_STAGE_CONFIG_JSON_FILE" ]] && [[ -f "$KUBE_PS1_STAGE_CONFIG_JSON_FILE" ]]; then
     KUBE_PS1_STAGE_CONFIG_JSON=$( cat $KUBE_PS1_STAGE_CONFIG_JSON_FILE )
  fi

  # if stage awareness is given as json
  if [[ -n "$KUBE_PS1_STAGE_CONFIG_JSON" ]]; then
      KUBE_PS1_STAGE_CONFIG=( $(echo "$KUBE_PS1_STAGE_CONFIG_JSON" | jq -r '.stages[] | (.patterns | join("|"))+":"+.color') )
  fi

  # create stage awareness by changing context color based on configured pattern
  if [[ ${#KUBE_PS1_STAGE_CONFIG[@]} -gt 0 ]]; then
    for stage in "${KUBE_PS1_STAGE_CONFIG[@]}"; do
        if [[ "$KUBE_PS1_CONTEXT" =~ "${stage//:*/}" ]]; then
            export KUBE_PS1_CTX_COLOR=${stage//*:/}
            break
        fi
    done
  fi
EOM
    )

    return_value=$(
        sed -e '/  # Context/,$d' $plugin_file_org > $plugin_file_new && \
        echo "$stage_sensitiv_code" >> $plugin_file_new && \
        sed -n '/  # Context/,$p' $plugin_file_org | grep -v Context >> $plugin_file_new 2>&1 )
    end_or_continue $? "$return_value"
}

function install_powerline_fonts () {
    local return_value target_dir target_os
    echo "$(date)|install powerline fonts for oh-my-zsh"

    target_dir="$ZSH_SUITE_CACHE_DIR/fonts"
    target_os=""

    # check os
    echo -n "$(date)|check os|"
    if [[ -f /etc/os-release ]]; then
    	target_os=$(grep "^NAME=" /etc/os-release |cut -d "=" -f 2 2>/dev/null | sed -e 's/^"//' -e 's/"$//')
    else
	target_os=$(uname)
    fi
    end_or_continue $? "$target_os"
    echo "$(date)|detected os: $target_os"

    if [[ "$target_os" == "Debian GNU/Linux" ]] || [[ "$target_os" == "Ubuntu" ]]; then
        echo "$(date)|need root"
        return_value=$(sudo who 2>&1)
        echo -n "$(date)|run apt-get install fonts-powerline|"
        return_value=$(sudo apt-get install -y fonts-powerline 2>&1)
        end_or_continue $? "$return_value"
   # elif [[ "$target_os" =~ Darwin ]]; then
   #	
    else
        # clone
        get_from_git "powerline fonts" "$REPO_POWERLINE_FONTS" "$target_dir"
    
        # install
        echo -n "$(date)|run install.sh - script|"
        return_value=$(cd $target_dir;./install.sh 2>&1)
        end_or_continue $? "$return_value"

        # clean-up a bit
        echo -n "$(date)|cleanup|"
        return_value=$(rm -rf $target_dir 2>&1)
        end_or_continue $? "$return_value"
    fi 
}

function install_oh_my_zsh () {
    local return_value date_suffix

    echo "$(date)|starting to install oh-my-zsh"
    date_suffix=$(date +%F-%H-%M-%S)

    # get all sources
    get_from_git "oh-my-zsh" "$REPO_OH_MY_ZSH" "$ZSH_SUITE_INSTALL_DIR"

    echo -n "$(date)|save old .zshrc|"
    if [[ -f ~/.zshrc ]]; then
        return_value=$(cp ~/.zshrc ~/.zshrc_before_zsh_suite_${date_suffix} 2>&1)
        end_or_continue $? "$return_value"
    else
        echo "skipped, no ~/.zshrc found"
    fi

    echo -n "$(date)|save old .tmux.conf|"
    if [[ -f ~/.tmux.conf ]]; then
        return_value=$(cp ~/.tmux.conf ~/.tmux.conf_before_zsh_suite_${date_suffix} 2>&1)
        end_or_continue $? "$return_value"
    else
        echo "skipped, no ~/.tmux.conf found"
    fi
}

function install_zsh_suite () {
    local return_value return_code temp_zsh_suite_dir completion_source_dir completion_target_dir
    local kube_ps1_context_config_file_source kube_ps1_context_config_file_target config_path custom_dir

    echo "$(date)|starting to install zsh-suite"

    temp_zsh_suite_dir="$ZSH_SUITE_CACHE_DIR/zsh-suite"

    custom_dir="$temp_zsh_suite_dir/custom"
    template_path_zsh_rc="$temp_zsh_suite_dir/templates/zshrc.zsh-template"
    template_path_tmux_conf_linux="$temp_zsh_suite_dir/templates/tmux.conf-template-linux"
    template_path_tmux_conf_mac="$temp_zsh_suite_dir/templates/tmux.conf-template-mac"
    template_path_tmux_conf_local_mac="$temp_zsh_suite_dir/templates/tmux.conf.local-template-mac"
    kube_ps1_context_config_file_source="$temp_zsh_suite_dir/files/kube-ps1-ctx.json"
    kube_ps1_context_config_file_target="$ZSH_SUITE_CUSTOM_DIR/files/kube-ps1-ctx.json"
    completion_source_dir="$temp_zsh_suite_dir/completions"
    completion_target_dir="$ZSH_SUITE_INSTALL_DIR/completions"

    # clone
    get_from_git "zsh-suite" "$REPO_ZSH_SUITE" "$temp_zsh_suite_dir"

    # install
    echo -n "$(date)|cp custom folder|"

    mkdir -p $ZSH_SUITE_CUSTOM_DIR &> /dev/null

    return_value=$(cp -r $custom_dir/* $ZSH_SUITE_CUSTOM_DIR/ 2>&1)
    end_or_continue $? "$return_value"

    # copy template zshrc
    echo -n "$(date)|cp zshrc template from zsh-suite|"
    return_value=$(cp -f $template_path_zsh_rc ~/.zshrc 2>&1)
    end_or_continue $? "$return_value"

    # copy template .tmux.conf
    echo -n "$(date)|cp .tmux.conf template from zsh-suite|"
    template_path_tmux_conf="$template_path_tmux_conf_linux"
    if [[ "$(uname | tr "[:upper:]" "[:lower:]" )" == "darwin" ]]; then
      return_value=$(cp -f $template_path_tmux_conf_local_mac ~/.tmux.conf.local 2>&1)
      end_or_continue $? "$return_value"
      template_path_tmux_conf="$template_path_tmux_conf_mac"
    fi

    return_value=$(cp -f $template_path_tmux_conf ~/.tmux.conf 2>&1)
    end_or_continue $? "$return_value"

    # reload .tmux.conf
    tmux list-sessions &> /dev/null
    if [ $? -eq 0 ]; then
        echo -n "$(date)|reload .tmux.conf|"
        return_value=$(tmux source-file ~/.tmux.conf 2>&1)
        end_or_continue $? "$return_value"
    fi

    # copy stage sensitive config for kube-ps1
    echo -n "$(date)|cp kube-ps1-ctx.json from zsh-suite|"
    mkdir -p $( dirname $kube_ps1_context_config_file_target ) &> /dev/null
    return_value=$(cp -f $kube_ps1_context_config_file_source $kube_ps1_context_config_file_target 2>&1)
    end_or_continue $? "$return_value"

    # completion
    echo -n "$(date)|cp completion files from repo dir $temp_zsh_suite_dir|"

    mkdir -p $completion_target_dir &> /dev/null

    return_value=""
    return_code=0
    for file in $(ls "$completion_source_dir/"*.zsh ); do
        target_file=$(basename $file)
        if [[ ! "$target_file" =~ "^_" ]]; then
            target_file="_${target_file}"
        fi
        return_value=$(cp -f $file $completion_target_dir/$target_file 2>&1 )
        return_code=$?
        if [[ $return_code -ne 0 ]]; then
            break
        fi
    done
    end_or_continue $return_code "$return_value"

    # clean-up a bit
    echo -n "$(date)|cleanup|"
    return_value=$(rm -rf $temp_zsh_suite_dir 2>&1)
    end_or_continue $? "$return_value"
}

function install_kubectx () {
    local return_value return_code temp_kubectx_dir bin_target_dir completion_source_dir completion_target_dir

    echo "$(date)|starting to install kubectx and kubens"

    kubectx_dir="$ZSH_SUITE_CUSTOM_DIR/repos/kubectx"
    bin_target_dir="$ZSH_SUITE_CUSTOM_DIR/bin"
    completion_source_dir="$kubectx_dir/completion"
    completion_target_dir="$ZSH_SUITE_CUSTOM_DIR/completions"

    # clone
    get_from_git "kubectx" "$REPO_KUBECTX" "$kubectx_dir"

    mkdir -p $bin_target_dir &> /dev/null
    mkdir -p $completion_target_dir &> /dev/null

    # install
    echo -n "$(date)|link scripts from repo dir $kubectx_dir|"
    for file in $(ls "$kubectx_dir/kube"*); do
        target_file=$(basename $file)
        return_value=$(ln -sf $file $bin_target_dir/$target_file 2>&1 )
        return_code=$?
        if [[ $return_code -ne 0 ]]; then
            break
        fi
    done
    end_or_continue $return_code "$return_value"

    # completion
    return_value=""
    return_code=0
    echo -n "$(date)|link completion files from repo dir $kubectx_dir|"
    for file in $(ls "$completion_source_dir/"*.zsh ); do
        target_file=$(basename $file)
        return_value=$(ln -sf $file $completion_target_dir/_$target_file 2>&1 )
        return_code=$?
        if [[ $return_code -ne 0 ]]; then
            break
        fi
    done
    end_or_continue $return_code "$return_value"
}


function install_zsh_autosuggestions () {
    local return_value dir

    dir="$ZSH_SUITE_CUSTOM_DIR/plugins/zsh-autosuggestions"

    # clone
    get_from_git "zsh-autosuggestions" "$REPO_ZSH_AUTOSUGGESTIONS" "$dir"

}

function install_fcf () {
    local return_value

    fzf_dir="$ZSH_SUITE_CUSTOM_DIR/repos/fzf"

    # clone
    get_from_git "fzf" "$REPO_FZF" "$fzf_dir"

    # install
    echo -n "$(date)|install fzf|"
    return_value=$(cd $fzf_dir; ./install --all 2>&1)
    end_or_continue $? "$return_value"

}

function zsh_customizations () {
cat >>~/.zshrc <<EOL
# dont put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoredups

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# add private key to every new shell
ssh-add  ~/.ssh/id_rsa.key &> /dev/null
EOL
}

function () {
    welcome_message
    precondition_check
    install_oh_my_zsh
    install_powerline_fonts
    install_kube_ps1
    install_zsh_suite
    install_zsh_output_highlighting
    install_zsh_autosuggestions
    install_kubectx
    install_fcf
    zsh_customizations
}