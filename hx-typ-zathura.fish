#!/usr/bin/env fish

# hx-typ-zathura: easily preview your typst documents from Helix!
# This script will automatically find a pdf that matches your
# current Typst document and attempt to open it with Zathura.
# Optionally, it will quit Zathura when you close Helix, and
# uses typst watch to continuously compile the file.
# Run this script with --help for usage info!

# Author: Daniel Fichtinger <daniel@ficd.ca
# License: MIT

argparse q/quiet k/kill-on-exit w/watch h/help -- $argv

if test (count $argv) -eq 0; or set -q _flag_h
    echo "Helper script for opening Typst files from Helix in Zathura."\n
    echo "Usage: (bind the following to a key)"
    echo ':sh hx-typ-zathura.fish [opts] %{buffer_name}'\n
    echo 'Example for config.toml:'
    echo '[keys.normal.space.t]'
    echo "p = ':sh /path/to/hx-typ-zathura.fish -k %{buffer_name}'"\n
    echo "Options:"
    echo "-q/--quiet: Don't \`echo\` on caught errors, return 1 instead."
    echo "-k/--kill-on-exit: Kill Zathura when parent Helix process exits."
    echo "-w/--watch: live preview mode"
    echo "-h/--help: print this screen"\n
    echo 'Author: Daniel Fichtinger <daniel@ficd.ca>'
    echo 'License: MIT'
    return 0
end

# only return status 1 if -q not set
# (if return status != 0, helix will not
# display anything that was echoed to stdout!)
if set -q _flag_q
    set ret 1
else
    set ret 0
end

# only echo if -q not set
function qecho
    if test "$ret" -ne 1
        echo $argv[1]
    end
end

# absolute path of %{buffer_name} file
set -g src_path (path resolve $argv[1])

# check if the user asked to kill zathura on helix exit
# or to watch the pdf
if set -q _flag_k || set -q _flag_w
    if set -q _flag_k
        set kill_parent
    end
    if set -q _flag_w
        set typst_watch
    end
    # traverse up process tree to find caller Helix PID
    # We use this PID to kill zathura if Helix exits first!
    # we only need to define this function
    # inside this scope
    function find_parent_process -a target
        # initialize current_pid as this shell's pid
        set -f current_pid $fish_pid

        # Stop when we reach init (PID 1)
        while test $current_pid -ne 1
            # parent of current_pid
            set parent (ps -o ppid= -p $current_pid | string trim)
            # get parent's command name
            set cmd (ps -o comm= -p $parent | string trim)

            # if the cmd matches our target command we return its pid
            if string match -q -- $target $cmd
                echo "$parent"
                return 0
            end

            set -f current_pid $parent
        end
        return 1
    end

    set parent_pid (find_parent_process hx)
    if test -z "$parent_pid"
        qecho "Couldn't find parent hx process!"
        return $ret
    end
end

# opens zathura, optionally watching for helix closing
function zopen --wraps zathura
    set -f pdf_path $argv[1]
    # this should be set if the user asked to kill
    if set -q kill_parent
        # create background sub-process
        # otherwise helix will hang
        begin
            zathura "$pdf_path" &>/dev/null &
            set zathura_pid $last_pid
            if set -q typst_watch
                typst watch "$src_path" "$pdf_path" &>/dev/null &
            end
            set typst_pid $last_pid
            waitpid -c 1 "$parent_pid" "$zathura_pid"
            kill $zathura_pid &>/dev/null
            if set -q typst_watch
                kill $typst_pid &>/dev/null
            end
        end &
    else
        # user didn't ask for watch, so open normally
        zathura "$pdf_path" &>/dev/null &
    end
    true
end

# try to find the target pdf file searching from root
function find_pdf
    set -l root $argv[1]
    set -l base $argv[2]
    set -l candidate (fd --no-ignore-vcs -F -1 "$base" "$root")
    if test -n "$candidate"
        zopen "$candidate"
    else
        return 1
    end
end

# echo $src_path
# return 0
# exit if not a typst file
if not string match -q '*.typ' $src_path
    qecho "$(path basename $src_path) is not a Typst file!"
    return $ret
end
# change abs path to pdf extension
set -l targ (string replace --regex '\.typ$' '.pdf' $src_path)
# get pdf target's base name
set -l base (path basename --no-extension $src_path).pdf

# if a suitable pdf exists in the same dir, open it
if test -f "$targ"
    zopen "$targ"
else
    # no such file in current dir, time to search!
    # if we're in a git repo, search from its root
    # if we're not, search from cwd
    if git rev-parse --is-inside-work-tree &>/dev/null
        set root (git rev-parse --show-toplevel)
    else
        set root (pwd)
    end
    if not find_pdf "$root" "$base"
        if set -q _flag_q
            return 1
        else
            echo "$base couldn't be found at root $root!"
        end
    end
end
