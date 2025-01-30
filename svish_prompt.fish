

function fish_prompt
    # Capture svish_exit_value immediately
    set -g svish_exit_value $status
    
    # Run the engine
    set -g svp_base_path (dirname (realpath (status --current-filename)))
    source $svp_base_path/core/svish_engine.fish
    source $svp_base_path/core/svish_helpers.fish
    svish_init
    svish_left_prompt
end

function fish_right_prompt
    svish_right_prompt
    svish_cleanup
end
