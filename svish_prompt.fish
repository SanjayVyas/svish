
# github.com/SanjayVyas

function fish_prompt
    # Capture svish_exit_value immediately
    set -g svish_exit_value $status
    
    # Run the engine
    set -g svish_base_path (dirname (realpath (status --current-filename)))
    source $svish_base_path/core/svish_engine.fish

    svish_init
    svish_render_left_prompt
end

function fish_right_prompt
    svish_render_right_prompt
    svish_cleanup
end
    