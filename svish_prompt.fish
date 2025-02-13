
# github.com/SanjayVyas

function svish_original_fish_prompt --description "Just in case we fail and user wants original prompt"
    set_color green
    echo -n (whoami)
    set_color white
    echo -n @(echo $hostname | cut -d'.' -f1)' '
    set_color cyan
    echo -n prompt_pwd
    set_color white
    echo -n '> '
end

function fish_prompt
    # Capture g_exit_value immediately
    set -g g_exit_value $status

    # Run the engine / Still have to fix Warp terminal, so drop to simple prompt
    if [ (status --current-filename) = "Standard input" ]
        echo "Probably running under Warp terminal. Unable to locate the exact path of this script"
        set_color green
        echo -n (whoami)
        set_color white
        echo -n @(echo $hostname | cut -d'.' -f1)' '
        set_color cyan
        echo -n (prompt_pwd)
        set_color white
        echo -n '> '
    else
        set -g g_base_path (dirname (realpath (status --current-filename)))
        source $g_base_path/core/svish_engine.fish
        svish_init
        svish_render_left_prompt
    end
end

function fish_right_prompt
    if [ "$g_base_path" != "" ]
        svish_render_right_prompt
        svish_cleanup
    end
end
